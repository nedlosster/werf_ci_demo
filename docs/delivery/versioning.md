# Версионирование

У каждого продукта одна версия на всё: бекенд, фронтенд, чарт и тег
контейнерных образов держатся синхронными. Источник истины -- файл `VERSION` в
корне продукта; один скрипт `scripts/set-version.sh` раскатывает значение по всем
файлам, где версия дублируется, а контракт `.helm/def.sh` отдаёт ту же версию
контуру как `CI_TAG`, который становится тегом образов при выкатке. Эта статья
описывает схему по реальным артефактам обоих продуктов: что хранит `VERSION`,
какие файлы синхронизирует `set-version.sh` и как версия доходит до тега образа.
Поток converge, потребляющий `CI_TAG`, разобран в
[Доставке в Kubernetes](../concepts/delivery-to-k8s.md).

## Источник истины и поток

```
VERSION (X.Y.Z, корень продукта)
  ├─> бекенд        (pom.xml | _version.py + pyproject.toml)
  ├─> фронтенд      (package.json)
  ├─> .helm/Chart.yaml (version + appVersion)
  └─> CI_TAG (.helm/def.sh: $(cat VERSION)) ──> werf --use-custom-tag=%image%-$CI_TAG ──> тег образа
```

Оба продукта стартуют с версии `0.1.0`
([app1-java-react/VERSION](../../apps/app1-java-react/VERSION),
[app2-python-angular/VERSION](../../apps/app2-python-angular/VERSION)). Формат --
semver `X.Y.Z`.

## Файлы версии по стекам

Версия дублируется в нескольких местах; `set-version.sh` держит их синхронными.
Набор файлов зависит от стека:

| Слой | app1-java-react (Java/React) | app2-python-angular (Python/Angular) |
|---|---|---|
| источник | `VERSION` | `VERSION` |
| бекенд | `backend/pom.xml` (`<version>`) | `backend/src/app2/_version.py`, `backend/pyproject.toml` |
| фронтенд | `frontend/package.json` | `frontend/package.json` |
| чарт | `.helm/Chart.yaml` (`version`, `appVersion`) | то же |

## Скрипт set-version.sh

У каждого продукта свой [`scripts/set-version.sh`](../../apps/app1-java-react/scripts/set-version.sh):

```bash
./scripts/set-version.sh 1.0.0   # установить конкретную версию
./scripts/set-version.sh bump    # инкремент patch: 0.1.0 -> 0.1.1
```

Что делает скрипт:

- читает текущую версию из `VERSION`;
- `bump` инкрементирует patch, явная версия проверяется на формат semver
  `X.Y.Z`;
- через `sed` подменяет версию в каждом целевом файле по его типу;
- в `Chart.yaml` синхронно правит `version` и `appVersion`;
- при `bump` добавляет изменённые файлы в индекс git (`git add`).

Различие между продуктами -- только в наборе целевых файлов:
[app1-java-react/scripts/set-version.sh](../../apps/app1-java-react/scripts/set-version.sh)
правит `pom.xml`, [app2-python-angular/scripts/set-version.sh](../../apps/app2-python-angular/scripts/set-version.sh)
-- `_version.py` и `pyproject.toml`. В `pom.xml` меняется именно проектная
версия; версия parent-артефакта Spring Boot не совпадает с текущей и поэтому не
затрагивается.

Поверх обоих скриптов есть единая обёртка
[`kube_ci/utils/bump-version.sh`](../../kube_ci/utils/bump-version.sh): она
вызывает `set-version.sh` нужного продукта или сразу обоих (`all`):

```bash
./bump-version.sh all              # инкремент patch обоим продуктам
./bump-version.sh app1-java-react 1.0.0
```

## Связь с werf (тег образа)

В [`.helm/def.sh`](../../apps/app1-java-react/.helm/def.sh) каждая env-функция
экспортирует `CI_TAG` из файла версии:

```bash
export CI_TAG=$(cat VERSION)
```

Функция `deploy()` в
[`utils/03-werf-converge.sh`](../../kube_ci/utils/03-werf-converge.sh) при
непустом `CI_TAG` добавляет `--use-custom-tag=%image%-$CI_TAG`, поэтому тег
опубликованного образа несёт версию продукта. `CI_TAG` -- единственная
`CI_*`-переменная, которую converge не пробрасывает в helm через `--set`:
строка с подстановкой ломала бы обработку через `sed`, и переменная используется
только для тега образов.

## Где проставляет версию CI

В демо версия меняется вручную через `set-version.sh` или `bump-version.sh`. В
реальном CI тег проставляет пайплайн: версия фиксируется на сборке и уходит в
`CI_TAG`, дальше -- тем же converge. Подключение скриптов к внешним CI-системам
планируется в [Интеграциях](../integrations/README.md) (GitLab CI, Jenkins).

## Связанные статьи

- [Один контур, два окружения](dev-prod.md)
- [Операции kube_ci](kube-ci-operations.md)
- [Управление секретами](secrets.md)
- [Доставка в Kubernetes](../concepts/delivery-to-k8s.md)
- [Контракт продукта (apps/README.md)](../../apps/README.md)
- [Интеграции](../integrations/README.md)
