---
title: Разбор типовых сбоев деплоя
status: stable
last-updated: 2026-06-13
area: runbooks
---

# Runbook: разбор типовых сбоев деплоя

Справочник по сбоям публикации kube_ci: симптом, вероятная причина, проверка,
решение. Структура -- от ошибок сборки и push образов к ошибкам рендера,
старту подов и доступу снаружи. Команды диагностики собраны в конце.

Полный сценарий публикации -- в [deploy.md](deploy.md) и
[first-deploy.md](first-deploy.md); подключение к кластеру -- в
[cluster-connection.md](cluster-connection.md); секреты -- в
[secrets-setup.md](secrets-setup.md).

## Ошибка TLS или registry при push образов

Симптом: converge падает на push образов с ошибкой проверки сертификата или
отказом HTTPS на хосте `registry-<NODE_IP>.nip.io`.

Причина: in-cluster registry отдаёт self-signed HTTPS, а insecure-послабления не
выставлены. werf задаёт их через env-переменные
([`k8s_defs`](../../kube_ci/dev/k8s_defs)), потому что cli-флаги до stage-storage
не доходят.

Проверка:

```bash
env | grep -E 'WERF_INSECURE_REGISTRY|WERF_SKIP_TLS_VERIFY_REGISTRY'
curl -sI http://registry-<NODE_IP>.nip.io/v2/
```

Решение: запускать converge через `00-build-deploy.sh`, который делает
`source k8s_defs` и экспортирует обе переменные. Дополнительно нода должна
доверять registry как insecure (containerd/Docker) -- см.
[requirements.md](../kubernetes/requirements.md) и
[cluster-connection.md](cluster-connection.md).

## converge падает по timeout

Симптом: converge висит и завершается по истечении `--timeout=300`, релиз
откатывается.

Причина: ресурсы релиза не вышли в Ready за отведённое время (под не стартует,
образ не тянется, БД не инициализировалась). converge идёт с `--atomic`, поэтому
неудачный релиз откатывается целиком -- частично выкаченного состояния не остаётся.

Проверка: пока converge ещё идёт, в соседней сессии смотреть события и поды
неймспейса:

```bash
kubectl -n <NAMESPACE>-<ENVNAME> get pods
kubectl -n <NAMESPACE>-<ENVNAME> get events --sort-by=.lastTimestamp
```

Решение: устранить корневую причину (она же видна в событиях -- ImagePullBackOff,
CrashLoop, нехватка ресурсов) и повторить converge. Параметры `--atomic` и
`--timeout` зашиты в [`utils/03-werf-converge.sh`](../../kube_ci/utils/03-werf-converge.sh).

## Отсутствует WERF_SECRET_KEY при рендере секретов

Симптом: converge падает на этапе рендера с ошибкой расшифровки `secrets-<env>.yaml`
(нет ключа или ключ не тот).

Причина: `deploy()` добавляет `--secret-values=.helm/secrets-<env>.yaml`, когда
файл есть, и werf требует ключ для его расшифровки. Ключ не задан или не совпадает
с тем, которым файл шифровали.

Проверка:

```bash
echo "${WERF_SECRET_KEY:+key set}"
```

Решение: экспортировать корректный `WERF_SECRET_KEY` (или положить файл ключа) --
см. [secrets-setup.md](secrets-setup.md). Если ключ сменили, секреты надо было
перешифровать ротацией; иначе старый файл не расшифруется.

## ImagePullBackOff

Симптом: под в статусе `ImagePullBackOff` или `ErrImagePull`.

Причина: образ отсутствует в registry под ожидаемым тегом, либо нода не может
достучаться до `registry-<NODE_IP>.nip.io` (insecure-доверие не настроено на ноде).

Проверка:

```bash
kubectl -n <NAMESPACE>-<ENVNAME> describe pod <pod>   # секция Events: тег и причина
```

Решение: убедиться, что converge опубликовал образы без ошибок (push прошёл,
см. раздел про TLS/registry) и что нода доверяет registry как insecure
([requirements.md](../kubernetes/requirements.md)). Тег образов завязан на
`CI_TAG` из [`.helm/def.sh`](../../apps/app1-java-react/.helm/def.sh) -- проверить,
что версия из `VERSION` совпадает с опубликованной.

