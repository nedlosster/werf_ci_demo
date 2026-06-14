# Концепции

Раздел вводит в инструмент werf и в модель доставки приложений в Kubernetes,
которую использует демо. Здесь объясняется, какую задачу решает werf, чем он
отличается от связки Docker + Helm и от GitOps-операторов, и какие компромиссы
по безопасности и эксплуатации заложены в выбранную схему.

Чтение раздела даёт базу, на которую опираются разделы
[kubernetes/](../kubernetes/README.md) и [delivery/](../delivery/README.md).

## Статьи

- [werf-intro.md](werf-intro.md) -- введение в werf: что делает, `converge`,
  giterminism, stages, установка через trdl.
- [werf-install.md](werf-install.md) -- установка werf по шагам: trdl, канал
  `werf 2 stable`, активация в сессии, проверка, встраивание в CI.
- [werf-vs-alternatives.md](werf-vs-alternatives.md) -- сравнение с `docker
  build` + `kubectl apply`, Helm, Helmfile, Kustomize, Skaffold и
  GitOps-операторами ArgoCD/Flux.
- [delivery-to-k8s.md](delivery-to-k8s.md) -- модель доставки: единый контур
  kube_ci, контракт `.helm/def.sh`, поток converge, три базовые операции.
- [application-contract.md](application-contract.md) -- контракт приложения:
  `.helm/def.sh`, переменные и файлы контракта, иерархия values, минимальный
  набор для нового продукта.
- [security-and-tradeoffs.md](security-and-tradeoffs.md) -- компромиссы схемы:
  insecure-registry, loose-giterminism, единый кластер dev/prod, nip.io,
  ключ секретов, dev-SSH-под.
