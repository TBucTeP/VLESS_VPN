#!/usr/bin/env bash
#
# Генерация конфига WireGuard
#
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_DIR="${PROJECT_DIR}/config/wireguard"
OUTPUT_DIR="${PROJECT_DIR}/output"

# Загрузка .env
if [ -f "${PROJECT_DIR}/.env" ]; then
    source "${PROJECT_DIR}/.env"
fi

# Дефолты
WG_PORT="${WG_PORT:-51820}"
PEERS_COUNT="${PEERS_COUNT:-1}"

echo "🔧 Генерация конфига WireGuard..."
echo "   Port: ${WG_PORT}"
echo "   Peers: ${PEERS_COUNT}"

# Создаём директории
mkdir -p "${CONFIG_DIR}" "${OUTPUT_DIR}"

# Определяем публичный IP
echo "🌐 Определение публичного IP..."
if [ -n "${SERVER_IP:-}" ]; then
    PUBIP="$SERVER_IP"
else
    PUBIP=$(curl -fsSL -4 --connect-timeout 5 ifconfig.co 2>/dev/null || \
            curl -fsSL -4 --connect-timeout 5 ip.sb 2>/dev/null || \
            echo "<SERVER_IP>")
    PUBIP=$(echo "$PUBIP" | tr -d ' \t\r\n')
fi
echo "   IP: ${PUBIP}"

# Создаём .env для docker-compose (переменные окружения)
# linuxserver/wireguard использует переменные окружения из docker-compose.yml

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║              ✅ WIREGUARD КОНФИГ ПОДГОТОВЛЕН!                 ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "📁 Конфиг будет создан автоматически при первом запуске контейнера"
echo "📄 Клиентские конфиги: ${CONFIG_DIR}/peer*/peer*.conf"
echo ""
echo "⚠️  Примечание: linuxserver/wireguard создаёт конфиги автоматически"
echo "   После запуска контейнера подожди 10-20 секунд"
echo ""
echo "Запуск: make wireguard-up"

