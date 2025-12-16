# ╔══════════════════════════════════════════════════════════════════╗
# ║            🔐 VLESS/REALITY VPN - Docker Deployment              ║
# ║                                                                  ║
# ║   git clone → make install → готовые ссылки!                     ║
# ╚══════════════════════════════════════════════════════════════════╝

SHELL := /bin/bash
.DEFAULT_GOAL := help

# Цвета
C_RED    := \033[0;31m
C_GREEN  := \033[0;32m
C_YELLOW := \033[1;33m
C_BLUE   := \033[0;34m
C_CYAN   := \033[0;36m
C_NC     := \033[0m

SCRIPTS := scripts
COMPOSE := docker compose

.PHONY: help install install-deps init up down restart logs status diagnostics \
        add remove list rotate-keys change-sni change-sid clean \
        wireguard-init wireguard-up wireguard-down wireguard-logs wireguard-add \
        openvpn-init openvpn-up openvpn-down openvpn-logs openvpn-add

# ════════════════════════════════════════════════════════════════════
# HELP
# ════════════════════════════════════════════════════════════════════
help:
	@echo -e "$(C_BLUE)╔══════════════════════════════════════════════════════════════╗$(C_NC)"
	@echo -e "$(C_BLUE)║       🔐 Multi-Protocol VPN Server - Docker                  ║$(C_NC)"
	@echo -e "$(C_BLUE)║       VLESS/REALITY • WireGuard • OpenVPN                    ║$(C_NC)"
	@echo -e "$(C_BLUE)╚══════════════════════════════════════════════════════════════╝$(C_NC)"
	@echo ""
	@echo -e "$(C_GREEN)🚀 Быстрый старт:$(C_NC)"
	@echo "   make install-deps - Установить все зависимости (Docker, firewall и т.д.)"
	@echo "   make install     - VLESS/REALITY (init + up + показать ссылки)"
	@echo "   make wireguard-up - WireGuard"
	@echo "   make openvpn-up   - OpenVPN"
	@echo ""
	@echo -e "$(C_YELLOW)📦 VLESS/REALITY:$(C_NC)"
	@echo "   make init        - Генерация конфига и ключей"
	@echo "   make up          - Запустить контейнер"
	@echo "   make down        - Остановить контейнер"
	@echo "   make restart     - Перезапустить"
	@echo "   make logs        - Логи Xray"
	@echo "   make status      - Статус"
	@echo "   make diagnostics - Полная диагностика"
	@echo "   make add         - Добавить клиента"
	@echo "   make remove UUID=<uuid> - Удалить клиента"
	@echo "   make list        - Список всех клиентов с ссылками"
	@echo "   make rotate-keys - Ротация ключей REALITY"
	@echo "   make change-sni SNI=<domain> - Сменить SNI"
	@echo "   make change-sid  - Сменить ShortID"
	@echo ""
	@echo -e "$(C_CYAN)🔷 WireGuard:$(C_NC)"
	@echo "   make wireguard-init - Генерация конфига WireGuard"
	@echo "   make wireguard-up    - Запустить WireGuard"
	@echo "   make wireguard-down  - Остановить WireGuard"
	@echo "   make wireguard-logs  - Логи WireGuard"
	@echo "   make wireguard-add   - Добавить нового клиента"
	@echo ""
	@echo -e "$(C_CYAN)🔶 OpenVPN:$(C_NC)"
	@echo "   make openvpn-init - Генерация конфига OpenVPN"
	@echo "   make openvpn-up   - Запустить OpenVPN"
	@echo "   make openvpn-down - Остановить OpenVPN"
	@echo "   make openvpn-logs - Логи OpenVPN"
	@echo "   make openvpn-add  - Добавить нового клиента"
	@echo ""
	@echo -e "$(C_RED)⚠️  Опасные:$(C_NC)"
	@echo "   make clean       - Удалить всё (контейнер + конфиги)"
	@echo ""

# ════════════════════════════════════════════════════════════════════
# MAIN COMMANDS
# ════════════════════════════════════════════════════════════════════
install: check-deps init up
	@echo ""
	@sleep 2
	@$(MAKE) --no-print-directory list
	@echo ""
	@echo -e "$(C_GREEN)╔══════════════════════════════════════════════════════════════╗$(C_NC)"
	@echo -e "$(C_GREEN)║              ✅ УСТАНОВКА ЗАВЕРШЕНА!                         ║$(C_NC)"
	@echo -e "$(C_GREEN)╚══════════════════════════════════════════════════════════════╝$(C_NC)"
	@echo ""
	@echo -e "$(C_CYAN)📄 Ссылки сохранены в: output/clients.txt$(C_NC)"
	@echo -e "$(C_CYAN)📋 Показать ссылки:    make list$(C_NC)"
	@echo ""

check-deps:
	@command -v docker >/dev/null 2>&1 || { \
		echo -e "$(C_RED)❌ Docker не установлен$(C_NC)"; \
		echo -e "$(C_YELLOW)💡 Установи зависимости: bash scripts/00-install-dependencies.sh$(C_NC)"; \
		exit 1; \
	}
	@command -v jq >/dev/null 2>&1 || { \
		echo -e "$(C_RED)❌ jq не установлен$(C_NC)"; \
		echo -e "$(C_YELLOW)💡 Установи зависимости: bash scripts/00-install-dependencies.sh$(C_NC)"; \
		exit 1; \
	}
	@docker info >/dev/null 2>&1 || { echo -e "$(C_RED)❌ Docker daemon не запущен$(C_NC)"; exit 1; }

install-deps: check-root
	@bash $(SCRIPTS)/00-install-dependencies.sh

init: env-file
	@echo -e "$(C_BLUE)🔧 Генерация конфига...$(C_NC)"
	@bash $(SCRIPTS)/generate-config.sh

env-file:
	@if [ ! -f .env ]; then cp .env.example .env; echo -e "$(C_YELLOW)📝 Создан .env из .env.example$(C_NC)"; fi

# ════════════════════════════════════════════════════════════════════
# DOCKER
# ════════════════════════════════════════════════════════════════════
up:
	@echo -e "$(C_BLUE)🚀 Запуск Xray...$(C_NC)"
	@$(COMPOSE) up -d
	@echo -e "$(C_GREEN)✅ Xray запущен$(C_NC)"

down:
	@echo -e "$(C_YELLOW)⏹️  Остановка Xray...$(C_NC)"
	@$(COMPOSE) down
	@echo -e "$(C_GREEN)✅ Остановлен$(C_NC)"

restart:
	@echo -e "$(C_YELLOW)🔄 Перезапуск Xray...$(C_NC)"
	@$(COMPOSE) restart
	@echo -e "$(C_GREEN)✅ Перезапущен$(C_NC)"

logs:
	@$(COMPOSE) logs -f --tail=100

status:
	@echo -e "$(C_BLUE)📊 Статус:$(C_NC)"
	@echo ""
	@$(COMPOSE) ps
	@echo ""
	@echo -e "$(C_YELLOW)Порт 443:$(C_NC)"
	@ss -ltnp 2>/dev/null | grep ':443' || netstat -tlnp 2>/dev/null | grep ':443' || echo "  Не найден"

diagnostics:
	@bash $(SCRIPTS)/diagnostics.sh

# ════════════════════════════════════════════════════════════════════
# CLIENTS
# ════════════════════════════════════════════════════════════════════
add:
	@bash $(SCRIPTS)/add-client.sh

remove:
ifndef UUID
	@echo -e "$(C_RED)❌ Укажи UUID: make remove UUID=<uuid>$(C_NC)"
	@exit 1
else
	@bash $(SCRIPTS)/remove-client.sh $(UUID)
endif

list:
	@bash $(SCRIPTS)/list-clients.sh

# ════════════════════════════════════════════════════════════════════
# SECURITY
# ════════════════════════════════════════════════════════════════════
rotate-keys:
	@bash $(SCRIPTS)/rotate-keys.sh

change-sni:
ifndef SNI
	@echo -e "$(C_RED)❌ Укажи SNI: make change-sni SNI=login.microsoftonline.com$(C_NC)"
	@exit 1
else
	@bash $(SCRIPTS)/change-sni.sh $(SNI)
endif

change-sid:
	@bash $(SCRIPTS)/change-sid.sh

# ════════════════════════════════════════════════════════════════════
# CLEANUP
# ════════════════════════════════════════════════════════════════════
# ════════════════════════════════════════════════════════════════════
# WIREGUARD
# ════════════════════════════════════════════════════════════════════
wireguard-init: env-file
	@echo -e "$(C_BLUE)🔷 Генерация конфига WireGuard...$(C_NC)"
	@bash $(SCRIPTS)/generate-wireguard.sh

wireguard-up: wireguard-init
	@echo -e "$(C_BLUE)🚀 Запуск WireGuard...$(C_NC)"
	@$(COMPOSE) up -d wireguard
	@sleep 5
	@echo -e "$(C_GREEN)✅ WireGuard запущен$(C_NC)"
	@echo ""
	@echo -e "$(C_CYAN)📄 Клиентские конфиги:$(C_NC)"
	@ls -1 config/wireguard/peer*/peer*.conf 2>/dev/null | head -5 || echo "   Конфиги будут созданы через несколько секунд..."

wireguard-down:
	@echo -e "$(C_YELLOW)⏹️  Остановка WireGuard...$(C_NC)"
	@$(COMPOSE) stop wireguard
	@echo -e "$(C_GREEN)✅ Остановлен$(C_NC)"

wireguard-logs:
	@$(COMPOSE) logs -f wireguard --tail=100

wireguard-add:
	@echo -e "$(C_BLUE)➕ Добавление нового WireGuard клиента...$(C_NC)"
	@if ! docker ps | grep -q wireguard-vpn; then \
		echo -e "$(C_RED)❌ WireGuard контейнер не запущен. Запусти: make wireguard-up$(C_NC)"; \
		exit 1; \
	fi
	@PEER_NUM=$$(($$(ls -1d config/wireguard/peer* 2>/dev/null | wc -l) + 1)); \
	docker exec wireguard-vpn addpeer $${PEER_NUM} >/dev/null 2>&1 || \
	docker exec wireguard-vpn /config/wg-quick/peer$${PEER_NUM}/add_peer.sh >/dev/null 2>&1 || \
	{ \
		echo -e "$(C_YELLOW)⚠️  Используем ручной метод...$(C_NC)"; \
		docker exec wireguard-vpn wg genkey | tee /tmp/peer_private.key | docker exec -i wireguard-vpn wg pubkey > /tmp/peer_public.key; \
		PEER_PRIV=$$(cat /tmp/peer_private.key); \
		PEER_PUB=$$(cat /tmp/peer_public.key); \
		SERVER_PUB=$$(docker exec wireguard-vpn cat /config/wg0.conf 2>/dev/null | grep -oP 'PublicKey = \K[^ ]+' | head -1); \
		SERVER_IP=$$(curl -fsSL -4 ifconfig.co 2>/dev/null || echo "<SERVER_IP>"); \
		PEER_IP="10.66.66.$$((PEER_NUM + 1))"; \
		mkdir -p "config/wireguard/peer$${PEER_NUM}"; \
		cat > "config/wireguard/peer$${PEER_NUM}/peer$${PEER_NUM}.conf" <<EOF; \
[Interface] \
PrivateKey = $${PEER_PRIV} \
Address = $${PEER_IP}/24 \
DNS = 1.1.1.1 \
 \
[Peer] \
PublicKey = $${SERVER_PUB} \
Endpoint = $${SERVER_IP}:51820 \
AllowedIPs = 0.0.0.0/0, ::/0 \
PersistentKeepalive = 25 \
EOF
		docker exec wireguard-vpn wg set wg0 peer $${PEER_PUB} allowed-ips $${PEER_IP}/32; \
		rm -f /tmp/peer_*.key; \
	}; \
	echo -e "$(C_GREEN)✅ Клиент добавлен$(C_NC)"; \
	if [ -f "config/wireguard/peer$${PEER_NUM}/peer$${PEER_NUM}.conf" ]; then \
		echo -e "$(C_CYAN)📄 Конфиг: config/wireguard/peer$${PEER_NUM}/peer$${PEER_NUM}.conf$(C_NC)"; \
	else \
		echo -e "$(C_CYAN)📄 Конфиг будет в: config/wireguard/peer$${PEER_NUM}/$(C_NC)"; \
		echo -e "$(C_YELLOW)   Подожди 10-20 секунд после добавления$(C_NC)"; \
	fi

# ════════════════════════════════════════════════════════════════════
# OPENVPN
# ════════════════════════════════════════════════════════════════════
openvpn-init: env-file check-deps
	@echo -e "$(C_BLUE)🔶 Генерация конфига OpenVPN...$(C_NC)"
	@bash $(SCRIPTS)/generate-openvpn.sh

openvpn-up: openvpn-init
	@echo -e "$(C_BLUE)🚀 Запуск OpenVPN...$(C_NC)"
	@$(COMPOSE) up -d openvpn
	@echo -e "$(C_GREEN)✅ OpenVPN запущен$(C_NC)"
	@echo ""
	@echo -e "$(C_CYAN)📄 Клиентские конфиги:$(C_NC)"
	@ls -1 output/client*.ovpn 2>/dev/null || echo "   Конфиги в output/"

openvpn-down:
	@echo -e "$(C_YELLOW)⏹️  Остановка OpenVPN...$(C_NC)"
	@$(COMPOSE) stop openvpn
	@echo -e "$(C_GREEN)✅ Остановлен$(C_NC)"

openvpn-logs:
	@$(COMPOSE) logs -f openvpn --tail=100

openvpn-add:
	@echo -e "$(C_BLUE)➕ Добавление нового OpenVPN клиента...$(C_NC)"
	@read -p "Имя клиента (clientX): " CLIENT_NAME; \
	CLIENT_NAME=$${CLIENT_NAME:-client$$(ls -1 output/client*.ovpn 2>/dev/null | wc -l | xargs -I {} expr {} + 1)}; \
	docker run --rm -v "$(PWD)/config/openvpn:/etc/openvpn" \
		-e EASYRSA_BATCH=yes \
		kylemanna/openvpn easyrsa build-client-full "$$CLIENT_NAME" nopass; \
	docker run --rm -v "$(PWD)/config/openvpn:/etc/openvpn" \
		kylemanna/openvpn ovpn_getclient "$$CLIENT_NAME" > "output/$$CLIENT_NAME.ovpn"; \
	echo -e "$(C_GREEN)✅ Клиент добавлен: output/$$CLIENT_NAME.ovpn$(C_NC)"

# ════════════════════════════════════════════════════════════════════
# CLEANUP
# ════════════════════════════════════════════════════════════════════
clean:
	@echo -e "$(C_RED)⚠️  Это удалит контейнер и все конфиги!$(C_NC)"
	@read -p "Продолжить? [y/N] " confirm && [ "$$confirm" = "y" ] || exit 1
	@$(COMPOSE) down -v 2>/dev/null || true
	@rm -rf config output logs
	@echo -e "$(C_GREEN)✅ Очищено$(C_NC)"
