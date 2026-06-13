# Схема работы с версиями (памятка)

Статья-памятка: единая версия продукта, синхронизированная по контейнерам,
бекенду и фронтенду. Схема взята из respoolman/cmdb и адаптирована под два
стека демо. Реализуется на этапе с кодом продуктов; здесь зафиксирована, чтобы
не потерять.

## Принцип

Одна версия (semver `X.Y.Z`) на продукт, единый источник истины -- файл
`VERSION` в корне продукта. Один скрипт `set-version.sh` раскатывает её во все
файлы, где версия дублируется, и она же становится тегом контейнерных образов
через werf.

```
VERSION (источник истины)
  ├─> бекенд        (версия пакета/приложения)
  ├─> фронтенд      (package.json)
  ├─> .helm/Chart.yaml (version + appVersion)
  └─> CI_TAG в .helm/def.sh ──> werf --use-custom-tag=%image%-$CI_TAG ──> тег образа
```

## Файлы версии по стекам

Версия дублируется в нескольких местах; `set-version.sh` держит их
синхронными. Набор файлов зависит от стека продукта.

| Слой | asset-svc (Python/Angular) | cmdb-web (Java/React) |
|---|---|---|
| источник | `VERSION` | `VERSION` |
| бекенд | `backend/src/<pkg>/_version.py`, `pyproject.toml` | `backend/pom.xml` (`<version>`) или `build.gradle` |
| фронтенд | `frontend/package.json` | `frontend/package.json` |
| чарт | `.helm/Chart.yaml` (`version`, `appVersion`) | то же |

## Скрипт set-version.sh (образец из respoolman)

```bash
./scripts/set-version.sh 1.0.0   # установить конкретную версию
./scripts/set-version.sh bump    # инкремент patch: 0.2.5 -> 0.2.6
```

Что делает:
- читает текущую версию из `VERSION` (или `_version.py`);
- `bump` инкрементирует patch;
- проверяет формат semver `X.Y.Z`;
- через `sed` подменяет версию в каждом целевом файле по его типу
  (`_version.py`, `pyproject.toml`, `package.json`, `Chart.yaml`);
- `Chart.yaml`: синхронно `version` и `appVersion` (kube_ci/werf другой схемы
  не требует);
- при `bump` -- `git add` изменённых файлов в текущий коммит.

Для cmdb-web (Java) ветка `case` дополняется обработкой `pom.xml`/`build.gradle`
вместо `_version.py`/`pyproject.toml`.

## Связь с werf (тег образа)

В `.helm/def.sh` каждая env-функция экспортирует `CI_TAG` из версии бекенда:

```bash
export CI_TAG=$(python3 -c "exec(open('backend/src/<pkg>/_version.py').read()); print(__version__)")
```

`kube_ci/utils/03-werf-converge.sh` подхватывает `CI_TAG` и передаёт werf
`--use-custom-tag=%image%-$CI_TAG`, поэтому тег опубликованного образа несёт
версию продукта. Для Java версия читается из `pom.xml`/`build.gradle`
(эквивалент строки выше).

## Где firm-up

Конкретные `set-version.sh`, `VERSION`, `_version.py`/`pom.xml`, `Chart.yaml`
создаются вместе с кодом продуктов (следующий этап). Зона -- `/devops` для
`.helm/Chart.yaml` и `CI_TAG`, `/backend` и `/frontend` для файлов версии своих
слоёв.
