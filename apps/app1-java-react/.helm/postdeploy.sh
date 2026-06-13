#!/bin/bash
# Хук после деплоя (вызывается kube_ci/utils/03-werf-converge.sh).
# Печатает URL развёрнутых ресурсов. CI_URL/ENVNAME экспортированы converge.
env="${1:-$ENVNAME}"

# Чистка ssh-ключа, положенного predeploy.sh (не оставлять на диске).
_DIR=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
rm -f "$_DIR"/tmp/id_rsa-vcs "$_DIR"/tmp/id_rsa-vcs.pub 2>/dev/null || true

echo "=================================================================="
echo "Развёрнутые ресурсы app1-java-react (${ENVNAME}):"
echo "  Фронт:   http://${CI_URL}/"
echo "  Бек:     http://${CI_URL}/api/v1/hello"
echo "  Swagger: http://${CI_URL}/api/swagger-ui.html"
case "$ENVNAME" in
    dev) echo "  pgAdmin: http://${CI_URL}/pgadmin" ;;
esac
echo "=================================================================="
