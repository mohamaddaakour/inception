#!/bin/bash

# This helps our initialization fail visibly rather than continuing after unexpected errors.
set -Eeuo pipefail

# `DATA_DIR` is the directory containing MariaDB's database files.
# `SOCKET` is the Unix socket used for communication with the temporary database server.
DATA_DIR="/var/lib/mysql"
SOCKET="/run/mysqld/mysqld.sock"

# Validate non-secret configuration
: "${MYSQL_DATABASE:?MYSQL_DATABASE is required}"
: "${MYSQL_USER:?MYSQL_USER is required}"

if [[ ! "$MYSQL_DATABASE" =~ ^[a-zA-Z][a-zA-Z0-9_]*$ ]] ||
   [[ ! "$MYSQL_USER" =~ ^[a-zA-Z][a-zA-Z0-9_]*$ ]]; then
    echo "Invalid database name or username" >&2
    exit 1
fi

# Prepare directories
mkdir -p "$DATA_DIR" /run/mysqld
chown -R mysql:mysql "$DATA_DIR" /run/mysqld

# Only initialize a new database
# This checks whether MariaDB's system database directory exists. If it doesn't exist, initialization runs.
# If it exists, initialization is skipped.
if [ ! -d "$DATA_DIR/mysql" ]; then
    echo "Initializing MariaDB..."

    # Read credentials from Docker secrets
    ROOT_PASSWORD="$(cat /run/secrets/db_root_password)"
    DB_PASSWORD="$(cat /run/secrets/db_password)"

    # Validate that our passwords are generated as hexadecimal strings
    if [[ ! "$ROOT_PASSWORD" =~ ^[0-9a-f]+$ ]] ||
       [[ ! "$DB_PASSWORD" =~ ^[0-9a-f]+$ ]]; then
        echo "Invalid secret format" >&2
        exit 1
    fi

    # Initialize MariaDB system tables
    mariadb-install-db \
        --user=mysql \
        --datadir="$DATA_DIR" \
        --auth-root-authentication-method=socket \
        --skip-test-db

    # Start a temporary local-only database server
    mariadbd \
        --user=mysql \
        --datadir="$DATA_DIR" \
        --socket="$SOCKET" \
        --skip-networking &

    # $! stores the PID of the most recently started background process.
    # We need it to stop the temporary MariaDB server after initialization.
    DB_PID=$!

    # Clean up the temporary server if initialization fails
    trap 'kill "$DB_PID" 2>/dev/null || true' EXIT

    # Wait until the temporary server accepts connections
    READY=0
    for attempt in $(seq 1 30); do
        if mariadb --protocol=socket \
            --socket="$SOCKET" \
            -u root -e "SELECT 1" >/dev/null 2>&1; then
            READY=1
            break
        fi
        sleep 1
    done

    if [ "$READY" -ne 1 ]; then
        echo "MariaDB failed to initialize" >&2
        exit 1
    fi

    # Create the database and application user
    mariadb --protocol=socket --socket="$SOCKET" -u root <<SQL

# Creates the WordPress database if it doesn't exist.
CREATE DATABASE IF NOT EXISTS \`$MYSQL_DATABASE\`;

# Creates a dedicated database user.
CREATE USER IF NOT EXISTS '$MYSQL_USER'@'%' IDENTIFIED BY '$DB_PASSWORD';

# Grant all privileges to this user
GRANT ALL PRIVILEGES ON \`$MYSQL_DATABASE\`.* TO '$MYSQL_USER'@'%';

# Configures password authentication for MariaDB's local root account.
ALTER USER 'root'@'localhost' IDENTIFIED BY '$ROOT_PASSWORD';

FLUSH PRIVILEGES;
SQL

    # Stop the temporary server
    kill -TERM "$DB_PID"
    wait "$DB_PID"
    trap - EXIT

    echo "MariaDB initialization completed."
fi

# Replace the shell with the actual database server
exec mariadbd --user=mysql --console