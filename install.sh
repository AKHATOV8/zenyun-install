#!/usr/bin/env bash
# ZenyunVPN — automated VPS installer
# Usage: curl -sSL https://raw.githubusercontent.com/AKHATOV8/zenyun-install/main/install.sh | bash
set -euo pipefail

# Force read from terminal (works with curl | bash)
if [ -t 0 ]; then
  TTY_INPUT="/dev/stdin"
else
  TTY_INPUT="/dev/tty"
fi

# ── Constants ────────────────────────────────────────────────────────────────
CORRECT_HASH="b0aef10571e26a3c3958c01e2c3c85d17e3eb6e55ddfd1a4bbffc2fb4e0ebe09"
INSTALL_DIR="${INSTALL_DIR:-/home/vpnbot}"
BOT_REPO_NAME="${BOT_REPO_NAME:-zenyun-vpn}"
DEPLOY_KEY_PATH="${DEPLOY_KEY_PATH:-/root/.ssh/zenyun_deploy_key}"
CERTBOT_EMAIL_DEFAULT="admin@example.com"
ZENYUN_LANG="${ZENYUN_LANG:-}"

# ── Colors & UI ──────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
  RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
  BLUE='\033[0;34m'; CYAN='\033[0;36m'; MAGENTA='\033[0;35m'
  BOLD='\033[1m'; DIM='\033[2m'; RESET='\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; BLUE=''; CYAN=''; MAGENTA=''; BOLD=''; DIM=''; RESET=''
fi

