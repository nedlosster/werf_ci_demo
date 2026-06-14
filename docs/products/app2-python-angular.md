# app2-python-angular

`app2-python-angular` -- демо-продукт на стеке Angular (фронт) и FastAPI
(бэкенд) с PostgreSQL и pgAdmin. Статья разбирает его состав так же, как
[app1-java-react.md](app1-java-react.md) разбирает первый продукт: исходники,
сборка, описание образов в `werf.yaml`, различия dev и prod. Это сознательная
противоположность app1 по языку и фреймворкам -- а значит, проверка того, что
контур не зависит от стека. Сопоставление двух продуктов -- в
[overview.md](overview.md); набор объектов чарта -- в
[../kubernetes/specifications.md](../kubernetes/specifications.md).

## Бэкенд: FastAPI

Бэкенд -- FastAPI (>=0.111) на Python 3.12 под uvicorn, менеджер пакетов pip
([`backend/pyproject.toml`](../../apps/app2-python-angular/backend/pyproject.toml)).
Зависимости минимальны: `fastapi`, `uvicorn[standard]` и `psycopg[binary]` для
работы с PostgreSQL. Пакет приложения лежит в `src/` (layout `src/app2`),
сборка через setuptools.

Запуск вынесен в
[`backend/entrypoint.sh`](../../apps/app2-python-angular/backend/entrypoint.sh):
`uvicorn app2.main:app --host 0.0.0.0 --port 8080 --proxy-headers
--forwarded-allow-ips='*'`. Флаги `--proxy-headers` и `--forwarded-allow-ips`
нужны, потому что приложение стоит за Ingress-прокси и должно доверять
заголовкам `X-Forwarded-*`. В отличие от app1, отдельного management-порта нет:
health-проба бьёт прямо по `/health` на том же порту 8080
([`030-backend-prod.yaml`](../../apps/app2-python-angular/.helm/templates/030-backend-prod.yaml)).
Подключение к базе берётся из тех же env-переменных `DB_*`, что подаёт чарт.

## Сборка бэкенда: Dockerfile

Prod-образ
([`backend/Dockerfile`](../../apps/app2-python-angular/backend/Dockerfile)) --
одностадийный на `python:3.12-slim`, но с разделением слоёв ради кеша. Сначала
ставятся только зависимости: копируется `pyproject.toml`, создаётся пустой пакет
и выполняется `pip install .` -- этот слой кешируется по `pyproject.toml` через
BuildKit cache mount. Затем копируются исходники и доустанавливается сам пакет
без зависимостей (`pip install --no-deps .`). Образ запускается под non-root
пользователем (uid 10001), `ENTRYPOINT` -- `sh entrypoint.sh`, `BUILD_HASH`
пишется в `/app/.build-info`.

В отличие от app1, тяжёлой стадии-builder нет: Python не компилируется в
артефакт, поэтому рантайм-образ совпадает со сборочным по базовому слою. Это
делает Dockerfile проще, но рантайм-образ несёт полный `pip` и инструментарий
установки.

Dev-образ
([`backend/Dockerfile.dev`](../../apps/app2-python-angular/backend/Dockerfile.dev))
устроен по тому же шаблону, что dev-образы app1: полный `python:3.12` с git,
openssh-client и passwordless sudo, кеш pip и `.vscode-server` через симлинки
в persistent-том `homeapp`, `ENTRYPOINT` -- `sleep infinity`. Исходники
клонируются в `/workspace` init-контейнером уже в кластере. Режим разработки --
в [../delivery/dev-in-cluster.md](../delivery/dev-in-cluster.md).

## Фронтенд: Angular

Фронт -- Angular 18.2, менеджер пакетов npm
([`frontend/package.json`](../../apps/app2-python-angular/frontend/package.json)).
Это вторая ключевая точка контраста с app1: там React на Vite и pnpm, здесь
Angular CLI на npm. Сборка -- `ng build`
([`angular.json`](../../apps/app2-python-angular/frontend/angular.json)),
builder `@angular-devkit/build-angular:application`, дефолтная конфигурация
`production` с оптимизацией и `outputHashing: all`. Точка входа --
[`src/main.ts`](../../apps/app2-python-angular/frontend/src/main.ts):
standalone-bootstrap `AppComponent` с провайдером `provideHttpClient()` для
обращений к бэкенду. Результат сборки кладётся в `dist/app2-frontend/browser`.

## Сборка фронтенда: build + nginx

Prod-образ
([`frontend/Dockerfile`](../../apps/app2-python-angular/frontend/Dockerfile)) --
двухстадийный: `node:20-alpine` ставит зависимости (`npm install` с кешем
`~/.npm`) и собирает статику, рантайм-стадия на `nginx:1.27-alpine` копирует
`dist/app2-frontend/browser` в `/usr/share/nginx/html`. Дефолтный конфиг nginx
заменяется на
[`frontend/nginx.conf`](../../apps/app2-python-angular/frontend/nginx.conf):
сервер слушает 8080, всё отдаётся через `try_files ... /index.html` (fallback
на index для маршрутов Angular). По сравнению с app1 конфиг проще -- без
отдельного immutable-кеша для ассетов; хеши в именах файлов даёт сам Angular
через `outputHashing`.

