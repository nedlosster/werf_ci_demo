---
title: Первый деплой продукта с нуля
status: stable
last-updated: 2026-06-13
area: runbooks
---

# Runbook: первый деплой продукта с нуля

End-to-end сценарий: от чистой машины до работающего продукта в кластере dev.
Каждый шаг ссылается на профильный runbook, где он расписан подробнее. После
прохождения всех шагов продукт доступен по nip.io-хосту, БД проинициализирована,
pgAdmin отвечает.

Сводка трёх базовых операций kube_ci -- в [deploy.md](deploy.md). Здесь --
полная первичная установка, включая werf, доступ к кластеру и секреты.

## Предусловия

Деплой и отладка идут на KVM-сервере (маршрут -- см. infa). Рабочая машина только
пушит код в git; на KVM-сервере выполняется `git pull` и прогон kube_ci. Все
команды ниже выполняются на KVM-сервере.

## Шаги

### 1. Получить репозиторий

На рабочей машине -- `git push`, на KVM-сервере -- подтянуть актуальное состояние:

```bash
git pull
```

### 2. Установить werf

werf активируется в текущей сессии менеджером версий trdl по единому каналу
`werf 2 stable`:

```bash
source "$(~/bin/trdl use werf 2 stable)"
```

Скрипты converge и dismiss делают это сами, но для ручных команд werf (секреты,
проверки) активировать werf в сессии нужно явно. Установка самого trdl и
добавление репозитория werf -- в [Введении в werf](../concepts/werf-intro.md).

### 3. Подключиться к кластеру

Положить kubeconfig, проверить и выбрать контекст:

```bash
kubectl config get-contexts
kubectl config use-context k8sadmin-k8s-public-paas@service-k8s-public-paas
kubectl get nodes
```

Параметры подключения, insecure-registry и переопределение под другой кластер --
в [cluster-connection.md](cluster-connection.md).

### 4. Настроить секреты

Задать ключ шифрования и убедиться, что у продукта есть зашифрованный
`secrets-<env>.yaml`:

```bash
export WERF_SECRET_KEY=<секретный-ключ>
```

Генерация ключа, создание и правка зашифрованных значений -- в
[secrets-setup.md](secrets-setup.md). Если `secrets-<env>.yaml` нет, чарт берёт
демо-дефолты паролей из `values.yaml` -- это допустимо только для показа.

### 5. Подготовить продукты

```bash
cd kube_ci/dev
./pull_products.sh
```

[`pull_products.sh`](../../kube_ci/dev/pull_products.sh) создаёт `products/` и
связывает в него каждый продукт из `productlist` symlink'ом на `apps/<product>`.
Если `productlist` отсутствует, он копируется из `productlist_official`. При
необходимости отредактировать `productlist` -- оставить только нужные продукты и
их окружения.

### 6. Выкатить продукт

```bash
./00-build-deploy.sh app1-java-react      # либо без аргумента -- все из productlist
```

[`00-build-deploy.sh`](../../kube_ci/dev/00-build-deploy.sh) подключает
[`utils/03-werf-converge.sh`](../../kube_ci/utils/03-werf-converge.sh) и для
выбранного продукта вызывает `werf converge`. Converge собирает образы, публикует
их в in-cluster registry и разворачивает релиз в неймспейсе `<NAMESPACE>-<ENVNAME>`
(для app1-java-react в dev -- `app1-java-react-dev`). Запуск идёт с `--atomic` и
`--timeout=300`: при сбое релиз откатывается целиком. Что именно делает converge
под капотом -- в [Операциях kube_ci](../delivery/kube-ci-operations.md) и
[Введении в werf](../concepts/werf-intro.md). После публикации postdeploy-хук
печатает URL фронта, бэкенда, Swagger и pgAdmin.

### 7. Проверить результат

```bash
kubectl -n app1-java-react-dev get pods
kubectl -n app1-java-react-dev get ingress
```

Все поды должны быть `Running` и `Ready`. Открыть напечатанные URL: фронт по
`http://<app>-dev-<NODE_IP>.nip.io/`, pgAdmin по `.../pgadmin`. Схема хостов и
маршрутизация одного хоста на фронт/бэкенд/pgAdmin -- в
[ingress.md](../kubernetes/ingress.md).

## Чеклист рабочего деплоя

- `git pull` выполнен, werf активирован (`source "$(~/bin/trdl use werf 2 stable)"`).
- `kubectl get nodes` возвращает ноды в статусе `Ready`, контекст -- целевого
  кластера.
- `WERF_SECRET_KEY` задан, `secrets-<env>.yaml` присутствует (или осознанно
  используются демо-дефолты).
- `00-build-deploy.sh` завершился без ошибок, напечатал URL ресурсов.
- В неймспейсе `<NAMESPACE>-<ENVNAME>` все поды `Running`/`Ready`, есть Ingress.
- Фронт и pgAdmin открываются по nip.io-хостам.

При сбое шага -- [troubleshooting.md](troubleshooting.md): TLS/registry,
timeout, отсутствие ключа, ImagePullBackOff, init БД, ingress 404, неверный
контекст.

## Связанные статьи

- [cluster-connection.md](cluster-connection.md) -- подключение к кластеру
- [secrets-setup.md](secrets-setup.md) -- настройка и ротация секретов
- [deploy.md](deploy.md) -- три базовые операции kube_ci
- [troubleshooting.md](troubleshooting.md) -- разбор сбоев
- [Операции kube_ci](../delivery/kube-ci-operations.md) -- что делает converge
- [ingress.md](../kubernetes/ingress.md) -- хосты и маршрутизация
