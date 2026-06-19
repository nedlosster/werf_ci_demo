---
title: Разработка внутри кластера (dev-схема)
status: draft
last-updated: 2026-06-14
area: delivery
---

# Разработка внутри кластера (dev-схема)

dev-вариант продукта разворачивается в Kubernetes как долгоживущий
под-песочница (`sleep infinity`), к которому разработчик подключается через VS
Code Remote и пишет код прямо в поде. Эта статья описывает dev-схему: что именно
рендерит окружение `dev` вместо prod-Deployment'ов, как persistent-volume'ы
сохраняют исходники и кеши между перезапусками, как под инициализируется и как к
нему подключиться. Сама модель окружений и переключение dev/prod -- в
[dev-prod](dev-prod.md); запуск выкатки -- в [Операциях kube_ci](kube-ci-operations.md).

В демо схема реализована для обоих продуктов: app1-java-react (бек Spring Boot,
фронт React+Vite) и app2-python-angular (бек FastAPI, фронт Angular). Поды
различаются только базовым образом и командой запуска dev-сервера.

## Что разворачивается в dev

`env=dev` (values-dev.yaml) рендерит вместо prod-Deployment'ов:
- `app1-java-react-backend-dev` -- StatefulSet, образ `backend-dev` (полный
  maven+JDK), `sleep infinity`;
- `app1-java-react-frontend-dev` -- StatefulSet, образ `frontend-dev` (полный
  node+pnpm), `sleep infinity`;
- PostgreSQL и pgAdmin (pgAdmin только в dev), ingress.

## Зачем dev в кластере, а не docker-compose

Тезис схемы: dev-окружение идентично prod, потому что собрано из тех же
кубовых объектов, и в нём отлаживается сама k8s-логика, а не одни контейнеры.
docker-compose на машине разработчика моделирует контейнеры и docker-сеть -- это
другая модель, в которой Kubernetes-слоя нет вовсе.

Ключевое:

1. Тот же Kubernetes и те же манифесты, что в prod: `.helm`-чарт, Ingress,
   Service, StatefulSet с Postgres, неймспейсы, ConfigMap и Secret. Среды
   совпадают по устройству, и класс расхождений «локально работало, в кластере
   нет» почти исчезает. docker-compose воспроизвёл бы только контейнеры и
   docker-сеть.
2. Отлаживается то, чего docker-compose не показывает: Ingress-маршрутизация
   (`/api`, `/pgadmin`, host по nip.io, nginx-аннотации, rewrite); service
   discovery по DNS и `targetPort`; readiness/liveness-пробы, поведение rollout,
   стратегия `updateStrategy: OnDelete` у Postgres; монтирование Secret и
   ConfigMap, init-контейнеры, семантика PVC и StatefulSet; сам `werf converge`
   с giterminism и хуками predeploy/postdeploy.

Эксплуатационные:

3. Один артефакт доставки без дрейфа. dev и prod различаются только окружением
   в [.helm/def.sh](../../apps/README.md); compose стал бы вторым параллельным
   артефактом рядом с чартом -- двойная поддержка и рассинхрон.
4. Реальная инфраструктура кластера. dev-под видит настоящий
   Ingress-контроллер, storage-class, CNI, DNS, preprod-сервисы и базы напрямую,
   без VPN и port-forward.
5. Тяжёлое -- на сервере, клиент лёгкий. Сборка (maven, node, pip), кеши и базы
   живут на ноде кластера; VS Code Remote -- только редактор и не нагружает
   ноутбук.