Dev-образ фронта собирается по тому же dev-шаблону, что и бэкенд: полный node,
sleep infinity, исходники из `/workspace`.

## Образы в werf.yaml

[`werf.yaml`](../../apps/app2-python-angular/werf.yaml) идентичен по устройству
файлу app1: образы не перечислены напрямую, а подключаются из `.werf-partial/`
через `Files.Glob` и `tpl`, каждый partial рендерится по `ENVNAME`:

| Partial | Условие | image | dockerfile |
|---|---|---|---|
| `backend-prod.yaml` | `ENVNAME != dev` | `backend` | `backend/Dockerfile` |
| `backend-dev.yaml` | `ENVNAME == dev` | `backend-dev` | `backend/Dockerfile.dev` |
| `frontend-prod.yaml` | `ENVNAME != dev` | `frontend` | `frontend/Dockerfile` |
| `frontend-dev.yaml` | `ENVNAME == dev` | `frontend-dev` | `frontend/Dockerfile.dev` |

Контекст prod-образов -- подкаталог (`backend`, `frontend`), dev-образов --
корень продукта (`.`). Секция `cleanup.keepPolicies` оставляет по два последних
образа на git-ссылку. Эта одинаковость `werf.yaml` у двух продуктов -- прямое
следствие единого контракта: контур собирает оба продукта одной командой.

## dev и prod деплоймент

Форму выбирает `.Values.env` из `values-<env>.yaml`.

В prod бэкенд и фронт -- Deployment на собранных prod-образах
([`030-backend-prod.yaml`](../../apps/app2-python-angular/.helm/templates/030-backend-prod.yaml),
[`040-frontend-prod.yaml`](../../apps/app2-python-angular/.helm/templates/040-frontend-prod.yaml)).
Бэкенд открывает один порт 8080, readiness и liveness бьют по `/health` на нём.
Реплик по два на бэкенд и фронт
([`values-prod.yaml`](../../apps/app2-python-angular/.helm/values-prod.yaml)),
pgAdmin выключен.

В dev бэкенд и фронт -- StatefulSet с одной репликой и dev-образами
([`031-backend-dev.yaml`](../../apps/app2-python-angular/.helm/templates/031-backend-dev.yaml),
[`041-frontend-dev.yaml`](../../apps/app2-python-angular/.helm/templates/041-frontend-dev.yaml)):
тома `workspace` и `homeapp`, init-контейнер, ssh-ключ, приложение не запущено
(sleep infinity). pgAdmin в dev включён
([`values-dev.yaml`](../../apps/app2-python-angular/.helm/values-dev.yaml)).
Service бэкенда и фронта называется одинаково в обеих формах
(`app2-python-angular-backend`, `app2-python-angular-frontend`).

## Плюсы, минусы, безопасность стека

Сильные стороны. Python-сервис стартует быстро и легко по памяти, пробы можно
держать с малым `initialDelaySeconds`. uvicorn с `--proxy-headers` корректно
работает за Ingress. Образ фронта в рантайме -- nginx без node.

Ограничения. Prod-`Dockerfile` бэкенда не отделяет рантайм от сборки: образ
несёт `pip` и заголовочные пакеты, которые в рантайме не нужны (app1 за счёт
multi-stage от этого избавлен). Health-проба бьёт в общий прикладной порт 8080 --
тяжёлый прикладной трафик и проверка живости делят один сокет. Чарт не задаёт
`requests`/`limits`.

Безопасность. Как и в app1, пароль базы и креды pgAdmin -- демо-дефолты в
[`values.yaml`](../../apps/app2-python-angular/.helm/values.yaml), трафик идёт
по HTTP. Отдельная деталь именно этого стека: `--forwarded-allow-ips='*'`
заставляет uvicorn доверять `X-Forwarded-*` от любого источника -- допустимо за
управляемым Ingress демо, но в открытом контуре это слишком широко. Разбор
послаблений и боевых альтернатив -- в
[../concepts/security-and-tradeoffs.md](../concepts/security-and-tradeoffs.md).

## Связанные статьи

- [overview.md](overview.md) -- сопоставление с app1-java-react.
- [app1-java-react.md](app1-java-react.md) -- симметричный разбор первого
  продукта.
- [postgres-and-init.md](postgres-and-init.md) -- PostgreSQL и init.sql.
- [pgadmin.md](pgadmin.md) -- pgAdmin как вспомогательный сервис.
- [../kubernetes/specifications.md](../kubernetes/specifications.md) -- объекты
  чарта, dev/prod-формы, образы.
- [../kubernetes/ingress.md](../kubernetes/ingress.md) -- маршрутизация на
  сервисы продукта.
- [../delivery/dev-in-cluster.md](../delivery/dev-in-cluster.md) -- dev-поды и
  разработка внутри кластера.
- [../delivery/versioning.md](../delivery/versioning.md) -- VERSION и CI_TAG.
- [../../apps/README.md](../../apps/README.md) -- контракт продукта.
