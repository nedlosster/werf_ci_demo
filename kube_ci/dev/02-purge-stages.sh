#!/bin/bash
# Очистка: сброс локального кеша сборки werf (stages) по всем продуктам.

THIS=$(readlink -f "${BASH_SOURCE[0]}")
DIR=$(dirname "${THIS}")
cd "$DIR" || exit 1

source ./productlist
source ../utils/05-purge-stages-local.sh

mkdir -p products && cd products || exit 1

echo "очистка stages по продуктам"

for product in "${!PRODUCTS[@]}"
do
    [ -d "$product" ] && ( cd "$product" && purge_stages_local "${PRODUCTS[$product]}" )
done
