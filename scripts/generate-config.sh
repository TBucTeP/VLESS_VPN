#!/usr/bin/env bash
#
# Генерация конфига Xray/REALITY
# Создаёт ключи, UUID клиентов, конфиг и ссылки
#
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_DIR="${PROJECT_DIR}/config"
OUTPUT_DIR="${PROJECT_DIR}/output"

# Загрузка .env
if [ -f "${PROJECT_DIR}/.env" ]; then
    source "${PROJECT_DIR}/.env"
fi

# Дефолты
BAIT_SNI="${BAIT_SNI:-www.microsoft.com}"
LISTEN_PORT="${LISTEN_PORT:-443}"
CLIENTS_COUNT="${CLIENTS_COUNT:-10}"

echo "🔧 Генерация конфига VLESS/REALITY..."
echo "   SNI: ${BAIT_SNI}"
echo "   Port: ${LISTEN_PORT}"
echo "   Clients: ${CLIENTS_COUNT}"

# Создаём директории
mkdir -p "${CONFIG_DIR}" "${OUTPUT_DIR}"

# Проверяем наличие xray для генерации ключей
if ! command -v xray &>/dev/null; then
    # Скачиваем xray временно для генерации ключей
    echo "📥 Скачиваем xray для генерации ключей..."
    TMP_DIR=$(mktemp -d)
    
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64) XR_ARCH="64" ;;
        aarch64|arm64) XR_ARCH="arm64-v8a" ;;
        *) echo "❌ Unsupported arch: $ARCH"; exit 1 ;;
    esac
    
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    case "$OS" in
        darwin) XR_OS="macos" ;;
        linux) XR_OS="linux" ;;
        *) echo "❌ Unsupported OS: $OS"; exit 1 ;;
    esac
    
    LATEST=$(curl -fsSL https://api.github.com/repos/XTLS/Xray-core/releases/latest | grep -o '"tag_name": "[^"]*' | cut -d'"' -f4)
    curl -fsSL -o "${TMP_DIR}/xray.zip" "https://github.com/XTLS/Xray-core/releases/download/${LATEST}/Xray-${XR_OS}-${XR_ARCH}.zip"
    unzip -q -o "${TMP_DIR}/xray.zip" -d "${TMP_DIR}"
    chmod +x "${TMP_DIR}/xray"
    XRAY_BIN="${TMP_DIR}/xray"
    CLEANUP_TMP=1
else
    XRAY_BIN="xray"
    CLEANUP_TMP=0
fi

# Генерация ключей REALITY
echo "🔑 Генерация ключей REALITY..."
KEY_OUTPUT=$("$XRAY_BIN" x25519 2>&1)

# Извлекаем Private Key
PRIV=$(echo "$KEY_OUTPUT" | grep -i "private" | sed 's/.*: *//' | tr -d ' \t\r\n')
if [ -z "$PRIV" ]; then
    echo "❌ Не удалось извлечь PrivateKey"
    echo "DEBUG: $KEY_OUTPUT"
    exit 1
fi

# Получаем Public Key (в новых версиях Xray он называется "Password")
PUB_OUTPUT=$("$XRAY_BIN" x25519 -i "$PRIV" 2>&1)

# Пробуем PublicKey (старые версии)
PUB=$(echo "$PUB_OUTPUT" | grep -i "public" | sed 's/.*: *//' | tr -d ' \t\r\n')

# Пробуем Password (новые версии Xray - это и есть PublicKey)
if [ -z "$PUB" ]; then
    PUB=$(echo "$PUB_OUTPUT" | grep -i "password" | sed 's/.*: *//' | tr -d ' \t\r\n')
fi

# Fallback: ищем любой base64url токен
if [ -z "$PUB" ]; then
    PUB=$(echo "$PUB_OUTPUT" | grep -Eo '[A-Za-z0-9_-]{43,44}' | grep -v "^${PRIV}$" | head -1)
fi

if [ -z "$PUB" ]; then
    echo "❌ Не удалось извлечь PublicKey"
    echo "DEBUG: $PUB_OUTPUT"
    exit 1
fi

# ShortID
SID=$(openssl rand -hex 8)

echo "   PrivateKey: ${PRIV:0:10}..."
echo "   PublicKey: ${PUB:0:10}..."
echo "   ShortID: ${SID}"

# Генерация UUID для клиентов
echo "👥 Генерация ${CLIENTS_COUNT} клиентов..."
declare -a CLIENT_UUIDS
CLIENTS_JSON="["

for i in $(seq 1 "$CLIENTS_COUNT"); do
    if command -v uuidgen &>/dev/null; then
        UUID=$(uuidgen | tr '[:upper:]' '[:lower:]')
    else
        UUID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || python3 -c "import uuid; print(uuid.uuid4())")
    fi
    CLIENT_UUIDS[$i]="$UUID"
    
    if [ "$i" -gt 1 ]; then
        CLIENTS_JSON="${CLIENTS_JSON},"
    fi
    CLIENTS_JSON="${CLIENTS_JSON}{\"id\":\"${UUID}\",\"flow\":\"xtls-rprx-vision\"}"
