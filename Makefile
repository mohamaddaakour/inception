COMPOSE = docker compose -f srcs/docker-compose.yml

.PHONY: all build up down stop logs status check-storage

all: up

build:
	$(COMPOSE) build mariadb

check-storage:
	bash srcs/tools/check-storage.sh

up: check-storage
	$(COMPOSE) up --build -d mariadb

down:
	$(COMPOSE) down

stop:
	$(COMPOSE) stop

logs:
	$(COMPOSE) logs --tail=100 mariadb

status:
	$(COMPOSE) ps
