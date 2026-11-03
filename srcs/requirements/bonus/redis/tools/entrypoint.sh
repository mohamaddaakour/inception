#!/bin/sh

# Fail on errors and unset variables.
set -eu

# Default to the Compose secret path when no override is provided.
: "${REDIS_PASSWORD_FILE:=/run/secrets/redis_password}"

# Stop immediately when the password secret file is missing.
if [ ! -f "$REDIS_PASSWORD_FILE" ]; then
    echo "Redis secret file not found: $REDIS_PASSWORD_FILE" >&2
    exit 1
fi

# Read the password and require exactly 64 hexadecimal characters.
password=$(cat "$REDIS_PASSWORD_FILE")
case "$password" in
    ''|*[!a-fA-F0-9]*) echo 'Redis secret must contain 64 hexadecimal characters' >&2; exit 1 ;;
esac
[ "${#password}" -eq 64 ] || { echo 'Invalid Redis secret length' >&2; exit 1; }

# Here, we configured Redis to use a password without passing the password directly as a command-line argument.
# Copy the configuration file
cp /etc/redis/redis.conf /tmp/redis.conf

# Add the password to the copied configuration
printf "\nrequirepass %s\n" "$password" >> /tmp/redis.conf

# Remove the password from the shell after writing the runtime configuration.
unset password

# Start redis
exec redis-server /tmp/redis.conf --daemonize no
