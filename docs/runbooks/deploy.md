# Runbook: деплой демо в dev / stage / prod

Три базовые операции kube_ci над уже развёрнутыми кластерами окружений
dev / stage / prod: **публикация, откат, очистка**.

Все команды одинаковы, меняется только каталог окружения (`kube_ci/dev`,
`kube_ci/stage`, `kube_ci/prod`). Ниже -- на примере `dev`.

ВРЕМЕННО все три окружения указывают на один физический preprod-кластер;
продукты различаются неймспейсом (`<NAMESPACE>-dev`, `-stage`, `-prod`).

## Предусловия

- Кластер окружения уже развёрнут и доступен -- см.
  [../k8s-requirements.md](../k8s-requirements.md).
- В `~/.kube/config` есть контекст кластера (задаётся в `<env>/k8s_defs`,
  переопределяется через `KUBECONTEXT`).
- `werf` подтягивается через `trdl` (`trdl use werf 2 stable`) -- см.
  [../werf-intro.md](../werf-intro.md).
- У каждого продукта в `apps/<product>/` есть `werf.yaml` и `.helm/` с `def.sh`
  (контракт -- [../../apps/README.md](../../apps/README.md)). На этапе 1
  продукты -- заготовки, поэтому реальный деплой возможен после добавления их
  исходников и `.helm/`.

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
./00-build-deploy.sh cmdb-web   # либо только выбранный продукт
```

`werf converge` собирает образы, публикует в in-cluster registry и
разворачивает релиз в неймспейсе `<NAMESPACE>-<ENVNAME>`. После деплоя
печатаются URL сервиса и pgAdmin.

## Откат

```bash
cd kube_ci/dev
./01-dissmiss.sh cmdb-web     # werf dismiss конкретного продукта
./01-dissmiss.sh --all        # снять все продукты из productlist
```

Без аргумента скрипт отказывает (защита от снятия всех продуктов разом).

## Очистка

```bash
cd kube_ci/dev
./02-purge-stages.sh         # сбросить локальный кеш сборки werf (stages)
```

Полная очистка werf-кеша хоста и docker-образов -- `../utils/10-purge-werf-registry.sh`.
