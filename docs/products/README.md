# Продукты

Раздел описывает два демо-продукта, контрастных по стеку, которые ставит общий
CI-контур: React + Spring Boot (app1-java-react) и Angular + FastAPI
(app2-python-angular). Оба используют PostgreSQL и pgAdmin. Цель раздела --
показать, как разнородные приложения деплоятся по единому контракту
`.helm/def.sh`.

Контракт, по которому `kube_ci` работает с продуктом, описан в
[../../apps/README.md](../../apps/README.md).

## Статьи

- [overview.md](overview.md) -- обзор обоих продуктов и их сопоставление
  (планируется).
- [app1-java-react.md](app1-java-react.md) -- состав app1: React, Spring Boot,
  PostgreSQL, pgAdmin (планируется).
- [app2-python-angular.md](app2-python-angular.md) -- состав app2: Angular,
  FastAPI, PostgreSQL, pgAdmin (планируется).
- [postgres-and-init.md](postgres-and-init.md) -- PostgreSQL в продуктах и
  инициализация схемы (планируется).
- [pgadmin.md](pgadmin.md) -- pgAdmin как вспомогательный сервис продукта
  (планируется).
