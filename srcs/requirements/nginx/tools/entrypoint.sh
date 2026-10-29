#!/bin/sh

# Stop on unhandled errors (-e) and undefined variables (-u).
set -eu

# Ensure DOMAIN_NAME is defined and not empty.
: "${DOMAIN_NAME:?DOMAIN_NAME is required}"

# Create the directory for TLS certificates and keys.
mkdir -p /etc/nginx/tls

# Generate a self-signed certificate and private key if either is missing or empty.
if [ ! -s /etc/nginx/tls/site.key ] || [ ! -s /etc/nginx/tls/site.crt ]; then

    # Restrict permissions on newly created files.
    umask 077

    # Generate a 2048-bit RSA private key and a self-signed
    # certificate valid for 365 days using DOMAIN_NAME.
    openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
        -keyout /etc/nginx/tls/site.key -out /etc/nginx/tls/site.crt \
        -subj "/CN=$DOMAIN_NAME" -addext "subjectAltName=DNS:$DOMAIN_NAME" >/dev/null 2>&1

    # Restore normal default file permissions.
    umask 022
fi

# Replace only DOMAIN_NAME in the NGINX configuration template.
# Preserve NGINX variables such as $document_root.
envsubst '${DOMAIN_NAME}' < /etc/nginx/templates/default.conf.template \
    > /etc/nginx/conf.d/default.conf

# Validate the generated NGINX configuration.
nginx -t

# Start NGINX in the foreground as the container's main process.
exec nginx -g 'daemon off;'
