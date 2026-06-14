#!/bin/bash
# Smoke-проверка опубликованного продукта по HTTP. Read-only: ничего не
# деплоит и не меняет в кластере, только curl по CI_URL и (для dev) чтение
# статуса подов через kubectl.
#
# Имя релиза/неймспейса -- как у converge: NAMESPACE по умолчанию == APPNAME,
# kube-namespace == <NAMESPACE>-<ENVNAME> (см. 03-werf-converge.sh). CI_URL --
# host ingress продукта из .helm/def.sh.
#
# Набор проверок зависит от ENVNAME:
#   dev  -- формы backend/frontend в dev являются sandbox-подами (ENTRYPOINT
#           sleep infinity), приложение поднимается разработчиком вручную, до
#           этого app-URL отдаёт 502. Поэтому dev-smoke проверяет только
#           инфраструктурную часть: pgAdmin (/pgadmin/ -> 200/302) и факт
#           Running подов продукта (kubectl get pods, read-only).
#   prod -- полноценные сервисы: фронт / -> 200, бек /api/v1/version -> 200,
#           swagger/docs -> 200, опц. /api/v1/items -> 200.
#
# Возврат: 0 -- все обязательные проверки прошли; 1 -- хотя бы одна обязательная
# провалена. Опциональные проверки (OPT) на код возврата не влияют.
#
# Работает как библиотека (source) и как самостоятельный скрипт.

# Один HTTP-пробинг. Печатает строку таблицы, выставляет глобальные счётчики.
# Аргументы: <метка> <url> <ожидаемые-коды-через-|> <режим req|opt>
_smoke_probe()
{
	local label="$1" url="$2" expect="$3" mode="${4:-req}"
	local code verdict

	code=$(curl -ks -o /dev/null -w '%{http_code}' --max-time 15 "$url" 2>/dev/null)
	[ -z "$code" ] && code="000"

	if [[ "|$expect|" == *"|$code|"* ]]; then
		verdict="OK"
	else
		verdict="FAIL"
		if [ "$mode" = "opt" ]; then
			verdict="WARN"
		else
			SMOKE_FAILED=$((SMOKE_FAILED + 1))
		fi
	fi

	printf '  %-4s %-22s %-5s ожид=%-11s %s\n' "$mode" "$label" "$code" "$expect" "$verdict"
}

function smoke()
{
	source .helm/def.sh

	local env="$1"
	$env

	[ -z "$NAMESPACE" ] && NAMESPACE=$APPNAME
	local kube_namespace="${NAMESPACE}-${ENVNAME}"
	local base="http://${CI_URL}"

	SMOKE_FAILED=0

	echo "smoke ${APPNAME} (${ENVNAME}), host ${CI_URL}, ns ${kube_namespace}"
	echo "  режим  проверка               код   ожидание    вердикт"

	if [ "$ENVNAME" = "dev" ]; then
		# dev: только инфраструктура (см. шапку файла).
		_smoke_probe "pgadmin /pgadmin/" "${base}/pgadmin/" "200|302" req

		echo "  поды продукта в ${kube_namespace} (read-only):"
		if command -v kubectl >/dev/null 2>&1; then
			local running total
			running=$(kubectl get pods -n "$kube_namespace" \
				--field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
			total=$(kubectl get pods -n "$kube_namespace" --no-headers 2>/dev/null | wc -l)
			kubectl get pods -n "$kube_namespace" 2>/dev/null | sed 's/^/    /'
			echo "    Running: ${running}/${total}"
			if [ "$total" -eq 0 ] || [ "$running" -lt "$total" ]; then
				echo "    FAIL: не все поды в Running"
				SMOKE_FAILED=$((SMOKE_FAILED + 1))
			fi
		else
			echo "    WARN: kubectl недоступен -- проверка подов пропущена"
		fi
	else
		# prod: полноценные сервисы. swagger у продуктов на разных путях
		# (app1 spring -- /api/swagger-ui/index.html, app2 fastapi -- /api/docs),
		# поэтому обе пробы опциональные: проходит та, что соответствует стеку.
		_smoke_probe "frontend /"      "${base}/"                          "200" req
		_smoke_probe "backend version" "${base}/api/v1/version"            "200" req
		_smoke_probe "docs (fastapi)"  "${base}/api/docs"                  "200" opt
		_smoke_probe "swagger (spring)" "${base}/api/swagger-ui/index.html" "200" opt
		_smoke_probe "backend items"   "${base}/api/v1/items"              "200" opt
	fi

	if [ "$SMOKE_FAILED" -eq 0 ]; then
		echo "  итог: OK (обязательные проверки пройдены)"
		return 0
	fi
	echo "  итог: FAIL (${SMOKE_FAILED} обязательных проверок провалено)"
	return 1
}

[[ "${#BASH_SOURCE[@]}" -gt "1" ]] && { return 0; }

smoke "$@"
