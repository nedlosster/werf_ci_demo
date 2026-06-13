# PostgreSQL и инициализация схемы

Оба продукта несут собственную базу PostgreSQL в своём неймспейсе, без внешнего
сервера БД. Статья описывает, как база поднимается чартом, как в неё попадает
начальная схема и почему отдельного миграционного инструмента в демо нет.
Различия между двумя продуктами здесь минимальны и сводятся к именам и
содержимому `init.sql`. Полный набор объектов чарта -- в
[../kubernetes/specifications.md](../kubernetes/specifications.md); общий обзор
продуктов -- в [overview.md](overview.md).

## PostgreSQL как StatefulSet

Postgres описан шаблоном
[`020-postgres.yaml`](../../apps/app1-java-react/.helm/templates/020-postgres.yaml)
и развёрнут StatefulSet-ом с одной репликой, а не Deployment-ом. Выбор
StatefulSet оправдан тем, что у базы есть состояние на диске: StatefulSet
связывает под со своим PersistentVolumeClaim через `volumeClaimTemplates`,
поэтому при пересоздании пода том `data` остаётся прежним.

Параметры тома и образа берутся из values: образ `postgres:16`, storageClass
`standard`, размер 5Gi, режим доступа `ReadWriteOnce`. Том монтируется в
`/var/lib/postgresql/data`, а `PGDATA` указывает на подкаталог `pgdata` внутри
него. Готовность пода проверяется readiness-пробой `pg_isready -U <user>`.
Рядом с базой создаётся Service с тем же именем (`<app>-postgres`) -- по нему
бэкенд и pgAdmin находят базу внутри неймспейса.

Учётные данные. Пользователь и имя БД приходят из `POSTGRES_USER` и
`POSTGRES_DB` (значения из
[`values.yaml`](../../apps/app1-java-react/.helm/values.yaml): `app1`/`app1` у
первого продукта, `app2`/`app2` у второго). Пароль контейнер получает из
`POSTGRES_PASSWORD` через `secretKeyRef` на Secret `<app>-secrets`, ключ
`DB_PASSWORD`. Сам пароль в демо задан дефолтом прямо в values
(`app1pass`/`app2pass`); в боевом контуре его место -- werf secret, см.
[../concepts/security-and-tradeoffs.md](../concepts/security-and-tradeoffs.md).

## Инициализация схемы из init.sql

Начальная схема не накатывается приложением и не лежит в манифесте напрямую --
она подаётся через штатный механизм образа postgres. Файл
[`.helm/files/init.sql`](../../apps/app1-java-react/.helm/files/init.sql)
вкладывается в ConfigMap
[`021-db-init-configmap.yaml`](../../apps/app1-java-react/.helm/templates/021-db-init-configmap.yaml)
через `.Files.Get`, и этот ConfigMap монтируется в каталог
`/docker-entrypoint-initdb.d` контейнера postgres. Образ postgres исполняет всё,
что лежит в этом каталоге, при первой инициализации кластера базы.

Ключевое слово -- «первой». Скрипты из `docker-entrypoint-initdb.d` запускаются,
только когда каталог данных пуст, то есть один раз за время жизни тома. На уже
инициализированной базе (под пересоздан, том сохранён) `init.sql` не
выполняется повторно. Поэтому изменение `init.sql` не доедет до существующей
базы само -- нужно пересоздать том или применить изменения вручную.

## Что в init.sql каждого продукта

Содержимое у обоих продуктов структурно одинаково и различается только
демо-данными. Каждый создаёт одну таблицу `items` и наполняет её тремя
записями:

```sql
CREATE TABLE IF NOT EXISTS items (
    id   SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    note TEXT
);
```

У app1-java-react
([`init.sql`](../../apps/app1-java-react/.helm/files/init.sql)) записи про
CI-сервер, сервис billing и базу данных; у app2-python-angular
([`init.sql`](../../apps/app2-python-angular/.helm/files/init.sql)) -- про
активы A-100/A-200/A-300. Таблица `items` -- та же, что фронт каждого продукта
показывает на главной странице, запрашивая `/api/v1/items` у бэкенда. Это
замыкает демонстрационную цепочку: запись из `init.sql` доходит до базы, бэкенд
читает её, фронт выводит.

## Миграций нет

Отдельного миграционного инструмента (Flyway, Liquibase, Alembic) в продуктах
нет -- это явный выбор демо, зафиксированный комментарием в самом `init.sql`
(«без миграторов»). Схема инициализируется один раз через
`docker-entrypoint-initdb.d` и дальше не версионируется. Для демо этого
достаточно: таблица одна, эволюции схемы нет.

Практическое следствие. Поскольку `init.sql` отрабатывает только на пустом
томе, повторная публикация продукта (`converge`) не меняет уже существующую
схему. Чтобы перезалить схему с нуля, нужно снести базу вместе с её томом --
например, через откат продукта `werf dismiss --with-namespace`, который удаляет
неймспейс целиком (см. [../runbooks/deploy.md](../runbooks/deploy.md)), и
опубликовать заново. В реальном продукте на месте `init.sql` стоял бы
миграционный инструмент, накатывающий изменения инкрементально.

## Сходства и различия двух продуктов

| Аспект | app1-java-react | app2-python-angular |
|---|---|---|
| Контроллер | StatefulSet, 1 реплика | StatefulSet, 1 реплика |
| Образ | `postgres:16` | `postgres:16` |
| Том data | 5Gi, ReadWriteOnce, standard | 5Gi, ReadWriteOnce, standard |
| Пользователь / БД | `app1` / `app1` | `app2` / `app2` |
| Пароль (демо) | `app1pass` в values | `app2pass` в values |
| Схема | `items` из init.sql | `items` из init.sql |
| Демо-записи | CI-сервер, billing, pg-01 | активы A-100/200/300 |
| Миграции | нет | нет |

Механика идентична -- различаются только имена и данные. Это и есть прямое
проявление общего шаблона чарта: база поднимается и инициализируется одинаково
независимо от языка бэкенда, который к ней обращается.

## Плюсы, минусы, безопасность

Плюсы. База идёт внутри чарта продукта StatefulSet'ом с постоянным томом и
инициализируется из `init.sql` через db-init-configmap, поэтому развёртывание
не требует внешнего сервиса БД. Схема и демо-записи воспроизводятся одинаково
при каждом первом старте.

Минусы. init.sql применяется только при пустом томе -- изменения схемы после
первого запуска инструмент не подхватит, а механизма миграций в демо нет.
Одна реплика StatefulSet без репликации не даёт отказоустойчивости.

Безопасность. Пароль базы хранится открыто в `values.yaml`, и в демо это
осознанно. Боевой контур переносит его в werf secret; разбор -- в
[Компромиссах и безопасности схемы](../concepts/security-and-tradeoffs.md) и
[Управлении секретами](../delivery/secrets.md).

## Связанные статьи

- [overview.md](overview.md) -- что общего и различного у двух продуктов.
- [app1-java-react.md](app1-java-react.md) -- бэкенд app1 и его обращение к БД.
- [app2-python-angular.md](app2-python-angular.md) -- бэкенд app2 и его
  обращение к БД.
- [pgadmin.md](pgadmin.md) -- веб-клиент к этой же базе.
- [../kubernetes/specifications.md](../kubernetes/specifications.md) -- объект
  PostgreSQL в общем наборе чарта.
- [../concepts/security-and-tradeoffs.md](../concepts/security-and-tradeoffs.md) --
  пароль БД в values против werf secret.
- [../runbooks/deploy.md](../runbooks/deploy.md) -- откат с удалением неймспейса
  и тома.
