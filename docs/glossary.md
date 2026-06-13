# Глоссарий

Краткий реестр терминов CI-контура демо. Каждая статья даёт определение в одно-два
предложения и ссылку на профильный материал. Термины сгруппированы по областям:
werf и сборка, доставка через kube_ci, Kubernetes и сеть, версии и секреты,
продукты и сервисы, метрики.

## werf и сборка

- **werf** -- инструмент, объединяющий сборку образов и релиз в Kubernetes в
  одной команде. В демо ставится через trdl каналом `werf 2 stable`. См.
  [Введение в werf](concepts/werf-intro.md).
- **converge** -- основная команда werf: собирает недостающие образы, публикует их
  в registry и применяет Helm-релиз в кластер. Идемпотентна. См.
  [Введение в werf](concepts/werf-intro.md), [Доставка в Kubernetes](concepts/delivery-to-k8s.md).
- **helm rollback** -- возврат helm-релиза на ранее опубликованную ревизию. В
  контуре вызывается из `03-rollback.sh` для отката версии продукта без
  пересборки; список ревизий даёт `helm history`. См.
  [Операции kube_ci](delivery/kube-ci-operations.md),
  [Runbook отката версии](runbooks/rollback.md).
- **dismiss** -- команда werf для снятия релиза. В контуре вызывается с
  `--with-namespace` -- удаляет релиз вместе с неймспейсом окружения. Это снос
  развёртывания, не откат версии. См.
  [Операции kube_ci](delivery/kube-ci-operations.md).
- **purge** -- очистка локального кеша стадий сборки (`werf stages purge`):
  освобождает место, следующая сборка идёт с нуля. См.
  [Операции kube_ci](delivery/kube-ci-operations.md).
- **stage, stages-storage** -- стадия сборки -- контентно-адресуемый слой образа;
  stages-storage -- хранилище таких слоёв (в демо in-cluster registry). Кеш стадий
  переиспользуется между сборками. См. [Введение в werf](concepts/werf-intro.md).
- **giterminism, loose-giterminism** -- привязка сборки к git-состоянию: строгий
  режим собирает только из коммита и даёт воспроизводимость; loose-режим
  (`--loose-giterminism`) разрешает сборку из рабочего дерева. Демо использует
  loose ради локальной разработки. См. [Введение в werf](concepts/werf-intro.md),
  [Компромиссы и безопасность схемы](concepts/security-and-tradeoffs.md).
- **trdl** -- менеджер версий werf, проверяющий целостность дистрибутива по TUF
  root-key. Активирует werf в shell-сессии (`trdl use werf 2 stable`). См.
  [Введение в werf](concepts/werf-intro.md).
- **Helm-чарт, values** -- helm-совместимый чарт продукта (`.helm/`) с шаблонами
  k8s-объектов и значениями `values.yaml` / `values-<env>.yaml`, которыми форма
  объектов переключается между окружениями. См.
  [Спецификации Kubernetes](kubernetes/specifications.md).

## Доставка через kube_ci

- **kube_ci** -- набор bash-скриптов, оркеструющих werf-деплой: подключает
  контракт продукта, готовит окружение и запускает базовые операции -- публикацию,
  откат версии, снос и очистку. См.
  [Операции kube_ci](delivery/kube-ci-operations.md).
- **контракт `.helm/def.sh`** -- shell-файл продукта с env-функциями окружений;
  экспортирует `APPNAME`, `ENVNAME`, `CI_URL`, опционально `NAMESPACE` и `CI_*`.
  По нему kube_ci работает с продуктом, не зная его внутренностей. См.
  [контракт продукта](../apps/README.md),
  [Доставка в Kubernetes](concepts/delivery-to-k8s.md).
- **окружение dev/prod** -- самодостаточный каталог `kube_ci/dev|prod/` со своими
  точками входа и `productlist`. Окружения различаются неймспейсом; временно оба
  указывают на один preprod-кластер. См.
  [Один контур, два окружения](delivery/dev-prod.md).
- **k8s_defs, KUBECONTEXT** -- файл окружения `<env>/k8s_defs` задаёт целевой
  кластер и registry; `KUBECONTEXT` определяет контекст kubeconfig. Переезд на
  отдельные кластеры меняет только эти значения. См.
  [Спецификации Kubernetes](kubernetes/specifications.md),
  [Один контур, два окружения](delivery/dev-prod.md).

## Kubernetes и сеть

- **namespace (неймспейс)** -- пространство имён кластера; релиз разворачивается в
  `<NAMESPACE>-<ENVNAME>`, поэтому одно приложение в dev и prod не конфликтует на
  общем кластере. См. [Спецификации Kubernetes](kubernetes/specifications.md).
- **ingress** -- объект маршрутизации внешнего HTTP-трафика; в демо один хост на
  релиз разводит запросы по пути на фронт, бэкенд и pgAdmin. См.
  [Ingress](kubernetes/ingress.md).
- **nip.io** -- сервис wildcard-DNS, резолвящий имена вида `host-<IP>.nip.io` в
  указанный IP. Даёт внешний хост релиза без DNS-записей. См.
  [Ingress](kubernetes/ingress.md).
- **registry, insecure-registry** -- хранилище образов; in-cluster registry в демо
  опубликован через ingress-nginx с self-signed TLS, поэтому werf работает с ним
  по insecure-флагам. См. [Требования к кластеру](kubernetes/requirements.md),
  [Компромиссы и безопасность схемы](concepts/security-and-tradeoffs.md).

## Версии и секреты

- **VERSION, CI_TAG (единая версия)** -- файл `apps/<product>/VERSION` -- источник
  истины версии продукта; `set-version.sh` раскладывает её по файлам стека, а в
  CI она уходит в `CI_TAG` и становится тегом образа. См.
  [Версионирование](delivery/versioning.md).
- **WERF_SECRET_KEY, werf secret** -- ключ шифрования и механизм werf для хранения
  секретов в репозитории в зашифрованном виде (`secret-values.yaml`). Ключ
  подключается только на деплое. См. [Управление секретами](delivery/secrets.md).

## Продукты и сервисы

- **pgAdmin** -- веб-клиент к PostgreSQL; в демо входит в чарт продукта с заранее
  прописанным подключением и включён только в dev. См.
  [pgAdmin](products/pgadmin.md).
- **db-init-configmap** -- ConfigMap с `init.sql`, монтируемый в PostgreSQL;
  применяется при первом старте пустого тома и создаёт схему с демо-записями. См.
  [PostgreSQL и init.sql](products/postgres-and-init.md).

## Метрики

- **DORA-метрики** -- четыре показателя поставки: Deployment Frequency (частота
  выкаток), Lead Time for Changes (время от изменения до прода), Change Failure
  Rate (доля сбойных выкаток), Mean Time to Restore (время восстановления). В демо
  снимаются с job-ов пайплайна. См. [Метрики DORA](integrations/dora-metrics.md).

## Связанные документы

- [Введение в werf](concepts/werf-intro.md)
- [Доставка в Kubernetes](concepts/delivery-to-k8s.md)
- [Компромиссы и безопасность схемы](concepts/security-and-tradeoffs.md)
- [Внешние ресурсы](resources.md)
- [Индекс документации](README.md)
