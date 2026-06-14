#!/usr/bin/env bash
# ZenyunVPN — automated VPS installer
# Usage: curl -sSL https://raw.githubusercontent.com/YOUR_USERNAME/zenyun-install/main/install.sh | bash
set -euo pipefail

# ── Constants ────────────────────────────────────────────────────────────────
CORRECT_HASH="b0aef10571e26a3c3958c01e2c3c85d17e3eb6e55ddfd1a4bbffc2fb4e0ebe09"
INSTALL_DIR="${INSTALL_DIR:-/home/vpnbot}"
BOT_REPO_NAME="${BOT_REPO_NAME:-zenyun-vpn}"
DEPLOY_KEY_PATH="${DEPLOY_KEY_PATH:-/root/.ssh/zenyun_deploy_key}"
CERTBOT_EMAIL_DEFAULT="admin@example.com"

# ── Colors & UI ──────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
  RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
  BLUE='\033[0;34m'; CYAN='\033[0;36m'; MAGENTA='\033[0;35m'
  BOLD='\033[1m'; DIM='\033[2m'; RESET='\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; BLUE=''; CYAN=''; MAGENTA=''; BOLD=''; DIM=''; RESET=''
fi

_lang() {
  case "${LANG:-ru}" in
    en*|EN*) echo "en" ;;
    *) echo "ru" ;;
  esac
}

_msg() {
  local ru="$1" en="$2"
  if [[ "$(_lang)" == "en" ]]; then echo "$en"; else echo "$ru"; fi
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
  local var="$1" ru="$2" en="$3" default="${4:-}"
  local text
  if [[ "$(_lang)" == "en" ]]; then text="$en"; else text="$ru"; fi
  if [[ -n "$default" ]]; then
    read -r -p "$(echo -e "${CYAN}?${RESET} ${text} [${default}]: ")" input
    printf -v "$var" '%s' "${input:-$default}"
  else
    read -r -p "$(echo -e "${CYAN}?${RESET} ${text}: ")" input
    printf -v "$var" '%s' "$input"
  fi
}

prompt_secret() {
  local var="$1" ru="$2" en="$3"
  local text
  if [[ "$(_lang)" == "en" ]]; then text="$en"; else text="$ru"; fi
  read -r -s -p "$(echo -e "${CYAN}?${RESET} ${text}: ")" input
  echo ""
  printf -v "$var" '%s' "$input"
}

# ── Password gate ────────────────────────────────────────────────────────────
check_password() {
  section "$(_msg "Проверка доступа" "Access verification")"
  prompt_secret INPUT_PASSWORD \
    "Введите пароль установки" \
    "Enter installation password"
  local input_hash
  input_hash=$(echo -n "$INPUT_PASSWORD" | sha256sum | cut -d' ' -f1)
  unset INPUT_PASSWORD
  if [[ "$input_hash" != "$CORRECT_HASH" ]]; then
    fail "$(_msg "Неверный пароль" "Wrong password")"
  fi
  ok "$(_msg "Пароль принят" "Password accepted")"
}

# ── System requirements ──────────────────────────────────────────────────────
check_requirements() {
  section "$(_msg "Проверка системы" "System requirements")"
  local step_n=0 total=4

  step_n=$((step_n + 1)); progress_bar "$step_n" "$total" "$(_msg "ОС" "OS")"
  if [[ ! -f /etc/os-release ]]; then
    fail "$(_msg "Не удалось определить ОС" "Cannot detect OS")"
  fi
  source /etc/os-release
  if [[ "${ID:-}" != "ubuntu" ]]; then
    warn "$(_msg "Рекомендуется Ubuntu. Обнаружено: ${PRETTY_NAME:-unknown}" "Ubuntu recommended. Detected: ${PRETTY_NAME:-unknown}")"
  else
    local ver_major="${VERSION_ID%%.*}"
    if [[ "${ver_major:-0}" -lt 20 ]]; then
      fail "$(_msg "Требуется Ubuntu 20.04+. Обнаружено: $VERSION_ID" "Ubuntu 20.04+ required. Found: $VERSION_ID")"
    fi
    ok "Ubuntu $VERSION_ID"
  fi

  step_n=$((step_n + 1)); progress_bar "$step_n" "$total" "$(_msg "Память" "RAM")"
  local ram_mb
  ram_mb=$(free -m | awk '/^Mem:/{print $2}')
  if [[ "${ram_mb:-0}" -lt 900 ]]; then
    fail "$(_msg "Минимум 1 ГБ RAM. Доступно: ${ram_mb} МБ" "Minimum 1 GB RAM. Available: ${ram_mb} MB")"
  fi
  ok "$(_msg "RAM: ${ram_mb} МБ" "RAM: ${ram_mb} MB")"

  step_n=$((step_n + 1)); progress_bar "$step_n" "$total" "$(_msg "CPU" "CPU")"
  local cpus
  cpus=$(nproc 2>/dev/null || echo 1)
  ok "$(_msg "CPU: ${cpus} ядер" "CPU: ${cpus} cores")"

  step_n=$((step_n + 1)); progress_bar "$step_n" "$total" "$(_msg "Диск" "Disk")"
  local disk_free
  disk_free=$(df -BG / | awk 'NR==2{gsub(/G/,"",$4); print $4}')
  if [[ "${disk_free:-0}" -lt 5 ]]; then
    warn "$(_msg "Мало места на диске: ${disk_free}G" "Low disk space: ${disk_free}G")"
  else
    ok "$(_msg "Свободно: ${disk_free}G" "Free: ${disk_free}G")"
  fi

  if [[ $EUID -ne 0 ]]; then
    fail "$(_msg "Запустите от root: sudo bash install.sh" "Run as root: sudo bash install.sh")"
  fi
}

