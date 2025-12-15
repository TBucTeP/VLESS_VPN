#!/usr/bin/env bash
#
# Добавление нового VLESS клиента
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

# Генерируем UUID
if command -v uuidgen &>/dev/null; then
    UUID=$(uuidgen | tr '[:upper:]' '[:lower:]')
else
    UUID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || python3 -c "import uuid; print(uuid.uuid4())")
fi

# Добавляем клиента в конфиг
echo "➕ Добавление клиента: ${UUID}"

if command -v jq &>/dev/null; then
    jq --arg id "$UUID" \
       '.inbounds[0].settings.clients += [{"id":$id,"flow":"xtls-rprx-vision"}]' \
       "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
else
    echo "❌ jq не установлен. Установи: brew install jq (Mac) или apt install jq (Linux)"
    exit 1
fi

# Определяем IP
PUBIP=$(curl -fsSL -4 --connect-timeout 5 ifconfig.co 2>/dev/null || \
        curl -fsSL -4 --connect-timeout 5 ip.sb 2>/dev/null || \
        echo "<SERVER_IP>")
PUBIP=$(echo "$PUBIP" | tr -d ' \t\r\n')

# Генерируем ссылку
LINK="vless://${UUID}@${PUBIP}:${PORT}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${SNI}&fp=chrome&pbk=${PUBLIC_KEY}&sid=${SHORT_ID}&type=tcp#VLESS-new"

# Добавляем в файл клиентов
{
    echo ""
    echo "[Client NEW - $(date)]"
    echo "UUID: ${UUID}"
    echo "Link: ${LINK}"
} >> "${OUTPUT_DIR}/clients.txt"

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║              ✅ КЛИЕНТ ДОБАВЛЕН!                             ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "UUID: ${UUID}"
echo ""
echo "Ссылка:"
echo "${LINK}"
echo ""
echo "⚠️  Перезапусти контейнер: make restart"

