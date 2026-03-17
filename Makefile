SHELL := /bin/bash
.DEFAULT_GOAL := help

COMPOSE := docker compose
SCRIPTS := scripts

# Detect mode: marzban if MARZBAN=1 or docker-compose has marzban image
MODE := standalone
ifneq ($(MARZBAN),)
  MODE := marzban
endif

.PHONY: help setup install install-deps check-deps check-root env-file \
        init up down restart logs status diagnostics \
        add remove list qr rotate-keys change-sni change-sid gen-keys admin \
        backup restore test-connection clean

# ================================================================
# HELP
# ================================================================
help:
	@echo ""
	@echo "  VLESS Reality VPN"
	@echo "  ================="
	@echo ""
	@echo "  Standalone (default):"
	@echo "    sudo make setup             All-in-one (deps + config + start)"
	@echo "    make install                Generate config + start Xray"
	@echo "    make install-deps           Install Docker, jq, openssl, ufw (sudo)"
	@echo ""
	@echo "  Marzban (web panel):"
	@echo "    sudo make setup MARZBAN=1   All-in-one with Marzban panel"
	@echo "    make install MARZBAN=1      Start with Marzban panel"
	@echo "    make admin MARZBAN=1        Create Marzban admin user"
	@echo ""
	@echo "  Docker:"
	@echo "    make up                     Start container"
	@echo "    make down                   Stop container"
	@echo "    make restart                Restart container"
	@echo "    make logs                   Show logs"
	@echo "    make status                 Container + port status"
	@echo "    make diagnostics            Full diagnostics (standalone)"
	@echo ""
	@echo "  Clients (standalone only):"
	@echo "    make list                   Show all clients with links"
	@echo "    make add                    Add a client"
	@echo "    make remove UUID=<uuid>     Remove a client"
	@echo "    make qr                     Show QR codes for all clients"
	@echo "    make qr N=3                 Show QR for client #3"
	@echo ""
	@echo "  Security (standalone only):"
	@echo "    make rotate-keys            Rotate Reality keys"
	@echo "    make change-sni SNI=<domain>"
	@echo "    make change-sid             Change ShortID"
	@echo ""
	@echo "  Tools:"
	@echo "    make test-connection        Test VPN connectivity"
	@echo "    make backup                 Backup configs + keys + data"
	@echo "    make restore                Restore from latest backup"
	@echo "    make restore FILE=<path>    Restore from specific backup"
	@echo ""
	@echo "  Danger:"
	@echo "    make clean                  Remove container + all data"
	@echo ""

# ================================================================
# CHECKS
# ================================================================
check-deps:
	@command -v docker >/dev/null 2>&1 || { echo "Docker not installed. Run: sudo make install-deps"; exit 1; }
	@command -v jq >/dev/null 2>&1 || { echo "jq not installed. Run: sudo make install-deps"; exit 1; }
	@docker info >/dev/null 2>&1 || { echo "Docker daemon not running"; exit 1; }

check-root:
	@if [ "$$(id -u)" -ne 0 ]; then echo "Requires root. Run with sudo."; exit 1; fi

install-deps: check-root
	@bash $(SCRIPTS)/install-deps.sh

env-file:
	@if [ ! -f .env ]; then cp .env.example .env; echo "Created .env from .env.example"; fi

# ================================================================
# SETUP / INSTALL
# ================================================================
setup: check-root
ifeq ($(MODE),marzban)
	@bash $(SCRIPTS)/install-deps.sh
	@$(MAKE) --no-print-directory install MARZBAN=1
else
	@bash $(SCRIPTS)/00-install-dependencies.sh
	@$(MAKE) --no-print-directory install
endif

install: check-deps env-file
ifeq ($(MODE),marzban)
	@$(COMPOSE) -f docker-compose.marzban.yml up -d
	@sleep 3
	@echo ""
	@echo "  Marzban is running!"
	@echo "  Panel: http://$$(curl -fsSL -4 --connect-timeout 3 ifconfig.co 2>/dev/null || echo '<SERVER_IP>'):8000/dashboard/"
	@echo "  Login with credentials from .env (or: make admin MARZBAN=1)"
	@echo ""