# ── Docker ───────────────────────────────────────────────────────────────────
install_docker() {
  section "$(_msg "Docker" "Docker")"
  if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    ok "$(_msg "Docker уже установлен: $(docker --version)" "Docker already installed: $(docker --version)")"
    return
  fi

  step "$(_msg "Установка Docker…" "Installing Docker…")"
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
  ok "$(_msg "Docker установлен" "Docker installed")"
}

# ── Configuration prompts ────────────────────────────────────────────────────
collect_config() {
  section "$(_msg "Настройка" "Configuration")"

  prompt BOT_TOKEN \
    "Токен бота Telegram (@BotFather)" \
    "Telegram bot token (@BotFather)"
  [[ -n "$BOT_TOKEN" ]] || fail "$(_msg "Токен обязателен" "Token is required")"

  prompt ADMIN_ID \
    "Telegram ID администратора" \
    "Admin Telegram ID"
  [[ "$ADMIN_ID" =~ ^[0-9]+$ ]] || fail "$(_msg "Некорректный Telegram ID" "Invalid Telegram ID")"

  prompt SUB_DOMAIN \
    "Домен подписки (например sub.example.com)" \
    "Subscription domain (e.g. sub.example.com)"
  SUB_DOMAIN="${SUB_DOMAIN#https://}"; SUB_DOMAIN="${SUB_DOMAIN#http://}"; SUB_DOMAIN="${SUB_DOMAIN%%/*}"

  local base="${SUB_DOMAIN#*.}"
  prompt APP_DOMAIN \
    "Домен кабинета (например app.example.com)" \
    "Cabinet domain (e.g. app.example.com)" \
    "app.${base}"

  prompt LANDING_DOMAIN \
    "Домен лендинга (например example.com, Enter — пропустить)" \
    "Landing domain (e.g. example.com, Enter to skip)" \
    "$base"

  prompt GITHUB_USER \
    "GitHub username/org с приватным репозиторием бота" \
    "GitHub username/org with private bot repo"

  prompt BOT_REPO_NAME_INPUT \
    "Имя репозитория бота" \
    "Bot repository name" \
    "$BOT_REPO_NAME"
  BOT_REPO_NAME="$BOT_REPO_NAME_INPUT"

  echo ""
  echo -e "${MAGENTA}$(_msg "Выберите тип SSL:" "Choose SSL type:")${RESET}"
  echo "  1) $(_msg "Let's Encrypt (ручной DNS на сервер)" "Let's Encrypt (manual DNS to server)")"
  echo "  2) $(_msg "Cloudflare (Origin Certificate)" "Cloudflare (Origin Certificate)")"
  prompt SSL_MODE \
    "Вариант (1 или 2)" \
    "Option (1 or 2)" \
    "1"

  if [[ "$SSL_MODE" == "2" ]]; then
    SSL_TYPE="cloudflare"
    prompt CF_CERT_PATH \
      "Путь к Cloudflare Origin Certificate (fullchain.pem)" \
      "Path to Cloudflare Origin Certificate (fullchain.pem)" \
      "/root/cloudflare-origin.pem"
    prompt CF_KEY_PATH \
      "Путь к Cloudflare Origin Private Key (privkey.pem)" \
      "Path to Cloudflare Origin Private Key (privkey.pem)" \
      "/root/cloudflare-origin.key"
  else
    SSL_TYPE="manual"
    prompt CERTBOT_EMAIL \
      "Email для Let's Encrypt" \
      "Email for Let's Encrypt" \
      "admin@${base}"
  fi

  prompt DEPLOY_KEY_PATH_INPUT \
    "Путь к deploy key для git clone" \
    "Path to deploy key for git clone" \
    "$DEPLOY_KEY_PATH"
  DEPLOY_KEY_PATH="$DEPLOY_KEY_PATH_INPUT"
}

