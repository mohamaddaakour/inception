# Compose resolves relative paths from srcs/docker-compose.yml.
COMPOSE = docker compose --env-file srcs/.env -f srcs/docker-compose.yml

.DEFAULT_GOAL := up

.PHONY: up down stop status logs config

up:
	$(COMPOSE) up --build -d --wait --wait-timeout 180
down:
	$(COMPOSE) down
stop:
	$(COMPOSE) stop
status:
	$(COMPOSE) ps
logs:
	$(COMPOSE) logs --tail=100
config:
	$(COMPOSE) config --quiet
