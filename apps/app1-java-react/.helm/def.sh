#!/bin/bash
# Контракт с kube_ci: env-функция (имя == ключу в productlist) экспортирует
# переменные для utils/03-werf-converge.sh. CI_TAG -- единая версия из VERSION.

function dev() {
    export APPNAME=app1-java-react
    export ENVNAME=dev
    export NAMESPACE=app1-java-react
    export CI_URL=app1-java-react-dev-192.168.125.31.nip.io
    export CI_TAG=$(cat VERSION)
}

function prod() {
    export APPNAME=app1-java-react
    export ENVNAME=prod
    export NAMESPACE=app1-java-react
    export CI_URL=app1-java-react-prod-192.168.125.31.nip.io
    export CI_TAG=$(cat VERSION)
}