# ── Deploy key & clone ───────────────────────────────────────────────────────
setup_deploy_key() {
  section "$(_msg "Deploy key" "Deploy key")"
  if [[ ! -f "$DEPLOY_KEY_PATH" ]]; then
    warn "$(_msg "Deploy key не найден: $DEPLOY_KEY_PATH" "Deploy key not found: $DEPLOY_KEY_PATH")"
    prompt DEPLOY_KEY_PATH \
      "Укажите путь к приватному ключу" \
      "Specify private key path"
    [[ -f "$DEPLOY_KEY_PATH" ]] || fail "$(_msg "Файл ключа не найден" "Key file not found")"
  fi
  chmod 600 "$DEPLOY_KEY_PATH"
  ok "$(_msg "Deploy key: $DEPLOY_KEY_PATH" "Deploy key: $DEPLOY_KEY_PATH")"
}

clone_source() {
  section "$(_msg "Загрузка исходников" "Fetching source code")"
  local repo_url="git@github.com:${GITHUB_USER}/${BOT_REPO_NAME}.git"
  export GIT_SSH_COMMAND="ssh -i ${DEPLOY_KEY_PATH} -o StrictHostKeyChecking=accept-new -o IdentitiesOnly=yes"

  if [[ -d "$INSTALL_DIR/.git" ]]; then
    warn "$(_msg "Каталог $INSTALL_DIR уже существует — обновление" "Directory $INSTALL_DIR exists — updating")"
    git -C "$INSTALL_DIR" pull --ff-only
  else
    mkdir -p "$(dirname "$INSTALL_DIR")"
    step "$(_msg "Клонирование $repo_url …" "Cloning $repo_url …")"
    git clone "$repo_url" "$INSTALL_DIR"
  fi
  ok "$(_msg "Исходники готовы" "Source code ready")"
}

# ── .env generation ──────────────────────────────────────────────────────────
generate_env() {
  section "$(_msg "Генерация .env" "Generating .env")"
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
  ok "$(_msg ".env создан" ".env created")"
  info "SUBSCRIPTION_BASE_URL=https://${SUB_DOMAIN}"
  info "ADMIN_PATH_SECRET=${admin_secret}"
}

# ── nginx config ─────────────────────────────────────────────────────────────
write_nginx_config() {
  section "$(_msg "Nginx" "Nginx")"
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
  ok "$(_msg "nginx.conf создан" "nginx.conf created")"
}

# ── SSL ──────────────────────────────────────────────────────────────────────
setup_ssl() {
  section "$(_msg "SSL-сертификаты" "SSL certificates")"
  local cert_dir="$INSTALL_DIR/nginx/certs"

  if [[ "$SSL_TYPE" == "cloudflare" ]]; then
    [[ -f "$CF_CERT_PATH" && -f "$CF_KEY_PATH" ]] || fail "$(_msg "Cloudflare сертификаты не найдены" "Cloudflare certificates not found")"
    cp "$CF_CERT_PATH" "$cert_dir/fullchain.pem"
    cp "$CF_KEY_PATH" "$cert_dir/privkey.pem"
    chmod 600 "$cert_dir/privkey.pem"
    ok "$(_msg "Cloudflare Origin Certificate установлен" "Cloudflare Origin Certificate installed")"
    return
  fi

  # Manual Let's Encrypt
  apt-get install -y -qq certbot
  mkdir -p /var/www/certbot

  # Temporary self-signed cert so nginx can start before LE
  if [[ ! -f "$cert_dir/fullchain.pem" ]]; then
    step "$(_msg "Временный self-signed сертификат…" "Temporary self-signed certificate…")"
    openssl req -x509 -newkey rsa:2048 -nodes -days 1 \
      -keyout "$cert_dir/privkey.pem" \
      -out "$cert_dir/fullchain.pem" \
      -subj "/CN=${SUB_DOMAIN}" 2>/dev/null
  fi

  local domains=("-d" "$SUB_DOMAIN" "-d" "$APP_DOMAIN")
  [[ -n "${LANDING_DOMAIN:-}" ]] && domains+=("-d" "$LANDING_DOMAIN" "-d" "www.${LANDING_DOMAIN}")

  step "$(_msg "Запрос Let's Encrypt…" "Requesting Let's Encrypt…")"
  info "$(_msg "Убедитесь, что DNS указывает на этот сервер" "Ensure DNS points to this server")"

  # Stop nginx container if running for standalone
  docker compose -f "$INSTALL_DIR/docker-compose.yml" stop nginx 2>/dev/null || true

  if certbot certonly --standalone --non-interactive --agree-tos \
      -m "${CERTBOT_EMAIL:-$CERTBOT_EMAIL_DEFAULT}" \
      "${domains[@]}"; then
    cp "/etc/letsencrypt/live/${SUB_DOMAIN}/fullchain.pem" "$cert_dir/fullchain.pem"
    cp "/etc/letsencrypt/live/${SUB_DOMAIN}/privkey.pem" "$cert_dir/privkey.pem"
    chmod 600 "$cert_dir/privkey.pem"
    ok "$(_msg "Let's Encrypt сертификат получен" "Let's Encrypt certificate obtained")"

    # Auto-renew hook
    cat > /etc/cron.d/zenyun-certbot <<CRON
0 3 * * * root certbot renew --quiet --deploy-hook "cp /etc/letsencrypt/live/${SUB_DOMAIN}/fullchain.pem ${cert_dir}/fullchain.pem && cp /etc/letsencrypt/live/${SUB_DOMAIN}/privkey.pem ${cert_dir}/privkey.pem && docker compose -f ${INSTALL_DIR}/docker-compose.yml exec nginx nginx -s reload"
CRON
  else
    warn "$(_msg "Certbot не смог получить сертификат — используется временный" "Certbot failed — using temporary cert")"
    warn "$(_msg "Запустите certbot вручную после настройки DNS" "Run certbot manually after DNS is configured")"
  fi
}

