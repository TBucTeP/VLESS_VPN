#!/usr/bin/env bash
#
# Генерация конфига Xray/REALITY (Multi-Port Anti-Block)
# Создаёт ключи, UUID клиентов, конфиг и ссылки
#
# Порты:
#   - 2053 (TCP)  - iCloud SNI (основной, редко блокируют)
#   - 8443 (gRPC) - Google SNI (резервный)
#   - 443  (TCP)  - опциональный (часто блокируют)
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

# Дефолты — Anti-Block конфигурация
PRIMARY_PORT="${PRIMARY_PORT:-2053}"
GRPC_PORT="${GRPC_PORT:-8443}"
LEGACY_PORT="${LEGACY_PORT:-443}"
PRIMARY_SNI="${PRIMARY_SNI:-gateway.icloud.com}"
GRPC_SNI="${GRPC_SNI:-www.google.com}"
CLIENTS_COUNT="${CLIENTS_COUNT:-10}"
ENABLE_LEGACY_PORT="${ENABLE_LEGACY_PORT:-false}"

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║       🔐 VLESS/REALITY Anti-Block Configuration              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "🔧 Генерация конфига VLESS/REALITY..."
echo "   Primary: TCP  port ${PRIMARY_PORT} (SNI: ${PRIMARY_SNI})"
echo "   gRPC:    gRPC port ${GRPC_PORT} (SNI: ${GRPC_SNI})"
if [ "$ENABLE_LEGACY_PORT" = "true" ]; then
    echo "   Legacy:  TCP  port ${LEGACY_PORT} (SNI: ${PRIMARY_SNI})"
fi
echo "   Clients: ${CLIENTS_COUNT}"
echo ""

# Создаём директории
mkdir -p "${CONFIG_DIR}" "${OUTPUT_DIR}"

# Проверяем наличие xray для генерации ключей
if ! command -v xray &>/dev/null; then
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

PRIV=$(echo "$KEY_OUTPUT" | grep -i "private" | sed 's/.*: *//' | tr -d ' \t\r\n')
if [ -z "$PRIV" ]; then
    echo "❌ Не удалось извлечь PrivateKey"
    echo "DEBUG: $KEY_OUTPUT"
    exit 1
fi

PUB_OUTPUT=$("$XRAY_BIN" x25519 -i "$PRIV" 2>&1)
PUB=$(echo "$PUB_OUTPUT" | grep -i "public" | sed 's/.*: *//' | tr -d ' \t\r\n' || true)

if [ -z "$PUB" ]; then
    PUB=$(echo "$PUB_OUTPUT" | grep -i "password" | sed 's/.*: *//' | tr -d ' \t\r\n' || true)
fi

if [ -z "$PUB" ]; then
    PUB=$(echo "$PUB_OUTPUT" | grep -Eo '[A-Za-z0-9_-]{43,44}' | grep -v "^${PRIV}$" | head -1 || true)
fi

if [ -z "$PUB" ]; then
    echo "❌ Не удалось извлечь PublicKey"
    exit 1
fi

# ShortID
SID=$(openssl rand -hex 8)

echo "   PrivateKey: ${PRIV:0:10}..."
echo "   PublicKey: ${PUB:0:10}..."
echo "   ShortID: ${SID}"

# Генерация UUID для клиентов
echo ""
echo "👥 Генерация ${CLIENTS_COUNT} клиентов..."
declare -a CLIENT_UUIDS

# JSON для клиентов с flow (TCP)
CLIENTS_TCP="["
# JSON для клиентов без flow (gRPC)
CLIENTS_GRPC="["

