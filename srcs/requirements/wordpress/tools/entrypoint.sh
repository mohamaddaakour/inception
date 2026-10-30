#!/bin/sh

# Stop on failed commands and missing variables.
set -eu

# Fail clearly before changing files if required settings are missing.
: "${DB_HOST:?}" "${DB_NAME:?}" "${DB_USER:?}" "${DB_PASSWORD_FILE:?}"
: "${DOMAIN_NAME:?}" "${WP_TITLE:?}" "${WP_ADMIN_USER:?}" "${WP_ADMIN_EMAIL:?}"
: "${WP_USER:?}" "${WP_USER_EMAIL:?}"

# Allow only supported characters and lengths in the two account names.
for name in "$WP_ADMIN_USER" "$WP_USER"; do
    case "$name" in
        ''|*[!a-zA-Z0-9_.-]*) echo 'Invalid WordPress username' >&2; exit 1 ;;
    esac
    [ "${#name}" -le 60 ] || { echo 'WordPress username too long' >&2; exit 1; }
done
# Reject admin anywhere, irrespective of capitalization (also covers administrator).
case "$(printf '%s' "$WP_ADMIN_USER" | tr '[:upper:]' '[:lower:]')" in
    *admin*) echo 'Administrator username must not contain admin' >&2; exit 1 ;;
esac

# Require separate usernames and email addresses for the two accounts.
[ "$WP_ADMIN_USER" != "$WP_USER" ] || { echo 'Use two distinct usernames' >&2; exit 1; }
[ "$WP_ADMIN_EMAIL" != "$WP_USER_EMAIL" ] || { echo 'Use two distinct emails' >&2; exit 1; }

# Keep the same simple password format; never log the contents.
for file in /run/secrets/db_password /run/secrets/wp_admin_password /run/secrets/wp_user_password; do
    password=$(cat "$file")
    case "$password" in
        ''|*[!a-fA-F0-9]*) echo 'Secrets must contain 64 hexadecimal characters' >&2; exit 1 ;;
    esac
    [ "${#password}" -eq 64 ] || { echo 'Invalid secret length' >&2; exit 1; }
done
# Remove the last password from the shell after validation.
unset password

# Create runtime, website, and WP-CLI cache directories.
mkdir -p /run/php /run/credentials /var/www/html /tmp/wp-cli-cache

# Give PHP workers a private, readable copy of the database secret.
install -o www-data -g www-data -m 400 /run/secrets/db_password "$DB_PASSWORD_FILE"

# volume contains only health.php, so seed the WordPress tree.
# On later starts leave existing WordPress files and uploads intact.
if [ ! -f /var/www/html/wp-includes/version.php ]; then
    cp -a /opt/wordpress/. /var/www/html/
fi

# Generate persistent login-session keys once, without calling an external API.
if [ ! -f /var/www/html/.inception-salts.php ]; then
    php -r '
        $code = "<?php\n";
        foreach (["AUTH_KEY", "SECURE_AUTH_KEY", "LOGGED_IN_KEY", "NONCE_KEY",
                  "AUTH_SALT", "SECURE_AUTH_SALT", "LOGGED_IN_SALT", "NONCE_SALT"] as $name) {
            $code .= "define(" . var_export($name, true) . ", "
                  . var_export(bin2hex(random_bytes(64)), true) . ");\n";
        }
        file_put_contents("/var/www/html/.inception-salts.php", $code);
    '
fi
# Configuration always reads secrets and DB settings from runtime files/env.
install -m 640 /opt/inception/wp-config.php /var/www/html/wp-config.php

# Preserve the diagnostic endpoint in the shared website volume.
install -m 644 /opt/inception/health.php /var/www/html/health.php

# Let PHP manage website files and restrict access to authentication salts.
chown -R www-data:www-data /var/www/html /tmp/wp-cli-cache
chmod 640 /var/www/html/.inception-salts.php

# Use a writable cache for WP-CLI commands running as www-data.
export WP_CLI_CACHE_DIR=/tmp/wp-cli-cache

# Execute application provisioning as the same unprivileged user as PHP workers.
wp() { runuser -u www-data -- /usr/local/bin/wp --path=/var/www/html "$@"; }
# Compose waits on MariaDB too, but this bounded check verifies app credentials.
ready=no
for attempt in $(seq 1 30); do
    if php /opt/inception/health.php | grep -q '"status":"ok"'; then
        ready=yes
        break
    fi
    sleep 1
done
[ "$ready" = yes ] || { echo 'Application database connection failed' >&2; exit 1; }

# Install the website and administrator only when WordPress is not installed.
if ! wp core is-installed; then
    # Read passwords from stdin; quiet mode suppresses WP-CLI echoing prompted arguments.
    wp core install --url="https://$DOMAIN_NAME" --title="$WP_TITLE" \
        --admin_user="$WP_ADMIN_USER" --admin_email="$WP_ADMIN_EMAIL" \
        --skip-email --quiet --prompt=admin_password < /run/secrets/wp_admin_password
fi

# Create the subscriber only if missing, preserving an existing password.
if ! wp user get "$WP_USER" --field=ID >/dev/null 2>&1; then
    wp user create "$WP_USER" "$WP_USER_EMAIL" --role=subscriber \
        --quiet --prompt=user_pass --porcelain < /run/secrets/wp_user_password
fi
# Reject unexpected existing roles rather than silently changing existing users.
wp user list --role=administrator --field=user_login | grep -Fxq -- "$WP_ADMIN_USER"
wp user list --role=subscriber --field=user_login | grep -Fxq -- "$WP_USER"

# Hand control to the foreground PHP server so it becomes PID 1.
echo 'WordPress is ready; starting PHP-FPM.'
exec php-fpm8.2 --nodaemonize