# ── Translations (ru / en / zh) ───────────────────────────────────────────────
# Usage: t <key>   |   tf <key> <arg> ...
t() {
  local key="$1" ru="" en="" zh=""
  case "$key" in
    lang_prompt)      ru="Выберите язык"; en="Select language"; zh="选择语言" ;;
    lang_menu)        ru="1) Русский  2) English  3) 中文"; en="1) Русский  2) English  3) 中文"; zh="1) Русский  2) English  3) 中文" ;;
    lang_choice)      ru="Язык (1/2/3)"; en="Language (1/2/3)"; zh="语言 (1/2/3)" ;;
    access_check)     ru="Проверка доступа"; en="Access verification"; zh="访问验证" ;;
    pwd_prompt)       ru="Введите пароль установки"; en="Enter installation password"; zh="请输入安装密码" ;;
    pwd_wrong)        ru="Неверный пароль"; en="Wrong password"; zh="密码错误" ;;
    pwd_ok)           ru="Пароль принят"; en="Password accepted"; zh="密码验证通过" ;;
    sys_check)        ru="Проверка системы"; en="System requirements"; zh="系统要求检查" ;;
    label_os)         ru="ОС"; en="OS"; zh="操作系统" ;;
    os_unknown)       ru="Не удалось определить ОС"; en="Cannot detect OS"; zh="无法检测操作系统" ;;
    os_warn)          ru="Рекомендуется Ubuntu. Обнаружено: %s"; en="Ubuntu recommended. Detected: %s"; zh="建议使用 Ubuntu。检测到：%s" ;;
    os_old)           ru="Требуется Ubuntu 20.04+. Обнаружено: %s"; en="Ubuntu 20.04+ required. Found: %s"; zh="需要 Ubuntu 20.04+。当前：%s" ;;
    label_ram)        ru="Память"; en="RAM"; zh="内存" ;;
    ram_low)          ru="Минимум 1 ГБ RAM. Доступно: %s МБ"; en="Minimum 1 GB RAM. Available: %s MB"; zh="至少需要 1 GB 内存。可用：%s MB" ;;
    ram_ok)           ru="RAM: %s МБ"; en="RAM: %s MB"; zh="内存：%s MB" ;;
    label_cpu)        ru="CPU"; en="CPU"; zh="CPU" ;;
    cpu_ok)           ru="CPU: %s ядер"; en="CPU: %s cores"; zh="CPU：%s 核" ;;
    label_disk)       ru="Диск"; en="Disk"; zh="磁盘" ;;
    disk_low)         ru="Мало места на диске: %sG"; en="Low disk space: %sG"; zh="磁盘空间不足：%sG" ;;
    disk_ok)          ru="Свободно: %sG"; en="Free: %sG"; zh="可用空间：%sG" ;;
    need_root)        ru="Запустите от root: sudo bash install.sh"; en="Run as root: sudo bash install.sh"; zh="请使用 root 运行：sudo bash install.sh" ;;
    docker_title)     ru="Docker"; en="Docker"; zh="Docker" ;;
    docker_exists)    ru="Docker уже установлен: %s"; en="Docker already installed: %s"; zh="Docker 已安装：%s" ;;
    docker_install)   ru="Установка Docker…"; en="Installing Docker…"; zh="正在安装 Docker…" ;;
    docker_ok)        ru="Docker установлен"; en="Docker installed"; zh="Docker 安装完成" ;;
    config_title)     ru="Настройка"; en="Configuration"; zh="配置" ;;
    ask_bot_token)    ru="Токен бота Telegram (@BotFather)"; en="Telegram bot token (@BotFather)"; zh="Telegram 机器人令牌 (@BotFather)" ;;
    token_required)   ru="Токен обязателен"; en="Token is required"; zh="令牌为必填项" ;;
    ask_admin_id)     ru="Telegram ID администратора"; en="Admin Telegram ID"; zh="管理员 Telegram ID" ;;
    admin_id_invalid) ru="Некорректный Telegram ID"; en="Invalid Telegram ID"; zh="Telegram ID 无效" ;;
    ask_sub_domain)   ru="Домен подписки (например sub.example.com)"; en="Subscription domain (e.g. sub.example.com)"; zh="订阅域名（例如 sub.example.com）" ;;
    ask_app_domain)   ru="Домен кабинета (например app.example.com)"; en="Cabinet domain (e.g. app.example.com)"; zh="用户中心域名（例如 app.example.com）" ;;
    ask_landing)      ru="Домен лендинга (например example.com, Enter — пропустить)"; en="Landing domain (e.g. example.com, Enter to skip)"; zh="落地页域名（例如 example.com，回车跳过）" ;;
    ask_github_user)  ru="GitHub username/org с приватным репозиторием бота"; en="GitHub username/org with private bot repo"; zh="拥有私有机器人仓库的 GitHub 用户名/组织" ;;
    ask_repo_name)    ru="Имя репозитория бота"; en="Bot repository name"; zh="机器人仓库名称" ;;
    ssl_choose)       ru="Выберите тип SSL:"; en="Choose SSL type:"; zh="选择 SSL 类型：" ;;
    ssl_le)           ru="Let's Encrypt (ручной DNS на сервер)"; en="Let's Encrypt (manual DNS to server)"; zh="Let's Encrypt（手动 DNS 指向服务器）" ;;
    ssl_cf)           ru="Cloudflare (Origin Certificate)"; en="Cloudflare (Origin Certificate)"; zh="Cloudflare（源站证书）" ;;
    ssl_option)       ru="Вариант (1 или 2)"; en="Option (1 or 2)"; zh="选项 (1 或 2)" ;;
    ask_cf_cert)      ru="Путь к Cloudflare Origin Certificate (fullchain.pem)"; en="Path to Cloudflare Origin Certificate (fullchain.pem)"; zh="Cloudflare 源站证书路径 (fullchain.pem)" ;;
    ask_cf_key)       ru="Путь к Cloudflare Origin Private Key (privkey.pem)"; en="Path to Cloudflare Origin Private Key (privkey.pem)"; zh="Cloudflare 源站私钥路径 (privkey.pem)" ;;
    ask_certbot_mail) ru="Email для Let's Encrypt"; en="Email for Let's Encrypt"; zh="Let's Encrypt 邮箱" ;;
    ask_deploy_key)   ru="Путь к deploy key для git clone"; en="Path to deploy key for git clone"; zh="git clone 部署密钥路径" ;;
    deploy_key_title) ru="Deploy key"; en="Deploy key"; zh="部署密钥" ;;
    deploy_key_miss)  ru="Deploy key не найден: %s"; en="Deploy key not found: %s"; zh="未找到部署密钥：%s" ;;
    ask_key_path)     ru="Укажите путь к приватному ключу"; en="Specify private key path"; zh="请输入私钥路径" ;;
    key_not_found)    ru="Файл ключа не найден"; en="Key file not found"; zh="密钥文件不存在" ;;
    deploy_key_ok)    ru="Deploy key: %s"; en="Deploy key: %s"; zh="部署密钥：%s" ;;
    clone_title)      ru="Загрузка исходников"; en="Fetching source code"; zh="获取源代码" ;;
    dir_exists)       ru="Каталог %s уже существует — обновление"; en="Directory %s exists — updating"; zh="目录 %s 已存在 — 正在更新" ;;
    cloning)          ru="Клонирование %s …"; en="Cloning %s …"; zh="正在克隆 %s …" ;;
    source_ok)        ru="Исходники готовы"; en="Source code ready"; zh="源代码就绪" ;;
    env_title)        ru="Генерация .env"; en="Generating .env"; zh="生成 .env" ;;
    env_ok)           ru=".env создан"; en=".env created"; zh=".env 已创建" ;;
    nginx_title)      ru="Nginx"; en="Nginx"; zh="Nginx" ;;
    nginx_ok)         ru="nginx.conf создан"; en="nginx.conf created"; zh="nginx.conf 已创建" ;;
    ssl_title)        ru="SSL-сертификаты"; en="SSL certificates"; zh="SSL 证书" ;;
    cf_not_found)     ru="Cloudflare сертификаты не найдены"; en="Cloudflare certificates not found"; zh="未找到 Cloudflare 证书" ;;
    cf_ok)            ru="Cloudflare Origin Certificate установлен"; en="Cloudflare Origin Certificate installed"; zh="Cloudflare 源站证书已安装" ;;
    temp_cert)        ru="Временный self-signed сертификат…"; en="Temporary self-signed certificate…"; zh="临时自签名证书…" ;;
    le_request)       ru="Запрос Let's Encrypt…"; en="Requesting Let's Encrypt…"; zh="正在申请 Let's Encrypt…" ;;
    dns_hint)         ru="Убедитесь, что DNS указывает на этот сервер"; en="Ensure DNS points to this server"; zh="请确保 DNS 已指向此服务器" ;;
    le_ok)            ru="Let's Encrypt сертификат получен"; en="Let's Encrypt certificate obtained"; zh="Let's Encrypt 证书已获取" ;;
    le_fail)          ru="Certbot не смог получить сертификат — используется временный"; en="Certbot failed — using temporary cert"; zh="Certbot 获取失败 — 使用临时证书" ;;
    le_manual)        ru="Запустите certbot вручную после настройки DNS"; en="Run certbot manually after DNS is configured"; zh="DNS 配置完成后请手动运行 certbot" ;;
    start_title)      ru="Запуск сервисов"; en="Starting services"; zh="启动服务" ;;
    build_images)     ru="Сборка образов (это может занять несколько минут)…"; en="Building images (may take a few minutes)…"; zh="正在构建镜像（可能需要几分钟）…" ;;
    containers_ok)    ru="Контейнеры запущены"; en="Containers started"; zh="容器已启动" ;;
    wait_ready)       ru="Ожидание готовности…"; en="Waiting for readiness…"; zh="等待服务就绪…" ;;
    pg_ready)         ru="PostgreSQL готов"; en="PostgreSQL ready"; zh="PostgreSQL 已就绪" ;;
    backup_cron)      ru="Cron бэкапа настроен (03:00)"; en="Backup cron configured (03:00)"; zh="备份定时任务已配置 (03:00)" ;;
    done_title)       ru="🎉 Установка завершена!"; en="🎉 Installation complete!"; zh="🎉 安装完成！" ;;
    urls_title)       ru="Доступные URL:"; en="Access URLs:"; zh="访问地址：" ;;
    url_miniapp)      ru="Mini App (подписка)"; en="Mini App (subscription)"; zh="Mini App（订阅）" ;;
    url_sub)          ru="Подписка"; en="Subscription endpoint"; zh="订阅端点" ;;
    url_cabinet)      ru="Веб-кабинет"; en="Web cabinet"; zh="网页用户中心" ;;
    url_admin)        ru="Секретная админ-панель"; en="Secret admin panel"; zh="秘密管理面板" ;;
    botfather_title)  ru="Следующие шаги в @BotFather:"; en="Next steps in @BotFather:"; zh="@BotFather 后续步骤：" ;;
    logs_hint)        ru="Логи: docker compose -f %s/docker-compose.yml logs -f bot web"; en="Logs: docker compose -f %s/docker-compose.yml logs -f bot web"; zh="日志：docker compose -f %s/docker-compose.yml logs -f bot web" ;;
    support)          ru="Поддержка: @zenyuntestbot"; en="Support: @zenyuntestbot"; zh="技术支持：@zenyuntestbot" ;;
    *) ru="$key"; en="$key"; zh="$key" ;;
  esac
  case "$ZENYUN_LANG" in
    en) echo "$en" ;;
    zh) echo "$zh" ;;
    *)  echo "$ru" ;;
  esac
}

