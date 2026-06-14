#!/bin/bash
# Smoke-проверка опубликованных продуктов в окружении PROD (read-only).
# Вызов: ./04-smoke.sh <product>|--all
#   prod-smoke проверяет фронт / (200), бек /api/v1/version (200) и опц.
#   swagger/docs и /api/v1/items (см. ../utils/07-smoke.sh).
# Возврат ненулевого кода, если хотя бы у одного продукта провалена
# обязательная проверка.

THIS=$(readlink -f "${BASH_SOURCE[0]}")
DIR=$(dirname "${THIS}")
cd "$DIR" || exit 1

source ./productlist
source ../utils/07-smoke.sh
source ./k8s_defs

if [ $# -eq 0 ]; then
    echo "FATAL: укажите product key(s) или --all. Доступно: ${!PRODUCTS[*]}" >&2
    echo "usage: ./04-smoke.sh <product>|--all" >&2
    exit 1
fi

readonly PRODUCTS_DIR=products

rc=0
matched=0
for product in "${!PRODUCTS[@]}"
do
    if [[ " ${*} " =~ " ${product} " || " ${*} " =~ " --all " ]]; then
        pushd "$(readlink -f "$PRODUCTS_DIR/$product")" >/dev/null || continue
        smoke "${PRODUCTS[$product]}" || rc=1
        popd >/dev/null || exit 1
        matched=1
    fi
done

if [ "$matched" = "0" ]; then
    echo "FATAL: ни один продукт не совпал с: $* . Доступно: ${!PRODUCTS[*]}" >&2
    exit 1
fi

exit "$rc"
