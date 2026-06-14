# Runbook: деплой демо в dev / prod

Базовые операции kube_ci над уже развёрнутыми кластерами окружений
dev / prod: **публикация, снос, очистка**. Откат версии релиза на ранее
опубликованную ревизию вынесен в отдельный [runbook отката](rollback.md).

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

## Обновление образа или спецификации Postgres

StatefulSet базы развёрнут со стратегией `updateStrategy: OnDelete`, поэтому
обычный `converge` не пересоздаёт под Postgres (механизм -- в
[PostgreSQL и инициализация схемы](../products/postgres-and-init.md)). При
намеренном изменении образа или спецификации базы под после `converge`
обновляют вручную:

```bash
kubectl delete pod <app>-postgres-0
```

StatefulSet поднимает под по новой спецификации; данные на PVC (том `data`)
сохраняются. В демо образ Postgres статичный (`postgres:16`), так что шаг
требуется только при намеренной правке самой базы.

## Снос

```bash
cd kube_ci/dev
./01-dissmiss.sh app1-java-react     # werf dismiss конкретного продукта
./01-dissmiss.sh --all        # снять все продукты из productlist
```

Без аргумента скрипт отказывает (защита от снятия всех продуктов разом). Снос
удаляет релиз вместе с неймспейсом -- это не возврат к прошлой версии. Откат
неудачной выкатки на ранее опубликованную ревизию -- обратная к публикации
операция, она описана в [runbook отката](rollback.md).

## Очистка

```bash
cd kube_ci/dev
./02-purge-stages.sh         # сбросить локальный кеш сборки werf (stages)
```

Полная очистка werf-кеша хоста и docker-образов -- `../utils/10-purge-werf-registry.sh`.

## Связанные runbook'и

- [rollback.md](rollback.md) -- откат версии релиза на ранее опубликованную
  ревизию через `helm rollback`, список доступных версий, ограничение по БД.
- [cluster-connection.md](cluster-connection.md) -- подключение к кластеру,
  kubeconfig, insecure-registry, переопределение под отдельный кластер.
- [secrets-setup.md](secrets-setup.md) -- генерация ключа `WERF_SECRET_KEY`,
  правка зашифрованных значений, ротация.
- [first-deploy.md](first-deploy.md) -- первый деплой продукта с нуля,
  end-to-end, с чеклистом проверки.
- [troubleshooting.md](troubleshooting.md) -- разбор типовых сбоев: TLS/registry,
  timeout, отсутствие ключа, ImagePullBackOff, init БД, ingress 404, контекст.
