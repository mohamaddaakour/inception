# MariaDB — roadmap step 6

This stage builds MariaDB from Debian Bookworm, initializes a database and its
application account, and persists the data in a Docker named volume. WordPress
and NGINX are implemented in later roadmap steps.

## Local configuration

Create `srcs/.env` from `srcs/.env.example` if it does not already exist. Set
`MYSQL_DATABASE` and `MYSQL_USER` to the desired database and application user.
Names start with a letter and contain only letters, digits or underscores. The
maximum lengths are 64 and 80 characters respectively. System database names
and the users `root` and `mysql` are reserved.

The two local files `secrets/db_password.txt` and
`secrets/db_root_password.txt` must each contain a different 64-character
lowercase hexadecimal password. On first setup, generate each password with
`openssl rand -hex 32` under `umask 077`. Keep these files mode `600` and outside
Git. Existing credentials must be preserved when rebuilding or restarting.
Compose mounts them as `/run/secrets/db_password` and
`/run/secrets/db_root_password`. It does not bake them into the image.

Changing the files or `.env` does not update an existing database's users or
passwords. Such changes require an explicit SQL migration. Connections will fail
if the supplied credentials no longer match the database.

## Host storage prerequisite

The subject requires real named volumes beneath `/home/<login>/data` and forbids
bind mounts for database and website storage. This project uses an ordinary
Docker named volume and puts Docker's data directory beneath that location.

On the project VM, merge the following setting into `/etc/docker/daemon.json`,
replacing `<login>` with your learner login:

```json
{
  "data-root": "/home/<login>/data/docker"
}
```

This is a host-wide Docker setting. Configure it before creating project volumes.
If the VM already has Docker data, back up and plan its migration before changing
the setting; changing `data-root` alone does not move existing volumes or images.
Preserve any other settings already present in the configuration file, and restart
Docker after changing it. The repository does not modify the host automatically.

Run `make check-storage` to verify the setting. By default it uses your OS username
(or the invoking user's username when run through `sudo`);
use `LEARNER_LOGIN=your_42_login make check-storage` if your learner login differs.
Use that same environment variable for `make`.
With sudo, pass an explicit override as `sudo LEARNER_LOGIN=your_42_login make check-storage`.

With the default project name, the database volume is `inception_mariadb_data`.
Its host mountpoint should be
`/home/<login>/data/docker/volumes/inception_mariadb_data/_data`.
Inspect the actual mountpoint with `docker volume inspect inception_mariadb_data`.

## Build and operate

Run these commands from the repository root, as a user with access to Docker:

```bash
make build          # Build the custom MariaDB image
make                # Check storage, build, and start the container in the background
make status
make logs
make stop           # Gracefully stop the service
make down           # Remove containers and the network, preserving the database
```

No database port is published on the host. Later, WordPress connects to
`mariadb:3306` on the `inception` bridge network with the application credentials.
The application account has privileges only on `MYSQL_DATABASE`. The root
account is local and uses the separate root password.

For a root SQL session, run:

```bash
docker compose -f srcs/docker-compose.yml exec mariadb mariadb -uroot -p
```

Enter the root secret at the prompt. Avoid placing passwords in command arguments.

## Initialization and failures

The Dockerfile empties `/var/lib/mysql` during image building. Runtime startup
never deletes database data. With an empty volume, the entrypoint creates system
tables, runs a temporary server with networking disabled, creates the application
database/account, and configures the root password. It writes
`.inception-initialized` only after successful SQL setup and clean shutdown of the
temporary server. The main MariaDB server then runs as PID 1.

Subsequent starts preserve the database. Docker restarts the container after a
crash. Starting the container does not guarantee that database initialization has
finished; inspect the logs and verify a SQL connection before using the database.

If data exists without the completion marker, startup stops with a clear error.
This includes interrupted first initialization and volumes created by older
versions of the script. Inspect and back up the volume, then restore a known-good
backup or repair the database deliberately. Do not add a marker blindly. A fresh
volume is an option only after confirming the existing data is disposable.

## Verification

Run `make status` and `make logs` to check that the container stays running and
MariaDB finishes startup. Open the root SQL session shown above, then run
`SHOW DATABASES;` and `SELECT User, Host FROM mysql.user;` to inspect the database
and accounts. Verify an application-user connection with its own password too.

To check persistence, create a temporary table with a known row in your application
database, run `make down` followed by `make`, and confirm the row remains. Remove
the temporary table afterward. Container removal must preserve the named volume.

These manual checks require an accessible Docker daemon and the host storage
setting above. Bash syntax and Compose validation alone cannot verify database behavior.

## References

- [MariaDB option files](https://mariadb.com/docs/server/server-management/install-and-upgrade-mariadb/configuring-mariadb/configuring-mariadb-with-option-files)
- [MariaDB system-table initialization](https://mariadb.com/docs/server/clients-and-utilities/deployment-tools/mariadb-install-db)
- [Docker named volumes](https://docs.docker.com/engine/storage/volumes/)
- [Docker data directory](https://docs.docker.com/engine/daemon/#daemon-data-directory)
