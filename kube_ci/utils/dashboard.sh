#!/bin/bash
# Доступ к дашборду кластера (headlamp) через kubectl port-forward.
# Использование: ./dashboard.sh [local-port]   (default 8088)
# Контекст -- из KUBECONTEXT (default -- k8s_alt_paas).
set -euo pipefail

KUBECONTEXT="${KUBECONTEXT:-k8sadmin-k8s-alt-paas@service-k8s-alt-paas}"
PORT="${1:-8088}"
NS="${HEADLAMP_NS:-headlamp}"
SVC="${HEADLAMP_SVC:-headlamp}"

echo "Дашборд headlamp: http://localhost:${PORT}"
echo "Контекст: ${KUBECONTEXT}"
echo "Токен для входа (если требуется) -- создать на SA с правами:"
echo "  kubectl --context ${KUBECONTEXT} -n ${NS} create token <serviceaccount>"
echo "port-forward... (Ctrl-C для выхода)"

exec kubectl --context "$KUBECONTEXT" -n "$NS" port-forward "svc/${SVC}" "${PORT}:80"
