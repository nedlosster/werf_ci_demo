#!/bin/bash
# Доступ к дашборду кластера (headlamp) через kubectl port-forward.
# Печатает токен для входа в headlamp и поднимает port-forward.
# Использование: ./dashboard.sh [local-port]   (default 8088)
# Контекст -- из KUBECONTEXT (env-обёртки берут его из k8s_defs).
set -euo pipefail

KUBECONTEXT="${KUBECONTEXT:-k8sadmin-k8s-public-paas@service-k8s-public-paas}"
PORT="${1:-8088}"
NS="${HEADLAMP_NS:-headlamp}"
SVC="${HEADLAMP_SVC:-headlamp}"
SECRET="${HEADLAMP_SECRET:-headlamp-admin}"
SA="${HEADLAMP_SA:-headlamp-admin}"

kc() { kubectl --context "$KUBECONTEXT" "$@"; }

# Токен для входа: сперва из постоянного Secret service-account-token
# (как в paasfabric), иначе -- эфемерный через TokenRequest (kubectl create token).
TOKEN="$(kc -n "$NS" get secret "$SECRET" -o jsonpath='{.data.token}' 2>/dev/null | base64 -d 2>/dev/null || true)"
if [ -z "$TOKEN" ]; then
    TOKEN="$(kc -n "$NS" create token "$SA" --duration=24h 2>/dev/null || true)"
fi

echo "Дашборд headlamp: http://localhost:${PORT}"
echo "Контекст: ${KUBECONTEXT}"
if [ -n "$TOKEN" ]; then
    echo "Токен для входа (headlamp -> Token):"
    echo "$TOKEN"
else
    echo "Токен не получен: нет Secret ${NS}/${SECRET} и не удалось create token на SA ${NS}/${SA}."
    echo "Создать SA с правами и токен вручную:"
    echo "  kubectl --context ${KUBECONTEXT} -n ${NS} create token <serviceaccount>"
fi
echo "port-forward... (Ctrl-C для выхода)"

exec kubectl --context "$KUBECONTEXT" -n "$NS" port-forward "svc/${SVC}" "${PORT}:80"