for i in $(seq 1 "$CLIENTS_COUNT"); do
    if command -v uuidgen &>/dev/null; then
        UUID=$(uuidgen | tr '[:upper:]' '[:lower:]')
    else
        UUID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || python3 -c "import uuid; print(uuid.uuid4())")
    fi
    CLIENT_UUIDS[$i]="$UUID"
    
    if [ "$i" -gt 1 ]; then
        CLIENTS_TCP="${CLIENTS_TCP},"
        CLIENTS_GRPC="${CLIENTS_GRPC},"
    fi
    CLIENTS_TCP="${CLIENTS_TCP}{\"id\":\"${UUID}\",\"flow\":\"xtls-rprx-vision\"}"
    CLIENTS_GRPC="${CLIENTS_GRPC}{\"id\":\"${UUID}\"}"
done
CLIENTS_TCP="${CLIENTS_TCP}]"
CLIENTS_GRPC="${CLIENTS_GRPC}]"

# Создание конфига Xray (Multi-Port)
echo "📝 Создание multi-port конфига..."

# Формируем inbounds
INBOUNDS="["

# 1. Primary TCP inbound (port 2053, iCloud SNI)
INBOUNDS="${INBOUNDS}
    {
      \"tag\": \"vless-reality-tcp\",
      \"port\": ${PRIMARY_PORT},
      \"listen\": \"0.0.0.0\",
      \"protocol\": \"vless\",
      \"settings\": {
        \"clients\": ${CLIENTS_TCP},
        \"decryption\": \"none\"
      },
      \"streamSettings\": {
        \"network\": \"tcp\",
        \"security\": \"reality\",
        \"realitySettings\": {
          \"show\": false,
          \"dest\": \"${PRIMARY_SNI}:443\",
          \"serverNames\": [\"${PRIMARY_SNI}\"],
          \"privateKey\": \"${PRIV}\",
          \"shortIds\": [\"${SID}\", \"\"]
        }
      },
      \"sniffing\": {
        \"enabled\": true,
        \"destOverride\": [\"http\", \"tls\", \"quic\"]
      }
    }"

# 2. gRPC inbound (port 8443, Google SNI)
INBOUNDS="${INBOUNDS},
    {
      \"tag\": \"vless-reality-grpc\",
      \"port\": ${GRPC_PORT},
      \"listen\": \"0.0.0.0\",
      \"protocol\": \"vless\",
      \"settings\": {
        \"clients\": ${CLIENTS_GRPC},
        \"decryption\": \"none\"
      },
      \"streamSettings\": {
        \"network\": \"grpc\",
        \"grpcSettings\": {
          \"serviceName\": \"grpc\"
        },
        \"security\": \"reality\",
        \"realitySettings\": {
          \"show\": false,
          \"dest\": \"${GRPC_SNI}:443\",
          \"serverNames\": [\"${GRPC_SNI}\"],
          \"privateKey\": \"${PRIV}\",
          \"shortIds\": [\"${SID}\", \"\"]
        }
      },
      \"sniffing\": {
        \"enabled\": true,
        \"destOverride\": [\"http\", \"tls\", \"quic\"]
      }
    }"

# 3. Legacy TCP inbound (port 443) — optional
if [ "$ENABLE_LEGACY_PORT" = "true" ]; then
    INBOUNDS="${INBOUNDS},
    {
      \"tag\": \"vless-reality-legacy\",
      \"port\": ${LEGACY_PORT},
      \"listen\": \"0.0.0.0\",
      \"protocol\": \"vless\",
      \"settings\": {
        \"clients\": ${CLIENTS_TCP},
        \"decryption\": \"none\"
      },
      \"streamSettings\": {
        \"network\": \"tcp\",
        \"security\": \"reality\",
        \"realitySettings\": {
          \"show\": false,
          \"dest\": \"${PRIMARY_SNI}:443\",
          \"serverNames\": [\"${PRIMARY_SNI}\"],
          \"privateKey\": \"${PRIV}\",
          \"shortIds\": [\"${SID}\", \"\"]
        }
      },
      \"sniffing\": {
        \"enabled\": true,
        \"destOverride\": [\"http\", \"tls\", \"quic\"]
      }
    }"
fi

