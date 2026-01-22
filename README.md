# 🔐 VLESS/REALITY VPN Server

Автоматическое развертывание VPN сервера через Docker с **VLESS/REALITY** (Xray-core) — маскировка трафика под реальные сайты.

**Быстрый старт:**
```bash
git clone https://github.com/TBucTeP/VLESS_VPN.git
cd VLESS_VPN
sudo make install-deps  # Установка зависимостей
make install            # Установка VPN
```

**Готово!** Ссылки для клиентов в `output/clients.txt`

---

## 📋 Требования

- **ОС**: Ubuntu 20.04+ / Debian 12+ (или любой Linux с поддержкой Docker)
- **Права**: Root доступ (sudo)
- **Порты**: 2053, 8443 (кастомные, настраиваются в `.env`)
- **Интернет**: Стабильное подключение для скачивания Docker и пакетов

---

## 🚀 Установка

### Шаг 1: Клонирование репозитория

```bash
git clone https://github.com/TBucTeP/VLESS_VPN.git
cd VLESS_VPN
```

### Шаг 2: Установка зависимостей

**Автоматическая установка (рекомендуется):**

```bash
sudo make install-deps
```

Или вручную:
```bash
sudo bash scripts/00-install-dependencies.sh
```

**Что устанавливается:**
- ✅ Docker + Docker Compose
- ✅ make, jq, openssl, unzip, curl
- ✅ UFW firewall (настраивается автоматически: порты 22, 2053, 8443, 443)

### Шаг 3: Настройка (опционально)

Перед установкой можно настроить параметры в `.env`:

```bash
cp .env.example .env
nano .env
```

**Параметры:**
```env
# SNI для маскировки (домен Microsoft, Google, и т.д.)
BAIT_SNI=gateway.icloud.com

# Порт для VLESS TCP (по умолчанию 2053)
PRIMARY_PORT=2053

# Порт для VLESS gRPC (по умолчанию 8443)
GRPC_PORT=8443

# Количество клиентов при первой генерации
CLIENTS_COUNT=10

# Публичный IP сервера (автоопределяется если пусто)
# SERVER_IP=
```

**Рекомендуемые SNI:**
- `gateway.icloud.com` (по умолчанию, хорошо работает)
- `www.microsoft.com`
- `login.microsoftonline.com`
- `www.google.com`
- `cloudflare.com`

### Шаг 4: Установка VPN

```bash
make install
```

**Что происходит:**
1. Генерируются ключи REALITY (приватный/публичный)
2. Создаются UUID для клиентов
3. Генерируется конфиг Xray с multi-port
4. Запускается Docker контейнер
5. Выводятся ссылки для подключения

**Результат:**
- Конфиг: `config/config.json`
- Ссылки: `output/clients.txt`
- Контейнер: `xray-vless` (запущен)

---

## 📖 Команды управления

### Основные команды

| Команда | Описание |
|---------|----------|
| `make install-deps` | Установить все зависимости (Docker, пакеты, firewall) |
| `make install` | Полная установка VPN (генерация конфига + запуск) |
| `make init` | Только генерация конфига (без запуска) |
| `make up` | Запустить контейнер Xray |
| `make down` | Остановить контейнер |
| `make restart` | Перезапустить контейнер |
| `make logs` | Показать логи Xray (live) |
| `make status` | Статус контейнера и портов |
| `make diagnostics` | Полная диагностика (проверка всего) |

### Управление клиентами

| Команда | Описание |
|---------|----------|
| `make list` | Показать всех клиентов со ссылками |
| `make add` | Добавить нового клиента (интерактивно) |
| `make remove UUID=<uuid>` | Удалить клиента по UUID |

**Примеры:**
```bash
# Показать всех клиентов
make list

# Добавить клиента
make add

# Удалить клиента
make remove UUID=c1a109e7-0d88-49ce-9c8d-0682cbba5d2d
```

### Безопасность

| Команда | Описание |
|---------|----------|
| `make rotate-keys` | Ротация ключей REALITY ⚠️ (все ссылки сменятся!) |
| `make change-sni SNI=<domain>` | Сменить SNI (маскировку) |
| `make change-sid` | Сменить ShortID |

**Примеры:**
```bash
# Ротация ключей (⚠️ все старые ссылки перестанут работать!)
make rotate-keys
make restart
make list  # Получи новые ссылки

# Сменить SNI
make change-sni SNI=login.microsoftonline.com
make restart

# Сменить ShortID
make change-sid
make restart
```

### Опасные команды

| Команда | Описание |
|---------|----------|
| `make clean` | Удалить всё (контейнер + конфиги) ⚠️ |

---

## 📱 Подключение клиентов

