#!/usr/bin/env bash
# ZenyunVPN — update existing installation
# Usage: bash check-update.sh
set -euo pipefail

CORRECT_HASH="b0aef10571e26a3c3958c01e2c3c85d17e3eb6e55ddfd1a4bbffc2fb4e0ebe09"
INSTALL_DIR="${INSTALL_DIR:-/home/vpnbot}"
DEPLOY_KEY_PATH="${DEPLOY_KEY_PATH:-/root/.ssh/zenyun_deploy_key}"
ZENYUN_LANG="${ZENYUN_LANG:-}"

if [[ -t 1 ]]; then
  RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
  BLUE='\033[0;34m'; CYAN='\033[0;36m'; MAGENTA='\033[0;35m'
  BOLD='\033[1m'; DIM='\033[2m'; RESET='\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; BLUE=''; CYAN=''; MAGENTA=''; BOLD=''; DIM=''; RESET=''
fi

# ── Translations (ru / en / zh) ───────────────────────────────────────────────
t() {
  local key="$1" ru="" en="" zh=""
  case "$key" in
    lang_choice)      ru="Язык (1/2/3)"; en="Language (1/2/3)"; zh="语言 (1/2/3)" ;;
    access_check)     ru="Проверка доступа"; en="Access verification"; zh="访问验证" ;;
    pwd_prompt)       ru="Введите пароль"; en="Enter password"; zh="请输入密码" ;;
    pwd_wrong)        ru="Неверный пароль"; en="Wrong password"; zh="密码错误" ;;
    pwd_ok)           ru="Пароль принят"; en="Password accepted"; zh="密码验证通过" ;;
    need_root)        ru="Запустите от root"; en="Run as root"; zh="请使用 root 运行" ;;
    dir_missing)      ru="Каталог %s не найден"; en="Directory %s not found"; zh="目录 %s 不存在" ;;
    compose_missing)  ru="docker-compose.yml не найден"; en="docker-compose.yml not found"; zh="未找到 docker-compose.yml" ;;
    env_missing)      ru=".env не найден"; en=".env not found"; zh="未找到 .env" ;;
    update_title)     ru="Обновление кода"; en="Updating code"; zh="更新代码" ;;
    git_pull)         ru="git pull…"; en="git pull…"; zh="git pull…" ;;
    up_to_date)       ru="Уже актуальная версия (%s)"; en="Already up to date (%s)"; zh="已是最新版本 (%s)" ;;
    updated)          ru="Обновлено: %s → %s"; en="Updated: %s → %s"; zh="已更新：%s → %s" ;;
    no_git)           ru="Git-репозиторий не найден — пропуск git pull"; en="Git repo not found — skipping git pull"; zh="未找到 Git 仓库 — 跳过 git pull" ;;
    rebuild_title)    ru="Пересборка сервисов"; en="Rebuilding services"; zh="重建服务" ;;
    compose_build)    ru="docker compose up -d --build …"; en="docker compose up -d --build …"; zh="docker compose up -d --build …" ;;
    services_ok)      ru="Сервисы перезапущены"; en="Services restarted"; zh="服务已重启" ;;
    changelog_title)  ru="Changelog"; en="Changelog"; zh="更新日志" ;;
    git_log_fail)     ru="Не удалось получить git log"; en="Could not get git log"; zh="无法获取 git log" ;;
    no_changelog)     ru="Changelog недоступен без git"; en="Changelog unavailable without git"; zh="无 Git 时无法显示更新日志" ;;
    health_title)     ru="Проверка здоровья"; en="Health check"; zh="健康检查" ;;
    svc_down)         ru="%s: не запущен"; en="%s: not running"; zh="%s：未运行" ;;
    all_ok)           ru="Все сервисы работают"; en="All services running"; zh="所有服务运行正常" ;;
    check_logs)       ru="Проверьте логи: docker compose logs -f"; en="Check logs: docker compose logs -f"; zh="请检查日志：docker compose logs -f" ;;
    done_title)       ru="🎉 Обновление завершено!"; en="🎉 Update complete!"; zh="🎉 更新完成！" ;;
    sub_label)        ru="Подписка"; en="Subscription"; zh="订阅" ;;
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

detect_lang() {
  case "${LANG:-}" in
    zh*|ZH*) echo "zh" ;;
    ru*|RU*) echo "ru" ;;
    *)       echo "en" ;;
  esac
}

