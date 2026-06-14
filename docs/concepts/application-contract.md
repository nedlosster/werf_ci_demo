# Контракт приложения

Контракт `.helm/def.sh` -- точка развязки между контуром доставки и продуктом.
`kube_ci` не содержит ничего специфичного для приложения: всё, что ему нужно, он
читает из переменных и файлов продукта по фиксированному соглашению, не зная его
внутреннего устройства. Из этой развязки и вырастает универсальность схемы --
Java/React и Python/Angular разворачиваются одним и тем же кодом доставки. Эта
статья собирает контракт целиком: ядро `.helm/def.sh`, набор переменных, поток
их чтения в converge, обязательные и опциональные файлы, иерархию values,
параметры кластера и секретов, подключение продукта в окружении и минимальный
набор для нового приложения. Поток доставки в целом разобран в
[Доставке в Kubernetes](delivery-to-k8s.md); здесь -- именно граница «контур --
продукт».

## `.helm/def.sh` -- ядро контракта

`.helm/def.sh` -- shell-файл продукта, описывающий окружения как функции. Одна
функция на окружение, имя функции совпадает со значением в `productlist`
соответствующего окружения (`[<product>]=<env-функция>`). Функция экспортирует
переменные, которые контур прокидывает в werf. Пример из
[app1-java-react](../../apps/app1-java-react/.helm/def.sh) с плейсхолдером
`<NODE_IP>` вместо адреса узла кластера:

```bash
function dev() {
    export APPNAME=app1-java-react
    export ENVNAME=dev
    export NAMESPACE=app1-java-react
    export CI_URL=app1-java-react-dev-<NODE_IP>.nip.io
    export CI_TAG=$(cat VERSION)
}

function prod() {
    export APPNAME=app1-java-react
    export ENVNAME=prod
    export NAMESPACE=app1-java-react
    export CI_URL=app1-java-react-prod-<NODE_IP>.nip.io
    export CI_TAG=$(cat VERSION)
}
```

Окружения отличаются `ENVNAME` и `CI_URL`; `APPNAME` и `NAMESPACE` общие. Хост
ingress строится через `nip.io` от адреса узла кластера, поэтому реальный IP
живёт только в `def.sh` продукта, а не в коде контура.

## Переменные контракта

Контракт делит переменные на обязательные и опциональные. Источник всех --
env-функция `def.sh`; потребитель -- `deploy()` из
[`utils/03-werf-converge.sh`](../../kube_ci/utils/03-werf-converge.sh).

| Переменная | Источник | Потребитель | Механизм | Пример |
|---|---|---|---|---|
| `APPNAME` | def.sh, обязательна | converge | `WERF_REPO=$REGISTRY/$APPNAME`, явный `--set APPNAME` | `app1-java-react` |
| `ENVNAME` | def.sh, обязательна | converge | `--env`, неймспейс `<NAMESPACE>-<ENVNAME>` | `dev` |
| `CI_URL` | def.sh, обязательна | helm | `--set ci_url=...` (как `CI_*`) | `app1-java-react-dev-<NODE_IP>.nip.io` |
| `CI_TAG` | def.sh, `$(cat VERSION)` | werf | `--use-custom-tag=%image%-$CI_TAG`, исключён из `--set` | `0.1.0` |
| `NAMESPACE` | def.sh, опциональна | converge | неймспейс; default = `APPNAME` | `app1-java-react` |
| любые `CI_*` | def.sh, опциональны | helm | `--set <имя в нижнем регистре>=<значение>` | `CI_FOO -> --set ci_foo=...` |

`CI_URL` формально относится к классу `CI_*` и пробрасывается в helm как
`ci_url`. `CI_TAG` тоже начинается с `CI_`, но обрабатывается отдельно (см.
ниже) и в `--set` не попадает.

## Как контур читает контракт

`deploy()` подключает контракт через `source .helm/def.sh` и вызывает
env-функцию окружения (`env=$1 && $env`). Дальше -- разбор экспортированных
переменных:

- если `NAMESPACE` пуст, берётся `APPNAME`; целевой неймспейс --
  `KUBE_NAMESPACE=<NAMESPACE>-<ENVNAME>`;
- репозиторий образов -- `WERF_REPO=$REGISTRY/$APPNAME`;
- все `CI_*`-переменные перебираются по именам реально экспортированных
  (`${!CI_@}`), значение берётся косвенно (`${!v}`) -- это безопасно к пробелам,
  кавычкам и спецсимволам и не требует разбора текста функции:

  ```bash
  ci_set_args=()
  for v in ${!CI_@}; do
    [ "$v" = "CI_TAG" ] && continue
    ci_set_args+=(--set "${v,,}=${!v}")
  done
  ```

- `CI_TAG` исключён из цикла и идёт отдельным тегом образов
  `--use-custom-tag=%image%-$CI_TAG` (источник версии -- файл `VERSION`, см.
  [версионирование](../delivery/versioning.md));
- сверх `CI_*` контур передаёт явные `--set APPNAME`, `--set DOMAIN`,
  `--set use_ngnix_virtualserver`.

Хуки выстроены вокруг converge: `predeploy.sh` запускается ДО converge (werf
читает `.helm/tmp/` при рендере секрета), `postdeploy.sh` -- ПОСЛЕ (обычно печать
URL развёрнутых ресурсов).

