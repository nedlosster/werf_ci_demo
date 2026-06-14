# Runbook: полный цикл теста деплоя

Сквозной прогон всех базовых операций kube_ci по обоим окружениям и обоим
продуктам: снос -> очистка -> сборка и развёртывание четырёх вариантов
(dev + prod для app1 и app2) -> smoke -> bump версии -> повторный деплой ->
повторный smoke. Цель -- за один проход проверить, что контур публикует,
обновляет и проверяется без ручного вмешательства, а bump версии корректно
выкатывается (zero-downtime у prod-форм, OnDelete у Postgres).

Сценарий рассчитан на эксплуатационный нюанс демо: формы backend/frontend в
окружении `dev` -- это sandbox-поды (ENTRYPOINT `sleep infinity`), приложение
в них поднимается вручную. Поэтому dev-smoke ограничен инфраструктурной
частью, а сами приложения в dev стартуют отдельным шагом.

## Где выполнять

Весь цикл выполняется на сервере деплоя (там же, где живёт чек-аут kube_ci и
есть доступ к кластеру и registry). Рабочая машина -- только `git push`; на
сервере деплоя -- `git pull` и прогон скриптов. Деплой в prod -- точка
остановки: выполняется только с разрешения Архитектора.

Все примеры host-ов используют плейсхолдер `<NODE_IP>` -- фактический IP узла
берётся из `kube_ci/<env>/k8s_defs` (`NODE_IP`, переопределяется через
`K8S_NODE_IP`). Host продукта формируется из `CI_URL` в `.helm/def.sh`.

## Предусловия

- Кластер развёрнут и доступен; контекст kubectl задан в `<env>/k8s_defs`
  (см. [cluster-connection.md](cluster-connection.md)).
- `werf` подтянут через `trdl use werf 2 stable`.
- Ключ `WERF_SECRET_KEY` доступен (см. [secrets-setup.md](secrets-setup.md)).
- Продукты подтянуты в оба окружения:

  ```bash
  cd kube_ci/dev  && ./pull_products.sh
  cd ../prod && ./pull_products.sh
  ```

  В каждом окружении `productlist` (копия `productlist_official`) содержит оба
  продукта.

## Обзор шагов

| # | Шаг | dev | prod |
|---|-----|-----|------|
| 1 | Снос всех профилей | `./01-dismiss.sh --all` | `./01-dismiss.sh --all` |
| 2 | Очистка stages | `./02-purge-stages.sh` | `./02-purge-stages.sh` |
| 3 | Сборка + деплой (4 варианта) | `./00-build-deploy.sh --all` | `./00-build-deploy.sh --all` |
| 4 | Ручной старт приложений в dev | см. ниже | -- |
| 5 | Smoke | `./04-smoke.sh --all` | `./04-smoke.sh --all` |
| 6 | Bump версии всех продуктов | `../utils/bump-version.sh all` | (та же команда) |
| 7 | Повторный деплой 4 вариантов | `./00-build-deploy.sh --all` | `./00-build-deploy.sh --all` |
| 8 | Повторный smoke | `./04-smoke.sh --all` | `./04-smoke.sh --all` |

Версия (`VERSION`) общая для dev и prod каждого продукта -- bump на шаге 6
делается один раз на продукт и затрагивает оба окружения. Команда из любого
каталога окружения; ниже -- из `kube_ci/prod`.

## Шаг 1. Снос всех профилей

```bash
cd kube_ci/dev  && ./01-dismiss.sh --all
cd ../prod && ./01-dismiss.sh --all
```

`werf dismiss` снимает релиз вместе с неймспейсом. Без аргумента скрипт
отказывает -- защита от случайного снятия всего. После сноса неймспейсы
`<NAMESPACE>-dev` и `<NAMESPACE>-prod` каждого продукта пропадают.

## Шаг 2. Очистка stages

```bash
cd kube_ci/dev  && ./02-purge-stages.sh
cd ../prod && ./02-purge-stages.sh
```

Сбрасывает локальный кеш сборки werf по каждому продукту через
`werf host purge --force --project-name <APPNAME>` (см.
`kube_ci/utils/05-purge-stages-local.sh`). Так следующий `converge` собирает
образы начисто.

## Шаг 3. Сборка и развёртывание четырёх вариантов

`converge` собирает образы, публикует в in-cluster registry и разворачивает
релиз. Сборка двух стеков (Spring/Maven и FastAPI/Angular) долгая, поэтому
запускать её удобнее отсоединённо, с логом и поллингом, чтобы прогон не
блокировал сессию.

```bash
cd kube_ci/dev
setsid bash -c './00-build-deploy.sh --all' >/tmp/deploy-dev.log 2>&1 < /dev/null &
# поллинг:
tail -f /tmp/deploy-dev.log
```

То же для prod (отдельный лог `/tmp/deploy-prod.log`). Окончание converge --
по строке вывода об успешном релизе в `tail` и завершению процесса
(`pgrep -af 00-build-deploy`).

### Проверка rollout prod-форм (zero-downtime)

prod-формы backend/frontend развёрнуты `Deployment` со стратегией
`RollingUpdate` (`maxUnavailable: 0`). После converge подтвердить, что
выкатка завершилась без простоя:

```bash
NS=app1-java-react-prod
kubectl rollout status deploy/app1-java-react-backend  -n "$NS"
kubectl rollout status deploy/app1-java-react-frontend -n "$NS"
```

Аналогично для `app2-python-angular-prod` (имена `app2-python-angular-backend`
/ `-frontend`).

### Наблюдение Postgres StatefulSet

