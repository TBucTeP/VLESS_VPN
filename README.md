# VLESS Reality VPN

VPN-сервер на VLESS + Reality (Xray-core). Два режима работы:

- **Standalone** (по умолчанию) — голый Xray, управление через CLI/Makefile
- **Marzban** (опционально) — веб-панель с UI, подписками, мониторингом трафика

## Быстрый старт

```bash
git clone https://github.com/TBucTeP/VLESS_VPN.git
cd VLESS_VPN
sudo make setup           # standalone
# или
sudo make setup MARZBAN=1 # с веб-панелью
```

---

## Standalone режим

Как было: скрипты генерируют конфиг Xray, ключи и ссылки для клиентов.

### Установка

```bash
sudo make install-deps    # Docker, jq, openssl, UFW
make install              # Генерация конфига + запуск
```

### Управление клиентами

```bash
make list                          # Показать всех клиентов со ссылками
make add                           # Добавить клиента
make remove UUID=<uuid>            # Удалить клиента
```

### Безопасность

```bash
make rotate-keys                   # Ротация ключей Reality
make change-sni SNI=cloudflare.com # Сменить SNI
make change-sid                    # Сменить ShortID
make restart                       # Применить изменения
```

### Настройка

Перед `make install` можно отредактировать `.env`:

```bash
cp .env.example .env
nano .env
```

| Параметр | По умолчанию | Описание |
|----------|-------------|----------|
| `BAIT_SNI` | `gateway.icloud.com` | SNI для маскировки |
| `LISTEN_PORT` | `2053` | Порт VLESS |
| `CLIENTS_COUNT` | `10` | Кол-во клиентов при генерации |
| `SERVER_IP` | авто | IP сервера |

### Файлы

```
config/config.json     # Конфиг Xray (генерируется)
config/.keys           # Ключи Reality
output/clients.txt     # Ссылки для клиентов
```

---

## Marzban режим

Веб-панель [Marzban](https://github.com/Gozargah/Marzban) вместо ручного управления.

### Что дает

- Веб-панель для управления пользователями
- Subscription URL — клиенты автоматически получают обновленные конфиги
- Мониторинг трафика, лимиты, сроки действия
- Telegram-бот для уведомлений
- REST API

### Установка

```bash
sudo make install-deps
cp .env.example .env
nano .env                          # Смени SUDO_USERNAME / SUDO_PASSWORD
make install MARZBAN=1
```

Панель: `http://<IP>:8000/dashboard/`

### Управление

```bash
make up MARZBAN=1                  # Запустить
make down MARZBAN=1                # Остановить
make restart MARZBAN=1             # Перезапустить
make logs MARZBAN=1                # Логи
make admin MARZBAN=1               # Создать админа через CLI
```

Клиенты, подписки и ключи управляются через веб-панель.

### Xray конфиг

`xray_config.json` — шаблон только с VLESS Reality (TCP:443 + gRPC:2053). Marzban автоматически добавляет пользователей.

---

## Общие команды

| Команда | Описание |
|---------|----------|
| `make status` | Статус контейнера и портов |
| `make diagnostics` | Полная диагностика (standalone) |
| `make clean` | Удалить все (контейнер + данные) |

## Порты

| Порт | Назначение |
|------|------------|
| 2053 | VLESS TCP Reality (standalone primary) |
| 8443 | VLESS gRPC Reality (standalone backup) |
| 443 | VLESS TCP Reality (Marzban primary) |
| 2053 | VLESS gRPC Reality (Marzban backup) |
| 8000 | Marzban панель (только Marzban режим) |

## Клиенты

- **iOS**: Shadowrocket, V2Box, Streisand
- **Android**: v2rayNG, NekoBox
- **Windows**: v2rayN, Nekoray
- **macOS**: V2RayXS, Nekoray

Standalone: копируй ссылку из `make list` -> вставь в клиент.
Marzban: скопируй subscription URL из панели -> вставь в клиент (автообновление конфигов).

## Рекомендуемые SNI

- `gateway.icloud.com` (по умолчанию)
- `www.microsoft.com`
- `login.microsoftonline.com`
- `cloudflare.com`
- `www.google.com`

## Структура проекта

```
VLESS_VPN/
├── docker-compose.yml              # Standalone (Xray)
├── docker-compose.marzban.yml      # Marzban (Xray + панель)
├── xray_config.json                # Xray конфиг для Marzban
├── Makefile
├── .env.example
├── scripts/
│   ├── install-deps.sh             # Зависимости (Marzban)
│   ├── 00-install-dependencies.sh  # Зависимости (standalone)
│   ├── generate-config.sh          # Генерация конфига
│   ├── gen-keys.sh                 # Генерация Reality-ключей
│   ├── add-client.sh
│   ├── remove-client.sh
│   ├── list-clients.sh
│   ├── rotate-keys.sh
│   ├── change-sni.sh
│   ├── change-sid.sh
│   └── diagnostics.sh
└── README.md
```

## Обновление

```bash
docker compose pull && make restart
# или для Marzban:
docker compose -f docker-compose.marzban.yml pull && make restart MARZBAN=1
```

## License

MIT
