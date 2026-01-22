#!/usr/bin/env bash
#
# Добавление нового VLESS клиента (Multi-Port)
#
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="${PROJECT_DIR}/config/config.json"
KEYS_FILE="${PROJECT_DIR}/config/.keys"
OUTPUT_DIR="${PROJECT_DIR}/output"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Конфиг не найден: $CONFIG_FILE"
    echo "   Сначала запусти: make init"
    exit 1
fi

if [ ! -f "$KEYS_FILE" ]; then
    echo "❌ Ключи не найдены: $KEYS_FILE"
    exit 1
fi

# Загружаем ключи
source "$KEYS_FILE"

# Дефолты
PRIMARY_PORT="${PRIMARY_PORT:-2053}"
GRPC_PORT="${GRPC_PORT:-8443}"
PRIMARY_SNI="${PRIMARY_SNI:-gateway.icloud.com}"
GRPC_SNI="${GRPC_SNI:-www.google.com}"

# Генерируем UUID
if command -v uuidgen &>/dev/null; then
    UUID=$(uuidgen | tr '[:upper:]' '[:lower:]')
else
    UUID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || python3 -c "import uuid; print(uuid.uuid4())")
fi

# Добавляем клиента в конфиг (во все inbounds)
echo "➕ Добавление клиента: ${UUID}"

if command -v jq &>/dev/null; then
    # Добавляем в TCP inbounds (с flow)
    jq --arg id "$UUID" \
       '.inbounds |= map(if .streamSettings.network == "tcp" then .settings.clients += [{"id":$id,"flow":"xtls-rprx-vision"}] else . end)' \
       "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
    
    # Добавляем в gRPC inbounds (без flow)
    jq --arg id "$UUID" \
       '.inbounds |= map(if .streamSettings.network == "grpc" then .settings.clients += [{"id":$id}] else . end)' \
       "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
else
    echo "❌ jq не установлен. Установи: apt install jq"
    exit 1
fi

# Определяем IP
PUBIP=$(curl -fsSL -4 --connect-timeout 5 ifconfig.co 2>/dev/null || \
        curl -fsSL -4 --connect-timeout 5 ip.sb 2>/dev/null || \
        echo "<SERVER_IP>")
PUBIP=$(echo "$PUBIP" | tr -d ' \t\r\n')

# Генерируем ссылки
LINK_TCP="vless://${UUID}@${PUBIP}:${PRIMARY_PORT}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${PRIMARY_SNI}&fp=chrome&pbk=${PUBLIC_KEY}&sid=${SHORT_ID}&type=tcp#VLESS-new-TCP"
LINK_GRPC="vless://${UUID}@${PUBIP}:${GRPC_PORT}?encryption=none&security=reality&sni=${GRPC_SNI}&fp=chrome&pbk=${PUBLIC_KEY}&sid=${SHORT_ID}&type=grpc&serviceName=grpc#VLESS-new-gRPC"

# Добавляем в файл клиентов
{
    echo ""
    echo "[Client NEW - $(date)]"
    echo "UUID: ${UUID}"
    echo "TCP:  ${LINK_TCP}"
    echo "gRPC: ${LINK_GRPC}"
} >> "${OUTPUT_DIR}/clients.txt"

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║              ✅ КЛИЕНТ ДОБАВЛЕН!                             ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "UUID: ${UUID}"
echo ""
echo "🔹 TCP (порт ${PRIMARY_PORT}) — основная:"
echo "${LINK_TCP}"
echo ""
echo "🔹 gRPC (порт ${GRPC_PORT}) — резервная:"
echo "${LINK_GRPC}"
echo ""
echo "⚠️  Перезапусти контейнер: make restart"