tf() {
  local key="$1"; shift
  # shellcheck disable=SC2059
  printf "$(t "$key")" "$@"
}

choose_lang() {
  echo "Select language / Выберите язык / 选择语言:"
  echo "  1) Русский"
  echo "  2) English"
  echo "  3) 中文"
  printf "Enter choice [1-3]: "
  read LANG_CHOICE < "$TTY_INPUT"

  case "$LANG_CHOICE" in
    1) ZENYUN_LANG="ru" ;;
    2) ZENYUN_LANG="en" ;;
    3) ZENYUN_LANG="zh" ;;
    *) ZENYUN_LANG="ru" ;;
  esac
  export ZENYUN_LANG
}

banner() {
  echo -e "${CYAN}${BOLD}"
  echo "  ╔══════════════════════════════════════════╗"
  echo "  ║       🛡  ZenyunVPN Installer  🛡       ║"
  echo "  ╚══════════════════════════════════════════╝"
  echo -e "${RESET}"
}

section() {
  echo ""
  echo -e "${BLUE}${BOLD}━━━ $1 ━━━${RESET}"
  echo ""
}

step() { echo -e "${GREEN}▶${RESET} $1"; }
ok()   { echo -e "${GREEN}✅${RESET} $1"; }
warn() { echo -e "${YELLOW}⚠️${RESET}  $1"; }
fail() { echo -e "${RED}❌${RESET} $1"; exit 1; }
info() { echo -e "${DIM}   $1${RESET}"; }

