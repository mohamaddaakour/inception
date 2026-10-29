
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    php8.2-fpm php8.2-mysql libfcgi-bin \
    && rm -rf /var/lib/apt/lists/*

COPY conf/www.conf /etc/php/8.2/fpm/pool.d/www.conf

COPY tools/health.php /opt/inception/health.php

COPY tools/entrypoint.sh /usr/local/bin/entrypoint

RUN chmod 755 /usr/local/bin/entrypoint

EXPOSE 9000

ENTRYPOINT ["/usr/local/bin/entrypoint"]
