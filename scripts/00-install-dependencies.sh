#!/usr/bin/env bash
#
# Автоматическая установка всех зависимостей
# Docker, make, jq, openssl, unzip, curl, firewall
#
set -Eeuo pipefail

[ "$(id -u)" -eq 0 ] || { echo "❌ Запусти как root: sudo bash $0"; exit 1; }

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║         🔧 УСТАНОВКА ЗАВИСИМОСТЕЙ ДЛЯ VLESS VPN             ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Определяем ОС
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VERSION=$VERSION_ID
else
    echo "❌ Не удалось определить ОС"
    exit 1
fi

echo "📦 Обнаружена ОС: $OS $VERSION"
echo ""

# Обновление пакетов
echo "🔄 Обновление списка пакетов..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y

# Базовые пакеты
echo "📦 Установка базовых пакетов (make, jq, openssl, unzip, curl)..."
apt-get install -y make jq openssl unzip curl ca-certificates gnupg lsb-release

# Docker
if ! command -v docker &>/dev/null; then
    echo "🐳 Установка Docker..."
    
    if [ "$OS" = "ubuntu" ] && [ "$(echo "$VERSION" | cut -d. -f1)" -lt 22 ]; then
        # Ubuntu 20.04 и ниже - ручная установка
        echo "   Ubuntu 20.04 или ниже - ручная установка Docker..."
        apt-get install -y ca-certificates curl
        install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
        chmod a+r /etc/apt/keyrings/docker.asc
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
        apt-get update -y
        apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    else
        # Ubuntu 22.04+ / Debian 12+ - автоматическая установка
        curl -fsSL https://get.docker.com | sh
    fi
    
    # Проверка Docker
    if docker --version &>/dev/null; then
        echo "   ✅ Docker установлен: $(docker --version)"
    else
        echo "   ❌ Ошибка установки Docker"
        exit 1
    fi
else
    echo "   ✅ Docker уже установлен: $(docker --version)"
fi

# Docker Compose
if ! docker compose version &>/dev/null; then
    echo "   ⚠️  Docker Compose не найден, но должен быть установлен с Docker"
else
    echo "   ✅ Docker Compose: $(docker compose version | head -1)"
fi

# Настройка firewall (UFW)
echo ""
echo "🛡️  Настройка Firewall (UFW)..."

if ! command -v ufw &>/dev/null; then
    echo "   Установка UFW..."
    apt-get install -y ufw
fi

# Настройка правил
echo "   Настройка правил firewall..."
ufw default deny incoming 2>/dev/null || true
ufw default allow outgoing 2>/dev/null || true
ufw allow 22/tcp comment 'SSH' 2>/dev/null || true
ufw allow 443/tcp comment 'VLESS/REALITY' 2>/dev/null || true
ufw allow 51820/udp comment 'WireGuard' 2>/dev/null || true
ufw allow 1194/udp comment 'OpenVPN' 2>/dev/null || true

# Включаем UFW (неинтерактивно)
if ! ufw status | grep -q "Status: active"; then
    echo "   Включение UFW..."
    ufw --force enable
else
    echo "   ✅ UFW уже активен"
fi

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║              ✅ ВСЕ ЗАВИСИМОСТИ УСТАНОВЛЕНЫ!                  ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "📋 Установлено:"
echo "   ✅ Docker: $(docker --version 2>/dev/null | cut -d' ' -f3 | tr -d ',')"
echo "   ✅ Docker Compose: $(docker compose version 2>/dev/null | head -1 | awk '{print $4}')"
echo "   ✅ make, jq, openssl, unzip, curl"
echo "   ✅ UFW (firewall) настроен: порты 22, 443 открыты"
echo ""
echo "🚀 Теперь можно запускать:"
echo "   cd ~/VLESS_VPN"
echo "   make install"
echo ""

