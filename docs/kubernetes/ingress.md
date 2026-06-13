# Ingress и доступ к продуктам

Статья описывает, как продукты становятся доступны снаружи кластера: единый
Ingress на продукт, хост вида `<...>.nip.io` и маршрутизация одного хоста на три
сервиса -- фронт, бэкенд и pgAdmin. Объекты, которые стоят за этими маршрутами,
разобраны в [specifications.md](specifications.md); требования к ingress-nginx и
registry -- в [requirements.md](requirements.md).

Каждый продукт публикуется одним Ingress
([`apps/<app>/.helm/templates/100-ingress.yaml`](../../apps/app1-java-react/.helm/templates/100-ingress.yaml))
с `ingressClassName: nginx`. Внешний контроллер -- ingress-nginx в кластере;
демо-приложения дополнительной балансировки не вводят.

## Хост на nip.io

Внешнее имя продукта задаёт `.Values.domain`. Значение приходит из окружения:
prod-дефолт в [`values.yaml`](../../apps/app1-java-react/.helm/values.yaml) --
заглушка `<app>.local`, а реальный публичный хост подставляет
[`values-<env>.yaml`](../../apps/app1-java-react/.helm/values-dev.yaml). Хосты
строятся по схеме `<app>-<env>-<NODE_IP>.nip.io`, например:

```
app1-java-react-dev-<NODE_IP>.nip.io
app1-java-react-prod-<NODE_IP>.nip.io
app2-python-angular-dev-<NODE_IP>.nip.io
app2-python-angular-prod-<NODE_IP>.nip.io
```

`nip.io` -- wildcard-DNS: любое имя, содержащее IP, резолвится в этот IP без
правки DNS. Поэтому хост окружения сразу указывает на ноду кластера, где
ingress-nginx принимает трафик. Тот же приём применяется к registry
(`registry-<NODE_IP>.nip.io`, см. [requirements.md](requirements.md)).

Хост дублируется в контракте [`.helm/def.sh`](../../apps/app1-java-react/.helm/def.sh)
как `CI_URL` -- kube_ci пробрасывает `CI_*` в helm через `--set` при converge, и
postdeploy-хук печатает итоговые URL после публикации.

## Маршрутизация одного хоста

Один Ingress раскладывает запросы по пути на три бэкенд-сервиса. Правила (в
порядке от частного к общему):

| Путь | pathType | Service | Порт |
|---|---|---|---|
| `/api` | Prefix | `<app>-backend` | `backend.port` (8080) |
| `/pgadmin` | Prefix | `<app>-pgadmin` | 80 (только при `pgadmin.enabled`) |
| `/` | Prefix | `<app>-frontend` | `frontend.port` (8080) |

Префикс `/api` уводит запросы на бэкенд, `/pgadmin` -- на pgAdmin, всё
остальное (`/`) -- на фронтенд. Маршрут `/pgadmin` рендерится только когда pgAdmin
включён, то есть в dev (`pgadmin.enabled: true`); в prod этого пути в Ingress
нет. Service-ы носят стабильные имена `<app>-backend` и `<app>-frontend`
независимо от dev/prod-формы пода, поэтому правила одинаковы для обоих окружений.

Аннотация `nginx.ingress.kubernetes.io/ssl-redirect: "false"` отключает
принудительный редирект на HTTPS -- продукты доступны по HTTP. Это согласуется с
insecure-режимом контура; компромисс описан в
[../concepts/security-and-tradeoffs.md](../concepts/security-and-tradeoffs.md).

## pgAdmin за тем же хостом

pgAdmin не получает отдельного хоста -- он живёт под префиксом `/pgadmin` того же
домена продукта. Чтобы веб-интерфейс работал из подкаталога, контейнеру задан
`SCRIPT_NAME=/pgadmin` (см.
[`050-pgadmin.yaml`](../../apps/app1-java-react/.helm/templates/050-pgadmin.yaml)).
Подключение к базе уже прописано в ConfigMap `servers.json`
([`050a-pgadmin-configmap.yaml`](../../apps/app1-java-react/.helm/templates/050a-pgadmin-configmap.yaml)):
host `<app>-postgres`, БД и пользователь из values. Доступ -- по адресу вида
`http://<app>-dev-<NODE_IP>.nip.io/pgadmin`.

## Доступ снаружи

Для обращения к продукту извне специальной настройки не требуется: хост nip.io
резолвится в IP ноды, ingress-nginx по `Host`-заголовку выбирает нужный Ingress,
а правила пути отдают запрос фронту, бэкенду или pgAdmin. Итоговые URL для
конкретного релиза печатает postdeploy-хук продукта; сценарий публикации -- в
[../runbooks/deploy.md](../runbooks/deploy.md).

## Плюсы, минусы, безопасность

Плюсы. Один хост nip.io на релиз с маршрутизацией по пути (`/`, `/api`,
`/pgadmin`) даёт внешний доступ без DNS-записей и без правки `/etc/hosts`: хост
сам резолвится в IP ноды. Один Ingress закрывает фронт, бэкенд и pgAdmin
продукта.

Минусы. Схема привязана к доступности nip.io и к IP ноды в имени хоста: смена
адреса ноды меняет URL релиза. Маршрутизация по одному хосту требует точных
правил пути -- их пересечение разводит трафик не туда.

Безопасность. Трафик идёт по HTTP без редиректа на HTTPS, а pgAdmin за тем же
хостом открывает веб-доступ к БД -- поэтому он ограничен dev. Разбор TLS и
боевых послаблений -- в
[Компромиссах и безопасности схемы](../concepts/security-and-tradeoffs.md).

## Связанные статьи

- [requirements.md](requirements.md) -- ingress-nginx, registry на nip.io,
  insecure-доступ.
- [specifications.md](specifications.md) -- Service-ы фронта, бэкенда и pgAdmin,
  на которые ссылается Ingress.
- [../concepts/security-and-tradeoffs.md](../concepts/security-and-tradeoffs.md) --
  почему трафик идёт по HTTP без редиректа.
- [../runbooks/deploy.md](../runbooks/deploy.md) -- публикация и печать URL.
