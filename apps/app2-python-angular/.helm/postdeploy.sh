#!/bin/bash
# Хук после деплоя (вызывается kube_ci/utils/03-werf-converge.sh).
# Печатает URL развёрнутых ресурсов. CI_URL/ENVNAME экспортированы converge.
env="${1:-$ENVNAME}"

echo "=================================================================="
echo "Развёрнутые ресурсы app2-python-angular (${ENVNAME}):"
echo "  Фронт:   http://${CI_URL}/"
echo "  Бек:     http://${CI_URL}/api/v1/hello"
echo "  Swagger: http://${CI_URL}/api/docs"
case "$ENVNAME" in
    dev) echo "  pgAdmin: http://${CI_URL}/pgadmin" ;;
esac
echo "=================================================================="