# ── Docker Compose ───────────────────────────────────────────────────────────
start_services() {
  section "$(_msg "Запуск сервисов" "Starting services")"
  cd "$INSTALL_DIR"

  step "$(_msg "Сборка образов (это может занять несколько минут)…" "Building images (may take a few minutes)…")"
  docker compose up -d --build
  ok "$(_msg "Контейнеры запущены" "Containers started")"

  step "$(_msg "Ожидание готовности…" "Waiting for readiness…")"
  local i
  for i in $(seq 1 30); do
    if docker compose exec -T db pg_isready -U vpnbot >/dev/null 2>&1; then
      ok "$(_msg "PostgreSQL готов" "PostgreSQL ready")"
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
    ok "$(_msg "Cron бэкапа настроен (03:00)" "Backup cron configured (03:00)")"
  fi
}

# ── Final status ─────────────────────────────────────────────────────────────
show_final_status() {
  section "$(_msg "🎉 Установка завершена!" "🎉 Installation complete!")"
  local admin_secret
  admin_secret=$(grep ADMIN_PATH_SECRET "$INSTALL_DIR/.env" | cut -d= -f2)

  echo -e "${GREEN}${BOLD}$(_msg "Доступные URL:" "Access URLs:")${RESET}"
  echo ""
  echo -e "  📱 $(_msg "Mini App (подписка)" "Mini App (subscription)")"
  echo -e "     ${CYAN}https://${SUB_DOMAIN}/app${RESET}"
  echo ""
  echo -e "  🔗 $(_msg "Подписка" "Subscription endpoint")"
  echo -e "     ${CYAN}https://${SUB_DOMAIN}/sub/{token}${RESET}"
  echo ""
  echo -e "  🖥  $(_msg "Веб-кабинет" "Web cabinet")"
  echo -e "     ${CYAN}https://${APP_DOMAIN}/${RESET}"
  echo ""
  echo -e "  🔐 $(_msg "Секретная админ-панель" "Secret admin panel")"
  echo -e "     ${CYAN}https://${APP_DOMAIN}/a/${admin_secret}${RESET}"
  echo ""
  echo -e "${YELLOW}$(_msg "Следующие шаги в @BotFather:" "Next steps in @BotFather:")${RESET}"
  echo "  1. /mybots → Bot Settings → Configure Mini App"
  echo "     URL: https://${SUB_DOMAIN}/app"
  echo "  2. Bot Settings → Menu Button → https://${SUB_DOMAIN}/app"
  echo ""
  echo -e "${DIM}$(_msg "Логи: docker compose -f ${INSTALL_DIR}/docker-compose.yml logs -f bot web" "Logs: docker compose -f ${INSTALL_DIR}/docker-compose.yml logs -f bot web")${RESET}"
  echo -e "${DIM}$(_msg "Поддержка: @zenyuntestbot" "Support: @zenyuntestbot")${RESET}"
  echo ""
}

# ── Main ─────────────────────────────────────────────────────────────────────
main() {
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
