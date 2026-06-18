#!/bin/bash
# Хук после деплоя (вызывается kube_ci/utils/03-werf-converge.sh).
# Печатает URL развёрнутых ресурсов. CI_URL/ENVNAME экспортированы converge.
env="${1:-$ENVNAME}"

# Чистка ssh-ключа, положенного predeploy.sh (не оставлять на диске).
_DIR=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
rm -f "$_DIR"/tmp/id_rsa-vcs "$_DIR"/tmp/id_rsa-vcs.pub 2>/dev/null || true

# Чтение значения <ключ> из блока <блок> values-файла (env-оверрайд -> база).
_yval() { awk -v b="$1:" -v k="$2:" '$1==b{f=1;next} /^[^[:space:]]/{f=0} f&&$1==k{print $2;exit}' "$3" 2>/dev/null; }
_get()  { local v; v=$(_yval "$1" "$2" "$_DIR/values-${ENVNAME}.yaml"); [ -z "$v" ] && v=$(_yval "$1" "$2" "$_DIR/values.yaml"); printf '%s' "$v"; }

PG_USER=$(_get postgres user);     PG_DB=$(_get postgres database)
PG_PASS=$(_get postgres password); PG_PORT=$(_get postgres port)

echo "=================================================================="
echo "Развёрнутые ресурсы app2-python-angular (${ENVNAME}):"
echo "  Фронт:   http://${CI_URL}/"
echo "  Бек:     http://${CI_URL}/api/v1/hello"
echo "  Swagger: http://${CI_URL}/api/docs"
case "$ENVNAME" in
    dev)
        echo "  pgAdmin: http://${CI_URL}/pgadmin"
        echo "    логин:  $(_get pgadmin email | grep . || echo admin@example.com)"
        echo "    пароль: $(_get pgadmin password | grep . || echo admin)"
        ;;
esac
echo "  PostgreSQL (в кластере): app2-python-angular-postgres:${PG_PORT:-5432}"
echo "    база:   ${PG_DB:-app2}"
echo "    user:   ${PG_USER:-app2}"
echo "    пароль: ${PG_PASS:-app2pass}"
echo "=================================================================="
