# Use Debian's previous stable release as the base image.
FROM debian:bookworm-slim

# Refresh package lists and install MariaDB without optional packages.
RUN apt-get update && apt-get install -y --no-install-recommends mariadb-server \
    # Remove package lists and build-time database files to keep initialization at startup.
    && rm -rf /var/lib/apt/lists/* /var/lib/mysql/*

# Copy the script that validates database settings and the password file.
COPY tools/validate-config.sh /usr/local/bin/validate-config

# Copy the script that initializes and starts MariaDB.
COPY tools/entrypoint.sh /usr/local/bin/entrypoint

# Allow both scripts to be executed inside the container.
RUN chmod 755 /usr/local/bin/validate-config /usr/local/bin/entrypoint

# Document MariaDB's internal port without publishing it to the host.
EXPOSE 3306

# Run the startup script whenever the container starts.
ENTRYPOINT ["/usr/local/bin/entrypoint"]
