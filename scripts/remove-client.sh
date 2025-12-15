#!/usr/bin/env bash
#
# Удаление VLESS клиента по UUID
#
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="${PROJECT_DIR}/config/config.json"

UUID="${1:-}"

if [ -z "$UUID" ]; then
    echo "❌ Укажи UUID клиента"
    echo "   Использование: $0 <uuid>"
    echo ""
    echo "   Список клиентов: make list"
    exit 1
fi

if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Конфиг не найден: $CONFIG_FILE"
    exit 1
fi

if ! command -v jq &>/dev/null; then
    echo "❌ jq не установлен"
    exit 1
fi

# Проверяем существование клиента
EXISTS=$(jq -r --arg id "$UUID" '.inbounds[0].settings.clients | map(select(.id == $id)) | length' "$CONFIG_FILE")

if [ "$EXISTS" -eq 0 ]; then
    echo "❌ Клиент не найден: $UUID"
    exit 1
fi

# Удаляем клиента
echo "➖ Удаление клиента: ${UUID}"
jq --arg id "$UUID" \
   '.inbounds[0].settings.clients |= map(select(.id != $id))' \
   "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"

echo ""
echo "✅ Клиент удалён: ${UUID}"
echo ""
echo "⚠️  Перезапусти контейнер: make restart"