### iOS

#### Shadowrocket ⭐ (Рекомендуется, платный)

**Способ 1: Импорт ссылки (самый простой)**

1. На сервере получи ссылку:
   ```bash
   make list
   ```
2. Скопируй ссылку полностью (от `vless://` до `#VLESS-X`)
3. Открой Shadowrocket
4. Нажми **+** (добавить сервер)
5. Выбери **Import from Clipboard**
6. Нажми **Save**
7. Включи переключатель вверху

**Способ 2: Ручная настройка**

1. Shadowrocket → **+** → **Add Server**
2. Тип: **VLESS**
3. Заполни:
   - **Address**: IP сервера (из `make list`)
   - **Port**: `2053` (TCP) или `8443` (gRPC)
   - **UUID**: из ссылки (`make list`)
   - **Encryption**: `none`
   - **Flow**: `xtls-rprx-vision` (только для TCP)
   - **Network**: `TCP` или `gRPC`
   - **TLS**: `Выключено`
   - **SNI**: `gateway.icloud.com` (в секции TLS)
   - **Открытый ключ** (Public key): из ссылки (pbk)
   - **Краткий ID** (Short ID): из ссылки (sid)
   - **Fingerprint**: `chrome` (если есть поле)
4. **Save** → включи переключатель

#### V2Box (iOS, бесплатный)

1. Скопируй ссылку из `make list`
2. Открой V2Box → **+** → **Import from Clipboard**
3. Или **Scan QR Code**

### Android

#### v2rayNG (бесплатный, рекомендуется)

1. Скопируй ссылку из `make list`
2. Открой v2rayNG
3. Нажми **+** → **Import from Clipboard**
4. Или **Scan QR Code**
5. Включи переключатель

#### NekoBox

1. Скопируй ссылку из `make list`
2. Открой NekoBox → **+** → **Import from Clipboard**

### Windows

#### v2rayN

1. Скопируй ссылку из `make list`
2. Открой v2rayN
3. Нажми **Серверы** → **Импорт серверов из буфера обмена**

#### Nekoray

1. Скопируй ссылку из `make list`
2. Открой Nekoray → **File** → **Import from Clipboard**

### macOS

#### V2RayXS / Nekoray

1. Скопируй ссылку из `make list`
2. Открой приложение → **Servers/File** → **Import from Clipboard**

---

## 🔧 Структура проекта

```
VLESS_VPN/
├── docker-compose.yml          # Docker конфигурация
├── Makefile                    # Команды управления
├── .env.example                # Пример настроек
├── .env                        # Твои настройки (создаётся автоматически)
├── .gitignore                  # Игнорируемые файлы
├── README.md                   # Эта документация
│
├── scripts/                    # Скрипты управления
│   ├── 00-install-dependencies.sh  # Установка зависимостей
│   ├── generate-config.sh          # Генерация конфига и ключей
│   ├── add-client.sh               # Добавить клиента
│   ├── remove-client.sh            # Удалить клиента
│   ├── list-clients.sh             # Список клиентов
│   ├── rotate-keys.sh              # Ротация ключей
│   ├── change-sni.sh               # Сменить SNI
│   ├── change-sid.sh               # Сменить ShortID
│   └── diagnostics.sh              # Диагностика
│
├── config/                      # Конфиг Xray (генерируется)
│   ├── config.json              # Основной конфиг
│   └── .keys                    # Приватные ключи (НЕ ПУБЛИКУЙ!)
│
├── output/                      # Ссылки клиентов (генерируется)
│   └── clients.txt              # Все ссылки для подключения
│
└── logs/                        # Логи Xray (если включено)
```

---

## 🐛 Диагностика и решение проблем

### Проверка статуса

```bash
# Полная диагностика
make diagnostics

# Статус контейнера
make status

# Логи в реальном времени
make logs
```

### Частые проблемы

#### 1. Порт не доступен извне

**Симптомы:**
- Клиент не подключается (timeout)
- `make diagnostics` показывает что порт закрыт

**Решение:**
```bash
# Проверь firewall провайдера/хостера
# Многие блокируют нестандартные порты

# Открой порты в UFW
ufw allow 2053/tcp
ufw allow 8443/tcp

# Проверь что порты открыты
ufw status
```

#### 2. Клиент не подключается

**Проверь:**
1. Все поля в клиенте заполнены правильно
2. Ключи совпадают (Public Key, Short ID)
3. SNI совпадает
4. Порт правильный (2053 TCP или 8443 gRPC)

**Решение:**
```bash
# Свери ключи
cat config/.keys
make list

# Если не совпадают - пересоздай
rm -rf config output
make install
```

