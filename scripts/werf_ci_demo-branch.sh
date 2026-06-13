#!/usr/bin/env bash
# Управление feature-ветками werf_ci_demo поверх git worktree.
#
# Упрощённый аналог cmdb-branch.sh: создание worktree от свежего main +
# симлинки на git-ignored файлы (CLAUDE.md, .claude) и пост-merge teardown.
# Без editable-install и KVM-чистки -- это демо-репозиторий.
#
# Использование:
#   ./scripts/werf_ci_demo-branch.sh new <тип/название>
#   ./scripts/werf_ci_demo-branch.sh cleanup <тип/название> [--keep-remote]
#   ./scripts/werf_ci_demo-branch.sh list
#
# Merge в main скрипт НЕ выполняет -- это точка остановки (требует разрешения
# Архитектора). После `gh pr merge --squash` запускать `cleanup`.
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'
ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
fail() { echo -e "${RED}[ERR]${NC} $1"; exit 1; }
info() { echo -e "${BLUE}[..]${NC} $1"; }

# Корень основного репозитория (работает и изнутри worktree).
MAIN_ROOT="$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")"

VALID_RE='^(feature|fix|docs|refactor|test)/[a-z0-9][a-z0-9-]*$'

usage() {
    cat <<'EOF'
Управление feature-ветками werf_ci_demo (git worktree)

Использование:
  ./scripts/werf_ci_demo-branch.sh new <тип/название>
      Создать worktree из свежего main: ветка + симлинки CLAUDE.md и .claude.

  ./scripts/werf_ci_demo-branch.sh cleanup <тип/название> [--keep-remote]
      Пост-merge teardown: удалить worktree и локальную ветку, удалить ветку
      на origin, prune, подтянуть main. Merge сам по себе НЕ делает.
        --keep-remote  не удалять ветку на origin

  ./scripts/werf_ci_demo-branch.sh list
      Список worktree.

Тип ветки: feature | fix | docs | refactor | test
Пример: ./scripts/werf_ci_demo-branch.sh new feature/cmdb-web-helm
EOF
}

cmd_new() {
    local branch="${1:-}"
    [[ -n "$branch" ]] || fail "не указан тип/название ветки (пример: feature/cmdb-web-helm)"
    [[ "$branch" =~ $VALID_RE ]] || \
        fail "имя '$branch' не по конвенции: <feature|fix|docs|refactor|test>/<латиница-через-дефис>"

    local wt_dir="$MAIN_ROOT/.worktrees/$branch"

    git -C "$MAIN_ROOT" show-ref --quiet --verify "refs/heads/$branch" && \
        fail "ветка '$branch' уже существует"
    [[ -e "$wt_dir" ]] && fail "каталог worktree уже существует: $wt_dir"

    info "обновляю main в основном репозитории"
    git -C "$MAIN_ROOT" pull --ff-only origin main || \
        warn "git pull --ff-only origin main не прошёл -- worktree из локального main"

    info "создаю worktree: $wt_dir"
    git -C "$MAIN_ROOT" worktree add "$wt_dir" -b "$branch" main
    ok "ветка '$branch' создана, worktree: $wt_dir"

    ln -sfn "$MAIN_ROOT/CLAUDE.md" "$wt_dir/CLAUDE.md"
    ln -sfn "$MAIN_ROOT/.claude"   "$wt_dir/.claude"
    ok "симлинки CLAUDE.md и .claude -> основной репозиторий"

    echo
    echo -e "${BOLD}Ветка готова.${NC}"
    echo "  Ветка:              $branch"
    echo "  Рабочая директория: $wt_dir"
    echo "  Перейти:  cd $wt_dir"
}

cmd_cleanup() {
    local branch="" keep_remote=0
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --keep-remote) keep_remote=1 ;;
            -*)            fail "неизвестный флаг: $1" ;;
            *)             [[ -z "$branch" ]] && branch="$1" || fail "лишний аргумент: $1" ;;
        esac
        shift
    done
    [[ -n "$branch" ]] || fail "не указан тип/название ветки для cleanup"

    local wt_dir="$MAIN_ROOT/.worktrees/$branch"

    # Уйти из worktree в основной репо ДО удаления, иначе CWD исчезнет.
    cd "$MAIN_ROOT"

    if git -C "$MAIN_ROOT" worktree list --porcelain | grep -qF "worktree $wt_dir"; then
        info "удаляю worktree: $wt_dir"
        git -C "$MAIN_ROOT" worktree remove --force "$wt_dir" && ok "worktree удалён"
    else
        warn "worktree не зарегистрирован: $wt_dir -- пропускаю"
    fi
    git -C "$MAIN_ROOT" worktree prune

    if git -C "$MAIN_ROOT" show-ref --quiet --verify "refs/heads/$branch"; then
        git -C "$MAIN_ROOT" branch -D "$branch" && ok "локальная ветка '$branch' удалена"
    else
        warn "локальной ветки '$branch' нет -- пропускаю"
    fi

    if [[ "$keep_remote" -eq 0 ]]; then
        info "удаляю ветку на origin"
        git -C "$MAIN_ROOT" push origin --delete "$branch" 2>/dev/null \
            && ok "ветка '$branch' удалена на origin" \
            || warn "ветка '$branch' на origin не найдена/уже удалена"
    fi

    git -C "$MAIN_ROOT" remote prune origin >/dev/null 2>&1 || true

    info "подтягиваю main"
    git -C "$MAIN_ROOT" pull --ff-only origin main || warn "git pull --ff-only origin main не прошёл"

    echo
    echo -e "${BOLD}Cleanup завершён.${NC} Ветка '$branch' удалена, основной репо на main."
}

cmd_list() {
    echo -e "${BOLD}Worktree:${NC}"
    git -C "$MAIN_ROOT" worktree list
}

case "${1:-}" in
    new)      shift; cmd_new "$@" ;;
    cleanup)  shift; cmd_cleanup "$@" ;;
    list)     shift; cmd_list "$@" ;;
    -h|--help|help|"") usage ;;
    *) fail "неизвестная команда: $1 (см. --help)" ;;
esac
