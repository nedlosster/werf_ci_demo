# Документация werf_ci_demo

Документация демо-репозитория, в котором единый CI-контур (`kube_ci`) ставит
два контрастных по стеку продукта в уже развёрнутые кластеры окружений dev и
prod по общему контракту `.helm/def.sh`. Материал рассчитан на инженера
среднего уровня, знакомого с Kubernetes и контейнерной сборкой, но не
обязательно с werf.

Документация разбита на тематические разделы. Каждый раздел -- отдельный
каталог со своим индексом `README.md` и набором статей. Один факт описывается
в одном месте; остальные разделы ссылаются на него.

## Путь чтения

Рекомендованный порядок освоения:

1. [concepts/](concepts/README.md) -- зачем werf, чем он отличается от
   альтернатив, как устроена доставка в Kubernetes, какие компромиссы заложены.
2. [kubernetes/](kubernetes/README.md) -- требования к кластеру, спецификации
   окружений, ingress.
3. [products/](products/README.md) -- два демо-продукта, их состав, базы данных
   и вспомогательные сервисы.
4. [delivery/](delivery/README.md) -- модель dev/prod, операции `kube_ci`,
   секреты, версионирование, разработка внутри кластера.
5. [integrations/](integrations/README.md) -- подключение `kube_ci` к внешним
   CI-системам и метрики поставки.
6. [runbooks/](runbooks/README.md) -- пошаговые сценарии эксплуатации.
7. [demo/](demo/README.md) -- материалы для показа: план доклада, слайды и банк
   вопросов.

Справочные материалы читаются по необходимости: [glossary.md](glossary.md) --
термины контура, [resources.md](resources.md) -- внешняя документация.

## Разделы

| Раздел | Назначение | Ключевые статьи |
|---|---|---|
| [concepts/](concepts/README.md) | Концепции werf и доставки в Kubernetes | [werf-intro.md](concepts/werf-intro.md), [werf-install.md](concepts/werf-install.md), [werf-vs-alternatives.md](concepts/werf-vs-alternatives.md), [delivery-to-k8s.md](concepts/delivery-to-k8s.md), [security-and-tradeoffs.md](concepts/security-and-tradeoffs.md) |
| [kubernetes/](kubernetes/README.md) | Кластеры, окружения, ingress | [requirements.md](kubernetes/requirements.md), [specifications.md](kubernetes/specifications.md), [ingress.md](kubernetes/ingress.md) |
| [products/](products/README.md) | Демо-продукты и их состав | [overview.md](products/overview.md), [app1-java-react.md](products/app1-java-react.md), [app2-python-angular.md](products/app2-python-angular.md), [postgres-and-init.md](products/postgres-and-init.md), [pgadmin.md](products/pgadmin.md) |
| [delivery/](delivery/README.md) | Поставка через kube_ci, секреты, версии | [dev-prod.md](delivery/dev-prod.md), [kube-ci-operations.md](delivery/kube-ci-operations.md), [secrets.md](delivery/secrets.md), [versioning.md](delivery/versioning.md), [dev-in-cluster.md](delivery/dev-in-cluster.md) |
| [integrations/](integrations/README.md) | Подключение к CI и метрики | [gitlab-ci.md](integrations/gitlab-ci.md), [jenkins.md](integrations/jenkins.md), [dora-metrics.md](integrations/dora-metrics.md) |
| [runbooks/](runbooks/README.md) | Сценарии эксплуатации | [first-deploy.md](runbooks/first-deploy.md), [deploy.md](runbooks/deploy.md), [cluster-connection.md](runbooks/cluster-connection.md), [secrets-setup.md](runbooks/secrets-setup.md), [troubleshooting.md](runbooks/troubleshooting.md) |
| [demo/](demo/README.md) | Материалы для показа | [talk-plan-40min.md](demo/talk-plan-40min.md), [slides.md](demo/slides.md), [qa-bank.md](demo/qa-bank.md) |
| Справочники | Термины и внешние ресурсы | [glossary.md](glossary.md), [resources.md](resources.md) |

## Диаграммы и изображения

- [diagrams/](diagrams/) -- источники диаграмм в формате `.mmd`: `architecture`
  (связка apps -> kube_ci -> кластер), `converge-flow`, `industrial-cicd`,
  `product-anatomy`, `dora-flow`.
- [pics/](pics/) -- отрендеренные `.png` для вставки в статьи (по одному на
  каждый источник из `diagrams/`).

## Связанные документы

- [../README.md](../README.md) -- обзор репозитория и базовые операции.
- [../apps/README.md](../apps/README.md) -- контракт продукта для kube_ci.
- [../kube_ci/README.md](../kube_ci/README.md) -- отличия адаптированной копии
  оркестрации от исходного kube_ci.
