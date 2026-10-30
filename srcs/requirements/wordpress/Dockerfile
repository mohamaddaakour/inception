
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    php8.2-fpm php8.2-cli php8.2-mysql php8.2-curl php8.2-gd \
    php8.2-mbstring php8.2-xml php8.2-zip php8.2-intl \
    libfcgi-bin ca-certificates curl unzip util-linux \
    && rm -rf /var/lib/apt/lists/*

# Install the Wordpress CLI and verify against the SHA-256 digest on its official release page.
ARG WP_CLI_VERSION=2.12.0
ARG WP_CLI_SHA256=ce34ddd838f7351d6759068d09793f26755463b4a4610a5a5c0a97b68220d85c
RUN curl -fsSL --retry 3 \
    "https://github.com/wp-cli/wp-cli/releases/download/v${WP_CLI_VERSION}/wp-cli-${WP_CLI_VERSION}.phar" \
    -o /usr/local/bin/wp \
    && echo "${WP_CLI_SHA256}  /usr/local/bin/wp" | sha256sum -c - \
    && chmod 755 /usr/local/bin/wp \
    && wp --allow-root --info

# Download Wordpress
ARG WP_VERSION=7.1.4
# Extract the official ZIP with unzip to preserve long filenames.
# WP-CLI 2.12.0's tar extraction can truncate paths through PHP PharData.
RUN mkdir -p /opt/wordpress \
    && curl -fsSL --retry 3 "https://wordpress.org/wordpress-${WP_VERSION}.zip" \
       -o /tmp/wordpress.zip \
    && unzip -q /tmp/wordpress.zip -d /opt \
    && rm /tmp/wordpress.zip \
    && wp --allow-root --path=/opt/wordpress core verify-checksums \
       --version="${WP_VERSION}" --locale=en_US

COPY conf/www.conf /etc/php/8.2/fpm/pool.d/www.conf

COPY conf/wp-config.php /opt/inception/wp-config.php

COPY tools/health.php /opt/inception/health.php

COPY tools/entrypoint.sh /usr/local/bin/entrypoint

RUN chmod 755 /usr/local/bin/entrypoint

EXPOSE 9000

ENTRYPOINT ["/usr/local/bin/entrypoint"]