progress_bar() {
  local current=$1 total=$2 label=$3
  local width=30
  local filled=$(( current * width / total ))
  local empty=$(( width - filled ))
  printf "   ["
  printf "%0.s█" $(seq 1 "$filled" 2>/dev/null) || true
  printf "%0.s░" $(seq 1 "$empty" 2>/dev/null) || true
  printf "] %d/%d %s\n" "$current" "$total" "$label"
}

prompt() {
  local var="$1" key="$2" default="${3:-}"
  local text; text="$(t "$key")"
  if [[ -n "$default" ]]; then
    printf "? %s [%s]: " "$text" "$default"
    read -r input < "$TTY_INPUT"
    printf -v "$var" '%s' "${input:-$default}"
  else
    printf "? %s: " "$text"
    read -r input < "$TTY_INPUT"
    printf -v "$var" '%s' "$input"
  fi
}

prompt_secret() {
  local var="$1" key="$2"
  printf "? %s: " "$(t "$key")"
  read -r -s input < "$TTY_INPUT"
  echo ""
  printf -v "$var" '%s' "$input"
}

# ── Password gate ────────────────────────────────────────────────────────────
check_password() {
  section "$(t access_check)"
  prompt_secret INPUT_PASSWORD pwd_prompt
  local input_hash
  input_hash=$(echo -n "$INPUT_PASSWORD" | sha256sum | cut -d' ' -f1)
  unset INPUT_PASSWORD
  [[ "$input_hash" == "$CORRECT_HASH" ]] || fail "$(t pwd_wrong)"
  ok "$(t pwd_ok)"
}

