# Use Debian 12 (Bookworm) as the base image.
# The "slim" version is smaller because it excludes
# many packages that are not necessary for our container.
FROM debian:bookworm-slim

# Update the package lists to get the latest available
# package information from the configured repositories.
#
# Install the MariaDB server inside the Debian image.
# We are not using the official MariaDB Docker image;
# instead, we install MariaDB ourselves.
#
# -y: Automatically answer "yes" to installation prompts.
# --no-install-recommends: Install only required dependencies,
# without optional recommended packages.
#
# &&: Execute the next command only if the previous one succeeds.
#
# rm -rf: Recursively remove files and directories without prompting.
#
# /var/lib/apt/lists/*:
# Remove downloaded APT package lists to reduce image size.
#
# /var/lib/mysql/*:
# Remove existing database files so MariaDB can be initialized
# by our custom entrypoint script.
RUN apt-get update && apt-get install -y --no-install-recommends mariadb-server \
    && rm -rf /var/lib/apt/lists/* /var/lib/mysql/*

# Copy the validate-config.sh script from our project
# into the Docker image.
#
# Source (host): tools/validate-config.sh
# Destination (container): /usr/local/bin/validate-config
#
# This script can be used to validate the MariaDB configuration.
COPY tools/validate-config.sh /usr/local/bin/validate-config

# Copy our custom entrypoint script into the Docker image.
#
# Source (host): tools/entrypoint.sh
# Destination (container): /usr/local/bin/entrypoint
#
# This script will execute when the container starts.
COPY tools/entrypoint.sh /usr/local/bin/entrypoint

# Give both scripts executable permissions.
#
# This allows the scripts to be executed.
RUN chmod 755 /usr/local/bin/validate-config /usr/local/bin/entrypoint

# Document that MariaDB uses TCP port 3306.
#
# EXPOSE does not publish the port to the host machine.
# Other containers on the same Docker network can connect
# to MariaDB on port 3306 if the server is listening there.
EXPOSE 3306

# Define the executable that Docker runs when the
# container starts.
ENTRYPOINT ["/usr/local/bin/entrypoint"]
