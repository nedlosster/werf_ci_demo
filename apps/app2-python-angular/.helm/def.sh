#!/bin/bash
# Контракт с kube_ci. CI_TAG -- единая версия из VERSION.

function dev() {
    export APPNAME=app2-python-angular
    export ENVNAME=dev
    export NAMESPACE=app2-python-angular
    export CI_URL=app2-python-angular-dev-192.168.123.31.nip.io
    export CI_TAG=$(cat VERSION)
}

function prod() {
    export APPNAME=app2-python-angular
    export ENVNAME=prod
    export NAMESPACE=app2-python-angular
    export CI_URL=app2-python-angular-prod-192.168.123.31.nip.io
    export CI_TAG=$(cat VERSION)
}
