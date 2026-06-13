# Документация werf_ci_demo

Индекс документации демо-репозитория.

## Статьи

- [werf-intro.md](werf-intro.md) -- введение в werf: что делает, converge,
  giterminism, установка через trdl.
- [k8s-requirements.md](k8s-requirements.md) -- требования к кластеру: топология,
  ingress, in-cluster registry через nip.io, insecure-доступ.
- [gitlab-ci.md](gitlab-ci.md) -- подключение системы скриптов kube_ci к GitLab CI.

## Runbook'и

- [runbooks/deploy.md](runbooks/deploy.md) -- публикация, откат и очистка демо
  в окружениях dev / prod.

## Связанные документы

- [../README.md](../README.md) -- обзор репозитория и базовые операции.
- [../apps/README.md](../apps/README.md) -- контракт продукта для kube_ci.
- [../kube_ci/README.md](../kube_ci/README.md) -- отличия адаптированной
  копии оркестрации от исходного kube_ci.

## Правила

- Без иконок-символов в `.md`.
- Сухо и технично, без слов-маркеров.
