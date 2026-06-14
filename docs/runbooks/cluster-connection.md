---
title: Подключение к кластеру и kubeconfig
status: stable
last-updated: 2026-06-13
area: runbooks
---

# Runbook: подключение к кластеру и kubeconfig

Перед любой операцией kube_ci рабочая машина должна иметь доступ к кластеру
окружения и правильный контекст kubectl. Параметры подключения kube_ci берёт
не из аргументов, а из файла окружения
[`kube_ci/dev/k8s_defs`](../../kube_ci/dev/k8s_defs) (для prod --
[`kube_ci/prod/k8s_defs`](../../kube_ci/prod/k8s_defs)), который точки входа
подключают через `source`. Этот runbook описывает, что в нём задано, как
проверить и переключить контекст и что менять при переходе на отдельный кластер.

Концептуальный разбор insecure-registry и общего preprod-кластера -- в
[Компромиссах и безопасности схемы](../concepts/security-and-tradeoffs.md);
требования к самому кластеру -- в [requirements.md](../kubernetes/requirements.md).

## Параметры из k8s_defs

`k8s_defs` идемпотентен и задаёт переменные с дефолтами, которые переопределяются
env-переменными:

| Переменная | Дефолт | Назначение |
|---|---|---|
| `NODE_IP` | `<NODE_IP>` (из `K8S_NODE_IP`; значение -- в `kube_ci/dev/k8s_defs`) | IP ноды кластера, основа nip.io-хостов |
| `REGISTRY` | `registry-${NODE_IP}.nip.io` | in-cluster registry для образов werf |
| `KUBECONTEXT` | `k8sadmin-k8s-public-paas@service-k8s-public-paas` | контекст kubectl |
| `KUBECONFIG` | `~/.kube/config` | путь к kubeconfig |

При `source k8s_defs` выполняется `kubectl config use-context "$KUBECONTEXT"` --
файл сам переключает активный контекст. Оба окружения сейчас указывают на один
физический preprod-кластер и различаются только неймспейсом `<NAMESPACE>-<ENVNAME>`.

## kubeconfig

kube_ci ожидает kubeconfig по пути из `KUBECONFIG` (по умолчанию `~/.kube/config`)
с контекстом из `KUBECONTEXT`. Файл выдаёт администратор кластера; в демо деплой
и отладка идут на сервере деплоя (маршрут -- см. infa), где kubeconfig уже размещён.
Положить полученный файл в `~/.kube/config` либо указать его путь:

```bash
export KUBECONFIG=/path/to/kubeconfig
```

Проверить, что нужный контекст присутствует и активен:

```bash
kubectl config get-contexts
kubectl config use-context k8sadmin-k8s-public-paas@service-k8s-public-paas
kubectl get nodes
```

`kubectl get nodes` должен вернуть ноды кластера в статусе `Ready`. Если контекст
не найден или `get nodes` отвечает ошибкой соединения -- kubeconfig не тот или
кластер недоступен; дальше идти нельзя.

## Insecure-registry

in-cluster registry опубликован через ingress-nginx, который отдаёт self-signed
HTTPS на хосте `registry-<NODE_IP>.nip.io`. Без послаблений werf отверг бы такой
сертификат при push образов. Поэтому `k8s_defs` экспортирует две env-переменные:

```bash
export WERF_INSECURE_REGISTRY=true
export WERF_SKIP_TLS_VERIFY_REGISTRY=true
```

Они задаются именно переменными окружения, потому что одноимённые cli-флаги
converge не доходят до слоя stage-storage. Дополнительно сама нода должна
доверять registry как insecure -- настройка containerd/Docker описана в
[requirements.md](../kubernetes/requirements.md). Зачем это допустимо в демо и
чем рискованно в проде -- в [Компромиссах и безопасности схемы](../concepts/security-and-tradeoffs.md).

## Переопределение под отдельный кластер

`KUBECONTEXT`, `REGISTRY` и `K8S_NODE_IP` берутся из env, если заданы. Чтобы
направить окружение на другой кластер без правки `k8s_defs`:

```bash
export K8S_NODE_IP=10.0.0.5
export KUBECONTEXT=my-cluster-admin@my-cluster
export REGISTRY=registry.internal.example
```

Когда у dev и prod появятся отдельные кластеры, постоянное переключение
прописывают прямо в `<env>/k8s_defs`: меняются только `KUBECONTEXT`, `REGISTRY` и
`K8S_NODE_IP` в нужном файле окружения, логика доставки не затрагивается. Если в
новом кластере registry получит валидный TLS, insecure-послабления из `k8s_defs`
снимают.

## Связанные статьи

- [deploy.md](deploy.md) -- три базовые операции kube_ci
- [first-deploy.md](first-deploy.md) -- первый деплой с нуля
- [troubleshooting.md](troubleshooting.md) -- разбор сбоев, включая неверный
  контекст и ошибки registry
- [requirements.md](../kubernetes/requirements.md) -- требования к кластеру и
  registry
- [Компромиссы и безопасность схемы](../concepts/security-and-tradeoffs.md)
