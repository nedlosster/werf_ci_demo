# Поставка

Раздел описывает, как продукты доходят до кластера: модель окружений dev/prod,
операции `kube_ci` (публикация, откат, очистка), работа с секретами, схема
версионирования и разработка внутри кластера. Это рабочая часть для тех, кто
запускает и сопровождает деплой.

Пошаговые сценарии вынесены в [../runbooks/](../runbooks/README.md); подключение
к внешним CI-системам -- в [../integrations/](../integrations/README.md).

## Статьи

- [dev-prod.md](dev-prod.md) -- модель двух окружений: единый контур, различие по
  неймспейсу, временно общий кластер и переход на раздельные.
- [kube-ci-operations.md](kube-ci-operations.md) -- три базовые операции
  kube_ci: публикация (converge), откат (dismiss), очистка (purge).
- [secrets.md](secrets.md) -- управление секретами продуктов: werf secret,
  ключ WERF_SECRET_KEY, шифрование `secrets-<env>.yaml`.
- [versioning.md](versioning.md) -- единая версия VERSION -> CI_TAG по
  контейнерам, бекенду, фронтенду и чарту; set-version.sh.
- [dev-in-cluster.md](dev-in-cluster.md) -- разработка внутри кластера: dev-поды
  с persistent-volume'ами (исходники, кеши, vscode-server), VS Code Remote.
