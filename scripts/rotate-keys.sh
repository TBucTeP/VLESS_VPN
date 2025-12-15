#!/usr/bin/env bash
#
# Ротация ключей REALITY
# ⚠️ После ротации все старые ссылки перестанут работать!
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

echo "⚠️  ВНИМАНИЕ: После ротации ключей все старые ссылки перестанут работать!"
read -p "Продолжить? [y/N] " confirm
if [ "${confirm}" != "y" ] && [ "${confirm}" != "Y" ]; then
    echo "Отменено"
    exit 0
fi

# Получаем xray для генерации ключей
if docker ps --format '{{.Names}}' | grep -q 'xray-vless'; then
    # Используем xray из контейнера
    KEY_OUTPUT=$(docker exec xray-vless xray x25519 2>&1)
else
    echo "❌ Контейнер xray-vless не запущен"
    echo "   Запусти: make up"
    exit 1
fi

# Извлекаем ключи
PRIV=$(echo "$KEY_OUTPUT" | grep -i "private" | sed 's/.*: *//' | tr -d ' \t\r\n')

if [ -z "$PRIV" ]; then
    echo "❌ Не удалось сгенерировать ключи"
    exit 1
fi

# Получаем публичный ключ
PUB_OUTPUT=$(docker exec xray-vless xray x25519 -i "$PRIV" 2>&1)
PUB=$(echo "$PUB_OUTPUT" | grep -i "public" | sed 's/.*: *//' | tr -d ' \t\r\n')

if [ -z "$PUB" ]; then
    PUB=$(echo "$PUB_OUTPUT" | grep -Eo '[A-Za-z0-9_-]{43,44}' | grep -v "^${PRIV}$" | head -1)
fi

if [ -z "$PUB" ]; then
    echo "❌ Не удалось получить публичный ключ"
    exit 1
fi

# Новый ShortID
SID=$(openssl rand -hex 8)

echo "🔑 Новые ключи:"
echo "   PrivateKey: ${PRIV:0:20}..."
echo "   PublicKey: ${PUB:0:20}..."
echo "   ShortID: ${SID}"

# Обновляем конфиг
if command -v jq &>/dev/null; then
    jq --arg pk "$PRIV" --arg sid "$SID" \
       '.inbounds[0].streamSettings.realitySettings.privateKey = $pk | 
        .inbounds[0].streamSettings.realitySettings.shortIds = [$sid]' \
       "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
else
    echo "❌ jq не установлен"
    exit 1
fi

# Обновляем файл ключей
SNI=$(jq -r '.inbounds[0].streamSettings.realitySettings.serverNames[0]' "$CONFIG_FILE")
PORT=$(jq -r '.inbounds[0].port' "$CONFIG_FILE")

cat > "${KEYS_FILE}" <<EOF
PRIVATE_KEY=${PRIV}
PUBLIC_KEY=${PUB}
SHORT_ID=${SID}
SNI=${SNI}
PORT=${PORT}
EOF

echo ""
echo "✅ Ключи обновлены!"
echo ""
echo "⚠️  Перезапусти контейнер: make restart"
echo "⚠️  Перегенерируй ссылки: make list"