done
CLIENTS_JSON="${CLIENTS_JSON}]"

# Создание конфига Xray
echo "📝 Создание конфига..."
cat > "${CONFIG_DIR}/config.json" <<EOF
{
  "log": {
    "loglevel": "warning",
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log"
  },
  "inbounds": [
    {
      "tag": "vless-reality-in",
      "port": ${LISTEN_PORT},
      "listen": "0.0.0.0",
      "protocol": "vless",
      "settings": {
        "clients": ${CLIENTS_JSON},
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "${BAIT_SNI}:443",
          "serverNames": ["${BAIT_SNI}"],
          "privateKey": "${PRIV}",
          "shortIds": ["${SID}"]
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls", "quic"],
        "routeOnly": false
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
    },
    {
      "protocol": "blackhole",
      "tag": "blocked"
    }
  ],
  "routing": {
    "domainStrategy": "AsIs",
    "rules": []
  }
}
EOF

# Определение публичного IP
echo "🌐 Определение публичного IP..."
if [ -n "${SERVER_IP:-}" ]; then
    PUBIP="$SERVER_IP"
else
    PUBIP=$(curl -fsSL -4 --connect-timeout 5 ifconfig.co 2>/dev/null || \
            curl -fsSL -4 --connect-timeout 5 ip.sb 2>/dev/null || \
            curl -fsSL -4 --connect-timeout 5 icanhazip.com 2>/dev/null || \
            echo "<SERVER_IP>")
    PUBIP=$(echo "$PUBIP" | tr -d ' \t\r\n')
fi
echo "   IP: ${PUBIP}"

# Генерация ссылок для клиентов
echo "📄 Генерация ссылок..."
{
    echo "# ════════════════════════════════════════════════════════════"
    echo "# VLESS/REALITY Clients"
    echo "# Generated: $(date)"
    echo "# ════════════════════════════════════════════════════════════"
    echo "#"
    echo "# Server: ${PUBIP}:${LISTEN_PORT}"
    echo "# SNI: ${BAIT_SNI}"
    echo "# PublicKey (pbk): ${PUB}"
    echo "# ShortID (sid): ${SID}"
    echo "#"
    echo "# ════════════════════════════════════════════════════════════"
    echo ""
    
    for i in $(seq 1 "$CLIENTS_COUNT"); do
        UUID="${CLIENT_UUIDS[$i]}"
        LINK="vless://${UUID}@${PUBIP}:${LISTEN_PORT}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${BAIT_SNI}&fp=chrome&pbk=${PUB}&sid=${SID}&type=tcp#VLESS-${i}"
        echo "[Client ${i}]"
        echo "UUID: ${UUID}"
        echo "Link: ${LINK}"
        echo ""
    done
} > "${OUTPUT_DIR}/clients.txt"

# Сохраняем ключи отдельно (для утилит)
cat > "${CONFIG_DIR}/.keys" <<EOF
PRIVATE_KEY=${PRIV}
PUBLIC_KEY=${PUB}
SHORT_ID=${SID}
SNI=${BAIT_SNI}
PORT=${LISTEN_PORT}
EOF

# Cleanup
if [ "${CLEANUP_TMP:-0}" -eq 1 ]; then
    rm -rf "${TMP_DIR}"
fi

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║              ✅ КОНФИГ СГЕНЕРИРОВАН!                         ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "📁 Конфиг: ${CONFIG_DIR}/config.json"
echo "📄 Ссылки: ${OUTPUT_DIR}/clients.txt"
echo ""
echo "Запуск: make up"

