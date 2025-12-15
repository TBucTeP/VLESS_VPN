# 🔐 VLESS/REALITY VPN

Автоматическое развертывание VLESS VPN с REALITY (Xray) через Docker.

```
git clone <repo>
cd VLESS_VPN
make install
```

**Готово!** Ссылки для клиентов в `output/clients.txt`

---

## 📋 Требования

- Ubuntu 22.04+ / Debian 12+ (или любой Linux с Docker)
- Docker + Docker Compose
- jq (`apt install jq`)
- Открытый порт 443

### Быстрая установка Docker (Ubuntu/Debian)

```bash
curl -fsSL https://get.docker.com | sh
apt install -y jq
```

---

## 🚀 Команды

### Установка

```bash
make install     # Полная установка: генерация конфига + запуск + ссылки
```

### Docker

```bash
make up          # Запустить
make down        # Остановить
make restart     # Перезапустить
make logs        # Логи
make status      # Статус
```

### Управление клиентами

```bash
make list        # Список всех клиентов со ссылками
make add         # Добавить нового клиента
make remove UUID=<uuid>  # Удалить клиента
```

### Безопасность

```bash
make rotate-keys              # Ротация ключей REALITY (⚠️ все ссылки сменятся)
make change-sni SNI=<domain>  # Сменить SNI (маскировка)
make change-sid               # Сменить ShortID
```

---

## ⚙️ Настройка

Перед `make install` можно настроить `.env`:

```bash
cp .env.example .env
nano .env
```

```env
# SNI для маскировки
BAIT_SNI=www.microsoft.com

# Порт
LISTEN_PORT=443

# Количество клиентов
CLIENTS_COUNT=10
```

### Рекомендуемые SNI

- `www.microsoft.com` (по умолчанию)
- `login.microsoftonline.com`
- `www.google.com`
- `cloudflare.com`
- `www.apple.com`

---

## 📱 Клиенты

### iOS
- **Shadowrocket** (платный, лучший)
- **V2Box**
- **Streisand**

### Android
- **v2rayNG** (бесплатный)
- **NekoBox**

### Windows
- **v2rayN**
- **Nekoray**

### macOS
- **V2RayXS**
- **Nekoray**

### Как подключиться

1. Скопируй ссылку из `make list`
2. В приложении: **Import** → **From Clipboard** или **Scan QR**
3. Подключись

---

## 🔧 Структура

```
VLESS_VPN/
├── docker-compose.yml   # Docker конфигурация
├── Makefile             # Команды управления
├── .env                 # Настройки (создаётся из .env.example)
├── scripts/             # Скрипты управления
│   ├── generate-config.sh
│   ├── add-client.sh
│   ├── remove-client.sh
│   ├── list-clients.sh
│   ├── rotate-keys.sh
│   ├── change-sni.sh
│   └── change-sid.sh
├── config/              # Конфиг Xray (генерируется)
│   ├── config.json
│   └── .keys
├── output/              # Ссылки клиентов
│   └── clients.txt
└── logs/                # Логи Xray
```

---

## 🔒 Безопасность

### Firewall (UFW)

```bash
ufw allow 22/tcp
ufw allow 443/tcp
ufw enable
```

### Ротация ключей

Периодически меняй ключи для безопасности:

```bash
make rotate-keys  # Генерирует новую пару ключей
make restart      # Применяет
make list         # Новые ссылки
```

---

## 🐛 Диагностика

```bash
# Статус
make status

# Логи
make logs

# Проверка порта
ss -ltnp | grep 443

# Проверка конфига
docker exec xray-vless xray -test -c /etc/xray/config.json
```

---

## 📝 Миграция на другой сервер

```bash
# На старом сервере
tar -czf vless-backup.tar.gz config/ output/

# Скопировать на новый сервер
scp vless-backup.tar.gz root@new-server:~/VLESS_VPN/

# На новом сервере
cd ~/VLESS_VPN
tar -xzf vless-backup.tar.gz
make up
```

---

## License

MIT

