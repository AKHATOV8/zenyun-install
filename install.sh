#!/usr/bin/env bash
# ZenyunVPN — automated VPS installer
# Usage: curl -sSL https://raw.githubusercontent.com/AKHATOV8/zenyun-install/main/install.sh -o install.sh && bash install.sh

set -euo pipefail

if [ ! -t 0 ]; then
  echo ""
  echo "⚠️  Please run the installer this way:"
  echo ""
  echo "  curl -sSL https://raw.githubusercontent.com/AKHATOV8/zenyun-install/main/install.sh -o install.sh && bash install.sh"
  echo ""
  exit 1
fi

# ── Constants ────────────────────────────────────────────────────────────────
CORRECT_HASH="f1ee2ab84c5aeb3268a2862286a0cd61026995b99aa371261f398c408025f389"
INSTALL_DIR="${INSTALL_DIR:-/home/vpnbot}"
PACKAGE_URL="https://github.com/AKHATOV8/zenyun-install/releases/download/v1.4.1/zenyun-vpn-v1.4.1.tar.gz"
PACKAGE_SHA256="44de10ce84819e891a8332fd0bd5cf7753f02db4c70ebb1631fe9edd15184f67"
CERTBOT_EMAIL_DEFAULT="admin@example.com"
ZENYUN_LANG="${ZENYUN_LANG:-}"
_CLEANUP_PATHS=()
_INSTALL_ROLLBACK=0

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
    packages_title)   ru="Системные пакеты"; en="System packages"; zh="系统软件包" ;;
    packages_install) ru="Обновление и установка пакетов…"; en="Updating and installing packages…"; zh="正在更新并安装软件包…" ;;
    packages_ok)      ru="Системные пакеты установлены"; en="System packages installed"; zh="系统软件包已安装" ;;
    docker_title)     ru="Docker"; en="Docker"; zh="Docker" ;;
    docker_exists)    ru="Docker уже установлен: %s"; en="Docker already installed: %s"; zh="Docker 已安装：%s" ;;
    docker_install)   ru="Установка Docker…"; en="Installing Docker…"; zh="正在安装 Docker…" ;;
    docker_ok)        ru="Docker установлен"; en="Docker installed"; zh="Docker 安装完成" ;;
    compose_install)  ru="Установка Docker Compose plugin…"; en="Installing Docker Compose plugin…"; zh="正在安装 Docker Compose 插件…" ;;
    compose_ok)       ru="Docker Compose готов"; en="Docker Compose ready"; zh="Docker Compose 已就绪" ;;
    auto_title)       ru="Автоматическая установка"; en="Automatic installation"; zh="自动安装" ;;
    config_title)     ru="Настройка"; en="Configuration"; zh="配置" ;;
    ask_bot_token)    ru="Токен бота Telegram (@BotFather)"; en="Telegram bot token (@BotFather)"; zh="Telegram 机器人令牌 (@BotFather)" ;;
    token_required)   ru="Токен обязателен"; en="Token is required"; zh="令牌为必填项" ;;
    ask_project_name) ru="Название проекта (например MyVPN)"; en="Project name (e.g. MyVPN)"; zh="项目名称（例如 MyVPN）" ;;
    project_branding_title) ru="Брендинг проекта"; en="Project branding"; zh="项目品牌" ;;
    project_branding_apply) ru="Замена названия в файлах проекта…"; en="Applying project name to project files…"; zh="正在将项目名称应用到项目文件…" ;;
    project_branding_ok) ru="Название проекта применено"; en="Project name applied"; zh="项目名称已应用" ;;
    project_yours)    ru="Ваш проект: %s"; en="Your project: %s"; zh="您的项目：%s" ;;
    ask_admin_id)     ru="Telegram ID администратора"; en="Admin Telegram ID"; zh="管理员 Telegram ID" ;;
    admin_id_invalid) ru="Некорректный Telegram ID"; en="Invalid Telegram ID"; zh="Telegram ID 无效" ;;
    ask_sub_domain)   ru="Домен подписки (например sub.example.com)"; en="Subscription domain (e.g. sub.example.com)"; zh="订阅域名（例如 sub.example.com）" ;;
    domain_required)  ru="Домен обязателен"; en="Domain is required"; zh="域名为必填项" ;;
    ask_app_domain)   ru="Домен кабинета (например app.example.com)"; en="Cabinet domain (e.g. app.example.com)"; zh="用户中心域名（例如 app.example.com）" ;;
    ssl_choose)       ru="Выберите тип SSL:"; en="Choose SSL type:"; zh="选择 SSL 类型：" ;;
    ssl_le)           ru="Let's Encrypt (ручной DNS на сервер)"; en="Let's Encrypt (manual DNS to server)"; zh="Let's Encrypt（手动 DNS 指向服务器）" ;;
    ssl_cf)           ru="Cloudflare (Origin Certificate)"; en="Cloudflare (Origin Certificate)"; zh="Cloudflare（源站证书）" ;;
    ssl_option)       ru="Вариант (1 или 2)"; en="Option (1 or 2)"; zh="选项 (1 或 2)" ;;
    download_title)   ru="Загрузка проекта"; en="Downloading project"; zh="下载项目" ;;
    downloading)      ru="Скачивание архива с сервера распространения…"; en="Downloading archive from distribution server…"; zh="正在从分发服务器下载压缩包…" ;;
    download_fail)    ru="Не удалось скачать архив"; en="Failed to download archive"; zh="下载压缩包失败" ;;
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
    url_bot)          ru="Telegram бот"; en="Telegram bot"; zh="Telegram 机器人" ;;
    botfather_title)  ru="Следующие шаги в @BotFather:"; en="Next steps in @BotFather:"; zh="@BotFather 后续步骤：" ;;
    logs_hint)        ru="Логи: docker compose -f %s/docker-compose.yml logs -f bot web"; en="Logs: docker compose -f %s/docker-compose.yml logs -f bot web"; zh="日志：docker compose -f %s/docker-compose.yml logs -f bot web" ;;
    checksum_fail)    ru="Контрольная сумма не совпадает — архив повреждён"; en="Checksum mismatch — archive corrupted"; zh="校验和不匹配 — 压缩包已损坏" ;;
    checksum_ok)      ru="Контрольная сумма проверена"; en="Checksum verified"; zh="校验和已验证" ;;
    eta_note)         ru="~%s мин"; en="~%s min"; zh="约 %s 分钟" ;;
    compose_fail)     ru="docker compose не запустился — откат контейнеров"; en="docker compose failed — rolling back containers"; zh="docker compose 启动失败 — 正在回滚容器" ;;
    health_title)     ru="Проверка API"; en="API health check"; zh="API 健康检查" ;;
    health_ok)        ru="Health endpoint отвечает OK"; en="Health endpoint OK"; zh="健康检查通过" ;;
    health_fail)      ru="Health endpoint недоступен на localhost:8000"; en="Health endpoint unavailable on localhost:8000"; zh="localhost:8000 健康检查失败" ;;
    err_line)         ru="Ошибка на строке %s (код %s)"; en="Error at line %s (exit %s)"; zh="第 %s 行出错（退出码 %s）" ;;
    checksum_verify)  ru="Проверка контрольной суммы…"; en="Verifying checksum…"; zh="正在校验校验和…" ;;
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

