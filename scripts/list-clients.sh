#!/usr/bin/env bash
#
# Список всех VLESS клиентов (Multi-Port)
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

# Дефолты
PRIMARY_PORT="${PRIMARY_PORT:-2053}"
GRPC_PORT="${GRPC_PORT:-8443}"
LEGACY_PORT="${LEGACY_PORT:-443}"
PRIMARY_SNI="${PRIMARY_SNI:-gateway.icloud.com}"
GRPC_SNI="${GRPC_SNI:-www.google.com}"
ENABLE_LEGACY_PORT="${ENABLE_LEGACY_PORT:-false}"

# Определяем IP
PUBIP=$(curl -fsSL -4 --connect-timeout 5 ifconfig.co 2>/dev/null || \
        curl -fsSL -4 --connect-timeout 5 ip.sb 2>/dev/null || \
        echo "<SERVER_IP>")
PUBIP=$(echo "$PUBIP" | tr -d ' \t\r\n')

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║              📋 СПИСОК КЛИЕНТОВ (Multi-Port)                 ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "Server: ${PUBIP}"
echo "PublicKey: ${PUBLIC_KEY:-<unknown>}"
echo "ShortID: ${SHORT_ID:-<unknown>}"
echo ""
echo "📡 Доступные порты:"
echo "   🔹 TCP  ${PRIMARY_PORT} (${PRIMARY_SNI}) — рекомендуется"
echo "   🔹 gRPC ${GRPC_PORT} (${GRPC_SNI}) — резервный"
if [ "$ENABLE_LEGACY_PORT" = "true" ]; then
    echo "   🔹 TCP  ${LEGACY_PORT} (${PRIMARY_SNI}) — legacy"
fi
echo ""
echo "════════════════════════════════════════════════════════════════"

# Получаем список клиентов из первого inbound
CLIENTS=$(jq -r '.inbounds[0].settings.clients[] | .id' "$CONFIG_FILE")
COUNT=0

while IFS= read -r UUID; do
    if [ -n "$UUID" ]; then
        COUNT=$((COUNT + 1))
        
        # Primary TCP link
        LINK_TCP="vless://${UUID}@${PUBIP}:${PRIMARY_PORT}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${PRIMARY_SNI}&fp=chrome&pbk=${PUBLIC_KEY:-}&sid=${SHORT_ID:-}&type=tcp#VLESS-${COUNT}-TCP"
        
        # gRPC link
        LINK_GRPC="vless://${UUID}@${PUBIP}:${GRPC_PORT}?encryption=none&security=reality&sni=${GRPC_SNI}&fp=chrome&pbk=${PUBLIC_KEY:-}&sid=${SHORT_ID:-}&type=grpc&serviceName=grpc#VLESS-${COUNT}-gRPC"
        
        echo ""
        echo "[${COUNT}] UUID: ${UUID}"
        echo ""
        echo "    🔹 TCP (порт ${PRIMARY_PORT}) — копируй эту:"
        echo "    ${LINK_TCP}"
        echo ""
        echo "    🔹 gRPC (порт ${GRPC_PORT}) — если TCP не работает:"
        echo "    ${LINK_GRPC}"
        
        if [ "$ENABLE_LEGACY_PORT" = "true" ]; then
            LINK_LEGACY="vless://${UUID}@${PUBIP}:${LEGACY_PORT}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${PRIMARY_SNI}&fp=chrome&pbk=${PUBLIC_KEY:-}&sid=${SHORT_ID:-}&type=tcp#VLESS-${COUNT}-Legacy"
            echo ""
            echo "    🔹 Legacy (порт ${LEGACY_PORT}):"
            echo "    ${LINK_LEGACY}"
        fi
    fi
done <<< "$CLIENTS"

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "Всего клиентов: ${COUNT}"
echo ""
echo "💡 Рекомендация: начни с TCP (порт ${PRIMARY_PORT})"
echo "   Если не работает — попробуй gRPC (порт ${GRPC_PORT})"
echo ""
