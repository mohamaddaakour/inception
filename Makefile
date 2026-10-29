# Define the Compose command, using our environment file and stack configuration.
COMPOSE = docker compose --env-file srcs/.env -f srcs/docker-compose.yml

# Run the up target when make is called without a target.
.DEFAULT_GOAL := up

# Treat these names as commands, even if files with the same names exist.
.PHONY: up down stop status logs config

# Build and start the application using docker-compose.
up:
	$(COMPOSE) up --build -d --wait --wait-timeout 180

# Remove the application's containers and network while keeping named volumes.
down:
	$(COMPOSE) down

# Stop the application while keeping its containers for later reuse.
stop:
	$(COMPOSE) stop

# Display the current state of the application.
# List the service active containers, their status, and their ports.
status:
	$(COMPOSE) ps

# Display recent application logs.
logs:
	$(COMPOSE) logs --tail=100

# Check the Compose configuration before starting the application.
config:
	$(COMPOSE) config --quiet