#### 3. Контейнер постоянно перезапускается

**Симптомы:**
- `docker ps` показывает `Restarting`

**Решение:**
```bash
# Посмотри логи
docker logs xray-vless --tail 100

# Проверь конфиг
docker exec xray-vless xray -test -c /etc/xray/config.json

# Если ошибка - пересоздай конфиг
rm -rf config output
make install
```

---

## 🔒 Безопасность

### Firewall (UFW)

Firewall настраивается автоматически при `make install-deps`:

```bash
# Проверить статус
ufw status verbose

# Открытые порты:
# - 22/tcp   (SSH)
# - 2053/tcp (VLESS TCP Primary)
# - 8443/tcp (VLESS gRPC Backup)
# - 443/tcp  (VLESS Legacy - опционально)
```

### Ротация ключей

**Важно:** Периодически меняй ключи для безопасности.

```bash
# Ротация ключей (⚠️ все старые ссылки перестанут работать!)
make rotate-keys
make restart
make list  # Получи новые ссылки
```

### Рекомендации

1. **Не публикуй** файлы `config/.keys` и `output/clients.txt` в публичных репозиториях
2. **Ротация ключей** раз в месяц
3. **Мониторинг логов** на подозрительную активность
4. **Обновление** Docker образа Xray периодически

---

## 📝 Миграция на другой сервер

### Резервное копирование

```bash
# На старом сервере
cd ~/VLESS_VPN
tar -czf vless-backup.tar.gz config/ output/ .env
```

### Восстановление

```bash
# На новом сервере
git clone https://github.com/TBucTeP/VLESS_VPN.git
cd VLESS_VPN

# Скопируй backup
scp root@old-server:~/VLESS_VPN/vless-backup.tar.gz .

# Распакуй
tar -xzf vless-backup.tar.gz

# Запусти
sudo make install-deps  # Если ещё не установлено
make up
```

**Важно:** IP в ссылках изменится! Обнови ссылки:
```bash
make list  # Покажет ссылки с новым IP
```

---

## 🔄 Обновление

```bash
cd ~/VLESS_VPN

# Обнови код
git pull

# Перезапусти контейнер
make restart

# Или обнови Docker образ
docker compose pull && docker compose up -d
```

---

## 📚 Дополнительная информация

### Технологии

- **VLESS**: Протокол VPN (без шифрования, быстрый)
- **REALITY**: Маскировка трафика под реальный сайт (iCloud, Google, Microsoft)
- **Xray-core**: Серверная часть (форк V2Ray)
- **Docker**: Контейнеризация для простоты

### Как работает REALITY

1. Клиент подключается к серверу
2. Сервер маскирует трафик под реальный сайт (SNI)
3. Для внешнего наблюдателя это выглядит как обычное HTTPS соединение
4. Невозможно отличить от реального трафика

### Multi-Port конфигурация

Сервер слушает на нескольких портах для обхода блокировок:

| Порт | Протокол | SNI | Назначение |
|------|----------|-----|------------|
| 2053 | TCP | gateway.icloud.com | Primary (основной) |
| 8443 | gRPC | www.google.com | Backup (резервный) |
| 443 | TCP | gateway.icloud.com | Legacy (опционально) |

### Полезные ссылки

- [Xray-core GitHub](https://github.com/XTLS/Xray-core)
- [REALITY документация](https://github.com/XTLS/Xray-core/discussions/1295)
- [VLESS протокол](https://github.com/XTLS/Xray-core/issues/263)

---

## ❓ FAQ

**Q: Можно ли использовать другие порты?**  
A: Да, измени `PRIMARY_PORT` и `GRPC_PORT` в `.env` и открой порты в firewall.

**Q: Сколько клиентов можно добавить?**  
A: Неограниченно, используй `make add`.

**Q: Что делать если провайдер блокирует порты?**  
A: Попробуй разные порты (443, 8443, 2053, 4443) в `.env`.

**Q: Можно ли использовать на VPS без root?**  
A: Нет, нужен root для привязки к привилегированным портам.

**Q: Как обновить Xray?**  
A: `docker compose pull && docker compose up -d`

**Q: Безопасно ли публиковать ссылки?**  
A: Нет! Ссылки содержат ключи доступа. Делись только с доверенными людьми.

**Q: Какой порт лучше использовать?**  
A: 2053 TCP (primary) - основной, 8443 gRPC - резервный если TCP блокируют.

---

## 📄 License

MIT

---

## 🤝 Поддержка

Если что-то не работает:
1. Запусти `make diagnostics`
2. Проверь логи: `make logs`
3. Создай issue на GitHub с выводом диагностики

---

**Сделано с ❤️ для свободы интернета**
