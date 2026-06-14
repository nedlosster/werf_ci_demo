#!/bin/bash
# Очистка: сброс локального кеша сборки werf (stages) для продукта.

function purge_stages_local()
{
	source "$(~/bin/trdl use werf 2 stable)"
	source .helm/def.sh
	env=$1
	$env
	# werf v2: команды `stages purge` нет; локальный кеш сборки чистится
	# `host purge` по имени проекта. project-name == APPNAME из .helm/def.sh
	# (совпадает с `project:` в werf.yaml).
	werf host purge --force --project-name "$APPNAME"
}

[[ "${#BASH_SOURCE[@]}" -gt "1" ]] && { return 0; }

purge_stages_local