6. Персистентность и быстрый рестарт. PVC `workspace` и `homeapp` держат клон,
   `node_modules`, `.m2` и кеши между пересозданиями пода -- разбор в
   [Кешах и persistent-volume'ах dev-сред](dev-caches-and-volumes.md).
7. Воспроизводимый онбординг. Среду задаёт dev-образ (локаль, таймзона, утилиты,
   ssh) -- она одинакова у всех, локальный тулчейн (Docker Desktop, версии JDK,
   Node, Python) не нужен.
8. Меньше зависимости от хоста. Нет расхождений по ОС разработчика
   (file-watching, права, версия Docker) -- всё исполняется в Linux-поде.
9. Демо-ценность. dev и prod проходят одним механизмом, что подтверждает:
   контур не привязан к окружению.

## Цена подхода: налог на сопровождение

Паритет dev и prod не бесплатен. За идентичность среды и возможность отлаживать
саму k8s-логику схема берёт постоянную плату -- не разовую настройку, а налог,
который платится при каждом запуске dev-сервера, каждом рестарте пода и каждой
правке dev-формы. Ниже собрано то, что docker-compose не требует.

Запуск dev-серверов остаётся ручным и неочевидным. Каждая строка `dev-start.sh`
-- след набитой шишки, и команды нельзя упростить до «как в документации
инструмента». Фронты ставят зависимости через `npm`, а не corepack/pnpm:
corepack падает на записи кеша в поде (`.cache/node/corepack`). Бинарь запускают
из локального `./node_modules/.bin` (`vite`, `ng`), потому что `npx ng` тянет
посторонний пакет. Бекенд app2 поднимает `uvicorn` без `--reload`: в
detached-запуске супервизор не выживает -- процесс переусыновляется к PID 1, и
watcher сбрасывается. Слушать нужно строго `0.0.0.0:8080` -- это `targetPort`
dev-Service. Фронты отвечают через ingress только при заданном `allowedHosts`
(`.nip.io`) в [vite.config.ts](../../apps/app1-java-react/frontend/vite.config.ts)
и [angular.json](../../apps/app2-python-angular/frontend/angular.json); без него
ingress отдаёт 403.

Состояние пода эфемерно и порождает гонки. site-packages бекенда и user-site
(`pip install --user`) живут только до пересоздания пода, если их не вынести на
PVC симлинками `~/.local` и `~/.npm` на том `homeapp` -- разбор в
[Кешах и persistent-volume'ах dev-сред](dev-caches-and-volumes.md). Порт 8080
требует чистого старта: повторный запуск без остановки прежнего процесса
конфликтует. А detached-запуск упирается в то же переусыновление к PID 1, из-за
которого `uvicorn --reload` и был убран.

Схема привязана к живому кластеру. Полноценная оффлайн-разработка затруднена:
под, его база и ingress существуют только в кластере. Remote-редактирование
добавляет сетевые задержки до кластера на каждое сохранение и навигацию.
Долгоживущие dev-поды (`sleep infinity`) держат CPU, RAM и диск под PVC всё
время, пока окружение существует, -- даже когда никто в них не работает.

Доступ к коду и его обновление тоже на сопровождении. `git pull` в поде идёт по
SSH и требует Secret `id-rsa-vcs` с приватным ключом плюс запечённого в
`Dockerfile.dev` блока `ssh_config` для `github.com`. Первичная настройка
dev-образа (локаль, таймзона, утилиты отладки) -- отдельный слой поверх
прод-обвязки, который надо поддерживать.

Наконец, сопровождается сама dev-форма. Отдельные `Dockerfile.dev`,
`init-dev-env.sh` и dev-StatefulSet'ы (шаблоны `031-*-dev`, `041-*-dev`) живут
рядом с прод-образами и прод-Deployment'ами. Это двойная поддержка: правка,
затрагивающая обе формы, вносится дважды, и dev/prod-формы дрейфуют, если
синхронизировать их вручную забывают.

Налог окупается там, где ценен паритет dev и prod и нужна отладка самой
k8s-логики -- маршрутизации ingress, service discovery, проб, PVC, `werf
converge` с хуками. Для простых компонентов без кубовой специфики или для работы
в офлайне docker-compose обходится дешевле: меньше движущихся частей, нет
зависимости от кластера, запуск ближе к документации инструментов. Поверхность
атаки dev-пода с примонтированным ssh-ключом и связанные компромиссы разобраны в
[Компромиссах и безопасности схемы](../concepts/security-and-tradeoffs.md).

Сравнение с docker-compose -- лишь одна ось. Тот же выбор «минимализм против
готового UX» встаёт при сравнении схемы с inner-loop-инструментами (Tilt,
Skaffold, okteto, Telepresence) и push-доставки с GitOps-операторами -- разбор в
[dev-в-кластере против inner-loop-инструментов и GitOps](dev-in-cluster-vs-tools.md).

## Донастройка dev-образов

Поверх базовой обвязки (git, openssh-client, sudo, procps, ca-certificates)
`Dockerfile.dev` всех четырёх компонентов добавляет набор для разработки и
отладки внутри пода:

- локаль `en_US.UTF-8` (пакет `locales` + генерация через `locale-gen`);
- таймзону `Europe/Moscow` (`tzdata`), переменные `ENV LANG`, `LC_ALL`, `TZ`,
  `TERM`;
- утилиты: `mc`, `curl`, `wget`, `less`, `jq`, `vim`, `iputils-ping`,
  `dnsutils`, `net-tools`, `telnet`, `socat`, `zip`, `tree`,
  `postgresql-client`.

Локаль dev-образов (`en_US.UTF-8`) отличается от прод-бекендов. Runtime-стадия
прод-`Dockerfile` бекендов задаёт встроенную `C.UTF-8` (`ENV LANG`, `LC_ALL`)
без пакета `locales`; этого хватает для не-ASCII в логах и I/O. Без неё
`file.encoding` на JRE 17 уходит в ASCII. Прод-фронты (nginx-alpine, статика)
локаль не задают -- она им не нужна.

На локаль и collation базы образ приложения не влияет: PostgreSQL -- отдельный
контейнер, кодировку он фиксирует при initdb внутри postgres-образа.

## Persistent-volume'ы (на каждый dev-под)

`volumeClaimTemplates` StatefulSet'а создаёт два PVC:

| PVC | Mount | Назначение |
|---|---|---|
| `workspace` | `/workspace` | клон монорепо werf_ci_demo (исходники) |
| `homeapp` | `/home/app/homeapp` | кеши пакетов + `.vscode-server` |

В dev-образе из `~/` сделаны симлинки в `/home/app/homeapp`:
- backend: `~/.m2` (maven), `~/.vscode-server`, `~/.config`;
- frontend: `~/.local/share/pnpm` (pnpm store), `~/.cache`, `~/.vscode-server`, `~/.config`.

Поэтому кеш пакетов и расширения/настройки VS Code пишутся в PVC `homeapp` и не
теряются при пересоздании пода или перезапуске ВМ. Детальный разбор обоих томов,
симлинков кешей по компонентам и жизненного цикла PVC --
[Кеши и persistent-volume'ы dev-сред](dev-caches-and-volumes.md).

## Инициализация (initContainer)

`initContainer` запускает `install/prepare-scripts/init-dev-env.sh`:
1. создаёт каталоги кешей в `/home/app/homeapp`;
2. подкладывает ssh-ключ (Secret `id-rsa-vcs` из `.helm/tmp/id_rsa-vcs`);
3. **однократно** клонирует `werf_ci_demo` в `/workspace` (маркер `.gitclone`).

Рабочая копия продукта: `/workspace/werf_ci_demo/apps/app1-java-react/{backend,frontend}`.

## Подключение VS Code

```bash
kubectl --context <ctx> -n app1-java-react-dev get pods
# подключиться VS Code Remote (Kubernetes/SSH) к поду *-backend-dev или *-frontend-dev,
# открыть папку /workspace/werf_ci_demo/apps/app1-java-react/<backend|frontend>
```

Внутри пода доступны сборочные инструменты (maven, node, python/pip), git и набор
утилит отладки. Сборка и запуск -- руками в поде. `.vscode-server` ставится один
раз и переживает перезапуски (живёт в PVC `homeapp`).

## Запуск dev-сервера в поде

dev-сервер поднимают скриптом `dev-start.sh` из каталога компонента внутри пода
(через VS Code Remote или `kubectl exec`). Скрипты лежат рядом с исходниками и
попадают в под вместе с клоном в `/workspace`.

| Компонент | Скрипт | Команда запуска |
|---|---|---|
| app1-java-react backend | [backend/dev-start.sh](../../apps/app1-java-react/backend/dev-start.sh) | `mvn -q -DskipTests spring-boot:run` (Spring Boot на `0.0.0.0:8080`, context-path `/api`, actuator `8081`) |
| app1-java-react frontend | [frontend/dev-start.sh](../../apps/app1-java-react/frontend/dev-start.sh) | `npm install` + `./node_modules/.bin/vite --host 0.0.0.0 --port 8080` |
| app2-python-angular backend | [backend/dev-start.sh](../../apps/app2-python-angular/backend/dev-start.sh) | `pip install --user -e .` + `python -m uvicorn app2.main:app --host 0.0.0.0 --port 8080` |
| app2-python-angular frontend | [frontend/dev-start.sh](../../apps/app2-python-angular/frontend/dev-start.sh) | `npm install` + `./node_modules/.bin/ng serve --host 0.0.0.0 --port 8080` |

Пример запуска бекенда app1 из подключённого пода:

```bash
cd /workspace/werf_ci_demo/apps/app1-java-react/backend
./dev-start.sh
```

Снаружи доступна обёртка [dev-run.sh](../../kube_ci/utils/dev-run.sh)
(`./dev-run.sh <product> <backend|frontend> [shell|run]`): `shell` даёт
интерактивный bash в поде, `run` запускает dev-сервер через `kubectl exec`.
Штатный путь -- всё же `dev-start.sh` внутри пода.

Команды в `dev-start.sh` подобраны под поведение инструментов в поде и не
сводятся к запуску «как в документации»: `npm` вместо corepack/pnpm, бинарь из
`./node_modules/.bin`, `uvicorn` без `--reload`, строгий `0.0.0.0:8080`,
`allowedHosts` под ingress. Каждый из этих выборов и его причина разобраны выше
в разделе [Цена подхода: налог на сопровождение](#цена-подхода-налог-на-сопровождение).

## Обновление рабочей копии (git pull по SSH)

Исходники в `/workspace` обновляют через `git pull` по SSH из каталога рабочей
копии от пользователя `app`. Приватный ключ монтируется Secret'ом `id-rsa-vcs` в
`~/.ssh/id_rsa`. В `/etc/ssh/ssh_config` dev-образы (`Dockerfile.dev`) запекают
блок для `github.com` (`StrictHostKeyChecking no`,
`UserKnownHostsFile=/dev/null`), так что `git pull` обходится без `known_hosts`:

```bash
cd /workspace/werf_ci_demo
git pull
```

## Предусловия

- Приватный clone требует ssh-ключ: положить приватный ключ в
  `apps/app1-java-react/.helm/tmp/id_rsa-vcs` (в `.gitignore`) перед `converge`.
  Без ключа под поднимется, но репозиторий нужно склонировать в `/workspace` вручную.
- `storageClass` (по умолчанию `standard`) должен существовать в кластере.

## Деплой

```bash
cd kube_ci/dev
./pull_products.sh
./00-build-deploy.sh app1-java-react   # werf соберёт dev-образы и развернёт dev-поды
```

Хук предеплоя, инъекция ssh-ключа и связанный риск разобраны в
[Компромиссах и безопасности схемы](../concepts/security-and-tradeoffs.md).

## Связанные статьи

- [Один контур, два окружения](dev-prod.md)
- [Типовой цикл работы в dev-поде](dev-workflow-cycle.md)
- [dev-в-кластере против inner-loop-инструментов и GitOps](dev-in-cluster-vs-tools.md)
- [Кеши и persistent-volume'ы dev-сред](dev-caches-and-volumes.md)
- [Операции kube_ci](kube-ci-operations.md)
- [Управление секретами](secrets.md)
- [Спецификации Kubernetes](../kubernetes/specifications.md)
- [Доставка в Kubernetes](../concepts/delivery-to-k8s.md)
- [Компромиссы и безопасность схемы](../concepts/security-and-tradeoffs.md)
- [app1-java-react](../products/app1-java-react.md)
