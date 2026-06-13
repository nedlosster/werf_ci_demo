#!/bin/bash
# Шифрует plaintext values.yaml -> ../secrets-<env>.yaml (werf helm secret).
# Использование: ./encrypt.sh [env]   (default: dev; допустимо dev|prod)
# Ключ: WERF_SECRET_KEY | .werf_secret_key | ~/.werf/global_secret_key.
set -euo pipefail
ENV="${1:-dev}"
DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$DIR/../.."

if [[ ! -f "$DIR/values.yaml" ]]; then
    echo "Файл $DIR/values.yaml не найден."
    echo "Создайте из шаблона: cp $DIR/../secret-values.yaml.example $DIR/values.yaml"
    exit 1
fi

source "$(~/bin/trdl use werf 2 stable)"
werf helm secret values encrypt "$DIR/values.yaml" \
    -o "$DIR/../secrets-${ENV}.yaml" \
    --dir "$PROJECT_DIR"

echo "Зашифровано: .helm/secrets-${ENV}.yaml"