cleanup_on_exit() {
  local code=$?
  for p in "${_CLEANUP_PATHS[@]}"; do
    rm -f "$p" 2>/dev/null || true
  done
  if [[ "$_INSTALL_ROLLBACK" -eq 1 && -d "$INSTALL_DIR" ]]; then
    (cd "$INSTALL_DIR" && docker compose down 2>/dev/null) || true
  fi
  if [[ $code -ne 0 ]]; then
    echo -e "${RED}❌${RESET} $(tf err_line "${BASH_LINENO[0]:-?}" "$code")" >&2
  fi
  return "$code"
}

on_err() {
  trap - ERR
  fail "$(tf err_line "$1" "$?")"
}

trap cleanup_on_exit EXIT
trap 'on_err $LINENO' ERR

choose_lang() {
  echo "Select language / Выберите язык / 选择语言:"
  echo "  1) Русский"
  echo "  2) English"
  echo "  3) 中文"
  printf "Enter choice [1-3]: "
  read -r LANG_CHOICE

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
eta()  { info "$(tf eta_note "$1")"; }

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
    read -r input
    printf -v "$var" '%s' "${input:-$default}"
  else
    printf "? %s: " "$text"
    read -r input
    printf -v "$var" '%s' "$input"
  fi
}

prompt_secret() {
  local var="$1" key="$2"
  printf "? %s: " "$(t "$key")"
  read -r -s input
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

# ── Automatic install (no prompts after config) ──────────────────────────────
install_system_packages() {
  section "$(t packages_title)"
  export DEBIAN_FRONTEND=noninteractive
  step "$(t packages_install)"
  eta 3
  apt-get update -y
  apt-get install -y curl wget git unzip nginx certbot python3-certbot-nginx openssl tar coreutils
  systemctl enable nginx
  ok "$(t packages_ok)"
}

install_docker() {
  section "$(t docker_title)"
  if command -v docker >/dev/null 2>&1; then
    ok "$(tf docker_exists "$(docker --version)")"
  else
    step "$(t docker_install)"
    eta 5
    curl --retry 3 --retry-delay 2 -fsSL https://get.docker.com | sh
    systemctl enable docker
    systemctl start docker
    ok "$(t docker_ok)"
  fi

  if docker compose version >/dev/null 2>&1; then
    ok "$(t compose_ok)"
  else
    step "$(t compose_install)"
    apt-get install -y docker-compose-plugin
    ok "$(t compose_ok)"
  fi
}

# ── Configuration prompts ────────────────────────────────────────────────────
collect_config() {
  section "$(t config_title)"

  prompt BOT_TOKEN ask_bot_token
  [[ -n "$BOT_TOKEN" ]] || fail "$(t token_required)"

  prompt PROJECT_NAME ask_project_name "ZenyunVPN"
  PROJECT_NAME=$(echo "$PROJECT_NAME" | tr -cd '[:alnum:][:space:]-')
  [[ -n "$PROJECT_NAME" ]] || PROJECT_NAME="ZenyunVPN"

  prompt ADMIN_ID ask_admin_id
  [[ "$ADMIN_ID" =~ ^[0-9]+$ ]] || fail "$(t admin_id_invalid)"

  prompt SUB_DOMAIN ask_sub_domain
  SUB_DOMAIN="${SUB_DOMAIN#https://}"
  SUB_DOMAIN="${SUB_DOMAIN#http://}"
  SUB_DOMAIN="${SUB_DOMAIN%%/*}"
  SUB_DOMAIN=$(echo "$SUB_DOMAIN" | tr -cd '[:alnum:].-')
  [[ -n "$SUB_DOMAIN" ]] || fail "$(t domain_required)"

  local base="${SUB_DOMAIN#*.}"
  prompt APP_DOMAIN ask_app_domain "app.${base}"
  APP_DOMAIN="${APP_DOMAIN#https://}"
  APP_DOMAIN="${APP_DOMAIN#http://}"
  APP_DOMAIN="${APP_DOMAIN%%/*}"
  APP_DOMAIN=$(echo "$APP_DOMAIN" | tr -cd '[:alnum:].-')
  [[ -n "$APP_DOMAIN" ]] || fail "$(t domain_required)"

  LANDING_DOMAIN=""

  echo ""
  echo -e "${MAGENTA}$(t ssl_choose)${RESET}"
  echo "  1) $(t ssl_le)"
  echo "  2) $(t ssl_cf)"
  prompt SSL_MODE ssl_option "1"

  if [[ "$SSL_MODE" == "2" ]]; then
    SSL_TYPE="cloudflare"
    CF_CERT_PATH="/root/cloudflare-origin.pem"
    CF_KEY_PATH="/root/cloudflare-origin.key"
  else
    SSL_TYPE="manual"
    CERTBOT_EMAIL="admin@${base}"
  fi
}

# ── Download project archive ───────────────────────────────────────────────────
download_package() {
  section "$(t download_title)"
  local archive="/tmp/zenyun-vpn-v1.3.tar.gz"
  _CLEANUP_PATHS+=("$archive")

  step "$(t downloading)"
  eta 2
  if ! wget --progress=bar:force --tries=3 --timeout=60 -O "$archive" "$PACKAGE_URL"; then
    rm -f "$archive"
    fail "$(t download_fail)"
  fi

  step "$(t checksum_verify)"
  local actual
  actual=$(sha256sum "$archive" | awk '{print $1}')
  if [[ "$actual" != "$PACKAGE_SHA256" ]]; then
    rm -f "$archive"
    fail "$(t checksum_fail)"
  fi
  ok "$(t checksum_ok)"

  mkdir -p "$INSTALL_DIR"
  tar -xzf "$archive" -C "$INSTALL_DIR" 2>/dev/null
  rm -f "$archive"
  _CLEANUP_PATHS=()

  [[ -d "$INSTALL_DIR" ]] || fail "$(t download_fail)"
  ok "$(t source_ok)"
}

# ── Apply project name branding ──────────────────────────────────────────────
apply_project_name() {
  section "$(t project_branding_title)"
  step "$(t project_branding_apply)"

  local PROJECT_LOWER file
  PROJECT_LOWER=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | tr -d ' ')

  while IFS= read -r -d '' file; do
    sed -i \
      -e "s/ZenyunVPN/${PROJECT_NAME}/g" \
      -e "s/Zenyun VPN/${PROJECT_NAME}/g" \
      -e "s/zenyunvpn/${PROJECT_LOWER}/g" \
      -e "s/ZenYun/${PROJECT_NAME}/g" \
      "$file"
  done < <(find "$INSTALL_DIR" -type f \( -name "*.html" -o -name "*.js" -o -name "*.py" -o -name "*.yml" \) -print0)

  ok "$(t project_branding_ok)"
}

