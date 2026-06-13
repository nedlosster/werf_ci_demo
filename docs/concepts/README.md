# Концепции

Раздел вводит в инструмент werf и в модель доставки приложений в Kubernetes,
которую использует демо. Здесь объясняется, какую задачу решает werf, чем он
отличается от связки Docker + Helm и от GitOps-операторов, и какие компромиссы
по безопасности и эксплуатации заложены в выбранную схему.

Чтение раздела даёт базу, на которую опираются разделы
[kubernetes/](../kubernetes/README.md) и [delivery/](../delivery/README.md).

## Статьи

- [werf-intro.md](werf-intro.md) -- введение в werf: что делает, `converge`,
  giterminism, установка через trdl.
- [werf-vs-alternatives.md](werf-vs-alternatives.md) -- сравнение с Docker +
  Helm, Kustomize, GitOps-операторами (планируется).
- [delivery-to-k8s.md](delivery-to-k8s.md) -- модель доставки в Kubernetes:
  сборка, публикация образов, релиз чарта (планируется).
- [security-and-tradeoffs.md](security-and-tradeoffs.md) -- компромиссы схемы:
  insecure-registry, единый кластер для dev/prod, доступы (планируется).