INBOUNDS="${INBOUNDS}
  ]"

# Полный конфиг
cat > "${CONFIG_DIR}/config.json" <<EOF
{
  "log": {
    "loglevel": "info"
  },
  "inbounds": ${INBOUNDS},
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
echo ""
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
    echo "# VLESS/REALITY Clients (Anti-Block Multi-Port)"
    echo "# Generated: $(date)"
    echo "# ════════════════════════════════════════════════════════════"
    echo "#"
    echo "# Server: ${PUBIP}"
    echo "# PublicKey (pbk): ${PUB}"
    echo "# ShortID (sid): ${SID}"
    echo "#"
    echo "# Ports:"
    echo "#   - ${PRIMARY_PORT} TCP  (${PRIMARY_SNI}) — primary, recommended"
    echo "#   - ${GRPC_PORT} gRPC (${GRPC_SNI}) — backup"
    if [ "$ENABLE_LEGACY_PORT" = "true" ]; then
        echo "#   - ${LEGACY_PORT} TCP  (${PRIMARY_SNI}) — legacy (often blocked)"
    fi
    echo "#"
    echo "# ════════════════════════════════════════════════════════════"
    echo ""
    
    for i in $(seq 1 "$CLIENTS_COUNT"); do
        UUID="${CLIENT_UUIDS[$i]}"
        
        # Primary TCP link
        LINK_TCP="vless://${UUID}@${PUBIP}:${PRIMARY_PORT}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${PRIMARY_SNI}&fp=chrome&pbk=${PUB}&sid=${SID}&type=tcp#VLESS-${i}-TCP"
        
        # gRPC link
        LINK_GRPC="vless://${UUID}@${PUBIP}:${GRPC_PORT}?encryption=none&security=reality&sni=${GRPC_SNI}&fp=chrome&pbk=${PUB}&sid=${SID}&type=grpc&serviceName=grpc#VLESS-${i}-gRPC"
        
        echo "[Client ${i}]"
        echo "UUID: ${UUID}"
        echo ""
        echo "🔹 TCP (Primary - port ${PRIMARY_PORT}):"
        echo "${LINK_TCP}"
        echo ""
        echo "🔹 gRPC (Backup - port ${GRPC_PORT}):"
        echo "${LINK_GRPC}"
        
        if [ "$ENABLE_LEGACY_PORT" = "true" ]; then
            LINK_LEGACY="vless://${UUID}@${PUBIP}:${LEGACY_PORT}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${PRIMARY_SNI}&fp=chrome&pbk=${PUB}&sid=${SID}&type=tcp#VLESS-${i}-Legacy"
            echo ""
            echo "🔹 Legacy (port ${LEGACY_PORT}):"
            echo "${LINK_LEGACY}"
        fi
        
        echo ""
        echo "────────────────────────────────────────────────────────────────"
        echo ""
    done
} > "${OUTPUT_DIR}/clients.txt"

# Сохраняем ключи
cat > "${CONFIG_DIR}/.keys" <<EOF
PRIVATE_KEY=${PRIV}
PUBLIC_KEY=${PUB}
SHORT_ID=${SID}
PRIMARY_SNI=${PRIMARY_SNI}
GRPC_SNI=${GRPC_SNI}
PRIMARY_PORT=${PRIMARY_PORT}
GRPC_PORT=${GRPC_PORT}
LEGACY_PORT=${LEGACY_PORT}
ENABLE_LEGACY_PORT=${ENABLE_LEGACY_PORT}
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
echo "🔐 Порты (все нужно открыть в firewall):"
echo "   - ${PRIMARY_PORT}/tcp (TCP primary)"
echo "   - ${GRPC_PORT}/tcp (gRPC backup)"
if [ "$ENABLE_LEGACY_PORT" = "true" ]; then
    echo "   - ${LEGACY_PORT}/tcp (Legacy)"
fi
echo ""
echo "Запуск: make up"
