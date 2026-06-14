# werf_ci_demo

Демонстрационный репозиторий связки **kube_ci** (bash-оркестрация сборки и
деплоя через [werf](https://werf.io)) с набором разнородных демо-приложений.

Назначение -- показать, как разнородные продукты (разные стеки) собираются и
деплоятся единым CI-контуром по общему контракту в два окружения
(**dev / prod**), и как выполняются три базовые операции:
**публикация, откат, очистка**.

Кластеры считаются уже развёрнутыми. ВРЕМЕННО оба окружения указывают на
один физический preprod-кластер; продукты различаются неймспейсом.

## Состав

| Каталог | Назначение |
|---|---|
| `apps/` | демо-продукты: исходники, `Dockerfile`, `werf.yaml`, `.helm/`-чарты |
| `kube_ci/` | адаптированная копия оркестрации werf-деплоя |
| `docs/` | документация и runbook'и |

### Демо-продукты (`apps/`)

| Продукт | Фронт | Бек | Хранилище |
|---|---|---|---|
| `app1-java-react` | React | Spring Boot (Java) | PostgreSQL + pgAdmin |
| `app2-python-angular` | Angular | FastAPI (Python) | PostgreSQL + pgAdmin |

Разные стеки специально: один CI-контур обслуживает оба продукта через единый
контракт `.helm/def.sh` (см. [apps/README.md](apps/README.md)).

## Базовые операции

Все операции запускаются из каталога окружения (`kube_ci/dev/` или
`kube_ci/prod/`):

| Операция | Команда |
|---|---|
| Публикация (werf converge) | `./pull_products.sh && ./00-build-deploy.sh` |
| Откат (dismiss namespace) | `./01-dissmiss.sh <product>` |
| Очистка (сброс кеша сборки) | `./02-purge-stages.sh` |

Полный сценарий -- [docs/runbooks/deploy.md](docs/runbooks/deploy.md).
Требования к кластеру -- [docs/kubernetes/requirements.md](docs/kubernetes/requirements.md).

## Документация

Документация разбита на тематические разделы; индекс и путь чтения -- в
[docs/README.md](docs/README.md).

| Раздел | Содержимое |
|---|---|
| [docs/concepts/](docs/concepts/README.md) | werf, сравнение с альтернативами, модель доставки, компромиссы |
| [docs/kubernetes/](docs/kubernetes/README.md) | требования к кластеру, спецификации объектов, ingress |
| [docs/products/](docs/products/README.md) | состав двух продуктов, PostgreSQL, pgAdmin |
| [docs/delivery/](docs/delivery/README.md) | окружения dev/prod, операции kube_ci, секреты, версии |
| [docs/integrations/](docs/integrations/README.md) | GitLab CI, Jenkins, метрики DORA |
| [docs/runbooks/](docs/runbooks/README.md) | пошаговые сценарии эксплуатации |
| [docs/demo/](docs/demo/README.md) | план доклада и банк вопросов |

Справочные материалы: [docs/glossary.md](docs/glossary.md) -- термины контура,
[docs/resources.md](docs/resources.md) -- внешние ресурсы.

## Состояние

Репозиторий содержит работающую оркестрацию и оба продукта целиком: исходники,
`Dockerfile`/`Dockerfile.dev`, `werf.yaml`, `.helm/`-чарты (ingress, pgAdmin,
db-init-configmap, backend/frontend в dev- и prod-формах, secret), файлы версии
и `set-version.sh`. Демонстрационной остаётся только бизнес-логика фронта и
бэкенда -- продукты служат носителями стека и контракта. Вне скоупа демо --
разворачивание самих кластеров (они считаются готовыми) и реальная продуктовая
функциональность.
