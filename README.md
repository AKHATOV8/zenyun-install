# ZenyunVPN — Installation Scripts

🇷🇺 [Русский](#русский) | 🇬🇧 [English](#english) | 🇨🇳 [中文](#中文)

---

## Русский

### ZenyunVPN — Скрипты установки

Приватный установщик для развёртывания [ZenyunVPN](https://t.me/zenyuntestbot) на VPS.

Репозиторий: `AKHATOV8/zenyun-install` (private)

### Быстрая установка

```bash
curl -sSL https://raw.githubusercontent.com/AKHATOV8/zenyun-install/main/install.sh -o install.sh && bash install.sh
```

**Текущая версия пакета:** `v1.2.0` — [скачать архив](https://github.com/AKHATOV8/zenyun-install/releases/download/v1.2.0/zenyun-vpn-v1.2.tar.gz)

> Не используйте `curl … | bash` — интерактивный ввод не работает через pipe.

### Требования

- **ОС:** Ubuntu 20.04+ (рекомендуется 22.04/24.04)
- **RAM:** минимум 1 ГБ
- **Диск:** минимум 5 ГБ свободного места
- **Домен:** DNS A-запись указывает на VPS
- **Telegram:** токен бота от [@BotFather](https://t.me/BotFather)
- **GitHub:** deploy key с доступом на чтение к приватному репозиторию бота

### Что устанавливает скрипт

- Docker + Docker Compose
- Telegram бот (aiogram)
- FastAPI веб-сервер
- PostgreSQL база данных
- Redis кеш
- Nginx + SSL (Let's Encrypt или Cloudflare Origin Certificate)

**Этапы установки:**

1. Проверка пароля (SHA-256, пароль не хранится)
2. Проверка системы (Ubuntu, RAM, диск)
3. Установка Docker при необходимости
4. Настройка: токен бота, admin ID, домены, SSL
5. Клонирование приватного репозитория через deploy key
6. Генерация `.env` (секреты Postgres, admin path)
7. Настройка Nginx (подписка + кабинет)
8. Запуск `docker compose up -d --build`

### Deploy key

```bash
ssh-keygen -t ed25519 -f /root/.ssh/zenyun_deploy_key -N ""
cat /root/.ssh/zenyun_deploy_key.pub
```

Добавьте публичный ключ: GitHub → Repository → Settings → Deploy keys.

### Обновление

```bash
cd /home/vpnbot
curl -sSL https://raw.githubusercontent.com/AKHATOV8/zenyun-install/main/check-update.sh -o check-update.sh
chmod +x check-update.sh
bash check-update.sh
```

Скрипт обновления: проверка пароля → `git pull` → `docker compose up -d --build` → changelog.

### Полезные команды

```bash
docker compose -f /home/vpnbot/docker-compose.yml logs -f bot web
docker compose -f /home/vpnbot/docker-compose.yml restart bot web
docker compose -f /home/vpnbot/docker-compose.yml ps
```

### Поддержка

Telegram: [@zenyuntestbot](https://t.me/zenyuntestbot)

---

## English

### ZenyunVPN — Installation Scripts

Private installer for deploying [ZenyunVPN](https://t.me/zenyuntestbot) on a VPS.

Repository: `AKHATOV8/zenyun-install` (private)

### Quick install

```bash
curl -sSL https://raw.githubusercontent.com/AKHATOV8/zenyun-install/main/install.sh -o install.sh && bash install.sh
```

> Do not use `curl … | bash` — interactive prompts do not work through a pipe.

On startup the script asks you to choose a language: **Русский / English / 中文**.

### Requirements

- **OS:** Ubuntu 20.04+ (22.04/24.04 recommended)
- **RAM:** minimum 1 GB
- **Disk:** minimum 5 GB free space
- **Domain:** DNS A-record pointing to your VPS
- **Telegram:** bot token from [@BotFather](https://t.me/BotFather)
- **GitHub:** deploy key with read access to the private bot repo

### What the installer deploys

- Docker + Docker Compose
- Telegram bot (aiogram)
- FastAPI web server
- PostgreSQL database
- Redis cache
- Nginx + SSL (Let's Encrypt or Cloudflare Origin Certificate)

**Installation steps:**

1. Password gate (SHA-256 verification, no plain password stored)
2. System check (Ubuntu version, RAM, disk)
3. Docker installation if missing
4. Configuration: bot token, admin ID, domains, SSL mode
5. Clone private bot repo via deploy key
6. Generate `.env` (Postgres secrets, admin path secret)
7. Configure Nginx (subscription + cabinet)
8. Run `docker compose up -d --build`

### Deploy key setup

```bash
ssh-keygen -t ed25519 -f /root/.ssh/zenyun_deploy_key -N ""
cat /root/.ssh/zenyun_deploy_key.pub
```

Add the public key in GitHub → Repository → Settings → Deploy keys.

### SSL options

- **Let's Encrypt** — point DNS A-records to the server; script uses `certbot --standalone`
- **Cloudflare** — provide Origin Certificate paths during install; set SSL mode to **Full (strict)**

### Updating

```bash
cd /home/vpnbot
curl -sSL https://raw.githubusercontent.com/AKHATOV8/zenyun-install/main/check-update.sh -o check-update.sh
chmod +x check-update.sh
bash check-update.sh
```

The update script: password check → `git pull` → `docker compose up -d --build` → changelog.

### Useful commands

```bash
docker compose -f /home/vpnbot/docker-compose.yml logs -f bot web
docker compose -f /home/vpnbot/docker-compose.yml restart bot web
docker compose -f /home/vpnbot/docker-compose.yml ps
```

### BotFather setup (after install)

1. `/mybots` → your bot → **Bot Settings** → **Configure Mini App** → `https://sub.yourdomain.com/app`
2. **Menu Button** → URL: `https://sub.yourdomain.com/app`

### Support

Telegram: [@zenyuntestbot](https://t.me/zenyuntestbot)

---

## 中文

### ZenyunVPN — 安装脚本

用于在 VPS 上部署 [ZenyunVPN](https://t.me/zenyuntestbot) 的私有安装程序。

仓库：`AKHATOV8/zenyun-install`（私有）

### 快速安装

```bash
curl -sSL https://raw.githubusercontent.com/AKHATOV8/zenyun-install/main/install.sh -o install.sh && bash install.sh
```

> 请勿使用 `curl … | bash` — 通过管道运行时无法进行交互输入。

启动时脚本会提示选择语言：**Русский / English / 中文**。

### 系统要求

- **操作系统：** Ubuntu 20.04+（推荐 22.04/24.04）
- **内存：** 最低 1 GB
- **磁盘：** 最低 5 GB 可用空间
- **域名：** DNS A 记录已指向 VPS
- **Telegram：** 来自 [@BotFather](https://t.me/BotFather) 的机器人令牌
- **GitHub：** 具有私有机器人仓库读取权限的 deploy key

### 安装内容

- Docker + Docker Compose
- Telegram 机器人（aiogram）
- FastAPI 网络服务器
- PostgreSQL 数据库
- Redis 缓存
- Nginx + SSL（Let's Encrypt 或 Cloudflare 源站证书）

**安装步骤：**

1. 密码验证（SHA-256，不存储明文密码）
2. 系统检查（Ubuntu 版本、内存、磁盘）
3. 如需要则安装 Docker
4. 配置：机器人令牌、管理员 ID、域名、SSL 模式
5. 通过 deploy key 克隆私有仓库
6. 生成 `.env`（Postgres 密钥、管理路径密钥）
7. 配置 Nginx（订阅 + 用户中心）
8. 运行 `docker compose up -d --build`

### Deploy key 设置

```bash
ssh-keygen -t ed25519 -f /root/.ssh/zenyun_deploy_key -N ""
cat /root/.ssh/zenyun_deploy_key.pub
```

在 GitHub → Repository → Settings → Deploy keys 中添加公钥。

### 更新

```bash
cd /home/vpnbot
curl -sSL https://raw.githubusercontent.com/AKHATOV8/zenyun-install/main/check-update.sh -o check-update.sh
chmod +x check-update.sh
bash check-update.sh
```

更新脚本：密码验证 → `git pull` → `docker compose up -d --build` → 更新日志。

### 常用命令

```bash
docker compose -f /home/vpnbot/docker-compose.yml logs -f bot web
docker compose -f /home/vpnbot/docker-compose.yml restart bot web
docker compose -f /home/vpnbot/docker-compose.yml ps
```

### 技术支持

Telegram: [@zenyuntestbot](https://t.me/zenyuntestbot)

---

## Files in this repository

| File | Description |
|------|-------------|
| `install.sh` | Full VPS installation script (RU / EN / ZH) |
| `check-update.sh` | Update existing deployment (RU / EN / ZH) |
| `README.md` | This documentation |

## Security notes

- Installation password is verified via SHA-256 hash only
- `.env` is generated with random Postgres password and admin secret
- Deploy key should be read-only
- Keep this repository **private**