else
	@bash $(SCRIPTS)/generate-config.sh
	@$(COMPOSE) up -d
	@sleep 2
	@$(MAKE) --no-print-directory list
	@echo ""
	@echo "  Standalone VLESS Reality is running!"
	@echo "  Client links saved to: output/clients.txt"
	@echo ""
endif

# ================================================================
# STANDALONE: config generation
# ================================================================
init: env-file
	@bash $(SCRIPTS)/generate-config.sh

# ================================================================
# DOCKER
# ================================================================
up:
ifeq ($(MODE),marzban)
	@$(COMPOSE) -f docker-compose.marzban.yml up -d
else
	@$(COMPOSE) up -d
endif
	@echo "Started"

down:
ifeq ($(MODE),marzban)
	@$(COMPOSE) -f docker-compose.marzban.yml down
else
	@$(COMPOSE) down
endif
	@echo "Stopped"

restart:
ifeq ($(MODE),marzban)
	@$(COMPOSE) -f docker-compose.marzban.yml restart
else
	@$(COMPOSE) restart
endif
	@echo "Restarted"

logs:
ifeq ($(MODE),marzban)
	@$(COMPOSE) -f docker-compose.marzban.yml logs -f --tail=100
else
	@$(COMPOSE) logs -f --tail=100
endif

status:
ifeq ($(MODE),marzban)
	@$(COMPOSE) -f docker-compose.marzban.yml ps
else
	@$(COMPOSE) ps
endif
	@echo ""
	@ss -ltnp 2>/dev/null | grep -E ':(443|2053|8443|8000)\s' || \
		netstat -tlnp 2>/dev/null | grep -E ':(443|2053|8443|8000)\s' || \
		echo "No listening ports found"

diagnostics:
	@bash $(SCRIPTS)/diagnostics.sh

# ================================================================
# STANDALONE: client management
# ================================================================
add:
	@bash $(SCRIPTS)/add-client.sh

remove:
ifndef UUID
	@echo "Specify UUID: make remove UUID=<uuid>"
	@exit 1
else
	@bash $(SCRIPTS)/remove-client.sh $(UUID)
endif

list:
	@bash $(SCRIPTS)/list-clients.sh

qr:
ifdef N
	@bash $(SCRIPTS)/qr.sh $(N)
else
	@bash $(SCRIPTS)/qr.sh
endif

# ================================================================
# STANDALONE: security
# ================================================================
rotate-keys:
	@bash $(SCRIPTS)/rotate-keys.sh

change-sni:
ifndef SNI
	@echo "Specify SNI: make change-sni SNI=<domain>"
	@exit 1
else
	@bash $(SCRIPTS)/change-sni.sh $(SNI)
endif

change-sid:
	@bash $(SCRIPTS)/change-sid.sh

# ================================================================
# MARZBAN: admin
# ================================================================
admin:
	@docker exec -it marzban marzban cli admin create

# ================================================================
# TOOLS
# ================================================================

test-connection:
	@bash $(SCRIPTS)/test-connection.sh

backup:
	@bash $(SCRIPTS)/backup.sh

restore:
ifdef FILE
	@bash $(SCRIPTS)/restore.sh $(FILE)
else
	@bash $(SCRIPTS)/restore.sh
endif

# ================================================================
# CLEANUP
# ================================================================
clean:
	@echo "This will remove the container and all generated data!"
	@read -p "Continue? [y/N] " confirm && [ "$$confirm" = "y" ] || exit 1
	@$(COMPOSE) down -v 2>/dev/null || true
	@$(COMPOSE) -f docker-compose.marzban.yml down -v 2>/dev/null || true
	@rm -rf config output logs
	@echo "Cleaned"
