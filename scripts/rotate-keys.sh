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

# Получаем публичный ключ (в новых версиях Xray он называется "Password")
PUB_OUTPUT=$(docker exec xray-vless xray x25519 -i "$PRIV" 2>&1)

# Пробуем PublicKey (старые версии) или Password (новые версии)
PUB=$(echo "$PUB_OUTPUT" | grep -i "public" | sed 's/.*: *//' | tr -d ' \t\r\n' || true)

if [ -z "$PUB" ]; then
    PUB=$(echo "$PUB_OUTPUT" | grep -i "password" | sed 's/.*: *//' | tr -d ' \t\r\n' || true)
fi

# Fallback
if [ -z "$PUB" ]; then
    PUB=$(echo "$PUB_OUTPUT" | grep -Eo '[A-Za-z0-9_-]{43,44}' | grep -v "^${PRIV}$" | head -1 || true)
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

# Обновляем конфиг (все inbounds)
if command -v jq &>/dev/null; then
    jq --arg pk "$PRIV" --arg sid "$SID" \
       '.inbounds |= map(.streamSettings.realitySettings.privateKey = $pk | .streamSettings.realitySettings.shortIds = [$sid, ""])' \
       "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
else
    echo "❌ jq не установлен"
    exit 1
fi

# Загружаем текущие настройки
if [ -f "$KEYS_FILE" ]; then
    source "$KEYS_FILE"
fi

# Обновляем файл ключей
cat > "${KEYS_FILE}" <<EOF
PRIVATE_KEY=${PRIV}
PUBLIC_KEY=${PUB}
SHORT_ID=${SID}
PRIMARY_SNI=${PRIMARY_SNI:-gateway.icloud.com}
GRPC_SNI=${GRPC_SNI:-www.google.com}
PRIMARY_PORT=${PRIMARY_PORT:-2053}
GRPC_PORT=${GRPC_PORT:-8443}
LEGACY_PORT=${LEGACY_PORT:-443}
ENABLE_LEGACY_PORT=${ENABLE_LEGACY_PORT:-false}
EOF

echo ""
echo "✅ Ключи обновлены!"
echo ""
echo "⚠️  Перезапусти контейнер: make restart"
echo "⚠️  Перегенерируй ссылки: make list"

