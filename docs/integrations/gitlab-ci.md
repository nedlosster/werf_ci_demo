# Подключение системы скриптов к GitLab CI

Статья показывает, как обернуть операции `kube_ci` в пайплайн GitLab CI. Это
справочник: требования к раннеру, переменные CI/CD, маппинг трёх операций на
стадии и рабочий `.gitlab-ci.yml`. Та же механика обёртки над bash-скриптами в
другой CI-системе описана в [Подключении к Jenkins](jenkins.md); статью
читать после раздела о самих операциях --
[Операции kube_ci](../delivery/kube-ci-operations.md).

kube_ci -- это набор bash-скриптов, которые запускаются вручную из каталога
окружения. Те же скрипты можно вызывать из GitLab CI: пайплайн становится
тонкой обёрткой над `00-build-deploy.sh` / `03-rollback.sh` / `01-dismiss.sh` /
`02-purge-stages.sh`.

## Что нужно от раннера

GitLab Runner (executor `shell` или `docker` с привилегиями для сборки), на
котором доступны:

- `docker` (сборка образов werf);
- `werf` через `trdl` (`trdl use werf 2 stable`) -- см. [werf-intro.md](../concepts/werf-intro.md);
- `kubectl` и `helm`;
- доступ к кластерам окружений и in-cluster registry -- см.
  [requirements.md](../kubernetes/requirements.md).

Раннер должен иметь сетевой доступ к кластеру и insecure-registry,
аналогично рабочей машине.

## Переменные CI/CD

В Settings -> CI/CD -> Variables проекта:

| Переменная | Назначение |
|---|---|
| `KUBECONFIG` (file) | доступ к кластеру окружения |
| `KUBECONTEXT` | имя контекста кластера окружения |
| `K8S_NODE_IP` | адрес ноды для nip.io-реестра |
| `WERF_SECRET_KEY` | ключ расшифровки `secrets-<env>.yaml` (если используются) |

`KUBECONFIG`/`WERF_SECRET_KEY` хранить как masked/protected. Контекст и адрес
ноды задаются отдельно для каждого окружения (dev/prod) -- через
environment-scoped переменные или `k8s_defs` соответствующего каталога.

## Маппинг операций на стадии

Базовые операции kube_ci и два окружения (dev/prod) ложатся на стадии
пайплайна. Типовой поток: автодеплой в `dev`, промоут в `prod` вручную.

| Операция kube_ci | Стадия GitLab |
|---|---|
| публикация (`00-build-deploy.sh`) | `deploy-dev` / `deploy-prod` |
| откат версии (`03-rollback.sh`) | `rollback` (manual) |
| снос (`01-dismiss.sh`) | `dismiss` (manual) |
| очистка (`02-purge-stages.sh`) | `cleanup` (manual / scheduled) |

## Пример `.gitlab-ci.yml`

```yaml
stages:
  - deploy
  - rollback
  - dismiss
  - cleanup

default:
  before_script:
    - source "$(~/bin/trdl use werf 2 stable)"

.deploy:
  stage: deploy
  script:
    - cd "kube_ci/$ENV"
    - ./pull_products.sh
    - ./00-build-deploy.sh --all

deploy-dev:
  extends: .deploy
  variables: { ENV: dev }
  rules:
    - if: '$CI_COMMIT_BRANCH == "main"'

deploy-prod:
  extends: .deploy
  variables: { ENV: prod }
  when: manual

rollback:
  stage: rollback
  script:
    - cd "kube_ci/$ENV"          # ENV, PRODUCT, REVISION задаются при ручном запуске
    - ./03-rollback.sh "$PRODUCT" "$REVISION"   # без REVISION -- печать helm history
  when: manual

dismiss:
  stage: dismiss
  script:
    - cd "kube_ci/$ENV"          # ENV и PRODUCT задаются при ручном запуске
    - ./01-dismiss.sh "$PRODUCT"
  when: manual

purge:
  stage: cleanup
  script:
    - cd "kube_ci/$ENV"
    - ./02-purge-stages.sh
  when: manual
```

## Замечания

- В CI продукты не обязательно тянуть через `pull_products.sh` symlink'ами:
  если каждый продукт -- отдельный репозиторий, его исходники подключаются как
  submodule или отдельным `git clone` в `products/<product>` на стадии deploy.
- `01-dismiss.sh` и `03-rollback.sh` требуют явного product key -- в ручном job
  значение передаётся через переменную (`$PRODUCT`), пустое приведёт к отказу.
  `03-rollback.sh` без `$REVISION` печатает `helm history` и не меняет кластер.
- Для werf-cleanup образов в registry по политикам (`werf.yaml: cleanup`)
  заводится отдельный scheduled-пайплайн с `werf cleanup`.

## Плюсы, минусы, безопасность

Плюсы. Пайплайн остаётся тонкой обёрткой: stage'ы вызывают те же скрипты
`kube_ci`, что и ручной запуск, поэтому поведение в CI и локально совпадает.
Переезд между CI-системами не трогает логику доставки -- меняется только синтаксис
`.gitlab-ci.yml`.

Минусы. Раннер должен сам предоставить werf, доступ к registry и kubeconfig --
часть среды живёт вне репозитория, и её рассинхрон проявляется на job-е. Откат
завязан на ручную передачу `$PRODUCT`, пустое значение намеренно валит job, чтобы
не снести лишнего.

Безопасность. `WERF_SECRET_KEY` и kubeconfig подключаются только в stage'ах
деплоя и хранятся masked/protected-переменными, а не в репозитории. Разбор
хранения ключа и боевых послаблений -- в
[Управлении секретами](../delivery/secrets.md) и
[Компромиссах и безопасности схемы](../concepts/security-and-tradeoffs.md).

## Связанные статьи

- [Подключение к Jenkins](jenkins.md) -- та же обёртка над скриптами в другой
  CI-системе.
- [Метрики DORA](dora-metrics.md) -- какие сигналы поставки снимаются с job-ов
  пайплайна.
- [Операции kube_ci](../delivery/kube-ci-operations.md) -- что делают скрипты,
  которые вызывает пайплайн.
- [Управление секретами](../delivery/secrets.md) -- ключ werf и хранение его как
  masked/protected-переменной CI.
- [Требования к Kubernetes-кластеру](../kubernetes/requirements.md) -- доступ
  раннера к кластеру и insecure-registry.