База развёрнута `StatefulSet` со стратегией `updateStrategy: OnDelete` --
обычный converge под Postgres не пересоздаёт. Зафиксировать стартовое значение
RESTARTS для последующей проверки на шаге 7:

```bash
kubectl get pod -n "$NS" -l component=postgres \
  -o custom-columns=NAME:.metadata.name,RESTARTS:.status.containerStatuses[0].restartCount
```

## Шаг 4. Ручной старт приложений в dev-песочницах

dev-формы backend/frontend -- sandbox-поды (`sleep infinity`); app-URL отдаёт
502, пока приложение не запущено вручную. Исходники монорепо смонтированы в
поде по пути `/workspace/werf_ci_demo`. Зайти в нужный под и стартовать
сервис на порту 8080 (на этот порт смотрит сервис ingress).

Вход в под (пример для backend app1, неймспейс `app1-java-react-dev`):

```bash
kubectl exec -it -n app1-java-react-dev \
  statefulset/app1-java-react-backend-dev -- bash
cd /workspace/werf_ci_demo/apps/app1-java-react/backend
```

Команды старта, проверенные в прогоне (порт 8080, host 0.0.0.0):

| Вариант | Под (StatefulSet) | Команда старта |
|---|---|---|
| app1 backend | `app1-java-react-backend-dev` | `mvn -q -DskipTests spring-boot:run` |
| app2 backend | `app2-python-angular-backend-dev` | `pip install -e . && python -m uvicorn app2.main:app --host 0.0.0.0 --port 8080` |
| app1 frontend | `app1-java-react-frontend-dev` | `npm install && ./node_modules/.bin/vite --host 0.0.0.0 --port 8080` |
| app2 frontend | `app2-python-angular-frontend-dev` | `./node_modules/.bin/ng serve --host 0.0.0.0 --port 8080` |

Нюансы (из прогона):

- app1 frontend -- запускать `vite` напрямую через `./node_modules/.bin/vite`,
  НЕ через corepack/pnpm: corepack падает на `mkdir .cache/node/corepack`.
- app2 frontend -- запускать `ng` напрямую через `./node_modules/.bin/ng`, НЕ
  `npx ng` (тянет посторонний пакет). Флаг `--disable-host-check` в Angular 18
  удалён -- не использовать.

Старт сервиса блокирует сессию пода; держать его в отдельном окне/панели или
под `setsid ... &` с логом, аналогично шагу 3.

## Шаг 5. Smoke

```bash
cd kube_ci/dev  && ./04-smoke.sh --all
cd ../prod && ./04-smoke.sh --all
```

`04-smoke.sh` (обёртка над `kube_ci/utils/07-smoke.sh`) печатает таблицу
HTTP-кодов и возвращает ненулевой код при провале обязательной проверки.

- dev: pgAdmin (`/pgadmin/` -> 200/302) и факт Running подов продукта
  (read-only `kubectl get pods`). app-URL в dev не проверяется -- см. шаг 4.
- prod: фронт `/` -> 200, бек `/api/v1/version` -> 200 (обязательные); swagger
  (`/api/swagger-ui/index.html` у app1) либо docs (`/api/docs` у app2) и
  `/api/v1/items` -> 200 (опциональные, на код возврата не влияют).

Host берётся из `CI_URL` продукта (например, `app1-java-react-prod-<NODE_IP>.nip.io`).

## Шаг 6. Bump версии всех продуктов

```bash
cd kube_ci/prod
../utils/bump-version.sh all          # инкремент patch у app1 и app2
# либо явная версия: ../utils/bump-version.sh all 0.2.0
```

`bump-version.sh` -- обёртка над `apps/<product>/scripts/set-version.sh`,
синхронизирует все файлы версии продукта. `VERSION` общий для dev и prod,
поэтому достаточно одного вызова на продукт.

## Шаг 7. Повторный деплой четырёх вариантов

Повторить шаг 3 для dev и prod (отсоединённый converge + поллинг). Это
проверка пути обновления версии:

- prod backend/frontend -- `kubectl rollout status` (как в шаге 3) должен
  завершиться без простоя (zero-downtime, `maxUnavailable: 0`).
- Postgres StatefulSet -- сравнить RESTARTS с зафиксированным на шаге 3:
  значение НЕ должно вырасти (`RESTARTS=0`). Это валидация стратегии
  `OnDelete`: converge с новой версией приложения не трогает под базы, данные
  на PVC сохраняются. Если база требует обновления намеренно -- под
  пересоздают вручную (`kubectl delete pod <app>-postgres-0`, см.
  [deploy.md](deploy.md)).

После prod-деплоя в dev приложения снова поднимают вручную (шаг 4), если
поды были пересозданы.

## Шаг 8. Повторный smoke

```bash
cd kube_ci/dev  && ./04-smoke.sh --all
cd ../prod && ./04-smoke.sh --all
```

Критерий завершения цикла: prod-smoke по обоим продуктам -- OK (обязательные
проверки пройдены), prod rollout завершён без простоя, RESTARTS Postgres не
вырос. dev-smoke -- pgAdmin доступен и поды в Running; app-URL проверяется
вручную после старта приложений (шаг 4).

## Связанные runbook'и

- [deploy.md](deploy.md) -- базовые операции (публикация, снос, очистка) по
  отдельности.
- [rollback.md](rollback.md) -- откат релиза на ранее опубликованную ревизию.
- [troubleshooting.md](troubleshooting.md) -- разбор типовых сбоев деплоя.
- [cluster-connection.md](cluster-connection.md) -- подключение к кластеру,
  kubeconfig, контекст, insecure-registry.
