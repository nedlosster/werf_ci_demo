# Требования к Kubernetes-кластеру

Демо ставит приложения в **уже развёрнутые** кластеры окружений
dev / stage / prod. Разворачивание кластеров в скоп демо не входит; здесь
зафиксированы требования к среде, без которых публикация через kube_ci не
заработает.

ВРЕМЕННО все три окружения указывают на один физический preprod-кластер
(там же работает preprod cmdb); требования к нему описаны ниже и применимы к
каждому будущему кластеру dev/stage/prod.

## Топология

- Single-node кластер (например, на KVM/VM или bare-metal).
- Доступ к кластеру с рабочей машины: контекст в `~/.kube/config`
  (имя контекста задаётся в `kube_ci/<env>/k8s_defs`, переопределяется через
  `KUBECONTEXT`; сейчас по умолчанию -- контекст preprod-кластера cmdb).

## Компоненты в кластере

| Компонент | Назначение |
|---|---|
| ingress-nginx | внешний доступ к сервисам и pgAdmin по `CI_URL` |
| in-cluster registry | приёмник образов, собранных werf |
| metrics-server | (опционально) метрики для HPA/обзора |

### In-cluster registry через nip.io

Реестр публикуется наружу через ingress на хосте вида
`registry-<NODE_IP>.nip.io`. `nip.io` -- wildcard-DNS: имя
`registry-192.168.125.31.nip.io` резолвится в `192.168.125.31` без настройки DNS.

В `kube_ci/<env>/k8s_defs` (сейчас одинаково для dev/stage/prod -- preprod cmdb):

```bash
NODE_IP=${K8S_NODE_IP:-192.168.125.31}
REGISTRY=${REGISTRY:-registry-${NODE_IP}.nip.io}
```

`NODE_IP` должен указывать на адрес ноды кластера. Переопределяется
переменной окружения `K8S_NODE_IP`.

## Доступ к реестру (insecure)

Реестр отдаётся по HTTP (или HTTPS с self-signed cert), поэтому и хост сборки,
и нода кластера должны считать его insecure.

### Docker на хосте сборки

`/etc/docker/daemon.json`:

```json
{
  "insecure-registries": ["registry-192.168.125.31.nip.io"]
}
```

После правки -- `sudo systemctl restart docker`.

### containerd на ноде кластера

`/etc/containerd/certs.d/registry-<NODE_IP>.nip.io/hosts.toml`:

```toml
server = "http://registry-<NODE_IP>.nip.io"

[host."http://registry-<NODE_IP>.nip.io"]
  capabilities = ["pull", "resolve"]
  skip_verify = true
```

В `/etc/containerd/config.toml` должен быть включён
`config_path = "/etc/containerd/certs.d"`.

werf дополнительно принуждается на HTTP/skip-verify через env-переменные в
`k8s_defs`:

```bash
export WERF_INSECURE_REGISTRY=true
export WERF_SKIP_TLS_VERIFY_REGISTRY=true
```

## Ресурсы

Для двух демо-продуктов (фронт + бек + PostgreSQL + pgAdmin на каждый) ориентир:
4 vCPU, 8 GB RAM, 20 GB диска. Точные запросы задаются в `.helm/values-*.yaml`
продуктов.

## Проверка готовности

```bash
kubectl --context "$KUBECONTEXT" get nodes
kubectl --context "$KUBECONTEXT" -n kube-system get pods -l app.kubernetes.io/component=controller
curl -sI http://registry-<NODE_IP>.nip.io/v2/
docker info | grep -A2 'Insecure Registries'
```
