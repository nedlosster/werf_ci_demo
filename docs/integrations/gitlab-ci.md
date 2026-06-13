# Подключение системы скриптов к GitLab CI

kube_ci -- это набор bash-скриптов, которые запускаются вручную из каталога
окружения. Те же скрипты можно вызывать из GitLab CI: пайплайн становится
тонкой обёрткой над `00-build-deploy.sh` / `01-dissmiss.sh` / `02-purge-stages.sh`.

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

В Settings → CI/CD → Variables проекта:

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

Два окружения (dev/prod) и три базовые операции kube_ci ложатся на стадии
пайплайна. Типовой поток: автодеплой в `dev`, промоут в `prod` вручную.

| Операция kube_ci | Стадия GitLab |
|---|---|
| публикация (`00-build-deploy.sh`) | `deploy-dev` / `deploy-prod` |
| откат (`01-dissmiss.sh`) | `rollback` (manual) |
| очистка (`02-purge-stages.sh`) | `cleanup` (manual / scheduled) |

## Пример `.gitlab-ci.yml`

```yaml
stages:
  - deploy
  - rollback
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
    - cd "kube_ci/$ENV"          # ENV и PRODUCT задаются при ручном запуске
    - ./01-dissmiss.sh "$PRODUCT"
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
- `01-dissmiss.sh` требует явного product key или `--all` -- в ручном job
  значение передаётся через переменную (`$PRODUCT`), пустое приведёт к отказу.
- Для werf-cleanup образов в registry по политикам (`werf.yaml: cleanup`)
  заводится отдельный scheduled-пайплайн с `werf cleanup`.