# ── .env generation ──────────────────────────────────────────────────────────
generate_env() {
  section "$(t env_title)"
  local pg_pass admin_secret jwt_secret
  pg_pass=$(openssl rand -hex 16)
  admin_secret=$(openssl rand -hex 24)
  jwt_secret=$(openssl rand -hex 32)

  cat > "$INSTALL_DIR/.env" <<EOF
# ============ ${PROJECT_NAME} — auto-generated $(date -Iseconds) ============
BOT_TOKEN=${BOT_TOKEN}
JWT_SECRET=${jwt_secret}
ADMIN_IDS=${ADMIN_ID}
ADMIN_LOG_CHANNEL_ID=
PROJECT_NAME=${PROJECT_NAME}

DATABASE_URL=postgresql+asyncpg://vpnbot:${pg_pass}@db:5432/vpnbot
REDIS_URL=redis://redis:6379/0

POSTGRES_USER=vpnbot
POSTGRES_PASSWORD=${pg_pass}
POSTGRES_DB=vpnbot

SUBSCRIPTION_BASE_URL=https://${SUB_DOMAIN}
APP_DOMAIN=${APP_DOMAIN}

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

# ── nginx config (host + project certs) ────────────────────────────────────────
write_nginx_config() {
  section "$(t nginx_title)"
  mkdir -p "$INSTALL_DIR/nginx/certs" "$INSTALL_DIR/backups"
  touch "$INSTALL_DIR/nginx/certs/.gitkeep"

  local cabinet_root="${INSTALL_DIR}/web/static/cabinet"
  local ssl_cert="${1:-}"
  local ssl_key="${2:-}"
  local app_listen sub_listen ssl_directives=""
  local http_redirect=""

  if [[ -n "$ssl_cert" && -n "$ssl_key" ]]; then
    app_listen="    listen 443 ssl;
    listen [::]:443 ssl;
    http2 on;"
    sub_listen="$app_listen"
    ssl_directives="    ssl_certificate     ${ssl_cert};
    ssl_certificate_key ${ssl_key};
    ssl_protocols       TLSv1.2 TLSv1.3;
    ssl_ciphers         HIGH:!aNULL:!MD5;"
    http_redirect="
server {
    listen 80;
    listen [::]:80;
    server_name ${APP_DOMAIN} ${SUB_DOMAIN};
    return 301 https://\$host\$request_uri;
}
"
  else
    app_listen="    listen 80;
    listen [::]:80;"
    sub_listen="$app_listen"
  fi

  cat > /etc/nginx/sites-available/zenyunvpn <<EOF
# ZenyunVPN — generated by zenyun-install
${http_redirect}
server {
${app_listen}
    server_name ${APP_DOMAIN};

${ssl_directives}
    client_max_body_size 50m;

    location /api/ {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 120s;
    }
    location /static/ {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    location ~ ^/a/[^/]+\$ {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-Proto \$scheme;
        add_header Cache-Control "no-store" always;
    }
    location = / {
        root ${cabinet_root};
        try_files /index.html =404;
        add_header Cache-Control "no-store" always;
    }
    location /health {
        proxy_pass http://127.0.0.1:8000;
    }
    location / {
        root ${cabinet_root};
        try_files \$uri /index.html;
        add_header Cache-Control "no-store" always;
    }
}

server {
${sub_listen}
    server_name ${SUB_DOMAIN};

${ssl_directives}
    client_max_body_size 50m;

    location /sub/ {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    location = /app {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    location = /admin-app {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    location /sub-app/ {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    location /static/ {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    location /api/ {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 120s;
        client_max_body_size 50m;
    }
    location /install/ {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    location /health {
        proxy_pass http://127.0.0.1:8000;
    }
}
EOF

  rm -f /etc/nginx/sites-enabled/default
  ln -sf /etc/nginx/sites-available/zenyunvpn /etc/nginx/sites-enabled/zenyunvpn
  nginx -t
  systemctl enable nginx
  systemctl restart nginx
  ok "$(t nginx_ok)"
}

prepare_docker_web_port() {
  cat > "$INSTALL_DIR/docker-compose.override.yml" <<EOF
# Generated by zenyun-install — expose web for host nginx
services:
  web:
    ports:
      - "127.0.0.1:8000:8000"
  nginx:
    profiles:
      - donotstart
EOF
}

sync_certs_to_project() {
  local cert_dir="$INSTALL_DIR/nginx/certs"
  if [[ -f /etc/letsencrypt/live/${SUB_DOMAIN}/fullchain.pem ]]; then
    cp "/etc/letsencrypt/live/${SUB_DOMAIN}/fullchain.pem" "$cert_dir/fullchain.pem"
    cp "/etc/letsencrypt/live/${SUB_DOMAIN}/privkey.pem" "$cert_dir/privkey.pem"
    chmod 600 "$cert_dir/privkey.pem"
  fi
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
    mkdir -p /etc/nginx/ssl
    cp "$CF_CERT_PATH" /etc/nginx/ssl/fullchain.pem
    cp "$CF_KEY_PATH" /etc/nginx/ssl/privkey.pem
    chmod 600 /etc/nginx/ssl/privkey.pem
    write_nginx_config /etc/nginx/ssl/fullchain.pem /etc/nginx/ssl/privkey.pem
    ok "$(t cf_ok)"
    return
  fi

  step "$(t le_request)"
  eta 2
  info "$(t dns_hint)"

  if certbot --nginx \
      -d "$SUB_DOMAIN" -d "$APP_DOMAIN" \
      --non-interactive --agree-tos \
      -m "${CERTBOT_EMAIL:-$CERTBOT_EMAIL_DEFAULT}" \
      --redirect; then
    sync_certs_to_project
    systemctl reload nginx
    ok "$(t le_ok)"
    cat > /etc/cron.d/zenyun-certbot <<CRON
0 3 * * * root certbot renew --quiet --deploy-hook "systemctl reload nginx"
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
  eta 10
  _INSTALL_ROLLBACK=1
  if ! docker compose up -d --build db redis bot web; then
    docker compose down 2>/dev/null || true
    _INSTALL_ROLLBACK=0
    fail "$(t compose_fail)"
  fi
  _INSTALL_ROLLBACK=0
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

  step "Database migrations"
  if docker compose exec -T web alembic upgrade head; then
    ok "Migrations applied"
  else
    warn "Migration failed"
  fi

  systemctl restart nginx
  docker compose ps
  post_install_health_check
}

post_install_health_check() {
  section "$(t health_title)"
  local i body
  for i in $(seq 1 15); do
    if body=$(curl --retry 3 --retry-delay 2 -fsS http://127.0.0.1:8000/health 2>/dev/null); then
      if echo "$body" | grep -q '"status"'; then
        ok "$(t health_ok)"
        info "$body"
        return 0
      fi
    fi
    sleep 2
  done
  fail "$(t health_fail)"
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
  local admin_secret bot_link="https://t.me/zenyuntestbot"
  admin_secret=$(grep ADMIN_PATH_SECRET "$INSTALL_DIR/.env" | cut -d= -f2)

  if [[ -n "${BOT_TOKEN:-}" ]]; then
    local bot_username
    bot_username=$(curl -fsS "https://api.telegram.org/bot${BOT_TOKEN}/getMe" 2>/dev/null \
      | grep -o '"username":"[^"]*"' | head -1 | cut -d'"' -f4 || true)
    [[ -n "$bot_username" ]] && bot_link="https://t.me/${bot_username}"
  fi

  echo -e "${GREEN}${BOLD}$(tf project_yours "$PROJECT_NAME")${RESET}"
  echo ""
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
  echo -e "  🤖 $(t url_bot)"
  echo -e "     ${CYAN}${bot_link}${RESET}"
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

run_automatic_install() {
  section "$(t auto_title)"
  install_system_packages
  install_docker
  download_package
  apply_project_name
  generate_env
  prepare_docker_web_port
  write_nginx_config
  setup_ssl
  start_services
  install_backup_cron
}

# ── Main ─────────────────────────────────────────────────────────────────────
main() {
  choose_lang
  banner
  check_password
  check_requirements
  collect_config
  run_automatic_install
  show_final_status
}

main "$@"
