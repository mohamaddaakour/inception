#!/bin/sh
set -eu
# Restrict identifiers before inserting them into SQL. No SQL escaping guesswork.
for value in "${DB_NAME:-}" "${DB_USER:-}"; do
    case "$value" in
        ''|*[!a-zA-Z0-9_]*) echo 'Invalid database identifier' >&2; exit 1 ;;
    esac
    [ "${#value}" -le 32 ] || { echo 'Identifier too long' >&2; exit 1; }
done

# Accept the generated secret format before interpolating SQL.
# Protect system accounts and schemas from accidental application configuration.
case "$DB_USER" in root|mysql|mariadb_sys) echo 'Reserved SQL user' >&2; exit 1 ;; esac
case "$DB_NAME" in mysql|sys|information_schema|performance_schema) echo 'Reserved database' >&2; exit 1 ;; esac
password=$(cat "${1:?Provide a secret file path}")
case "$password" in
    ''|*[!a-fA-F0-9]*) echo 'Secret must be 64 hexadecimal characters' >&2; exit 1 ;;
esac
[ "${#password}" -eq 64 ] || { echo 'Secret must be 64 hexadecimal characters' >&2; exit 1; }
# Never print the secret, even on success.
