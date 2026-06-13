#!/bin/bash
# Откат: werf dismiss неймспейса продукта в кластере этого окружения.

THIS=$(readlink -f "${BASH_SOURCE[0]}")
DIR=$(dirname "${THIS}")
cd "$DIR" || exit 1

source ./productlist
source ../utils/04-dissmiss.sh
source ./k8s_defs

# Безопасность: dismiss требует явного product key(s) или --all. Без аргумента
# скрипт снял бы ВСЕ продукты из productlist разом.
if [ $# -eq 0 ]; then
    echo "FATAL: укажите product key(s) или --all. Доступно: ${!PRODUCTS[*]}" >&2
    exit 1
fi

echo "откат продуктов"

readonly PRODUCTS_DIR=products

matched=0
for product in "${!PRODUCTS[@]}"
do
    if [[ " ${*} " =~ " ${product} " || " ${*} " =~ " --all " ]]; then
        pushd "$PRODUCTS_DIR/$product" || continue
        dissmiss "${PRODUCTS[$product]}"
        popd || exit 1
        matched=1
    else
        echo "пропущен продукт ${product}"
    fi
done

if [ "$matched" = "0" ]; then
    echo "FATAL: ни один продукт не совпал с: $* . Доступно: ${!PRODUCTS[*]}" >&2
    exit 1
fi
