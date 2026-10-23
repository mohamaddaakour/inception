#!/bin/bash

# This helps our initialization fail visibly rather than continuing after unexpected errors.
set -Eeuo pipefail

# `DATA_DIR` is the directory containing MariaDB's database files.
# `SOCKET` is the Unix socket used for communication with the temporary database server.
DATA_DIR="/var/lib/mysql"
SOCKET="/run/mysqld/mysqld.sock"
INITIALIZED="$DATA_DIR/.inception-initialized"
DB_PID=""

fail() {
    echo "MariaDB: $*" >&2
    exit 1
}

# Clean up the temporary server if initialization fails.
# Reap the temporary server on failure or a container stop during initialization.
cleanup() {
    if [[ -n "$DB_PID" ]]; then
        kill -TERM "$DB_PID" 2>/dev/null || true
        wait "$DB_PID" 2>/dev/null || true
    fi
}
trap cleanup EXIT
trap 'exit 143' TERM
trap 'exit 130' INT

# Validate non-secret configuration
: "${MYSQL_DATABASE:?MYSQL_DATABASE is required}"
: "${MYSQL_USER:?MYSQL_USER is required}"

# These restrictions also make interpolation into SQL safe.
[[ "$MYSQL_DATABASE" =~ ^[a-zA-Z][a-zA-Z0-9_]*$ && ${#MYSQL_DATABASE} -le 64 ]] \
    || fail "Invalid database name (use at most 64 letters, digits or underscores, starting with a letter)."
[[ "$MYSQL_USER" =~ ^[a-zA-Z][a-zA-Z0-9_]*$ && ${#MYSQL_USER} -le 80 ]] \
    || fail "Invalid username (use at most 80 letters, digits or underscores, starting with a letter)."
case "${MYSQL_DATABASE,,}" in
    mysql|information_schema|performance_schema|sys)
        fail "MYSQL_DATABASE must not name a system database." ;;
esac
case "${MYSQL_USER,,}" in
    root|mysql) fail "MYSQL_USER must be a dedicated application account." ;;
esac

# Read credentials from Docker secrets
# Secrets stay in local variables and are never included in process arguments.
[[ -r /run/secrets/db_root_password ]] || fail "Missing readable db_root_password secret."
[[ -r /run/secrets/db_password ]] || fail "Missing readable db_password secret."
ROOT_PASSWORD="$(cat /run/secrets/db_root_password)"
DB_PASSWORD="$(cat /run/secrets/db_password)"

# Validate that our passwords are generated as 64-character lowercase hexadecimal strings.
[[ "$ROOT_PASSWORD" =~ ^[0-9a-f]{64}$ && "$DB_PASSWORD" =~ ^[0-9a-f]{64}$ ]] \
    || fail "Secrets must each contain 64 lowercase hexadecimal characters (openssl rand -hex 32)."
[[ "$ROOT_PASSWORD" != "$DB_PASSWORD" ]] || fail "Root and application passwords must be different."

# Prepare directories
mkdir -p "$DATA_DIR" /run/mysqld

# Only initialize a new database
# This checks whether our initialization completion marker exists.
# If it exists and MariaDB's system database directory exists, initialization is skipped.
# If it doesn't exist, initialization runs only when the data directory is empty.
if [[ -f "$INITIALIZED" ]]; then
    [[ -d "$DATA_DIR/mysql" ]] || fail "Initialization marker exists but system tables are missing."
    echo "MariaDB: using the existing database."
else
    # Existing files do not prove that database/user/password setup completed.
    # Preserve them for recovery instead of deleting data or serving a partial setup.
    [[ -z "$(find "$DATA_DIR" -mindepth 1 -maxdepth 1 -print -quit)" ]] \
        || fail "Data exists without an initialization marker. Inspect or restore this volume before retrying; no data was deleted."

    chown -R mysql:mysql "$DATA_DIR" /run/mysqld
    echo "MariaDB: initializing a new database."

    # Initialize MariaDB system tables
    mariadb-install-db \
        --user=mysql \
        --datadir="$DATA_DIR" \
        --auth-root-authentication-method=socket \
        --auth-root-socket-user=root \
        --skip-test-db

    # Start a temporary local-only database server
    # The bootstrap server is reachable only through its local Unix socket.
    mariadbd --user=mysql --datadir="$DATA_DIR" --socket="$SOCKET" --skip-networking &

    # $! stores the PID of the most recently started background process.
    # We need it to stop the temporary MariaDB server after initialization.
    DB_PID=$!

    # Wait until the temporary server accepts connections
    READY=0
    for ((attempt = 0; attempt < 60; attempt++)); do
        kill -0 "$DB_PID" 2>/dev/null || fail "The temporary server exited during initialization."
        if mariadb --protocol=socket --socket="$SOCKET" -u root \
            -e 'SELECT 1' >/dev/null 2>&1; then
            READY=1
            break
        fi
        sleep 1
    done
    [[ "$READY" -eq 1 ]] || fail "Timed out waiting for the temporary server."

    # GRANT treats underscores in database names as wildcards unless escaped.
    GRANT_DATABASE="${MYSQL_DATABASE//_/\\_}"
    # Create the database and application user
    # Suppress SQL errors here: the client can echo a statement containing a password.
    if ! mariadb --protocol=socket --socket="$SOCKET" -u root >/dev/null 2>&1 <<SQL
# Creates the WordPress database during first-time initialization.
CREATE DATABASE \`$MYSQL_DATABASE\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

# Creates a dedicated database user.
CREATE USER '$MYSQL_USER'@'%' IDENTIFIED BY '$DB_PASSWORD';

# Grant all privileges on the WordPress database only to this user.
GRANT ALL PRIVILEGES ON \`$GRANT_DATABASE\`.* TO '$MYSQL_USER'@'%';

# Configures password authentication for MariaDB's local root account.
ALTER USER 'root'@'localhost' IDENTIFIED BY '$ROOT_PASSWORD';
SQL
    then
        fail "Database/account setup failed. The volume is incomplete; no completion marker was written."
    fi

    # Stop the temporary server
    kill -TERM "$DB_PID"
    wait "$DB_PID"
    DB_PID=""
    # Mark success only after SQL setup and a clean bootstrap shutdown.
    touch "$INITIALIZED"
    echo "MariaDB: initialization completed."
fi

unset ROOT_PASSWORD DB_PASSWORD
chown -R mysql:mysql "$DATA_DIR" /run/mysqld
trap - EXIT TERM INT
# Replace the shell with the actual database server
# MariaDB becomes PID 1 and receives Docker's stop signal directly.
exec mariadbd --user=mysql --datadir="$DATA_DIR" --socket="$SOCKET" --console
