# app1-java-react

`app1-java-react` -- демо-продукт на стеке React (фронт) и Spring Boot (бэкенд)
с PostgreSQL и pgAdmin. Эта статья разбирает его состав от исходников до образов:
из чего собирается каждая часть, как описаны образы в `werf.yaml` и чем
отличаются dev- и prod-формы. Контракт продукта и общая раскладка манифестов уже
описаны -- здесь только то, что специфично для этого стека. Сопоставление с
вторым продуктом -- в [overview.md](overview.md); набор объектов чарта -- в
[../kubernetes/specifications.md](../kubernetes/specifications.md).

## Бэкенд: Spring Boot

Бэкенд -- Spring Boot 3.2.5 на Java 17, менеджер пакетов и сборки Maven
([`backend/pom.xml`](../../apps/app1-java-react/backend/pom.xml)). Подключены
стартеры web, actuator и jdbc, драйвер PostgreSQL и springdoc для swagger-ui.
Приложение целиком работает под context-path `/api`
([`application.yaml`](../../apps/app1-java-react/backend/src/main/resources/application.yaml)),
чтобы swagger-ui и его ассеты попали под путь, который Ingress маршрутизирует на
бэкенд. Подключение к базе берётся из переменных `DB_HOST`, `DB_PORT`, `DB_NAME`,
`DB_USER`, `DB_PASSWORD` -- их подаёт ConfigMap и Secret чарта.

Actuator вынесен на отдельный порт 8081 (вне `/api`), на нём открыты только
health-эндпойнты с включёнными probe-группами. Это разводит прикладной трафик
(порт 8080) и служебные пробы (порт 8081): readiness и liveness Kubernetes
бьют по `/actuator/health/readiness` и `/actuator/health/liveness` на 8081, не
задевая `/api`.

## Сборка бэкенда: multi-stage Dockerfile

Prod-образ собирается многоступенчатым
[`backend/Dockerfile`](../../apps/app1-java-react/backend/Dockerfile). Стадия
`builder` на `maven:3.9-eclipse-temurin-17` сначала тянет зависимости
(`mvn dependency:go-offline` по одному `pom.xml`), затем собирает jar
(`mvn package -DskipTests`). Слой зависимостей отделён от слоя исходников и
маунтит кеш `/root/.m2` через BuildKit, поэтому пересборка без изменения
зависимостей не перекачивает их заново. `finalName` в pom фиксирует имя артефакта
`target/app.jar`, чтобы рантайм-стадия копировала предсказуемый путь.

Рантайм-стадия -- `eclipse-temurin:17-jre`: только JRE, без Maven и JDK. Образ
запускается под non-root пользователем (uid 10001), `ENTRYPOINT` --
`java -jar /app/app.jar`. Build-аргумент `BUILD_HASH` записывается в
`/app/.build-info`.

Dev-образ -- отдельный
[`backend/Dockerfile.dev`](../../apps/app1-java-react/backend/Dockerfile.dev) с
полным Maven и JDK, git, openssh-client и passwordless sudo. Исходники в этот
образ не кладутся -- они клонируются в том `/workspace` init-контейнером уже в
кластере. Кеши Maven (`~/.m2`) и `.vscode-server` уводятся симлинками в
persistent-том `homeapp`. `ENTRYPOINT` dev-образа -- `sleep infinity`: под не
запускает приложение, а держится живым, чтобы разработчик зашёл в него по VS Code
Remote. Подробнее режим -- в
[../delivery/dev-in-cluster.md](../delivery/dev-in-cluster.md).

## Фронтенд: React + Vite

Фронт -- React 18 на Vite 5, менеджер пакетов pnpm 9.12
([`frontend/package.json`](../../apps/app1-java-react/frontend/package.json)).
Сборка `tsc -b && vite build`. Версия фронта берётся из `package.json` и
подставляется в код как константа `__APP_VERSION__` через `define` в
[`vite.config.ts`](../../apps/app1-java-react/frontend/vite.config.ts).

Содержимое страницы демонстрационное
([`frontend/src/App.tsx`](../../apps/app1-java-react/frontend/src/App.tsx)):
компонент запрашивает `/api/v1/version` и `/api/v1/items` у бэкенда и выводит
версию фронта, версию бэкенда и таблицу записей из БД. Это и есть весь
прикладной слой -- он существует, чтобы показать сквозную цепочку фронт ->
бэкенд -> база.

## Сборка фронтенда: build + nginx

Prod-образ
([`frontend/Dockerfile`](../../apps/app1-java-react/frontend/Dockerfile)) --
двухстадийный: стадия `builder` на `node:20-alpine` ставит зависимости через
pnpm (corepack) с кешем pnpm-store и собирает статику в `dist`; рантайм-стадия
на `nginx:1.27-alpine` копирует `dist` в `/usr/share/nginx/html`. Дефолтный
конфиг nginx удаляется, на его место кладётся
[`frontend/nginx.conf`](../../apps/app1-java-react/frontend/nginx.conf): сервер
слушает 8080, ассеты под `/assets/` отдаются с годовым immutable-кешем,
а всё остальное -- через `try_files ... /index.html` (fallback на index для
SPA-маршрутов).

Dev-образ фронта
([`frontend/Dockerfile.dev`](../../apps/app1-java-react/frontend/Dockerfile.dev))
устроен так же, как dev-образ бэкенда: полный node с pnpm, sleep infinity,
исходники из `/workspace`, кеши через симлинки в `homeapp`.

