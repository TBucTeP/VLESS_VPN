#!/usr/bin/env bash
#
# Диагностика VLESS/REALITY
#
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="${PROJECT_DIR}/config/config.json"

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    🔍 ДИАГНОСТИКА VPN                        ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# 1. Статус контейнера
echo "1️⃣  Статус контейнера:"
docker ps --filter "name=xray-vless" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" || echo "❌ Контейнер не запущен"
echo ""

# 2. Порт 443
echo "2️⃣  Порт 443:"
if ss -ltnp 2>/dev/null | grep -q ':443'; then
    echo "✅ Порт 443 слушает:"
    ss -ltnp 2>/dev/null | grep ':443' || true
else
    echo "❌ Порт 443 НЕ слушает!"
fi
echo ""

# 3. Firewall
echo "3️⃣  Firewall (UFW):"
if command -v ufw &>/dev/null; then
    UFW_STATUS=$(ufw status | head -1)
    echo "$UFW_STATUS"
    if echo "$UFW_STATUS" | grep -q "active"; then
        echo "   Правила для порта 443:"
        ufw status | grep 443 || echo "   ⚠️  Порт 443 не разрешён в UFW!"
    fi
else
    echo "⚠️  UFW не установлен"
fi
echo ""

# 4. Публичный IP
echo "4️⃣  Публичный IP сервера:"
PUBIP=$(curl -fsSL -4 --connect-timeout 5 ifconfig.co 2>/dev/null || \
        curl -fsSL -4 --connect-timeout 5 ip.sb 2>/dev/null || \
        echo "<не определён>")
echo "   $PUBIP"
echo ""

# 5. Проверка SNI
if [ -f "$CONFIG_FILE" ]; then
    SNI=$(jq -r '.inbounds[0].streamSettings.realitySettings.serverNames[0]' "$CONFIG_FILE" 2>/dev/null || echo "")
    if [ -n "$SNI" ]; then
        echo "5️⃣  Проверка SNI ($SNI):"
        if curl -fsSL -4 --connect-timeout 5 "https://${SNI}" >/dev/null 2>&1; then
            echo "   ✅ SNI доступен"
        else
            echo "   ⚠️  SNI недоступен (это нормально для некоторых доменов)"
        fi
    fi
    echo ""
fi

# 6. Логи Xray (последние 20 строк)
echo "6️⃣  Последние логи Xray:"
docker logs xray-vless --tail 20 2>&1 | tail -10 || echo "❌ Не удалось получить логи"
echo ""

# 7. Конфиг
if [ -f "$CONFIG_FILE" ]; then
    echo "7️⃣  Проверка конфига:"
    if docker exec xray-vless xray -test -c /etc/xray/config.json 2>&1 | grep -q "OK"; then
        echo "   ✅ Конфиг валидный"
    else
        echo "   ❌ Ошибки в конфиге:"
        docker exec xray-vless xray -test -c /etc/xray/config.json 2>&1 || true
    fi
else
    echo "   ❌ Конфиг не найден: $CONFIG_FILE"
fi
echo ""

# 8. Проверка извне (если есть публичный IP)
if [ -n "$PUBIP" ] && [ "$PUBIP" != "<не определён>" ]; then
    echo "8️⃣  Проверка доступности порта 443 извне:"
    echo "   Запусти на другом компьютере:"
    echo "   nc -zv ${PUBIP} 443"
    echo "   или"
    echo "   telnet ${PUBIP} 443"
    echo ""
fi

# 9. Рекомендации
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    💡 РЕКОМЕНДАЦИИ                             ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "Если порт 443 не доступен извне:"
echo "  1. Проверь firewall провайдера (может блокировать)"
echo "  2. Убедись что UFW разрешает порт: ufw allow 443/tcp"
echo "  3. Проверь что нет других сервисов на порту 443"
echo ""
echo "Если клиент не подключается:"
echo "  1. Проверь что ссылка скопирована полностью"
echo "  2. Убедись что SNI в ссылке совпадает с конфигом"
echo "  3. Проверь PublicKey (pbk) и ShortID (sid) в ссылке"
echo "  4. Попробуй другого клиента (v2rayNG, Shadowrocket)"
echo ""

