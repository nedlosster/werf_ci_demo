#!/bin/bash
# Публикация: werf converge продуктов из productlist в кластер этого окружения.
# Без аргументов или с --all -- все продукты; иначе только перечисленные.

THIS=$(readlink -f "${BASH_SOURCE[0]}")
DIR=$(dirname "${THIS}")
cd "$DIR" || exit 1

source ../utils/03-werf-converge.sh
source productlist
source k8s_defs

readonly PRODUCTS_DIR=products

export REGISTRY KUBECONTEXT KUBECONFIG

for product in "${!PRODUCTS[@]}"
do
    if [[ " ${*} " =~ " ${product} " || " ${*} " =~ " --all " || $# = 0 ]]; then
        pushd "$PRODUCTS_DIR/$product" && deploy "${PRODUCTS[$product]}" && popd
    else
        echo "пропущен продукт ${product}"
    fi
done