## Под не стартует (инициализация БД)

Симптом: под приложения в `CrashLoopBackOff` или ждёт БД; под Postgres стартует,
но схема пуста.

Причина: init-скрипты БД лежат в ConfigMap (`db-init-configmap`) и применяются при
первом старте Postgres. Если том БД уже существует с прежним состоянием, init не
переигрывается; если ConfigMap пуст или не смонтирован -- схема не создаётся.

Проверка:

```bash
kubectl -n <NAMESPACE>-<ENVNAME> logs <postgres-pod>
kubectl -n <NAMESPACE>-<ENVNAME> get configmap
```

Решение: разобрать логи Postgres и приложения. Модель инициализации БД и
db-init-configmap -- в [postgres-and-init.md](../products/postgres-and-init.md).
Для чистой переинициализации БД нужен сброс тома (учитывая, что данные пропадут).

## Ingress 404 или хост не резолвится

Симптом: запрос к `http://<app>-<env>-<NODE_IP>.nip.io/` возвращает 404 либо хост
вообще не резолвится.

Причина: хост строится по схеме `<app>-<env>-<NODE_IP>.nip.io`. Несовпадение
`NODE_IP` в хосте и фактического IP ноды (`nip.io` зашивает IP в имя), отсутствие
Ingress или маршрута пути -- частые причины. Маршрут `/pgadmin` рендерится только
при `pgadmin.enabled`.

Проверка:

```bash
kubectl -n <NAMESPACE>-<ENVNAME> get ingress
kubectl -n <NAMESPACE>-<ENVNAME> describe ingress <name>
nslookup <app>-<env>-<NODE_IP>.nip.io
```

Решение: сверить хост из вывода postdeploy с `CI_URL` в
[`.helm/def.sh`](../../apps/app1-java-react/.helm/def.sh) и фактическим `NODE_IP`.
Схема хостов и таблица маршрутов пути -- в [ingress.md](../kubernetes/ingress.md).

## Неверный контекст kubectl или не тот неймспейс

Симптом: операции идут не в том кластере или ресурсы «пропали» -- их ищут не в том
неймспейсе.

Причина: активен чужой контекст kubectl, либо текущий неймспейс контекста сбит.
После converge `deploy()` сам ставит текущим неймспейс продукта
(`kubectl config set-context --current --namespace=<NAMESPACE>-<ENVNAME>`).

Проверка:

```bash
kubectl config current-context
kubectl config view --minify -o jsonpath='{..namespace}'
```

Решение: выбрать корректный контекст и явно указывать неймспейс в командах
(`-n <NAMESPACE>-<ENVNAME>`). Параметры контекста -- в
[cluster-connection.md](cluster-connection.md).

## Где смотреть логи и состояние

```bash
kubectl -n <NAMESPACE>-<ENVNAME> get pods
kubectl -n <NAMESPACE>-<ENVNAME> logs <pod> [-c <container>]
kubectl -n <NAMESPACE>-<ENVNAME> describe pod <pod>
kubectl -n <NAMESPACE>-<ENVNAME> get events --sort-by=.lastTimestamp
```

Дашборд кластера (headlamp) поднимается через port-forward --
[`kube_ci/dev/dashboard.sh`](../../kube_ci/dev/dashboard.sh) берёт `KUBECONTEXT`
из `k8s_defs` и пробрасывает порт на сервис headlamp:

```bash
cd kube_ci/dev
./dashboard.sh        # http://localhost:8088 (можно передать другой порт)
```

## Связанные статьи

- [deploy.md](deploy.md) -- три базовые операции kube_ci
- [first-deploy.md](first-deploy.md) -- полная последовательность деплоя
- [cluster-connection.md](cluster-connection.md) -- подключение и контекст
- [secrets-setup.md](secrets-setup.md) -- ключ и зашифрованные значения
- [ingress.md](../kubernetes/ingress.md) -- хосты и маршрутизация
- [postgres-and-init.md](../products/postgres-and-init.md) -- инициализация БД
