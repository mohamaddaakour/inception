# Use the local environment and Compose configuration.
COMPOSE = docker compose --env-file srcs/.env -f srcs/docker-compose.yml
.DEFAULT_GOAL := up
.PHONY: all up down stop status logs config

# Build and start the complete application.
all: up

# Build images and wait for the services to become ready.
up:
	$(COMPOSE) up --build -d --wait --wait-timeout 240

# Remove containers and the network while retaining named volumes.
down:
	$(COMPOSE) down

# Stop containers without removing them.
stop:
	$(COMPOSE) stop

# Display service health and published ports.
status:
	$(COMPOSE) ps

# Display recent service logs.
logs:
	$(COMPOSE) logs --tail=100

# Validate the resolved Compose configuration.
config:
	$(COMPOSE) config --quiet