## Образы в werf.yaml

[`werf.yaml`](../../apps/app1-java-react/werf.yaml) не перечисляет образы напрямую
-- он подключает файлы из каталога `.werf-partial/` через `Files.Glob` и `tpl`.
Каждый partial -- условный фрагмент, который рендерится только в своём окружении
по переменной `ENVNAME`:

| Partial | Условие | image | dockerfile |
|---|---|---|---|
| `backend-prod.yaml` | `ENVNAME != dev` | `backend` | `backend/Dockerfile` |
| `backend-dev.yaml` | `ENVNAME == dev` | `backend-dev` | `backend/Dockerfile.dev` |
| `frontend-prod.yaml` | `ENVNAME != dev` | `frontend` | `frontend/Dockerfile` |
| `frontend-dev.yaml` | `ENVNAME == dev` | `frontend-dev` | `frontend/Dockerfile.dev` |

Так в prod werf собирает образы `backend` и `frontend`, в dev -- `backend-dev`
и `frontend-dev`, и одно окружение не тянет образы другого. Контекст сборки у
prod-образов -- подкаталог (`backend`, `frontend`), у dev-образов -- корень
продукта (`.`), потому что dev-`Dockerfile` копирует install-скрипты из общего
дерева. Секция `cleanup.keepPolicies` оставляет по два последних образа на
git-ссылку.

## dev и prod деплоймент

Какие манифесты попадут в кластер, решает `.Values.env`, который приходит из
`values-<env>.yaml`.

В prod бэкенд и фронт -- это Deployment
([`030-backend-prod.yaml`](../../apps/app1-java-react/.helm/templates/030-backend-prod.yaml),
[`040-frontend-prod.yaml`](../../apps/app1-java-react/.helm/templates/040-frontend-prod.yaml))
с собранными prod-образами через `.Values.werf.image`. Бэкенд открывает порты
8080 и 8081, пробы бьют в actuator на 8081. Число реплик -- по два на бэкенд и
фронт ([`values-prod.yaml`](../../apps/app1-java-react/.helm/values-prod.yaml)).
pgAdmin в prod выключен.

В dev бэкенд и фронт -- StatefulSet с одной репликой
([`031-backend-dev.yaml`](../../apps/app1-java-react/.helm/templates/031-backend-dev.yaml),
[`041-frontend-dev.yaml`](../../apps/app1-java-react/.helm/templates/041-frontend-dev.yaml))
на dev-образах. Под получает два persistent-тома (`workspace`, `homeapp`),
init-контейнер `prepare-dev-env` готовит окружение, смонтирован ssh-ключ
`id-rsa-vcs`. Прикладное приложение в dev-поде не запущено (sleep infinity) --
его запускает разработчик вручную внутри пода. pgAdmin в dev включён
([`values-dev.yaml`](../../apps/app1-java-react/.helm/values-dev.yaml)). Service
бэкенда и фронта в обеих формах называется одинаково (`app1-java-react-backend`,
`app1-java-react-frontend`), поэтому Ingress не зависит от выбранной формы.

## Плюсы, минусы, безопасность стека

Сильные стороны. Multi-stage сборка даёт лёгкий рантайм-образ -- в prod уезжает
JRE без Maven и JDK, в фронте -- nginx со статикой без node. BuildKit-кеш по
`pom.xml` и pnpm-store ускоряет повторные сборки. actuator на отдельном порту
аккуратно разводит пробы и прикладной трафик. Образы запускаются под non-root.

Ограничения. JVM-рантайм заметно тяжелее по памяти и времени старта, чем
аналогичный Python-сервис; пробы выставлены с запасом по `initialDelaySeconds`
именно под прогрев JVM. Чарт не задаёт `requests`/`limits`, поэтому ресурсная
изоляция держится на дефолтах кластера (см.
[../kubernetes/specifications.md](../kubernetes/specifications.md)).

Безопасность. Пароль базы по умолчанию лежит в открытом виде в
[`values.yaml`](../../apps/app1-java-react/.helm/values.yaml), креды pgAdmin --
демо-дефолты, трафик идёт по HTTP без редиректа на HTTPS. Это осознанные
послабления демо-контура; их разбор и боевые альтернативы (werf secret,
TLS) -- в [../concepts/security-and-tradeoffs.md](../concepts/security-and-tradeoffs.md).

## Связанные статьи

- [overview.md](overview.md) -- сопоставление с app2-python-angular.
- [app2-python-angular.md](app2-python-angular.md) -- симметричный разбор
  второго продукта.
- [postgres-and-init.md](postgres-and-init.md) -- PostgreSQL и init.sql.
- [pgadmin.md](pgadmin.md) -- pgAdmin как вспомогательный сервис.
- [../kubernetes/specifications.md](../kubernetes/specifications.md) -- объекты
  чарта, dev/prod-формы, образы.
- [../kubernetes/ingress.md](../kubernetes/ingress.md) -- маршрутизация `/api`,
  `/pgadmin`, `/` на сервисы продукта.
- [../delivery/dev-in-cluster.md](../delivery/dev-in-cluster.md) -- dev-поды и
  разработка внутри кластера.
- [../delivery/versioning.md](../delivery/versioning.md) -- VERSION и CI_TAG.
- [../../apps/README.md](../../apps/README.md) -- контракт продукта.
