# Требования к Kubernetes-кластеру

Демо ставит приложения в **уже развёрнутые** кластеры окружений dev / prod.
Разворачивание кластеров в скоп демо не входит; здесь зафиксированы требования
к среде, без которых публикация через kube_ci не заработает.

ВРЕМЕННО оба окружения указывают на один физический кластер
`k8s-public-paas` (paasfabric, внутренняя сеть с NAT и выходом в интернет --
чтобы dev-под клонировал монорепо). Окружения dev и prod
различаются только неймспейсом; требования к кластеру описаны ниже и применимы к
каждому будущему отдельному кластеру dev/prod.

Статья -- регистр того, что должно быть в кластере и на хосте сборки: топология,
обязательные компоненты, реестр образов (в демо -- in-cluster на nip.io),
insecure-доступ к нему, ориентир по ресурсам, команды проверки готовности. Состав объектов, которые чарт
создаёт внутри неймспейса, вынесен в [specifications.md](specifications.md);
маршрутизация снаружи -- в [ingress.md](ingress.md).

## Топология

- Single-node кластер (например, на KVM/VM или bare-metal).
- Доступ к кластеру с рабочей машины: контекст в `~/.kube/config`. Имя контекста
  задаётся в [`kube_ci/<env>/k8s_defs`](../../kube_ci/dev/k8s_defs), переопределяется
  через `KUBECONTEXT`. Сейчас по умолчанию для dev и prod:

  ```bash
  KUBECONTEXT=${KUBECONTEXT:-k8sadmin-k8s-public-paas@service-k8s-public-paas}
  KUBECONFIG=${KUBECONFIG:-~/.kube/config}
  ```

  Точка входа окружения переключает kubectl на этот контекст
  (`kubectl config use-context`).

## Компоненты в кластере

| Компонент | Назначение |
|---|---|
| ingress-nginx | внешний доступ к сервисам и pgAdmin по `CI_URL` |
| реестр образов | приёмник образов werf (в демо -- in-cluster, см. ниже; может быть внешним) |
| metrics-server | (опционально) метрики для HPA/обзора |

### Реестр образов (в демо -- in-cluster через nip.io)

werf публикует собранные образы в container registry. **Сам реестр не обязан
быть внутри кластера** -- подойдёт любой доступный: внешний managed-реестр,
отдельный сервер registry, реестр в другом кластере. Контур читает адрес из
`REGISTRY` (`kube_ci/<env>/k8s_defs`), поэтому смена реестра -- это смена одной
переменной, без правок продуктов.

В демо ради самодостаточности реестр поднят прямо в кластере и опубликован
наружу через ingress на хосте вида `registry-<NODE_IP>.nip.io`. `nip.io` --
wildcard-DNS: имя `registry-<NODE_IP>.nip.io` резолвится в `<NODE_IP>` без
настройки DNS.

В [`kube_ci/<env>/k8s_defs`](../../kube_ci/dev/k8s_defs) (сейчас одинаково для
dev и prod -- кластер `k8s-public-paas`):

```bash
NODE_IP=${K8S_NODE_IP:-<NODE_IP>}
REGISTRY=${REGISTRY:-registry-${NODE_IP}.nip.io}
```

`NODE_IP` должен указывать на адрес ноды кластера. Фактическое значение задаётся
в [`kube_ci/<env>/k8s_defs`](../../kube_ci/dev/k8s_defs) и переопределяется
переменной окружения `K8S_NODE_IP`.

## Доступ к реестру (insecure)

Insecure-режим реестра -- **выбор демо ради упрощения**, а не требование werf
или Kubernetes. Так не нужно заводить доверенный TLS-сертификат и его цепочку:
реестр отдаётся по HTTP (или HTTPS с self-signed cert), а хост сборки и нода
кластера считают его insecure. В реальной поставке вместо этого используют
реестр с валидным TLS, и тогда описанные ниже послабления не нужны. Риски
insecure-режима и боевые альтернативы -- в
[security-and-tradeoffs.md](../concepts/security-and-tradeoffs.md).

Для демо же и хост сборки, и нода кластера должны считать реестр insecure.

### Docker на хосте сборки

`/etc/docker/daemon.json`:

```json
{
  "insecure-registries": ["registry-<NODE_IP>.nip.io"]
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
4 vCPU, 8 GB RAM, 20 GB диска. Демо-чарты не задают `requests`/`limits` на
поды, поэтому планирование идёт по дефолтам кластера; persistent-объём под
PostgreSQL -- 5Gi на продукт (`postgres.storageSize` в
[`apps/<app>/.helm/values.yaml`](../../apps/app1-java-react/.helm/values.yaml)).
Раскладка объектов и томов по окружениям -- в [specifications.md](specifications.md).

## Проверка готовности

```bash
kubectl --context "$KUBECONTEXT" get nodes
kubectl --context "$KUBECONTEXT" -n kube-system get pods -l app.kubernetes.io/component=controller
curl -sI http://registry-<NODE_IP>.nip.io/v2/
docker info | grep -A2 'Insecure Registries'
```

## Связанные статьи

- [specifications.md](specifications.md) -- объекты, которые чарт продукта создаёт
  в неймспейсе окружения, и различия dev vs prod.
- [ingress.md](ingress.md) -- маршрутизация ingress-nginx, хосты nip.io, доступ к
  фронту, бэкенду и pgAdmin.
- [../concepts/security-and-tradeoffs.md](../concepts/security-and-tradeoffs.md) --
  почему registry и TLS работают в insecure-режиме и чем это рискованно в проде.
- [../runbooks/deploy.md](../runbooks/deploy.md) -- запуск публикации, отката и
  очистки против подготовленного кластера.
