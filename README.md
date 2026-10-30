*This project has been created as part of the 42 curriculum by mdaakour.*

# Inception

## Description

Inception runs a WordPress website inside a Linux virtual machine using three custom Docker images: NGINX, WordPress with PHP-FPM, and MariaDB. NGINX is the only public entrypoint, on HTTPS port 443 with TLS 1.2 or TLS 1.3. Two named volumes preserve the database and website files.

## Instructions

Install Docker Engine, the Compose plugin, GNU Make, curl, and OpenSSL inside the VM. Configure Docker's `data-root` as `/home/<login>/data` before creating project volumes; see [DEV_DOC.md](DEV_DOC.md).

Create local configuration and password files:

```sh
cp -n srcs/.env.example srcs/.env
mkdir -p srcs/secrets
chmod 700 srcs/secrets
(umask 077; test -e srcs/secrets/db_password.txt || openssl rand -hex 32 > srcs/secrets/db_password.txt)
(umask 077; test -e srcs/secrets/wp_admin_password.txt || openssl rand -hex 32 > srcs/secrets/wp_admin_password.txt)
(umask 077; test -e srcs/secrets/wp_user_password.txt || openssl rand -hex 32 > srcs/secrets/wp_user_password.txt)
chmod 600 srcs/.env srcs/secrets/*.txt
```

Edit `srcs/.env` with your domain, database settings, and two distinct WordPress account identities. The administrator username must not contain `admin` in any capitalization. Preserve existing secrets when restarting an installed site.

On the browsing machine, map `<VM-IP> <login>.42.fr` in the hosts file. Use `127.0.0.1` when the browser runs inside the Docker VM.

```sh
make config
make up
make status
```

Open `https://<login>.42.fr` and `/wp-admin/`. Accept a local exception for the self-signed certificate after verifying the address. Read passwords privately from the ignored `srcs/secrets/` files.

```sh
make logs
make stop
make up
make down
```

`stop` retains containers; `down` removes containers and their network while keeping named volumes. Do not add `-v` if you want to preserve data. [USER_DOC.md](USER_DOC.md) describes daily operation and verification.

## Project description

The root Makefile builds the images through `srcs/docker-compose.yml`. Each service has its own Dockerfile under `srcs/requirements/` and a locally built image named after the service, tagged `inception`. Only the allowed `debian:bookworm-slim` base is pulled. Bookworm is Debian's previous stable release at implementation time; consult [Debian releases](https://www.debian.org/releases/) before changing the base.

NGINX terminates HTTPS and forwards PHP requests to PHP-FPM over the explicit Compose bridge network. WordPress connects to MariaDB over that network. No database or PHP port is published. The daemons run in the foreground as PID 1 and use restart policies. Readiness retries are finite.

WordPress and WP-CLI versions are pinned in the WordPress Dockerfile. The CLI download is checked with SHA-256; WordPress files are checked against official core checksums. The official ZIP avoids a known tar-extraction issue with long filenames. Existing accounts, passwords, content, and authentication salts survive ordinary startup. The administrator and subscriber are WordPress accounts, distinct from the application's SQL account. Root SQL access uses local Unix-socket authentication.

| Comparison | Design choice |
|---|---|
| Virtual machines vs Docker | A VM runs its own kernel and OS. Containers share the host kernel while isolating services. These containers run inside the required VM. |
| Secrets vs environment variables | `.env` stores non-secret configuration. Compose secrets mount password files only into services that need them. Local Compose secrets are file mounts, so host permissions still matter. |
| Docker network vs host network | The bridge provides isolation and service-name DNS. Host networking shares the host network namespace and is forbidden here. Only NGINX publishes port 443. |
| Docker volumes vs bind mounts | Named volumes are managed by Docker and survive container replacement. Bind mounts expose chosen host directories directly. Both persistent stores here are ordinary named volumes without bind-backed driver options. |

Docker stores the named volumes beneath `/home/<login>/data/volumes/`. The database volume appears at `/var/lib/mysql` in MariaDB; the website volume appears at `/var/www/html` in WordPress and read-only in NGINX. Each mount accesses the same underlying data, not a synchronized copy.

## Resources

- [Docker installation](https://docs.docker.com/engine/install/debian/)
- [Docker daemon storage](https://docs.docker.com/engine/daemon/)
- [Docker volumes](https://docs.docker.com/engine/storage/volumes/)
- [Compose startup ordering](https://docs.docker.com/compose/how-tos/startup-order/)
- [Docker restart policies](https://docs.docker.com/engine/containers/start-containers-automatically/)
- [NGINX HTTPS configuration](https://nginx.org/en/docs/http/configuring_https_servers.html)
- [PHP-FPM configuration](https://www.php.net/manual/en/install.fpm.configuration.php)
- [MariaDB initialization](https://mariadb.com/docs/server/clients-and-utilities/deployment-tools/mariadb-install-db)
- [WordPress releases](https://wordpress.org/download/releases/)
- [WP-CLI installation](https://make.wordpress.org/cli/handbook/guides/installing/)
- [WP-CLI extraction issue](https://github.com/wp-cli/core-command/issues/347)

AI assisted with Dockerfiles, startup scripts, documentation and troubleshooting.
