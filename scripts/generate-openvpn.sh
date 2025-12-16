#!/usr/bin/env bash
#
# Генерация конфига OpenVPN
#
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_DIR="${PROJECT_DIR}/config/openvpn"
OUTPUT_DIR="${PROJECT_DIR}/output"

# Загрузка .env
if [ -f "${PROJECT_DIR}/.env" ]; then
    source "${PROJECT_DIR}/.env"
fi

# Дефолты
OVPN_PORT="${OVPN_PORT:-1194}"
CLIENTS_COUNT="${OVPN_CLIENTS_COUNT:-1}"

echo "🔧 Генерация конфига OpenVPN..."
echo "   Port: ${OVPN_PORT}"
echo "   Clients: ${CLIENTS_COUNT}"

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

# Проверяем наличие docker-compose
if ! command -v docker &>/dev/null; then
    echo "❌ Docker не установлен"
    exit 1
fi

echo ""
echo "📝 Инициализация OpenVPN конфига..."
echo "   Это займёт несколько минут..."

# Создаём базовый конфиг через docker
docker run --rm -v "${CONFIG_DIR}:/etc/openvpn" \
    -e OVPN_SERVER_URL="${PUBIP}" \
    kylemanna/openvpn ovpn_genconfig -u udp://"${PUBIP}":${OVPN_PORT}

# Генерируем CA и серверные ключи
docker run --rm -v "${CONFIG_DIR}:/etc/openvpn" \
    -e EASYRSA_BATCH=yes \
    kylemanna/openvpn ovpn_initpki nopass

# Генерируем клиентские сертификаты
for i in $(seq 1 "$CLIENTS_COUNT"); do
    CLIENT_NAME="client${i}"
    echo "   Генерация клиента: ${CLIENT_NAME}"
    docker run --rm -v "${CONFIG_DIR}:/etc/openvpn" \
        -e EASYRSA_BATCH=yes \
        kylemanna/openvpn easyrsa build-client-full "${CLIENT_NAME}" nopass
    
    # Экспортируем конфиг клиента
    docker run --rm -v "${CONFIG_DIR}:/etc/openvpn" \
        kylemanna/openvpn ovpn_getclient "${CLIENT_NAME}" > "${OUTPUT_DIR}/${CLIENT_NAME}.ovpn"
done

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║              ✅ OPENVPN КОНФИГ СГЕНЕРИРОВАН!                   ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "📁 Конфиг: ${CONFIG_DIR}/"
echo "📄 Клиентские конфиги: ${OUTPUT_DIR}/client*.ovpn"
echo ""
echo "Запуск: make openvpn-up"

