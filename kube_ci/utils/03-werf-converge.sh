#!/bin/bash
# Публикация продукта: werf converge (сборка образов + деплой релиза) в
# уже развёрнутый кластер. deploy() читает контракт .helm/def.sh продукта.
# Работает как библиотека (source) и как самостоятельный скрипт.

function deploy()
{
  source "$(~/bin/trdl use werf 2 stable)"
  source .helm/def.sh

  env=$1 && $env
  [ -z "$NAMESPACE" ] && NAMESPACE=$APPNAME

  export WERF_REPO="$REGISTRY/$APPNAME"

  if [[ ${NAMESPACE} ]]; then KUBE_NAMESPACE=${NAMESPACE}-${ENVNAME}; fi

  if [ -e ".helm/values-$ENVNAME.yaml" ]; then
    values_param="--values=.helm/values-$ENVNAME.yaml"
  fi

  if [ -e ".helm/secrets-$ENVNAME.yaml" ]; then
    secret_values_param="--secret-values=.helm/secrets-$ENVNAME.yaml"
  fi

  # Переменные CI_* из env-функции def.sh пробрасываются в helm через --set
  # (в нижнем регистре). CI_TAG исключён: строка с $(python3 ...) ломает sed.
  def_content=$(set | awk "/^${env} \(\)/,/\}/")
  ci_values=$(echo "$def_content" | awk '/export CI_/ && !/CI_TAG/ {gsub("export ", ""); print}' | sed 's/\(.*\)=\(.*\)/--set \L\1\E=\2/' | tr -d ';')

  # version-based тег образов (из def.sh через CI_TAG)
  [ -n "$CI_TAG" ] && custom_tag_param="--use-custom-tag=%image%-$CI_TAG"

  werf converge \
    --dev \
    --env="$ENVNAME" \
    --synchronization :local \
    --insecure-registry=true \
    --skip-tls-verify-registry=true \
    --atomic="${WERF_ATOMIC_FLAG:-true}" \
    --timeout=300 \
    --namespace="$KUBE_NAMESPACE" \
    ${values_param} \
    ${secret_values_param} \
    ${custom_tag_param} \
    --loose-giterminism=true $ci_values \
    --set APPNAME="$APPNAME" \
    --set DOMAIN="$DOMAIN" \
    --set use_ngnix_virtualserver="$USE_NGNIX_VIRTUALSERVER"

  # Печать URL развёрнутых ресурсов -- в .helm/postdeploy.sh продукта
  # (фронт/бек/swagger/pgAdmin, по образцу calligrapher).
  [ -f .helm/postdeploy.sh ] && ./.helm/postdeploy.sh "$env"

  kubectl config set-context --current --namespace="$NAMESPACE-$ENVNAME"
}

[[ "${#BASH_SOURCE[@]}" -gt "1" ]] && { return 0; }

deploy
