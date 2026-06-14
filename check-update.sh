#!/usr/bin/env bash
# ZenyunVPN — update existing installation
# Usage: bash check-update.sh
set -euo pipefail

CORRECT_HASH="b0aef10571e26a3c3958c01e2c3c85d17e3eb6e55ddfd1a4bbffc2fb4e0ebe09"
INSTALL_DIR="${INSTALL_DIR:-/home/vpnbot}"
DEPLOY_KEY_PATH="${DEPLOY_KEY_PATH:-/root/.ssh/zenyun_deploy_key}"

if [[ -t 1 ]]; then
  RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
  BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; RESET='\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; BLUE=''; CYAN=''; BOLD=''; DIM=''; RESET=''
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
  echo "  ║       🔄  ZenyunVPN Updater  🔄          ║"
  echo "  ╚══════════════════════════════════════════╝"
  echo -e "${RESET}"
}

section() {
  echo ""
  echo -e "${BLUE}${BOLD}━━━ $1 ━━━${RESET}"
  echo ""
}

ok()   { echo -e "${GREEN}✅${RESET} $1"; }
warn() { echo -e "${YELLOW}⚠️${RESET}  $1"; }
fail() { echo -e "${RED}❌${RESET} $1"; exit 1; }
step() { echo -e "${GREEN}▶${RESET} $1"; }

check_password() {
  section "$(_msg "Проверка доступа" "Access verification")"
  read -r -s -p "$(echo -e "${CYAN}?${RESET} $(_msg "Введите пароль" "Enter password"): ")" INPUT_PASSWORD
  echo ""
  local input_hash
  input_hash=$(echo -n "$INPUT_PASSWORD" | sha256sum | cut -d' ' -f1)
  unset INPUT_PASSWORD
  if [[ "$input_hash" != "$CORRECT_HASH" ]]; then
    fail "$(_msg "Неверный пароль" "Wrong password")"
  fi
  ok "$(_msg "Пароль принят" "Password accepted")"
}

check_install_dir() {
  [[ -d "$INSTALL_DIR" ]] || fail "$(_msg "Каталог $INSTALL_DIR не найден" "Directory $INSTALL_DIR not found")"
  [[ -f "$INSTALL_DIR/docker-compose.yml" ]] || fail "$(_msg "docker-compose.yml не найден" "docker-compose.yml not found")"
  [[ -f "$INSTALL_DIR/.env" ]] || fail "$(_msg ".env не найден" ".env not found")"
}

pull_updates() {
  section "$(_msg "Обновление кода" "Updating code")"
  cd "$INSTALL_DIR"

  if [[ -d .git ]]; then
    if [[ -f "$DEPLOY_KEY_PATH" ]]; then
      export GIT_SSH_COMMAND="ssh -i ${DEPLOY_KEY_PATH} -o StrictHostKeyChecking=accept-new -o IdentitiesOnly=yes"
    fi
    local old_rev new_rev
    old_rev=$(git rev-parse --short HEAD)
    step "$(_msg "git pull…" "git pull…")"
    git pull --ff-only
    new_rev=$(git rev-parse --short HEAD)
    if [[ "$old_rev" == "$new_rev" ]]; then
      ok "$(_msg "Уже актуальная версия ($new_rev)" "Already up to date ($new_rev)")"
    else
      ok "$(_msg "Обновлено: $old_rev → $new_rev" "Updated: $old_rev → $new_rev")"
    fi
  else
    warn "$(_msg "Git-репозиторий не найден — пропуск git pull" "Git repo not found — skipping git pull")"
  fi
}

rebuild_services() {
  section "$(_msg "Пересборка сервисов" "Rebuilding services")"
  cd "$INSTALL_DIR"
  step "$(_msg "docker compose up -d --build …" "docker compose up -d --build …")"
  docker compose up -d --build
  ok "$(_msg "Сервисы перезапущены" "Services restarted")"
  docker compose ps
}

show_changelog() {
  section "$(_msg "Changelog" "Changelog")"
  cd "$INSTALL_DIR"
  if [[ -d .git ]]; then
    echo -e "${DIM}"
    git log --oneline --decorate -15 2>/dev/null || warn "$(_msg "Не удалось получить git log" "Could not get git log")"
    echo -e "${RESET}"
  else
    warn "$(_msg "Changelog недоступен без git" "Changelog unavailable without git")"
  fi
}

health_check() {
  section "$(_msg "Проверка здоровья" "Health check")"
  cd "$INSTALL_DIR"
  local failed=0
  for svc in db redis bot web nginx; do
    local status
    status=$(docker compose ps --format '{{.Name}} {{.Status}}' 2>/dev/null | grep "$svc" | head -1 || true)
    if echo "$status" | grep -qi "up"; then
      ok "$status"
    else
      warn "$(_msg "$svc: не запущен" "$svc: not running")"
      failed=1
    fi
  done
  if [[ $failed -eq 0 ]]; then
    ok "$(_msg "Все сервисы работают" "All services running")"
  else
    warn "$(_msg "Проверьте логи: docker compose logs -f" "Check logs: docker compose logs -f")"
  fi
}

show_final() {
  section "$(_msg "🎉 Обновление завершено!" "🎉 Update complete!")"
  local sub_url
  sub_url=$(grep SUBSCRIPTION_BASE_URL "$INSTALL_DIR/.env" 2>/dev/null | cut -d= -f2- || echo "https://your-domain")
  echo -e "  🔗 Subscription: ${CYAN}${sub_url}/sub/{token}${RESET}"
  echo -e "  ${DIM}$(_msg "Поддержка: @zenyuntestbot" "Support: @zenyuntestbot")${RESET}"
  echo ""
}

main() {
  banner
  [[ $EUID -eq 0 ]] || fail "$(_msg "Запустите от root" "Run as root")"
  check_password
  check_install_dir
  pull_updates
  rebuild_services
  show_changelog
  health_check
  show_final
}

main "$@"
