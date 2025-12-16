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
        add remove list rotate-keys change-sni change-sid clean

# ════════════════════════════════════════════════════════════════════
# HELP
# ════════════════════════════════════════════════════════════════════
help:
	@echo -e "$(C_BLUE)╔══════════════════════════════════════════════════════════════╗$(C_NC)"
	@echo -e "$(C_BLUE)║          🔐 VLESS/REALITY VPN - Docker                       ║$(C_NC)"
	@echo -e "$(C_BLUE)╚══════════════════════════════════════════════════════════════╝$(C_NC)"
	@echo ""
	@echo -e "$(C_GREEN)🚀 Быстрый старт:$(C_NC)"
	@echo "   make install-deps - Установить все зависимости (Docker, firewall и т.д.)"
	@echo "   make install     - Полная установка (init + up + показать ссылки)"
	@echo ""
	@echo -e "$(C_YELLOW)📦 Docker:$(C_NC)"
	@echo "   make init        - Генерация конфига и ключей"
	@echo "   make up          - Запустить контейнер"
	@echo "   make down        - Остановить контейнер"
	@echo "   make restart     - Перезапустить"
	@echo "   make logs        - Логи Xray"
	@echo "   make status      - Статус"
	@echo "   make diagnostics - Полная диагностика"
	@echo ""
	@echo -e "$(C_YELLOW)👥 Клиенты:$(C_NC)"
	@echo "   make add         - Добавить клиента"
	@echo "   make remove UUID=<uuid> - Удалить клиента"
	@echo "   make list        - Список всех клиентов с ссылками"
	@echo ""
	@echo -e "$(C_YELLOW)🔒 Безопасность:$(C_NC)"
	@echo "   make rotate-keys - Ротация ключей REALITY"
	@echo "   make change-sni SNI=<domain> - Сменить SNI"
	@echo "   make change-sid  - Сменить ShortID"
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
clean:
	@echo -e "$(C_RED)⚠️  Это удалит контейнер и все конфиги!$(C_NC)"
	@read -p "Продолжить? [y/N] " confirm && [ "$$confirm" = "y" ] || exit 1
	@$(COMPOSE) down -v 2>/dev/null || true
	@rm -rf config output logs
	@echo -e "$(C_GREEN)✅ Очищено$(C_NC)"
