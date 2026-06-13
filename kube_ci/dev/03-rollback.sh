#!/bin/bash
# Откат релиза продукта на предыдущую ревизию helm в кластере этого окружения.
# Вызов: ./03-rollback.sh <product> [revision]
#   без revision -- печать helm history релиза + usage (список ревизий);
#   с revision   -- откат релиза на указанную ревизию.

THIS=$(readlink -f "${BASH_SOURCE[0]}")
DIR=$(dirname "${THIS}")
cd "$DIR" || exit 1

source ./productlist
source ../utils/06-rollback.sh
source ./k8s_defs

# Безопасность: rollback требует явного product key (без --all по умолчанию).
if [ $# -eq 0 ]; then
    echo "FATAL: укажите product и опционально revision. Доступно: ${!PRODUCTS[*]}" >&2
    echo "usage: ./03-rollback.sh <product> [revision]" >&2
    exit 1
fi

product=$1
revision=$2

if [ -z "${PRODUCTS[$product]+x}" ]; then
    echo "FATAL: продукт '${product}' не найден в productlist. Доступно: ${!PRODUCTS[*]}" >&2
    exit 1
fi

readonly PRODUCTS_DIR=products

echo "откат продукта ${product}"

pushd "$(readlink -f "$PRODUCTS_DIR/$product")" || exit 1
rollback "${PRODUCTS[$product]}" "$revision"
popd || exit 1
