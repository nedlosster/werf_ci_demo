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

  # Хук перед деплоем (например, инъекция ssh-ключа в .helm/tmp/ для dev-clone).
  # Должен отработать ДО werf converge -- werf читает tmp/ при рендере секрета.
  [ -f .helm/predeploy.sh ] && ./.helm/predeploy.sh "$env"

  export WERF_REPO="$REGISTRY/$APPNAME"

  if [[ ${NAMESPACE} ]]; then KUBE_NAMESPACE=${NAMESPACE}-${ENVNAME}; fi

  if [ -e ".helm/values-$ENVNAME.yaml" ]; then
    values_param="--values=.helm/values-$ENVNAME.yaml"
  fi

  if [ -e ".helm/secrets-$ENVNAME.yaml" ]; then
    secret_values_param="--secret-values=.helm/secrets-$ENVNAME.yaml"
  fi

  # Переменные CI_* из контракта .helm/def.sh пробрасываются в helm через --set
  # (имя в нижнем регистре). Перебор -- по именам реально экспортированных
  # CI_*-переменных (${!CI_@}), значение берётся косвенно (${!v}) -- безопасно
  # к спецсимволам, кавычкам и пробелам, без разбора текста env-функции.
  # CI_TAG исключён: он пробрасывается отдельно через --use-custom-tag (ниже).
  ci_set_args=()
  for v in ${!CI_@}; do
    [ "$v" = "CI_TAG" ] && continue
    ci_set_args+=(--set "${v,,}=${!v}")
  done

  # version-based тег образов (из def.sh через CI_TAG)
  custom_tag_args=()
  [ -n "$CI_TAG" ] && custom_tag_args=(--use-custom-tag="%image%-$CI_TAG")

  # git-identity машины деплоя -> в dev-поды (init-dev-env проставит в /workspace).
  # Берётся из git config деплой-машины, не хардкодится в репозитории.
  git_set_args=()
  _gn=$(git config user.name 2>/dev/null);  [ -n "$_gn" ] && git_set_args+=(--set "git_user_name=$_gn")
  _ge=$(git config user.email 2>/dev/null); [ -n "$_ge" ] && git_set_args+=(--set "git_user_email=$_ge")

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
    "${custom_tag_args[@]}" \
    --loose-giterminism=true \
    "${ci_set_args[@]}" \
    "${git_set_args[@]}" \
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
