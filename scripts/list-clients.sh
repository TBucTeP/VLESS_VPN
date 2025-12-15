#!/usr/bin/env bash
#
# Список всех VLESS клиентов
#
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="${PROJECT_DIR}/config/config.json"
KEYS_FILE="${PROJECT_DIR}/config/.keys"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Конфиг не найден: $CONFIG_FILE"
    echo "   Сначала запусти: make init"
    exit 1
fi

if ! command -v jq &>/dev/null; then
    echo "❌ jq не установлен"
    exit 1
fi

# Загружаем ключи
if [ -f "$KEYS_FILE" ]; then
    source "$KEYS_FILE"
fi

# Определяем IP
PUBIP=$(curl -fsSL -4 --connect-timeout 5 ifconfig.co 2>/dev/null || echo "<SERVER_IP>")
PUBIP=$(echo "$PUBIP" | tr -d ' \t\r\n')

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    📋 СПИСОК КЛИЕНТОВ                        ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "Server: ${PUBIP}:${PORT:-443}"
echo "SNI: ${SNI:-www.microsoft.com}"
echo "PublicKey: ${PUBLIC_KEY:-<unknown>}"
echo "ShortID: ${SHORT_ID:-<unknown>}"
echo ""
echo "────────────────────────────────────────────────────────────────"

# Получаем список клиентов
CLIENTS=$(jq -r '.inbounds[0].settings.clients[] | .id' "$CONFIG_FILE")
COUNT=0

while IFS= read -r UUID; do
    if [ -n "$UUID" ]; then
        COUNT=$((COUNT + 1))
        LINK="vless://${UUID}@${PUBIP}:${PORT:-443}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${SNI:-www.microsoft.com}&fp=chrome&pbk=${PUBLIC_KEY:-}&sid=${SHORT_ID:-}&type=tcp#VLESS-${COUNT}"
        echo ""
        echo "[${COUNT}] UUID: ${UUID}"
        echo "    Link: ${LINK}"
    fi
done <<< "$CLIENTS"

echo ""
echo "────────────────────────────────────────────────────────────────"
echo "Всего клиентов: ${COUNT}"
echo ""

