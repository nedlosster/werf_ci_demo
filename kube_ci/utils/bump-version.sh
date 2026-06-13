#!/bin/bash
# Бамп/установка единой версии продукта(ов). Обёртка над
# apps/<product>/scripts/set-version.sh (синхронизирует все файлы версии).
# Использование:
#   ./bump-version.sh <app1-java-react|app2-python-angular|all> [bump|X.Y.Z]
#   (по умолчанию -- bump: инкремент patch)
set -euo pipefail

THIS=$(readlink -f "${BASH_SOURCE[0]}")
DIR=$(dirname "$THIS")
APPS=$(readlink -f "$DIR/../../apps")

target="${1:?укажите продукт (app1-java-react | app2-python-angular | all)}"
ver="${2:-bump}"

run_one() {
    local p="$1"
    echo "== $p =="
    ( cd "$APPS/$p" && ./scripts/set-version.sh "$ver" )
}

case "$target" in
    all)
        run_one app1-java-react
        run_one app2-python-angular
        ;;
    app1-java-react|app2-python-angular)
        run_one "$target"
        ;;
    *)
        echo "неизвестный продукт: $target" >&2
        exit 1
        ;;
esac
