FROM debian:bookworm-slim

# Install Redis Server
RUN apt-get update && apt-get install -y --no-install-recommends \
    redis-server \
    && rm -rf /var/lib/apt/lists/*

COPY conf/redis.conf /etc/redis/redis.conf
COPY tools/entrypoint.sh /usr/local/bin/entrypoint

RUN chmod 755 /usr/local/bin/entrypoint

# Expose the internal port for the Docker bridge network; never published to host.
EXPOSE 6379

ENTRYPOINT ["/usr/local/bin/entrypoint"]