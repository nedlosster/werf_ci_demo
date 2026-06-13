#!/bin/bash
# Очистка: сброс локального кеша сборки werf (stages) для продукта.

function purge_stages_local()
{
	source "$(~/bin/trdl use werf 2 stable)"
	source .helm/def.sh
	env=$1
	$env
	werf stages purge --force --stages-storage=:local
}

[[ "${#BASH_SOURCE[@]}" -gt "1" ]] && { return 0; }

purge_stages_local
