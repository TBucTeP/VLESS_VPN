#!/usr/bin/env bash
#
# Install dependencies: Docker, jq, openssl, curl, UFW
#
set -Eeuo pipefail

[ "$(id -u)" -eq 0 ] || { echo "Run as root: sudo bash $0"; exit 1; }

echo ""
echo "  Installing dependencies for VLESS VPN (Marzban)"
echo "  ================================================"
echo ""

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VERSION=$VERSION_ID
else
    echo "Unsupported OS"
    exit 1
fi

echo "OS: $OS $VERSION"
echo ""

# Update packages
export DEBIAN_FRONTEND=noninteractive
apt-get update -y

# Base packages
echo "Installing base packages..."
apt-get install -y make jq openssl unzip curl ca-certificates gnupg lsb-release qrencode

# Docker
if ! command -v docker &>/dev/null; then
    echo "Installing Docker..."
    curl -fsSL https://get.docker.com | sh
    echo "Docker installed: $(docker --version)"
else
    echo "Docker already installed: $(docker --version)"
fi

# Docker Compose check
if docker compose version &>/dev/null; then
    echo "Docker Compose: $(docker compose version | head -1)"
else
    echo "WARNING: Docker Compose plugin not found"
fi

# UFW
echo ""
echo "Configuring firewall..."

if ! command -v ufw &>/dev/null; then
    apt-get install -y ufw
fi

ufw default deny incoming 2>/dev/null || true
ufw default allow outgoing 2>/dev/null || true
ufw allow 22/tcp comment 'SSH' 2>/dev/null || true
ufw allow 443/tcp comment 'VLESS-TCP-Reality' 2>/dev/null || true
ufw allow 2053/tcp comment 'VLESS-gRPC-Reality' 2>/dev/null || true
ufw allow 8000/tcp comment 'Marzban-Panel' 2>/dev/null || true

if ! ufw status | grep -q "Status: active"; then
    ufw --force enable
else
    echo "UFW already active"
fi

echo ""
echo "  Dependencies installed"
echo "  ======================"
echo ""
echo "  Docker: $(docker --version 2>/dev/null | cut -d' ' -f3 | tr -d ',')"
echo "  Ports opened: 22, 443, 2053, 8000"
echo ""
echo "  Next: make install"
echo ""
