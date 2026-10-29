FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx openssl gettext-base curl \
    && rm -rf /var/lib/apt/lists/* /etc/nginx/sites-enabled/default

COPY conf/default.conf.template /etc/nginx/templates/default.conf.template

COPY tools/entrypoint.sh /usr/local/bin/entrypoint

RUN chmod 755 /usr/local/bin/entrypoint

EXPOSE 443

ENTRYPOINT ["/usr/local/bin/entrypoint"]
