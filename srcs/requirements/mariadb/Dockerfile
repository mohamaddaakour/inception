# Uses Debian 12 as our base image.
FROM debian:bookworm

# Download MariaDB.
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        mariadb-server \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Documents that MariaDB normally listens on port 3306.
EXPOSE 3306

# Defines the default process that will run when the container starts.
# 1. mariadbd is the MariaDB server.
# 2. --user=mysql runs the database server as the mysql user.
# 3. --console directs server logging to the console where supported.
CMD ["mariadbd", "--user=mysql", "--console"]
