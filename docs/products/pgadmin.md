# pgAdmin

pgAdmin -- веб-клиент к PostgreSQL, который оба продукта поднимают как
вспомогательный сервис рядом с базой. Статья описывает, как он развёрнут, как
заранее подключён к базе продукта, как доступен через Ingress и почему включён
только в dev. Объект pgAdmin в общем наборе чарта упомянут в
[../kubernetes/specifications.md](../kubernetes/specifications.md), маршрутизация
`/pgadmin` -- в [../kubernetes/ingress.md](../kubernetes/ingress.md); здесь --
устройство самого сервиса.

## Развёртывание

pgAdmin описан шаблоном
[`050-pgadmin.yaml`](../../apps/app1-java-react/.helm/templates/050-pgadmin.yaml)
и весь обёрнут условием `{{- if .Values.pgadmin.enabled }}` -- если pgAdmin
выключен, ни одного объекта не создаётся. Под него рендерятся Service и
Deployment с одной репликой; стратегия обновления -- `Recreate` (старый под
сносится до старта нового, чтобы не конфликтовать за состояние). Образ --
`dpage/pgadmin4:8`, тянется из публичного registry напрямую. Контейнеру задан
`securityContext.fsGroup: 5050` под требования образа к правам на данные.

Из переменных окружения контейнер получает учётные данные администратора
(`PGADMIN_DEFAULT_EMAIL`, `PGADMIN_DEFAULT_PASSWORD`) из Secret
`<app>-pgadmin-secrets`, отключённый мастер-пароль
(`PGADMIN_CONFIG_MASTER_PASSWORD_REQUIRED: "False"`) и `SCRIPT_NAME: /pgadmin`.
Последняя переменная говорит pgAdmin, что он работает из подкаталога `/pgadmin`,
а не из корня домена -- без неё веб-интерфейс ломал бы свои ссылки за Ingress.

## Предзаданное подключение к базе

Подключение к базе не настраивается руками после запуска -- оно приходит готовым
из ConfigMap
[`050a-pgadmin-configmap.yaml`](../../apps/app1-java-react/.helm/templates/050a-pgadmin-configmap.yaml).
ConfigMap несёт файл `servers.json`, смонтированный в `/pgadmin4/servers.json`,
который pgAdmin читает при старте и заводит сервер автоматически. Параметры
сервера берутся из тех же values, что и сама база:

- `Host` -- `<app>-postgres` (имя Service базы внутри неймспейса);
- `Port` -- `postgres.port` (5432);
- `MaintenanceDB` и `Username` -- `postgres.database` и `postgres.user`
  (`app1`/`app2`);
- `SSLMode` -- `prefer`.

Так после публикации pgAdmin сразу показывает сервер продукта в дереве
подключений. Пароль к базе в `servers.json` не записан -- его вводят в UI при
первом подключении к серверу (это пароль из Secret `<app>-secrets`, тот же, что
получает postgres). Связь с базой разобрана в
[postgres-and-init.md](postgres-and-init.md).

## Доступ через Ingress

Отдельного хоста pgAdmin не получает -- он живёт под путём `/pgadmin` того же
домена продукта. Единый Ingress
([`100-ingress.yaml`](../../apps/app1-java-react/.helm/templates/100-ingress.yaml))
уводит префикс `/pgadmin` на Service `<app>-pgadmin` (порт 80), а `SCRIPT_NAME`
в контейнере делает интерфейс работоспособным из этого подкаталога. Маршрут
`/pgadmin` в Ingress рендерится только при `pgadmin.enabled`, поэтому в prod его
в правилах нет. Итоговый адрес -- вида `http://<app>-dev-<NODE_IP>.nip.io/pgadmin`.
Полная схема маршрутов -- в [../kubernetes/ingress.md](../kubernetes/ingress.md).

## Только в dev

pgAdmin включён в dev и выключен в prod. Управляет этим флаг `pgadmin.enabled`:
дефолт в [`values.yaml`](../../apps/app1-java-react/.helm/values.yaml) --
`false`, а
[`values-dev.yaml`](../../apps/app1-java-react/.helm/values-dev.yaml)
переопределяет его на `true`;
[`values-prod.yaml`](../../apps/app1-java-react/.helm/values-prod.yaml) явно
держит `false`. Логика разделения: pgAdmin -- инструмент разработки и отладки,
в dev им удобно смотреть, что лежит в базе, а в prod держать открытый
веб-доступ к базе незачем и вреднее.

## Зачем в демо-контуре

pgAdmin показывает, что вспомогательный сервис описывается тем же чартом, что и
основное приложение, и подключается к соседям через внутренние Service-имена и
общий Ingress. Это иллюстрация того, как в один релиз продукта входит не только
бэкенд с фронтом, но и сервисная обвязка, причём её появление в кластере
управляется одним флагом values без правок кода. Практически pgAdmin даёт
быстрый доступ к данным dev-базы без проброса портов.

## Плюсы, минусы, безопасность

Плюсы. pgAdmin даёт веб-доступ к базе без проброса портов и локального клиента;
подключение к серверу прописано заранее через configmap, поэтому открывать
консоль можно сразу. Сервис входит в тот же чарт и тот же Ingress, отдельной
установки не требует.

Минусы. pgAdmin поднимает дополнительный под и веб-консоль с прямым доступом к
БД, что расширяет поверхность атаки -- именно поэтому он включён только в dev и
выключен в prod. Креды и настройки заданы статически в values, под реальные
команды их пришлось бы выносить.

Безопасность. pgAdmin -- слабое место демо-контура по умолчанию, и это сделано
осознанно.

- Креды администратора -- демо-дефолты (`admin@example.com` / `admin`) в
  [`values.yaml`](../../apps/app1-java-react/.helm/values.yaml). В боевом
  контуре их место -- werf secret через `secrets-<env>.yaml`.
- Мастер-пароль pgAdmin отключён (`MASTER_PASSWORD_REQUIRED: "False"`) -- учётка
  доступна сразу после ввода логина администратора.
- Доступ идёт по HTTP без редиректа на HTTPS, как и остальной трафик продукта.
- pgAdmin даёт веб-доступ к базе данных -- именно поэтому он ограничен dev и
  выключен в prod.

Разбор всех послаблений демо и боевых альтернатив (werf secret, TLS) -- в
[../concepts/security-and-tradeoffs.md](../concepts/security-and-tradeoffs.md).

## Связанные статьи

- [postgres-and-init.md](postgres-and-init.md) -- база, к которой подключён
  pgAdmin.
- [overview.md](overview.md) -- pgAdmin среди общих частей двух продуктов.
- [app1-java-react.md](app1-java-react.md) -- состав первого продукта.
- [app2-python-angular.md](app2-python-angular.md) -- состав второго продукта.
- [../kubernetes/ingress.md](../kubernetes/ingress.md) -- маршрут `/pgadmin` и
  SCRIPT_NAME.
- [../kubernetes/specifications.md](../kubernetes/specifications.md) -- pgAdmin
  в общем наборе объектов чарта.
- [../concepts/security-and-tradeoffs.md](../concepts/security-and-tradeoffs.md) --
  демо-креды и доступ по HTTP.
