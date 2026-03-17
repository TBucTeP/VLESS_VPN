#!/usr/bin/env bash
#
# Generate Reality keys and inject them into xray_config.json
#
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="${PROJECT_DIR}/xray_config.json"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "xray_config.json not found"
    exit 1
fi

# Check if keys already generated (not placeholder)
CURRENT_KEY=$(jq -r '.inbounds[0].streamSettings.realitySettings.privateKey' "$CONFIG_FILE" 2>/dev/null)
if [ -n "$CURRENT_KEY" ] && [ "$CURRENT_KEY" != "GENERATE_ME" ] && [ "$CURRENT_KEY" != "null" ]; then
    echo "Keys already exist in xray_config.json"
    echo "  PrivateKey: ${CURRENT_KEY:0:10}..."
    read -p "Regenerate? [y/N] " confirm
    if [ "${confirm}" != "y" ] && [ "${confirm}" != "Y" ]; then
        echo "Skipped"
        exit 0
    fi
fi

# Get xray binary
XRAY_BIN=""
CLEANUP_TMP=0

if command -v xray &>/dev/null; then
    XRAY_BIN="xray"
elif docker ps --format '{{.Names}}' 2>/dev/null | grep -q 'marzban'; then
    # Use xray from running Marzban container
    KEY_OUTPUT=$(docker exec marzban xray x25519 2>&1)
    PRIV=$(echo "$KEY_OUTPUT" | grep -i "private" | sed 's/.*: *//' | tr -d ' \t\r\n')
    if [ -n "$PRIV" ]; then
        PUB_OUTPUT=$(docker exec marzban xray x25519 -i "$PRIV" 2>&1)
        PUB=$(echo "$PUB_OUTPUT" | grep -Eo '[A-Za-z0-9_-]{43,44}' | grep -v "^${PRIV}$" | head -1 || true)
    fi
else
    echo "Downloading xray for key generation..."
    TMP_DIR=$(mktemp -d)
    CLEANUP_TMP=1

    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64) XR_ARCH="64" ;;
        aarch64|arm64) XR_ARCH="arm64-v8a" ;;
        *) echo "Unsupported arch: $ARCH"; exit 1 ;;
    esac

    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    case "$OS" in
        darwin) XR_OS="macos" ;;
        linux) XR_OS="linux" ;;
        *) echo "Unsupported OS: $OS"; exit 1 ;;
    esac

    LATEST=$(curl -fsSL https://api.github.com/repos/XTLS/Xray-core/releases/latest | grep -o '"tag_name": "[^"]*' | cut -d'"' -f4)
    curl -fsSL -o "${TMP_DIR}/xray.zip" "https://github.com/XTLS/Xray-core/releases/download/${LATEST}/Xray-${XR_OS}-${XR_ARCH}.zip"
    unzip -q -o "${TMP_DIR}/xray.zip" -d "${TMP_DIR}"
    chmod +x "${TMP_DIR}/xray"
    XRAY_BIN="${TMP_DIR}/xray"
fi

# Generate keys if not already done via docker
if [ -z "${PRIV:-}" ]; then
    KEY_OUTPUT=$("$XRAY_BIN" x25519 2>&1)
    PRIV=$(echo "$KEY_OUTPUT" | grep -i "private" | sed 's/.*: *//' | tr -d ' \t\r\n')

    if [ -z "$PRIV" ]; then
        echo "Failed to generate keys"
        exit 1
    fi

    PUB_OUTPUT=$("$XRAY_BIN" x25519 -i "$PRIV" 2>&1)
    PUB=$(echo "$PUB_OUTPUT" | grep -i "public" | sed 's/.*: *//' | tr -d ' \t\r\n' || true)

    if [ -z "$PUB" ]; then
        PUB=$(echo "$PUB_OUTPUT" | grep -Eo '[A-Za-z0-9_-]{43,44}' | grep -v "^${PRIV}$" | head -1 || true)
    fi
fi

if [ -z "${PUB:-}" ]; then
    echo "Failed to extract public key"
    exit 1
fi

# Generate ShortID
SID=$(openssl rand -hex 8)

# Update xray_config.json — all inbounds get same keys
jq --arg pk "$PRIV" --arg sid "$SID" \
   '.inbounds |= map(.streamSettings.realitySettings.privateKey = $pk | .streamSettings.realitySettings.shortIds = [$sid])' \
   "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"

# Cleanup
if [ "${CLEANUP_TMP}" -eq 1 ]; then
    rm -rf "${TMP_DIR}"
fi

echo ""
echo "  Reality keys generated"
echo "  ======================"
echo "  PrivateKey: ${PRIV:0:20}..."
echo "  PublicKey:  ${PUB:0:20}..."
echo "  ShortID:    ${SID}"
echo ""
echo "  Keys injected into xray_config.json"
echo ""
