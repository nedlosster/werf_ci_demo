# Runbook: деплой демо в dev / prod

Три базовые операции kube_ci над уже развёрнутыми кластерами окружений
dev / prod: **публикация, откат, очистка**.

Все команды одинаковы, меняется только каталог окружения (`kube_ci/dev`,
`kube_ci/prod`). Ниже -- на примере `dev`.

ВРЕМЕННО оба окружения указывают на один физический preprod-кластер;
продукты различаются неймспейсом (`<NAMESPACE>-dev`, `-prod`).

## Предусловия

- Кластер окружения уже развёрнут и доступен -- см.
  [requirements.md](../kubernetes/requirements.md).
- В `~/.kube/config` есть контекст кластера (задаётся в `<env>/k8s_defs`,
  переопределяется через `KUBECONTEXT`).
- `werf` подтягивается через `trdl` (`trdl use werf 2 stable`) -- см.
  [werf-intro.md](../concepts/werf-intro.md).
- У каждого продукта в `apps/<product>/` есть исходники, `werf.yaml` и `.helm/`
  с `def.sh` (контракт -- [../../apps/README.md](../../apps/README.md)) --
  артефакты для сборки и деплоя на месте. Вне скоупа демо -- разворачивание
  самих кластеров (считаются готовыми) и реальная продуктовая бизнес-логика.

## Подготовка продуктов

```bash
cd kube_ci/dev
./pull_products.sh           # связать apps/<product> -> products/<product>
```

При необходимости отредактировать `productlist` (копия `productlist_official`):
список продуктов и их окружений.

## Публикация

```bash
cd kube_ci/dev
./00-build-deploy.sh         # werf converge всех продуктов из productlist
./00-build-deploy.sh app1-java-react   # либо только выбранный продукт
```

`werf converge` собирает образы, публикует в in-cluster registry и
разворачивает релиз в неймспейсе `<NAMESPACE>-<ENVNAME>`. После деплоя
печатаются URL сервиса и pgAdmin.

## Откат

```bash
cd kube_ci/dev
./01-dissmiss.sh app1-java-react     # werf dismiss конкретного продукта
./01-dissmiss.sh --all        # снять все продукты из productlist
```

Без аргумента скрипт отказывает (защита от снятия всех продуктов разом).

## Очистка

```bash
cd kube_ci/dev
./02-purge-stages.sh         # сбросить локальный кеш сборки werf (stages)
```

Полная очистка werf-кеша хоста и docker-образов -- `../utils/10-purge-werf-registry.sh`.

## Связанные runbook'и

- [cluster-connection.md](cluster-connection.md) -- подключение к кластеру,
  kubeconfig, insecure-registry, переопределение под отдельный кластер.
- [secrets-setup.md](secrets-setup.md) -- генерация ключа `WERF_SECRET_KEY`,
  правка зашифрованных значений, ротация.
- [first-deploy.md](first-deploy.md) -- первый деплой продукта с нуля,
  end-to-end, с чеклистом проверки.
- [troubleshooting.md](troubleshooting.md) -- разбор типовых сбоев: TLS/registry,
  timeout, отсутствие ключа, ImagePullBackOff, init БД, ingress 404, контекст.
