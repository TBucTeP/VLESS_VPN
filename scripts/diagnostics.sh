#!/usr/bin/env bash
#
# Диагностика VLESS/REALITY (Multi-Port)
#
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="${PROJECT_DIR}/config/config.json"
KEYS_FILE="${PROJECT_DIR}/config/.keys"

# Загружаем ключи
if [ -f "$KEYS_FILE" ]; then
    source "$KEYS_FILE"
fi

# Дефолты
PRIMARY_PORT="${PRIMARY_PORT:-2053}"
GRPC_PORT="${GRPC_PORT:-8443}"

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║              🔍 ДИАГНОСТИКА VPN (Multi-Port)                 ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# 1. Статус контейнера
echo "1️⃣  Статус контейнера:"
docker ps --filter "name=xray-vless" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" || echo "❌ Контейнер не запущен"
echo ""

# 2. Порты
echo "2️⃣  Порты (${PRIMARY_PORT}, ${GRPC_PORT}):"
for PORT in $PRIMARY_PORT $GRPC_PORT; do
    if ss -ltnp 2>/dev/null | grep -q ":${PORT}"; then
        echo "   ✅ Порт ${PORT} слушает"
    else
        echo "   ❌ Порт ${PORT} НЕ слушает!"
    fi
done
echo ""

# 3. Firewall
echo "3️⃣  Firewall (UFW):"
if command -v ufw &>/dev/null; then
    UFW_STATUS=$(ufw status | head -1)
    echo "$UFW_STATUS"
    if echo "$UFW_STATUS" | grep -q "active"; then
        echo "   Правила для VLESS портов:"
        ufw status | grep -E "2053|8443|443" || echo "   ⚠️  Порты не разрешены в UFW!"
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
    echo "5️⃣  Проверка SNI:"
    # Get all unique SNIs from config
    SNIS=$(jq -r '.inbounds[].streamSettings.realitySettings.serverNames[0]' "$CONFIG_FILE" 2>/dev/null | sort -u)
    while IFS= read -r SNI; do
        if [ -n "$SNI" ] && [ "$SNI" != "null" ]; then
            if curl -fsSL -4 --connect-timeout 3 "https://${SNI}" >/dev/null 2>&1; then
                echo "   ✅ ${SNI} — доступен"
            else
                echo "   ⚠️  ${SNI} — недоступен (это может быть нормально)"
            fi
        fi
    done <<< "$SNIS"
    echo ""
fi

# 6. Логи Xray
echo "6️⃣  Последние логи Xray:"
docker logs xray-vless --tail 15 2>&1 | tail -10 || echo "❌ Не удалось получить логи"
echo ""

# 7. Конфиг
if [ -f "$CONFIG_FILE" ]; then
    echo "7️⃣  Проверка конфига:"
    if docker exec xray-vless xray -test -c /etc/xray/config.json 2>&1 | grep -q "OK"; then
        echo "   ✅ Конфиг валидный"
    else
        echo "   ❌ Ошибки в конфиге:"
        docker exec xray-vless xray -test -c /etc/xray/config.json 2>&1 | head -5 || true
    fi
else
    echo "   ❌ Конфиг не найден: $CONFIG_FILE"
fi
echo ""

# 8. Проверка доступности портов извне
if [ -n "$PUBIP" ] && [ "$PUBIP" != "<не определён>" ]; then
    echo "8️⃣  Проверка доступности портов извне:"
    echo "   IP: ${PUBIP}"
    echo ""
    echo "   Проверь с другого компьютера:"
    echo "   nc -zv ${PUBIP} ${PRIMARY_PORT}  # TCP primary"
    echo "   nc -zv ${PUBIP} ${GRPC_PORT}  # gRPC backup"
    echo ""
    echo "   Или используй онлайн-чекер:"
    echo "   https://www.yougetsignal.com/tools/open-ports/"
    echo ""
fi

# 9. Проверка конфигурации ссылки
if [ -f "$CONFIG_FILE" ]; then
    echo "9️⃣  Конфигурация для ссылок:"
    
    # Получаем inbounds
    INBOUNDS_COUNT=$(jq '.inbounds | length' "$CONFIG_FILE" 2>/dev/null)
    
    for i in $(seq 0 $((INBOUNDS_COUNT - 1))); do
        TAG=$(jq -r ".inbounds[$i].tag" "$CONFIG_FILE" 2>/dev/null)
        PORT=$(jq -r ".inbounds[$i].port" "$CONFIG_FILE" 2>/dev/null)
        NETWORK=$(jq -r ".inbounds[$i].streamSettings.network" "$CONFIG_FILE" 2>/dev/null)
        SNI=$(jq -r ".inbounds[$i].streamSettings.realitySettings.serverNames[0]" "$CONFIG_FILE" 2>/dev/null)
        SID=$(jq -r ".inbounds[$i].streamSettings.realitySettings.shortIds[0]" "$CONFIG_FILE" 2>/dev/null)
        
        echo ""
        echo "   📡 ${TAG}:"
        echo "      Port: ${PORT}"
        echo "      Network: ${NETWORK}"
        echo "      SNI: ${SNI}"
        echo "      ShortID: ${SID}"
    done
    echo ""
    echo "   PublicKey: ${PUBLIC_KEY:-<смотри в config/.keys>}"
fi
echo ""

# 10. Рекомендации
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    💡 РЕКОМЕНДАЦИИ                           ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "Если клиент не подключается:"
echo "  1. Попробуй сначала TCP порт ${PRIMARY_PORT} (iCloud SNI)"
echo "  2. Если не работает — попробуй gRPC порт ${GRPC_PORT} (Google SNI)"
echo "  3. Проверь что ссылка скопирована полностью"
echo "  4. Убедись что firewall открыл порты: ufw status"
echo ""
echo "Если провайдер блокирует:"
echo "  1. Порт 2053 выглядит как DNS-over-TLS — редко блокируют"
echo "  2. gRPC сложнее детектировать чем обычный TCP"
echo "  3. Попробуй сменить SNI: make change-sni SNI=cloudflare.com"
echo ""
