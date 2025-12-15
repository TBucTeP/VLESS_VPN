#!/usr/bin/env bash
#
# Смена ShortID
#
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="${PROJECT_DIR}/config/config.json"
KEYS_FILE="${PROJECT_DIR}/config/.keys"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Конфиг не найден"
    exit 1
fi

if ! command -v jq &>/dev/null; then
    echo "❌ jq не установлен"
    exit 1
fi

# Генерируем новый ShortID
NEW_SID=$(openssl rand -hex 8)

echo "🔄 Новый ShortID: ${NEW_SID}"

# Обновляем конфиг
jq --arg sid "$NEW_SID" \
   '.inbounds[0].streamSettings.realitySettings.shortIds = [$sid]' \
   "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"

# Обновляем файл ключей
if [ -f "$KEYS_FILE" ]; then
    sed -i.bak "s/^SHORT_ID=.*/SHORT_ID=${NEW_SID}/" "$KEYS_FILE" 2>/dev/null || \
    sed -i '' "s/^SHORT_ID=.*/SHORT_ID=${NEW_SID}/" "$KEYS_FILE"
    rm -f "${KEYS_FILE}.bak"
fi

echo ""
echo "✅ ShortID изменён"
echo ""
echo "⚠️  Перезапусти контейнер: make restart"
echo "⚠️  Обнови ссылки: make list"

