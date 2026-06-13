#!/bin/bash
# Хук перед деплоем (по образцу calligrapher). Для dev кладёт github-ssh-ключ
# оператора в .helm/tmp/id_rsa-vcs -> Secret id-rsa-vcs -> dev-под клонирует
# монорепо с github. Файл в .gitignore, подчищается postdeploy.sh.
# Для не-dev окружений ничего не делает.
set -e
env="${1:-}"
THIS=$(readlink -f "${BASH_SOURCE[0]}")
DIR=$(dirname "$THIS")
cd "$DIR"

[ "$env" = "dev" ] || exit 0

mkdir -p tmp
if [ -f ~/.ssh/id_rsa ]; then
    cp -f ~/.ssh/id_rsa tmp/id_rsa-vcs
    [ -f ~/.ssh/id_rsa.pub ] && cp -f ~/.ssh/id_rsa.pub tmp/id_rsa-vcs.pub
    echo "predeploy: github-ssh-ключ -> .helm/tmp/id_rsa-vcs"
else
    : > tmp/id_rsa-vcs
    echo "predeploy: ~/.ssh/id_rsa не найден -- Secret будет пустым, clone в dev-поде делать вручную"
fi
