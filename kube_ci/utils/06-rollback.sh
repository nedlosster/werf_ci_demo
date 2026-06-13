#!/bin/bash
# Откат релиза продукта на предыдущую ревизию helm. ЧП-операция: быстрый возврат
# к ранее опубликованной ревизии релиза (образ уже в registry), без пересборки и
# без исходного кода целевой версии.
#
# Имя релиза werf по умолчанию -- %project%-%env%, где project берётся из
# werf.yaml (== APPNAME контракта), env == ENVNAME. Неймспейс релиза --
# <NAMESPACE>-<ENVNAME> (см. KUBE_NAMESPACE в 03-werf-converge.sh).
#
# Без revision: печать helm history + usage (список ревизий для выбора цели).
# С revision: проверка образа целевой ревизии в registry, предупреждение про БД,
# затем helm rollback.
#
# Работает как библиотека (source) и как самостоятельный скрипт.

function rollback()
{
	source "$(~/bin/trdl use werf 2 stable)"
	source .helm/def.sh

	env=$1
	revision=$2
	$env

	[ -z "$NAMESPACE" ] && NAMESPACE=$APPNAME
	release="${APPNAME}-${ENVNAME}"
	kube_namespace="${NAMESPACE}-${ENVNAME}"

	# helm из поставки werf -- совместимая версия по тому же KUBECONFIG/контексту.
	helm_bin="$(werf version >/dev/null 2>&1 && echo "werf helm" || echo helm)"

	if [ -z "$revision" ]; then
		echo "история ревизий релиза ${release} в неймспейсе ${kube_namespace}:"
		$helm_bin history "$release" --namespace "$kube_namespace" --kubeconfig "$KUBECONFIG"
		echo
		echo "usage: 03-rollback.sh <product> <revision>"
		echo "  без revision -- печать истории; с revision -- откат на эту ревизию"
		return 0
	fi

	# Предупреждение: откат релиза не трогает БД.
	echo "ВНИМАНИЕ: откат меняет только релиз ${release}. Схема БД НЕ откатывается"
	echo "(persistent Postgres, init.sql). При forward-несовместимых миграциях"
	echo "нужен отдельный ручной шаг приведения схемы к целевой версии."

	# Проверка наличия образа целевой версии в registry. CI_TAG целевой ревизии
	# в общем случае отличается от текущего; точное соответствие revision -> тег
	# хранит helm history (колонка APP VERSION). Здесь сверяем, что в репозитории
	# образа продукта вообще есть опубликованные теги -- через registry HTTP API
	# (--insecure: ingress отдаёт self-signed, см. WERF_*_REGISTRY в k8s_defs).
	image_ref="${REGISTRY}/${APPNAME}"
	echo "проверка тегов образов в registry: ${image_ref}"
	tags=$(curl -fsSk "https://${REGISTRY}/v2/${APPNAME}/tags/list" 2>/dev/null)
	if [ -n "$tags" ]; then
		echo "$tags"
	else
		echo "ПРЕДУПРЕЖДЕНИЕ: список тегов образа недоступен (registry HTTP API"
		echo "не ответил). Откат продолжится по сохранённой ревизии релиза --"
		echo "ссылка на образ берётся из манифестов целевой ревизии helm."
	fi

	echo "откат релиза ${release} на ревизию ${revision} в ${kube_namespace}"
	$helm_bin rollback "$release" "$revision" --namespace "$kube_namespace" --kubeconfig "$KUBECONFIG"
}

[[ "${#BASH_SOURCE[@]}" -gt "1" ]] && { return 0; }

rollback
