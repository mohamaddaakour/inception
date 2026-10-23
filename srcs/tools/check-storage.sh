#!/bin/bash
set -euo pipefail

# Under sudo, use the invoking user's login rather than root.
LEARNER_LOGIN="${LEARNER_LOGIN:-${SUDO_USER:-$(id -un)}}"
[[ "$LEARNER_LOGIN" =~ ^[a-zA-Z0-9_-]+$ ]] || {
    echo "Invalid LEARNER_LOGIN." >&2
    exit 1
}
EXPECTED="/home/$LEARNER_LOGIN/data"
DOCKER_ROOT="$(docker info --format '{{.DockerRootDir}}')"
case "$DOCKER_ROOT" in
    "$EXPECTED"|"$EXPECTED"/*)
        printf 'Docker stores named volumes beneath %s.\n' "$DOCKER_ROOT" ;;
    *)
        printf 'Docker data-root is %s; the subject requires volume data beneath %s.\n' "$DOCKER_ROOT" "$EXPECTED" >&2
        echo 'Configure Docker on the project VM as described in docs/mariadb.md before starting.' >&2
        exit 1 ;;
esac
