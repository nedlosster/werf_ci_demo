# Продукты

Раздел описывает два демо-продукта, контрастных по стеку, которые ставит общий
CI-контур: React + Spring Boot (app1-java-react) и Angular + FastAPI
(app2-python-angular). Оба используют PostgreSQL и pgAdmin. Цель раздела --
показать, как разнородные приложения деплоятся по единому контракту
`.helm/def.sh`.

Контракт, по которому `kube_ci` работает с продуктом, описан в
[../../apps/README.md](../../apps/README.md).

## Статьи

- [overview.md](overview.md) -- обзор обоих продуктов, сопоставление стеков и
  что у них общее.
- [app1-java-react.md](app1-java-react.md) -- состав и сборка app1: Spring Boot,
  React + Vite, dev/prod-образы, описание в werf.yaml.
- [app2-python-angular.md](app2-python-angular.md) -- состав и сборка app2:
  FastAPI, Angular, dev/prod-образы, описание в werf.yaml.
- [postgres-and-init.md](postgres-and-init.md) -- PostgreSQL как StatefulSet и
  инициализация схемы из init.sql (без миграторов).
- [pgadmin.md](pgadmin.md) -- pgAdmin как вспомогательный сервис: подключение к
  базе, доступ через Ingress, только в dev.