choose_lang() {
  local detected default_choice choice
  detected="$(detect_lang)"
  case "$detected" in
    ru) default_choice="1" ;;
    zh) default_choice="3" ;;
    *)  default_choice="2" ;;
  esac
  echo ""
  echo -e "${MAGENTA}${BOLD}Select language / Выберите язык / 选择语言:${RESET}"
  echo "  1) Русский"
  echo "  2) English"
  echo "  3) 中文"
  read -r -p "$(echo -e "${CYAN}?${RESET} $(t lang_choice) [${default_choice}]: ")" choice
  choice="${choice:-$default_choice}"
  case "$choice" in
    1|ru|RU) ZENYUN_LANG="ru" ;;
    3|zh|ZH|cn) ZENYUN_LANG="zh" ;;
    *) ZENYUN_LANG="en" ;;
  esac
  export ZENYUN_LANG
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
  section "$(t access_check)"
  read -r -s -p "$(echo -e "${CYAN}?${RESET} $(t pwd_prompt): ")" INPUT_PASSWORD
  echo ""
  local input_hash
  input_hash=$(echo -n "$INPUT_PASSWORD" | sha256sum | cut -d' ' -f1)
  unset INPUT_PASSWORD
  [[ "$input_hash" == "$CORRECT_HASH" ]] || fail "$(t pwd_wrong)"
  ok "$(t pwd_ok)"
}

check_install_dir() {
  [[ -d "$INSTALL_DIR" ]] || fail "$(tf dir_missing "$INSTALL_DIR")"
  [[ -f "$INSTALL_DIR/docker-compose.yml" ]] || fail "$(t compose_missing)"
  [[ -f "$INSTALL_DIR/.env" ]] || fail "$(t env_missing)"
}

pull_updates() {
  section "$(t update_title)"
  cd "$INSTALL_DIR"

  if [[ -d .git ]]; then
    if [[ -f "$DEPLOY_KEY_PATH" ]]; then
      export GIT_SSH_COMMAND="ssh -i ${DEPLOY_KEY_PATH} -o StrictHostKeyChecking=accept-new -o IdentitiesOnly=yes"
    fi
    local old_rev new_rev
    old_rev=$(git rev-parse --short HEAD)
    step "$(t git_pull)"
    git pull --ff-only
    new_rev=$(git rev-parse --short HEAD)
    if [[ "$old_rev" == "$new_rev" ]]; then
      ok "$(tf up_to_date "$new_rev")"
    else
      ok "$(tf updated "$old_rev" "$new_rev")"
    fi
  else
    warn "$(t no_git)"
  fi
}

rebuild_services() {
  section "$(t rebuild_title)"
  cd "$INSTALL_DIR"
  step "$(t compose_build)"
  docker compose up -d --build
  ok "$(t services_ok)"
  docker compose ps
}

show_changelog() {
  section "$(t changelog_title)"
  cd "$INSTALL_DIR"
  if [[ -d .git ]]; then
    echo -e "${DIM}"
    git log --oneline --decorate -15 2>/dev/null || warn "$(t git_log_fail)"
    echo -e "${RESET}"
  else
    warn "$(t no_changelog)"
  fi
}

health_check() {
  section "$(t health_title)"
  cd "$INSTALL_DIR"
  local failed=0
  for svc in db redis bot web nginx; do
    local status
    status=$(docker compose ps --format '{{.Name}} {{.Status}}' 2>/dev/null | grep "$svc" | head -1 || true)
    if echo "$status" | grep -qi "up"; then
      ok "$status"
    else
      warn "$(tf svc_down "$svc")"
      failed=1
    fi
  done
  if [[ $failed -eq 0 ]]; then
    ok "$(t all_ok)"
  else
    warn "$(t check_logs)"
  fi
}

show_final() {
  section "$(t done_title)"
  local sub_url
  sub_url=$(grep SUBSCRIPTION_BASE_URL "$INSTALL_DIR/.env" 2>/dev/null | cut -d= -f2- || echo "https://your-domain")
  echo -e "  🔗 $(t sub_label): ${CYAN}${sub_url}/sub/{token}${RESET}"
  echo -e "  ${DIM}$(t support)${RESET}"
  echo ""
}

main() {
  choose_lang
  banner
  [[ $EUID -eq 0 ]] || fail "$(t need_root)"
  check_password
  check_install_dir
  pull_updates
  rebuild_services
  show_changelog
  health_check
  show_final
}

main "$@"
