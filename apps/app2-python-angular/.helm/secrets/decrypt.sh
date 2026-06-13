#!/bin/bash
# Расшифровывает ../secrets-<env>.yaml -> values.yaml (для редактирования).
# Использование: ./decrypt.sh [env]   (default: dev)
# Ключ: WERF_SECRET_KEY | .werf_secret_key | ~/.werf/global_secret_key.
set -euo pipefail
ENV="${1:-dev}"
DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$DIR/../.."
ENCRYPTED="$DIR/../secrets-${ENV}.yaml"

if [[ ! -f "$ENCRYPTED" ]]; then
    echo "Файл $ENCRYPTED не найден. Создайте из шаблона и зашифруйте (encrypt.sh)."
    exit 1
fi

source "$(~/bin/trdl use werf 2 stable)"
werf helm secret values decrypt "$ENCRYPTED" --dir "$PROJECT_DIR" | tee "$DIR/values.yaml"

echo ""
echo "Расшифровано: .helm/secrets/values.yaml (plaintext, в .gitignore)."
echo "Отредактируйте и зашифруйте обратно: ./encrypt.sh ${ENV}"
