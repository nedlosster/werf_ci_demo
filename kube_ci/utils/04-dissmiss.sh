#!/bin/bash
# Откат: werf dismiss неймспейса продукта.

function dissmiss()
{
	source "$(~/bin/trdl use werf 2 stable)"
	source .helm/def.sh
	env=$1
	$env
	werf dismiss --kube-config "$KUBECONFIG" --env "$env" --with-namespace --loose-giterminism true
}

[[ "${#BASH_SOURCE[@]}" -gt "1" ]] && { return 0; }

dissmiss
