# Debian 12 is the penultimate stable Debian release.
FROM debian:bookworm

# Download MariaDB.
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        mariadb-server \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /var/lib/mysql \
    && mkdir -p /var/lib/mysql

# COPY copies files from the Docker build context into the image.
COPY conf/mariadb.cnf /etc/mysql/mariadb.conf.d/mariadb.cnf

COPY tools/init.sh /usr/local/bin/init.sh

RUN chmod 755 /usr/local/bin/init.sh

# Documents that MariaDB normally listens on port 3306.
EXPOSE 3306

ENTRYPOINT ["/usr/local/bin/init.sh"]