# ── System requirements ──────────────────────────────────────────────────────
check_requirements() {
  section "$(t sys_check)"
  local step_n=0 total=4

  step_n=$((step_n + 1)); progress_bar "$step_n" "$total" "$(t label_os)"
  [[ -f /etc/os-release ]] || fail "$(t os_unknown)"
  # shellcheck source=/dev/null
  source /etc/os-release
  if [[ "${ID:-}" != "ubuntu" ]]; then
    warn "$(tf os_warn "${PRETTY_NAME:-unknown}")"
  else
    local ver_major="${VERSION_ID%%.*}"
    [[ "${ver_major:-0}" -ge 20 ]] || fail "$(tf os_old "$VERSION_ID")"
    ok "Ubuntu $VERSION_ID"
  fi

  step_n=$((step_n + 1)); progress_bar "$step_n" "$total" "$(t label_ram)"
  local ram_mb
  ram_mb=$(free -m | awk '/^Mem:/{print $2}')
  [[ "${ram_mb:-0}" -ge 900 ]] || fail "$(tf ram_low "$ram_mb")"
  ok "$(tf ram_ok "$ram_mb")"

  step_n=$((step_n + 1)); progress_bar "$step_n" "$total" "$(t label_cpu)"
  local cpus
  cpus=$(nproc 2>/dev/null || echo 1)
  ok "$(tf cpu_ok "$cpus")"

  step_n=$((step_n + 1)); progress_bar "$step_n" "$total" "$(t label_disk)"
  local disk_free
  disk_free=$(df -BG / | awk 'NR==2{gsub(/G/,"",$4); print $4}')
  if [[ "${disk_free:-0}" -lt 5 ]]; then
    warn "$(tf disk_low "$disk_free")"
  else
    ok "$(tf disk_ok "$disk_free")"
  fi

  [[ $EUID -eq 0 ]] || fail "$(t need_root)"
}

# ── Docker ───────────────────────────────────────────────────────────────────
install_docker() {
  section "$(t docker_title)"
  if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    ok "$(tf docker_exists "$(docker --version)")"
    return
  fi

  step "$(t docker_install)"
  apt-get update -qq
  apt-get install -y -qq ca-certificates curl gnupg lsb-release git openssl

  install -m 0755 -d /etc/apt/keyrings
  if [[ ! -f /etc/apt/keyrings/docker.gpg ]]; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
  fi

  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    > /etc/apt/sources.list.d/docker.list

  apt-get update -qq
  apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  systemctl enable docker
  systemctl start docker
  ok "$(t docker_ok)"
}

# ── Configuration prompts ────────────────────────────────────────────────────
collect_config() {
  section "$(t config_title)"

  prompt BOT_TOKEN ask_bot_token
  [[ -n "$BOT_TOKEN" ]] || fail "$(t token_required)"

  prompt ADMIN_ID ask_admin_id
  [[ "$ADMIN_ID" =~ ^[0-9]+$ ]] || fail "$(t admin_id_invalid)"

  prompt SUB_DOMAIN ask_sub_domain
  SUB_DOMAIN="${SUB_DOMAIN#https://}"; SUB_DOMAIN="${SUB_DOMAIN#http://}"; SUB_DOMAIN="${SUB_DOMAIN%%/*}"

  local base="${SUB_DOMAIN#*.}"
  prompt APP_DOMAIN ask_app_domain "app.${base}"
  prompt LANDING_DOMAIN ask_landing "$base"
  prompt GITHUB_USER ask_github_user
  prompt BOT_REPO_NAME_INPUT ask_repo_name "$BOT_REPO_NAME"
  BOT_REPO_NAME="$BOT_REPO_NAME_INPUT"

  echo ""
  echo -e "${MAGENTA}$(t ssl_choose)${RESET}"
  echo "  1) $(t ssl_le)"
  echo "  2) $(t ssl_cf)"
  prompt SSL_MODE ssl_option "1"

  if [[ "$SSL_MODE" == "2" ]]; then
    SSL_TYPE="cloudflare"
    prompt CF_CERT_PATH ask_cf_cert "/root/cloudflare-origin.pem"
    prompt CF_KEY_PATH ask_cf_key "/root/cloudflare-origin.key"
  else
    SSL_TYPE="manual"
    prompt CERTBOT_EMAIL ask_certbot_mail "admin@${base}"
  fi

  prompt DEPLOY_KEY_PATH_INPUT ask_deploy_key "$DEPLOY_KEY_PATH"
  DEPLOY_KEY_PATH="$DEPLOY_KEY_PATH_INPUT"
}

# ── Deploy key & clone ───────────────────────────────────────────────────────
setup_deploy_key() {
  section "$(t deploy_key_title)"
  if [[ ! -f "$DEPLOY_KEY_PATH" ]]; then
    warn "$(tf deploy_key_miss "$DEPLOY_KEY_PATH")"
    prompt DEPLOY_KEY_PATH ask_key_path
    [[ -f "$DEPLOY_KEY_PATH" ]] || fail "$(t key_not_found)"
  fi
  chmod 600 "$DEPLOY_KEY_PATH"
  ok "$(tf deploy_key_ok "$DEPLOY_KEY_PATH")"
}

