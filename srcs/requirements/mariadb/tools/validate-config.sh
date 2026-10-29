#!/bin/sh
set -eu
# Restrict identifiers before inserting them into SQL. No SQL escaping guesswork.
for value in "${DB_NAME:-}" "${DB_USER:-}"; do
    case "$value" in
        ''|*[!a-zA-Z0-9_]*) echo 'Invalid database identifier' >&2; exit 1 ;;
    esac
    [ "${#value}" -le 32 ] || { echo 'Identifier too long' >&2; exit 1; }
done

# openssl rand -hex 32 produces this alphabet and length (256 random bits).
# A final newline is normal for a text secret and command substitution removes it.
password=$(cat "${1:?Provide a secret file path}")
case "$password" in
    ''|*[!a-fA-F0-9]*) echo 'Secret must be 64 hexadecimal characters' >&2; exit 1 ;;
esac
[ "${#password}" -eq 64 ] || { echo 'Secret must be 64 hexadecimal characters' >&2; exit 1; }
# Never print the secret, even on success.
