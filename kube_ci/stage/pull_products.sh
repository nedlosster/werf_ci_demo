#!/bin/bash
# Подготовка продуктов: связать apps/<product> -> products/<product>.
# В демо исходники продуктов лежат локально в репозитории (../../apps),
# поэтому вместо клонирования из git создаются symlinks.

THIS=$(readlink -f "${BASH_SOURCE[0]}")
DIR=$(dirname "${THIS}")
cd "$DIR" || exit 1

readonly APPS_DIR=$(readlink -f ../../apps)
readonly PRODUCTS_DIR=products

if [ ! -f ./productlist ]; then
    echo "файл ./productlist не найден, копируем из ./productlist_official"
    cp productlist_official productlist
fi

source ./productlist

mkdir -p "$PRODUCTS_DIR"

for product in "${!PRODUCTS[@]}"
do
    src="$APPS_DIR/$product"
    link="$PRODUCTS_DIR/$product"
    if [ ! -d "$src" ]; then
        echo "пропуск: каталог продукта не найден -- $src"
        continue
    fi
    [ -L "$link" ] && rm "$link"
    ln -s "$src" "$link"
    echo "связан продукт: $link -> $src"
done
