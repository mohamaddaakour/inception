#!/bin/sh
set -eu
: "${DOMAIN_NAME:?DOMAIN_NAME is required}"
mkdir -p /etc/nginx/tls

# Renew missing, expiring, or domain-mismatched local certificates.
if [ ! -s /etc/nginx/tls/site.key ] || [ ! -s /etc/nginx/tls/site.crt ] \
    || ! openssl x509 -in /etc/nginx/tls/site.crt -checkend 86400 -noout >/dev/null 2>&1 \
    || ! openssl x509 -in /etc/nginx/tls/site.crt -checkhost "$DOMAIN_NAME" -noout >/dev/null 2>&1; then
    umask 077
    openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
        -keyout /etc/nginx/tls/site.key -out /etc/nginx/tls/site.crt \
        -subj "/CN=$DOMAIN_NAME" -addext "subjectAltName=DNS:$DOMAIN_NAME" >/dev/null 2>&1
    umask 022
fi

# Replace only the domain and preserve NGINX's own variables.
envsubst '${DOMAIN_NAME}' < /etc/nginx/templates/default.conf.template \
    > /etc/nginx/conf.d/default.conf
nginx -t

# Run the real server as PID 1.
exec nginx -g 'daemon off;'
