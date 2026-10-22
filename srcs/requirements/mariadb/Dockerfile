# Uses Debian 12 (stable version) as our base image.
FROM debian:bookworm

# Download MariaDB.
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        mariadb-server \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY tools/init.sh /usr/local/bin/init.sh

RUN chmod 755 /usr/local/bin/init.sh

# Documents that MariaDB normally listens on port 3306.
EXPOSE 3306

ENTRYPOINT ["/usr/local/bin/init.sh"]