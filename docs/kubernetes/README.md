# Kubernetes

Раздел описывает среду, в которую `kube_ci` ставит продукты: требования к
кластеру, спецификации окружений dev и prod, организацию ingress. Разворачивание
кластеров в скоп демо не входит -- предполагается, что они уже доступны.

Схема связки приложений, оркестрации и кластера -- на диаграмме
[../diagrams/architecture.mmd](../diagrams/architecture.mmd) (рендер в
[../pics/](../pics/)).

## Статьи

- [requirements.md](requirements.md) -- требования к кластеру: топология,
  ingress, in-cluster registry через nip.io, insecure-доступ.
- [specifications.md](specifications.md) -- параметры окружений dev/prod:
  контекст, неймспейсы, реестр (планируется).
- [ingress.md](ingress.md) -- организация ingress и маршрутизация к сервисам
  продуктов (планируется).
