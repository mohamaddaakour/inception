#!/bin/sh

# Stop the script if an unhandled command fails (-e)
# or if an undefined variable is used (-u).
set -eu

# Create the required directories if they do not exist.
# /run/php: Stores PHP-FPM runtime files.
# /run/credentials: Stores the database password used by PHP workers.
# /var/www/html: Stores WordPress website files.
mkdir -p /run/php /run/credentials /var/www/html

# Copy the database password from the Docker secret to a runtime file.
#
# install: Copy a file while setting its ownership and permissions.
# -o www-data: Set the file owner to www-data.
# -g www-data: Set the file group to www-data.
# -m 400: Give read permission only to the file owner.
#
# This allows PHP-FPM workers running as www-data to read the password
# without making it accessible to other non-root users.
install -o www-data -g www-data -m 400 /run/secrets/db_password /run/credentials/db_password

# Copy the PHP health-check file into the website directory.
#
# -o www-data: Set the file owner to www-data.
# -g www-data: Set the file group to www-data.
# -m 644: Owner can read/write; group and others can only read.
#
# This file is used to verify that PHP-FPM is working.
# Other WordPress files and uploads are left unchanged.
install -o www-data -g www-data -m 644 /opt/inception/health.php /var/www/html/health.php

# Start the PHP-FPM server.
#
# exec: Replace the shell process with PHP-FPM.
# php-fpm8.2: Start PHP FastCGI Process Manager version 8.2.
# --nodaemonize: Keep PHP-FPM running in the foreground.
#
# This makes PHP-FPM the container's main process (PID 1),
# allowing Docker to manage its lifecycle and stop signals.
exec php-fpm8.2 --nodaemonize
