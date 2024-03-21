# Set default no argument goal to help
.DEFAULT_GOAL := help

# Ensure that errors don't hide inside pipes
SHELL         = /bin/bash
.SHELLFLAGS   = -o pipefail -c

# Setup variables
PROJECT_NAME?=$(shell cat .env | grep -v ^\# | grep COMPOSE_PROJECT_NAME | sed 's/.*=//')
APP_BASEURL?=$(shell cat .env | grep VIRTUAL_HOST | sed 's/.*=//')
APPS_NETWORK?=$(shell cat .env | grep -v ^\# | grep APPS_NETWORK | sed 's/.*=//')

# Every command is a PHONY, to avoid file naming confliction -> strengh comes from good habits!
.PHONY: help
help:
	@echo "=================================================================================="
	@echo "        Secure HTTPS reverse proxy based on SWAG, Portainer and Authelia  "
	@echo "       >> https://github.com/elasticlabs/https-nginx-proxy-docker-compose"
	@echo " "
	@echo " Hints for developers:"
	@echo "  make up-hub           # Brings the hub to life!"
	@echo "  make up-apps          # Brings the SDI apps to life!"
	@echo "  make up-api           # Brings the SDI API to life!"
	@echo "  "
	@echo "  make set-hosts    # Replaces your hosts file with the generated one"
	@echo "  make cleanup      # /!\ Remove images, containers, volumes & data"
	@echo "  make update           # Update the whole stack"
	@echo "=================================================================================="

.PHONY: build
build:
	# Network creation if not done yet
	@echo "[INFO] Create ${APPS_NETWORK} network if doesn't already exist"
	docker network inspect ${APPS_NETWORK} >/dev/null 2>&1 || docker network create --subnet=172.24.0.0/16 --driver bridge ${APPS_NETWORK}
	#
	# Build the stack
	@echo "[INFO] Building the stack"
	docker compose -f docker-compose.yml build
	@echo "[INFO] Build OK."

.PHONY: up-hub
up-hub: build
	@echo "[INFO] Bringing up the Hub"
	docker compose -f docker-compose.yml up -d --remove-orphans nginx-proxy

.PHONY: up-apps
sdi-up: build
	@echo "[INFO] Bringing up the SDI Apps"
	docker compose -f docker-compose.yml up -d --remove-orphans apps-proxy

.PHONY: up-api
up-api: build
	@echo "[INFO] Bringing up the SDI API apps"
	docker compose -f docker-compose.yml up -d --remove-orphans api-proxy

.PHONY: hub-set-hosts
hub-set-hosts:
	@echo "[INFO] Updating system hosts file (sudo mode)"
	@echo "172.24.0.2	ensg-sdi.docker	api.ensg-sdi.docker	hub.ensg-sdi.docker" > /etc/hosts 

.PHONY: cleanup
cleanup:
	@echo "[INFO] Bringing down the proxy HUB"
	docker compose -f docker-compose-hub.yml down --remove-orphans
	@echo "[INFO] Bringing down the SDI stack"
	docker compose -f docker-compose-hub.yml down --remove-orphans
	# Delete all hosted persistent data available in volumes
	@echo "[INFO] Cleaning up static volumes"
	#docker volume rm -f $(PROJECT_NAME)_ssl-certs
	#docker volume rm -f $(PROJECT_NAME)_portainer-data
	@echo "[INFO] Cleaning up containers & images"
	docker system prune -a

.PHONY: pull
pull: 
	docker compose -f docker-compose.yml pull

.PHONY: update
update: pull up-hub up-apps up-api wait
	docker image prune -a

.PHONY: wait
wait: 
	sleep 7
