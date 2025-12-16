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

# Сохраняем настройки для docker-compose
cat > "${CONFIG_DIR}/.env" <<EOF
SERVERPORT=${WG_PORT}
PEERS=${PEERS_COUNT}
EOF

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║              ✅ WIREGUARD КОНФИГ ПОДГОТОВЛЕН!                 ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "📁 Конфиг будет создан после первого запуска контейнера"
echo "📄 Клиентские конфиги: ${CONFIG_DIR}/peer*/peer*.conf"
echo ""
echo "Запуск: make wireguard-up"

