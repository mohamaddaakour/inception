# User and administrator guide

## Provided services

The stack provides a WordPress website and administration dashboard. NGINX accepts HTTPS connections, PHP-FPM executes WordPress, and MariaDB stores the database. Only port 443 is published. No bonus services are included.

## Start and stop

Run from the repository root inside the VM:

```sh
make up
make status
make stop
make up
make down
```

`up` builds the images and waits for service readiness. `stop` retains containers; `down` removes containers and the network but retains both named volumes. Startup preserves existing accounts and passwords. Do not use `down -v` or delete volumes during routine troubleshooting.

## Website and administration

Read `DOMAIN_NAME` in `srcs/.env`. For this learner's domain:

- Website: `https://mdaakour.42.fr/`
- Administration: `https://mdaakour.42.fr/wp-admin/`

Map the domain to the VM IP in the browsing machine's hosts file. Use `127.0.0.1` only when Firefox and Docker run in the same VM. Enter `https://` explicitly; the project does not serve port 80.

The certificate is self-signed. Verify the domain and VM address, then accept a local browser exception. Replacing the NGINX container generates a new certificate and may require another exception.

## Credentials

Non-secret account names and emails are in `srcs/.env`:

- `WP_ADMIN_USER`: administrator, able to publish and manage the site.
- `WP_USER`: subscriber, able to log in and edit their own profile.

Read initial passwords privately from:

| File | Purpose |
|---|---|
| `srcs/secrets/wp_admin_password.txt` | WordPress administrator password |
| `srcs/secrets/wp_user_password.txt` | WordPress subscriber password |
| `srcs/secrets/db_password.txt` | Application's SQL connection password |

The secret directory should have permission `700`; password files and `.env` should have permission `600`. They are ignored by Git. Never share them in commits, screenshots, or logs.

Change WordPress passwords through the user's profile or the administrator's Users screen. Local secret files do not automatically mirror dashboard password changes; keep your private credential record current. Rebuilding containers does not reset existing passwords. Editing usernames in `.env` does not rename installed accounts.

Do not replace the SQL password file alone: an existing SQL account must be explicitly updated to the same password. See DEV_DOC.md. Root SQL access uses the local Unix socket inside the MariaDB container.

## Check operation

```sh
make config
make status
make logs
```

All three services should be healthy. In a browser:

1. Sign in as administrator and publish a post.
2. Upload a small image and confirm it appears publicly.
3. Confirm Users lists an administrator and subscriber.
4. Sign in as subscriber and confirm publishing, plugin installation, and user management are unavailable.
5. Run `make down`, then `make up`; confirm both accounts, the post, and image remain.

`3306/tcp` and `9000/tcp` in status output are internal ports when no host mapping is shown. NGINX alone should show `443->443`.

For connection problems, check the VM IP, hosts entry, port 443, and service status. For certificate warnings, verify the address before accepting the local exception. For HTTP 502/503 errors, inspect application/database logs. Do not delete persistent storage to resolve a configuration error.
