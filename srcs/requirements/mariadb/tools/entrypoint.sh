#!/bin/sh

# Stop on unhandled errors (-e) and undefined variables (-u).
set -eu

# Validate the configuration and database password secret.
/usr/local/bin/validate-config /run/secrets/db_password

# Create MariaDB directories and give ownership to the mysql user.
mkdir -p /run/mysqld /var/lib/mysql
chown -R mysql:mysql /run/mysqld /var/lib/mysql

# Initialize MariaDB if its system database does not exist.
if [ ! -d /var/lib/mysql/mysql ]; then
    mariadb-install-db --user=mysql --datadir=/var/lib/mysql \
        --auth-root-authentication-method=socket --skip-test-db >/dev/null
fi

# Run database provisioning only if it has not been completed before.
if [ ! -f /var/lib/mysql/.inception-ready ]; then

    # Start a temporary MariaDB server in the background without TCP networking.
    # $! stores the PID of the background process.
    mariadbd --user=mysql --datadir=/var/lib/mysql --skip-networking &
    temporary_pid=$!

    # Clean up the temporary server when the script exits.
    # Exit with an error if an interrupt or termination signal is received.
    trap 'kill "$temporary_pid" 2>/dev/null || :; wait "$temporary_pid" 2>/dev/null || :' EXIT
    trap 'exit 1' INT TERM

    # Try connecting to MariaDB up to 30 times, waiting 1 second between failures.
    # Stop trying as soon as the database responds successfully.
    ready=no
    for attempt in $(seq 1 30); do
        if mariadb --protocol=socket -uroot -Nse 'SELECT 1' >/dev/null 2>&1; then
            ready=yes
            break
        fi
        sleep 1
    done

    # Stop initialization if MariaDB did not become ready.
    [ "$ready" = yes ] || { echo 'MariaDB initialization timed out' >&2; exit 1; }

    # Read the database password from the Docker secret file.
    password=$(cat /run/secrets/db_password)

        # Create missing resources without resetting existing credentials.
        mariadb --protocol=socket -uroot <<SQL
CREATE DATABASE IF NOT EXISTS \`$DB_NAME\`;
CREATE USER IF NOT EXISTS '$DB_USER'@'%' IDENTIFIED BY '$password';
GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'%';
SQL

    # Remove the password variable from the shell.
    unset password

    # Gracefully stop the temporary MariaDB server.
    # Wait for its process to finish before continuing.
    mariadb-admin --protocol=socket -uroot shutdown
    wait "$temporary_pid"

    # Remove the previously registered cleanup and signal traps.
    trap - EXIT INT TERM

    # Create a marker file indicating that database provisioning is complete.
    # Future container starts will skip the provisioning block.
    touch /var/lib/mysql/.inception-ready
fi

# Start the permanent MariaDB server.
# Run the real server as PID 1 and accept connections on the Docker network.
exec mariadbd --user=mysql --datadir=/var/lib/mysql --bind-address=0.0.0.0
