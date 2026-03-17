#!/usr/bin/env bash
#
# Generate QR codes for all clients (standalone mode)
#
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="${PROJECT_DIR}/config/config.json"
KEYS_FILE="${PROJECT_DIR}/config/.keys"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Config not found. Run: make init"
    exit 1
fi

if ! command -v qrencode &>/dev/null; then
    echo "qrencode not installed."
    echo ""
    echo "  Ubuntu/Debian: sudo apt install qrencode"
    echo "  macOS:         brew install qrencode"
    exit 1
fi

if ! command -v jq &>/dev/null; then
    echo "jq not installed"
    exit 1
fi

# Load keys
if [ -f "$KEYS_FILE" ]; then
    source "$KEYS_FILE"
fi

PRIMARY_PORT="${PRIMARY_PORT:-2053}"
GRPC_PORT="${GRPC_PORT:-8443}"
PRIMARY_SNI="${PRIMARY_SNI:-gateway.icloud.com}"
GRPC_SNI="${GRPC_SNI:-www.google.com}"

# Detect IP
PUBIP=$(curl -fsSL -4 --connect-timeout 5 ifconfig.co 2>/dev/null || \
        curl -fsSL -4 --connect-timeout 5 ip.sb 2>/dev/null || \
        echo "<SERVER_IP>")
PUBIP=$(echo "$PUBIP" | tr -d ' \t\r\n')

# Optional: specific client number
TARGET="${1:-}"

CLIENTS=$(jq -r '.inbounds[0].settings.clients[] | .id' "$CONFIG_FILE")
COUNT=0

while IFS= read -r UUID; do
    [ -z "$UUID" ] && continue
    COUNT=$((COUNT + 1))

    # Skip if user requested a specific client
    if [ -n "$TARGET" ] && [ "$COUNT" -ne "$TARGET" ]; then
        continue
    fi

    LINK_TCP="vless://${UUID}@${PUBIP}:${PRIMARY_PORT}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${PRIMARY_SNI}&fp=chrome&pbk=${PUBLIC_KEY:-}&sid=${SHORT_ID:-}&type=tcp#VLESS-${COUNT}-TCP"

    echo ""
    echo "  [Client ${COUNT}] TCP port ${PRIMARY_PORT}"
    echo "  UUID: ${UUID}"
    echo ""
    qrencode -t ANSIUTF8 "$LINK_TCP"
    echo ""
    echo "  Link: ${LINK_TCP}"
    echo ""
    echo "  ────────────────────────────────────────"

done <<< "$CLIENTS"

if [ "$COUNT" -eq 0 ]; then
    echo "No clients found"
    exit 1
fi

echo ""
echo "  Total: ${COUNT} client(s)"
echo "  Scan QR with Shadowrocket / v2rayNG / V2RayN"
echo ""
echo "  Show specific client: make qr N=3"
echo ""
