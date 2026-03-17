#!/usr/bin/env bash
#
# Test VPN connection by checking port reachability
# and optionally testing through the proxy
#
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="${PROJECT_DIR}/config/config.json"
KEYS_FILE="${PROJECT_DIR}/config/.keys"

# Load keys
if [ -f "$KEYS_FILE" ]; then
    source "$KEYS_FILE"
fi

PRIMARY_PORT="${PRIMARY_PORT:-2053}"
GRPC_PORT="${GRPC_PORT:-8443}"
PRIMARY_SNI="${PRIMARY_SNI:-gateway.icloud.com}"
GRPC_SNI="${GRPC_SNI:-www.google.com}"

echo ""
echo "  VLESS Reality Connection Test"
echo "  =============================="
echo ""

# 1. Container check
echo "  [1/5] Container status"
if docker ps --format '{{.Names}}' 2>/dev/null | grep -q 'xray-vless'; then
    UPTIME=$(docker ps --filter "name=xray-vless" --format '{{.Status}}')
    echo "        OK  xray-vless ($UPTIME)"
elif docker ps --format '{{.Names}}' 2>/dev/null | grep -q 'marzban'; then
    UPTIME=$(docker ps --filter "name=marzban" --format '{{.Status}}')
    echo "        OK  marzban ($UPTIME)"
else
    echo "        FAIL  No VPN container running"
    echo "              Run: make up"
    exit 1
fi

# 2. Local port check
echo ""
echo "  [2/5] Local ports"
PORTS_OK=0
PORTS_FAIL=0
for PORT in $PRIMARY_PORT $GRPC_PORT; do
    if ss -ltnp 2>/dev/null | grep -q ":${PORT} " || \
       netstat -tlnp 2>/dev/null | grep -q ":${PORT} "; then
        echo "        OK  :${PORT} listening"
        PORTS_OK=$((PORTS_OK + 1))
    else
        echo "        FAIL  :${PORT} not listening"
        PORTS_FAIL=$((PORTS_FAIL + 1))
    fi
done

# 3. Public IP
echo ""
echo "  [3/5] Public IP"
PUBIP=$(curl -fsSL -4 --connect-timeout 5 ifconfig.co 2>/dev/null || \
        curl -fsSL -4 --connect-timeout 5 ip.sb 2>/dev/null || \
        echo "")
if [ -n "$PUBIP" ]; then
    echo "        OK  $PUBIP"
else
    echo "        FAIL  Could not determine public IP"
fi

# 4. SNI reachability
echo ""
echo "  [4/5] SNI targets"
for SNI in "$PRIMARY_SNI" "$GRPC_SNI"; do
    HTTP_CODE=$(curl -fsSL -o /dev/null -w "%{http_code}" --connect-timeout 3 "https://${SNI}" 2>/dev/null || echo "000")
    if [ "$HTTP_CODE" != "000" ]; then
        echo "        OK  $SNI (HTTP $HTTP_CODE)"
    else
        echo "        WARN  $SNI unreachable (may still work for Reality)"
    fi
done

# 5. External port check (self-connect via public IP)
echo ""
echo "  [5/5] External reachability"
if [ -n "$PUBIP" ]; then
    for PORT in $PRIMARY_PORT $GRPC_PORT; do
        if timeout 3 bash -c "echo >/dev/tcp/${PUBIP}/${PORT}" 2>/dev/null; then
            echo "        OK  ${PUBIP}:${PORT} reachable"
        else
            echo "        FAIL  ${PUBIP}:${PORT} not reachable"
            echo "              Check: ufw status, cloud provider firewall"
        fi
    done
else
    echo "        SKIP  No public IP detected"
fi

# Summary
echo ""
echo "  ────────────────────────────────────────"
if [ "$PORTS_FAIL" -eq 0 ] && [ -n "$PUBIP" ]; then
    echo "  Server looks good. If clients can't connect:"
    echo "    1. Check cloud provider firewall (AWS SG, etc.)"
    echo "    2. Try different port: gRPC ${GRPC_PORT} instead of TCP ${PRIMARY_PORT}"
    echo "    3. Try different SNI: make change-sni SNI=cloudflare.com"
else
    echo "  Issues detected. Check errors above."
fi
echo ""
