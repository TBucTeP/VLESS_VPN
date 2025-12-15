#!/usr/bin/env bash
#
# Смена SNI (домена для маскировки)
#
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="${PROJECT_DIR}/config/config.json"
KEYS_FILE="${PROJECT_DIR}/config/.keys"

NEW_SNI="${1:-}"

if [ -z "$NEW_SNI" ]; then
    echo "❌ Укажи новый SNI"
    echo "   Использование: $0 <domain>"
    echo ""
    echo "   Примеры SNI:"
    echo "   - www.microsoft.com"
    echo "   - login.microsoftonline.com"
    echo "   - www.google.com"
    echo "   - cloudflare.com"
    exit 1
fi

if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Конфиг не найден"
    exit 1
fi

if ! command -v jq &>/dev/null; then
    echo "❌ jq не установлен"
    exit 1
fi

echo "🔄 Смена SNI на: ${NEW_SNI}"

# Обновляем конфиг
jq --arg sni "$NEW_SNI" \
   '.inbounds[0].streamSettings.realitySettings.serverNames = [$sni] | 
    .inbounds[0].streamSettings.realitySettings.dest = ($sni + ":443")' \
   "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"

# Обновляем файл ключей
if [ -f "$KEYS_FILE" ]; then
    sed -i.bak "s/^SNI=.*/SNI=${NEW_SNI}/" "$KEYS_FILE" 2>/dev/null || \
    sed -i '' "s/^SNI=.*/SNI=${NEW_SNI}/" "$KEYS_FILE"
    rm -f "${KEYS_FILE}.bak"
fi

echo ""
echo "✅ SNI изменён на: ${NEW_SNI}"
echo ""
echo "⚠️  Перезапусти контейнер: make restart"
echo "⚠️  Все ссылки теперь с новым SNI: make list"

