# Поставка

Раздел описывает, как продукты доходят до кластера: модель окружений dev/prod,
операции `kube_ci` (публикация, откат версии, снос, очистка), работа с
секретами, схема версионирования и разработка внутри кластера. Это рабочая часть для тех, кто
запускает и сопровождает деплой.

Пошаговые сценарии вынесены в [../runbooks/](../runbooks/README.md); подключение
к внешним CI-системам -- в [../integrations/](../integrations/README.md).

## Статьи

- [dev-prod.md](dev-prod.md) -- модель двух окружений: единый контур, различие по
  неймспейсу, временно общий кластер и переход на раздельные.
- [kube-ci-operations.md](kube-ci-operations.md) -- базовые операции kube_ci:
  публикация (converge), откат версии (helm rollback), снос (dismiss), очистка
  (purge).
- [secrets.md](secrets.md) -- управление секретами продуктов: werf secret,
  ключ WERF_SECRET_KEY, шифрование `secrets-<env>.yaml`.
- [versioning.md](versioning.md) -- единая версия VERSION -> CI_TAG по
  контейнерам, бекенду, фронтенду и чарту; set-version.sh.
- [dev-in-cluster.md](dev-in-cluster.md) -- разработка внутри кластера: dev-поды
  с persistent-volume'ами (исходники, кеши, vscode-server), VS Code Remote,
  запуск dev-серверов через `dev-start.sh`, обновление рабочей копии `git pull`
  по SSH.
- [dev-caches-and-volumes.md](dev-caches-and-volumes.md) -- устройство двух PVC
  dev-пода (`workspace`, `homeapp`), симлинки кешей пакетных менеджеров на том,
  что переживает пересоздание пода и перезагрузку ВМ.
- [dev-workflow-cycle.md](dev-workflow-cycle.md) -- типовой цикл работы в
  dev-поде: подключение, `git pull`, петля правка-отладка-тест, `git push`,
  выкат через `kube_ci` в dev и prod.
- [dev-in-cluster-vs-tools.md](dev-in-cluster-vs-tools.md) -- сравнение dev-схемы
  с inner-loop-инструментами (Tilt, Skaffold, okteto, Telepresence) и push-доставки
  с GitOps-операторами (ArgoCD, Flux); когда оправдан какой подход.