clone_source() {
  section "$(t clone_title)"
  local repo_url="git@github.com:${GITHUB_USER}/${BOT_REPO_NAME}.git"
  export GIT_SSH_COMMAND="ssh -i ${DEPLOY_KEY_PATH} -o StrictHostKeyChecking=accept-new -o IdentitiesOnly=yes"

  if [[ -d "$INSTALL_DIR/.git" ]]; then
    warn "$(tf dir_exists "$INSTALL_DIR")"
    git -C "$INSTALL_DIR" pull --ff-only
  else
    mkdir -p "$(dirname "$INSTALL_DIR")"
    step "$(tf cloning "$repo_url")"
    git clone "$repo_url" "$INSTALL_DIR"
  fi
  ok "$(t source_ok)"
}

# ── .env generation ──────────────────────────────────────────────────────────
generate_env() {
  section "$(t env_title)"
  local pg_pass admin_secret
  pg_pass=$(openssl rand -hex 16)
  admin_secret=$(openssl rand -hex 24)

  cat > "$INSTALL_DIR/.env" <<EOF
# ============ ZenyunVPN — auto-generated $(date -Iseconds) ============
BOT_TOKEN=${BOT_TOKEN}
ADMIN_IDS=${ADMIN_ID}
ADMIN_LOG_CHANNEL_ID=

DATABASE_URL=postgresql+asyncpg://vpnbot:${pg_pass}@db:5432/vpnbot
REDIS_URL=redis://redis:6379/0

POSTGRES_USER=vpnbot
POSTGRES_PASSWORD=${pg_pass}
POSTGRES_DB=vpnbot

SUBSCRIPTION_BASE_URL=https://${SUB_DOMAIN}

ALIPAY_ACCOUNT=
WECHAT_ACCOUNT=
UZCARD_NUMBER=
UZCARD_HOLDER=
CRYPTO_USDT_TRC20=
CRYPTO_USDT_ERC20=

STRIPE_ENABLED=false
STRIPE_SECRET_KEY=
STRIPE_WEBHOOK_SECRET=

ADMIN_PATH_SECRET=${admin_secret}

DEFAULT_LANGUAGE=ru
LOG_LEVEL=INFO
EOF
  chmod 600 "$INSTALL_DIR/.env"
  ok "$(t env_ok)"
  info "SUBSCRIPTION_BASE_URL=https://${SUB_DOMAIN}"
  info "ADMIN_PATH_SECRET=${admin_secret}"
}

