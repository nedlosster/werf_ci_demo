#!/bin/bash
# Разработка внутри кластера: shell в dev-под или запуск dev-сервера приложения.
# dev-поды (sleep infinity) держат исходники в /workspace (PVC) + кеши/vscode.
# Использование:
#   ./dev-run.sh <app1-java-react|app2-python-angular> <backend|frontend> [shell|run]
#   shell (default) -- интерактивный bash в поде; run -- запустить dev-сервер.
# Контекст -- из KUBECONTEXT (default k8s_alt_paas).
set -euo pipefail

KUBECONTEXT="${KUBECONTEXT:-k8sadmin-k8s-alt-paas@service-k8s-alt-paas}"
product="${1:?продукт: app1-java-react | app2-python-angular}"
comp="${2:?компонент: backend | frontend}"
mode="${3:-shell}"

ns="${product}-dev"
pod="${product}-${comp}-dev-0"
ws="/workspace/werf_ci_demo/apps/${product}/${comp}"

case "$product/$comp" in
    app1-java-react/backend)      run="cd '$ws' && mvn spring-boot:run" ;;
    app1-java-react/frontend)     run="cd '$ws' && pnpm install && pnpm dev --host" ;;
    app2-python-angular/backend)  run="cd '$ws' && pip install -e . && uvicorn app2.main:app --host 0.0.0.0 --port 8080 --reload" ;;
    app2-python-angular/frontend) run="cd '$ws' && npm install && npx ng serve --host 0.0.0.0" ;;
    *) echo "неизвестная пара: $product/$comp" >&2; exit 1 ;;
esac

if [ "$mode" = "run" ]; then
    echo "Запуск dev-сервера в $ns/$pod: $run"
    exec kubectl --context "$KUBECONTEXT" -n "$ns" exec -it "$pod" -- bash -lc "$run"
else
    echo "Shell в $ns/$pod. Рабочая копия: $ws"
    echo "Команда запуска dev-сервера: $run"
    echo "(если /workspace пуст -- склонируйте монорепо вручную, см. docs/dev-in-cluster.md)"
    exec kubectl --context "$KUBECONTEXT" -n "$ns" exec -it "$pod" -- bash
fi
