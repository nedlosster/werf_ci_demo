#!/bin/bash
# Дашборд кластера окружения dev. Берёт KUBECONTEXT из ./k8s_defs и вызывает
# общий ../utils/dashboard.sh (port-forward к headlamp).
# Использование: ./dashboard.sh [local-port]
set -euo pipefail

THIS=$(readlink -f "${BASH_SOURCE[0]}")
DIR=$(dirname "$THIS")
cd "$DIR"

source ./k8s_defs
export KUBECONTEXT KUBECONFIG

exec ../utils/dashboard.sh "$@"