# ── nginx config ─────────────────────────────────────────────────────────────
write_nginx_config() {
  section "$(t nginx_title)"
  mkdir -p "$INSTALL_DIR/nginx/certs" "$INSTALL_DIR/backups"
  touch "$INSTALL_DIR/nginx/certs/.gitkeep"

  local landing_block=""
  if [[ -n "${LANDING_DOMAIN:-}" ]]; then
    landing_block=$(cat <<LANDING

# ── Landing — ${LANDING_DOMAIN} ────────────────────────────────────────────
server {
    listen 80;
    listen 443 ssl;
    http2 on;
    server_name www.${LANDING_DOMAIN};
    ssl_certificate     /etc/nginx/certs/fullchain.pem;
    ssl_certificate_key /etc/nginx/certs/privkey.pem;
    return 301 https://${LANDING_DOMAIN}\$request_uri;
}

server {
    listen 80;
    listen 443 ssl;
    http2 on;
    server_name ${LANDING_DOMAIN};
    ssl_certificate     /etc/nginx/certs/fullchain.pem;
    ssl_certificate_key /etc/nginx/certs/privkey.pem;
    ssl_protocols       TLSv1.2 TLSv1.3;
    ssl_ciphers         HIGH:!aNULL:!MD5;
    root /usr/share/nginx/landing;
    index index.html;
    location /.well-known/acme-challenge/ { root /var/www/certbot; }
    location / { try_files \$uri \$uri/ /index.html; }
}
LANDING
)
  fi

  cat > "$INSTALL_DIR/nginx/nginx.conf" <<EOF
# ZenyunVPN — generated by zenyun-install

server {
    listen 80;
    listen 443 ssl default_server;
    http2 on;
    server_name ${APP_DOMAIN};
    ssl_certificate     /etc/nginx/certs/fullchain.pem;
    ssl_certificate_key /etc/nginx/certs/privkey.pem;
    ssl_protocols       TLSv1.2 TLSv1.3;
    ssl_ciphers         HIGH:!aNULL:!MD5;
    client_max_body_size 50m;
    resolver 127.0.0.11 valid=30s ipv6=off;

    location /api/ {
        set \$api_backend web:8000;
        proxy_pass http://\$api_backend;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header CF-Connecting-IP \$http_cf_connecting_ip;
        proxy_read_timeout 120s;
    }
    location /static/ {
        set \$static_backend web:8000;
        proxy_pass http://\$static_backend;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    location ~ ^/a/[^/]+\$ {
        set \$admin_backend web:8000;
        proxy_pass http://\$admin_backend;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-Proto \$scheme;
        add_header Cache-Control "no-store" always;
    }
    location = / { root /usr/share/nginx/cabinet; try_files /index.html =404; add_header Cache-Control "no-store" always; }
    location /health { set \$h web:8000; proxy_pass http://\$h; }
    location / { root /usr/share/nginx/cabinet; try_files \$uri /index.html; add_header Cache-Control "no-store" always; }
}

server {
    listen 80;
    listen 443 ssl;
    http2 on;
    server_name ${SUB_DOMAIN};
    ssl_certificate     /etc/nginx/certs/fullchain.pem;
    ssl_certificate_key /etc/nginx/certs/privkey.pem;
    ssl_protocols       TLSv1.2 TLSv1.3;
    ssl_ciphers         HIGH:!aNULL:!MD5;
    client_max_body_size 50m;
    resolver 127.0.0.11 valid=30s ipv6=off;

    location /sub/ {
        set \$sub_backend web:8000;
        proxy_pass http://\$sub_backend;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header CF-Connecting-IP \$http_cf_connecting_ip;
    }
    location = /app {
        set \$app_backend web:8000;
        proxy_pass http://\$app_backend;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header CF-Connecting-IP \$http_cf_connecting_ip;
    }
    location = /admin-app {
        set \$adminapp_backend web:8000;
        proxy_pass http://\$adminapp_backend;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    location /sub-app/ {
        set \$subapp_backend web:8000;
        proxy_pass http://\$subapp_backend;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    location /static/ {
        set \$static_backend web:8000;
        proxy_pass http://\$static_backend;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    location /api/ {
        set \$api_backend web:8000;
        proxy_pass http://\$api_backend;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 120s;
        client_max_body_size 50m;
    }
    location /health { set \$h web:8000; proxy_pass http://\$h; }
}
${landing_block}

server {
    listen 80 default_server;
    server_name _;
    location /.well-known/acme-challenge/ { root /var/www/certbot; }
    location / { return 301 https://\$host\$request_uri; }
}
EOF
  ok "$(t nginx_ok)"
}

# ── SSL ──────────────────────────────────────────────────────────────────────
setup_ssl() {
  section "$(t ssl_title)"
  local cert_dir="$INSTALL_DIR/nginx/certs"

  if [[ "$SSL_TYPE" == "cloudflare" ]]; then
    [[ -f "$CF_CERT_PATH" && -f "$CF_KEY_PATH" ]] || fail "$(t cf_not_found)"
    cp "$CF_CERT_PATH" "$cert_dir/fullchain.pem"
    cp "$CF_KEY_PATH" "$cert_dir/privkey.pem"
    chmod 600 "$cert_dir/privkey.pem"
    ok "$(t cf_ok)"
    return
  fi

  apt-get install -y -qq certbot
  mkdir -p /var/www/certbot

  if [[ ! -f "$cert_dir/fullchain.pem" ]]; then
    step "$(t temp_cert)"
    openssl req -x509 -newkey rsa:2048 -nodes -days 1 \
      -keyout "$cert_dir/privkey.pem" \
      -out "$cert_dir/fullchain.pem" \
      -subj "/CN=${SUB_DOMAIN}" 2>/dev/null
  fi

  local domains=("-d" "$SUB_DOMAIN" "-d" "$APP_DOMAIN")
  [[ -n "${LANDING_DOMAIN:-}" ]] && domains+=("-d" "$LANDING_DOMAIN" "-d" "www.${LANDING_DOMAIN}")

  step "$(t le_request)"
  info "$(t dns_hint)"

  docker compose -f "$INSTALL_DIR/docker-compose.yml" stop nginx 2>/dev/null || true

  if certbot certonly --standalone --non-interactive --agree-tos \
      -m "${CERTBOT_EMAIL:-$CERTBOT_EMAIL_DEFAULT}" \
      "${domains[@]}"; then
    cp "/etc/letsencrypt/live/${SUB_DOMAIN}/fullchain.pem" "$cert_dir/fullchain.pem"
    cp "/etc/letsencrypt/live/${SUB_DOMAIN}/privkey.pem" "$cert_dir/privkey.pem"
    chmod 600 "$cert_dir/privkey.pem"
    ok "$(t le_ok)"

    cat > /etc/cron.d/zenyun-certbot <<CRON
0 3 * * * root certbot renew --quiet --deploy-hook "cp /etc/letsencrypt/live/${SUB_DOMAIN}/fullchain.pem ${cert_dir}/fullchain.pem && cp /etc/letsencrypt/live/${SUB_DOMAIN}/privkey.pem ${cert_dir}/privkey.pem && docker compose -f ${INSTALL_DIR}/docker-compose.yml exec nginx nginx -s reload"
CRON
  else
    warn "$(t le_fail)"
    warn "$(t le_manual)"
  fi
}

# ── Docker Compose ───────────────────────────────────────────────────────────
start_services() {
  section "$(t start_title)"
  cd "$INSTALL_DIR"

  step "$(t build_images)"
  docker compose up -d --build
  ok "$(t containers_ok)"

  step "$(t wait_ready)"
  local i
  for i in $(seq 1 30); do
    if docker compose exec -T db pg_isready -U vpnbot >/dev/null 2>&1; then
      ok "$(t pg_ready)"
      break
    fi
    sleep 2
  done

  docker compose ps
}

install_backup_cron() {
  if [[ -f "$INSTALL_DIR/backup.sh" ]]; then
    chmod +x "$INSTALL_DIR/backup.sh"
    local cron_line="0 3 * * * root ${INSTALL_DIR}/backup.sh >> /var/log/zenyun-backup.log 2>&1"
    grep -qF "zenyun-backup" /etc/cron.d/zenyun-backup 2>/dev/null || \
      echo "$cron_line" > /etc/cron.d/zenyun-backup
    ok "$(t backup_cron)"
  fi
}

# ── Final status ─────────────────────────────────────────────────────────────
show_final_status() {
  section "$(t done_title)"
  local admin_secret
  admin_secret=$(grep ADMIN_PATH_SECRET "$INSTALL_DIR/.env" | cut -d= -f2)

  echo -e "${GREEN}${BOLD}$(t urls_title)${RESET}"
  echo ""
  echo -e "  📱 $(t url_miniapp)"
  echo -e "     ${CYAN}https://${SUB_DOMAIN}/app${RESET}"
  echo ""
  echo -e "  🔗 $(t url_sub)"
  echo -e "     ${CYAN}https://${SUB_DOMAIN}/sub/{token}${RESET}"
  echo ""
  echo -e "  🖥  $(t url_cabinet)"
  echo -e "     ${CYAN}https://${APP_DOMAIN}/${RESET}"
  echo ""
  echo -e "  🔐 $(t url_admin)"
  echo -e "     ${CYAN}https://${APP_DOMAIN}/a/${admin_secret}${RESET}"
  echo ""
  echo -e "${YELLOW}$(t botfather_title)${RESET}"
  echo "  1. /mybots → Bot Settings → Configure Mini App"
  echo "     URL: https://${SUB_DOMAIN}/app"
  echo "  2. Bot Settings → Menu Button → https://${SUB_DOMAIN}/app"
  echo ""
  echo -e "${DIM}$(tf logs_hint "$INSTALL_DIR")${RESET}"
  echo -e "${DIM}$(t support)${RESET}"
  echo ""
}

# ── Main ─────────────────────────────────────────────────────────────────────
main() {
  choose_lang
  banner
  check_password
  check_requirements
  install_docker
  collect_config
  setup_deploy_key
  clone_source
  generate_env
  write_nginx_config
  setup_ssl
  start_services
  install_backup_cron
  show_final_status
}

main "$@"