## Файлы контракта

| Файл | Путь | Назначение | Когда |
|---|---|---|---|
| def.sh | `.helm/def.sh` | env-функции окружений | обязательно |
| werf.yaml | `werf.yaml` (+ `.werf-partial/*.yaml` через `range Files.Glob`) | описание образов сборки | обязательно |
| Chart.yaml | `.helm/Chart.yaml` | метаданные helm-чарта | обязательно |
| VERSION | `VERSION` | версия для `CI_TAG` и тега образов | обязательно |
| predeploy.sh | `.helm/predeploy.sh` | хук ДО converge | опционально |
| postdeploy.sh | `.helm/postdeploy.sh` | хук ПОСЛЕ converge | опционально |
| require.sh | `.helm/require.sh` | хук перед сборкой | опционально |
| values | `.helm/values.yaml`, `.helm/values-<env>.yaml` | дефолты и переопределения окружения | values.yaml обязателен, env-вариант опционален |
| secrets | `.helm/secrets-<env>.yaml` (+ `.example`) | зашифрованные значения окружения | опционально |
| templates | `.helm/templates/` (числовые префиксы), `.helm/_helpers.tpl` | k8s-манифесты и хелперы | обязательно |
| set-version | `scripts/set-version.sh` | запись версии в `VERSION` | опционально |

`werf.yaml` собирает фрагменты сборки из `.werf-partial/*.yaml` циклом
`range .Files.Glob`, поэтому dev- и prod-формы образов лежат отдельными файлами.

## Конфиги и values

Values окружения формируются слиянием по возрастанию приоритета:

```
values.yaml -> values-<env>.yaml -> --secret-values -> --set
```

`--set` имеет высший приоритет и перекрывает всё предыдущее; именно через него
приходят `ci_url`, `APPNAME`, `DOMAIN` и прочие переменные контракта. Ключевые
блоки [`values.yaml`](../../apps/app1-java-react/.helm/values.yaml):

- `env` -- `dev` или `prod`, управляет рендером dev/prod-манифестов;
- `domain` -- базовый домен;
- `backend.{replicas,port}`, `frontend.{replicas,port}` -- реплики и порты;
- `postgres.{image,user,database,password,port,storageSize,storageClass}` --
  параметры базы;
- `pgadmin.{enabled,image,email,password}` -- вспомогательный pgAdmin;
- `dev.{workspaceSize,homeappSize,storageClass}` -- размеры томов dev-схемы;
- `secrets.*` -- значения из `--secret-values` (по умолчанию пусто, чарт берёт
  демо-дефолты).

## Среда кластера и секреты

Параметры кластера окружения задаёт `<env>/k8s_defs`:
`REGISTRY`, `KUBECONTEXT`, `KUBECONFIG`, а также `WERF_INSECURE_REGISTRY` и
`WERF_SKIP_TLS_VERIFY_REGISTRY` (env-переменные -- cli-флаги до stage-storage не
доходят). Они не входят в контракт продукта и переключают окружение независимо от
`.helm/`. Полный список требований к кластеру --
[требования к кластеру](../kubernetes/requirements.md).

Ключ расшифровки `secrets-<env>.yaml` ищется по приоритету:
`WERF_SECRET_KEY` -> `.werf_secret_key` -> `~/.werf/global_secret_key`. Подробно
-- [секреты](../delivery/secrets.md).

## Подключение продукта

Продукт попадает в деплой через `productlist` окружения (`kube_ci/<env>/`,
формат `[<product>]=<env-функция>`, шаблон -- `productlist_official`).
`pull_products.sh` создаёт каталог `products/` и связывает каждый продукт из
`productlist` symlink'ом на `apps/<product>`, после чего converge работает с ним
по локальному пути.

## Минимальный контракт нового продукта

Чтобы продукт деплоился контуром без правок `kube_ci`:

1. `.helm/def.sh` -- env-функция под каждое окружение (имя функции == значению в
   `productlist`); внутри -- `APPNAME`, `ENVNAME`, `CI_URL`, `CI_TAG=$(cat
   VERSION)`.
2. `werf.yaml` -- описание образов сборки.
3. `.helm/Chart.yaml` -- метаданные чарта.
4. `VERSION` -- файл с версией.
5. Строка в `productlist` окружения: `[<product>]=<env-функция>`.

Остальное (values-`<env>`, secrets, хуки, pgAdmin) -- опционально.

## Типичные ошибки

- Имя env-функции в `def.sh` не совпадает со значением в `productlist` --
  `$env` не вызывается, переменные не экспортируются.
- Нет `.helm/def.sh` -- `source` падает, продукт не деплоится.
- Пустой `CI_TAG` из-за отсутствующего `VERSION` -- образы тегируются без
  version-тега (`--use-custom-tag` не добавляется).

## Связанные статьи

- [Введение в werf](werf-intro.md)
- [Доставка в Kubernetes](delivery-to-k8s.md)
- [Операции kube_ci](../delivery/kube-ci-operations.md)
- [Один контур, два окружения](../delivery/dev-prod.md)
- [Версионирование](../delivery/versioning.md)
- [Секреты](../delivery/secrets.md)
- [Спецификации окружений](../kubernetes/specifications.md)
- [Контракт продукта (apps/README.md)](../../apps/README.md)
- [Глоссарий](../glossary.md)
