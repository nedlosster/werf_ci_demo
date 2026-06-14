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

## Донастройка dev-образов

`Dockerfile.dev` всех четырёх компонентов поверх базовой обвязки
(git, openssh-client, sudo, procps, ca-certificates) ставят набор для
разработки и отладки внутри пода:

- локаль `en_US.UTF-8` (пакет `locales` + генерация через `locale-gen`);
- таймзону `Europe/Moscow` (`tzdata`), переменные `ENV LANG`, `LC_ALL`, `TZ`,
  `TERM`;
- утилиты: `mc`, `curl`, `wget`, `less`, `jq`, `vim`, `iputils-ping`,
  `dnsutils`, `net-tools`, `telnet`, `socat`, `zip`, `tree`,
  `postgresql-client`.

Локаль dev-образов (`en_US.UTF-8`) отличается от прод-бекендов. Runtime-стадия
прод-`Dockerfile` бекендов задаёт встроенную `C.UTF-8` (`ENV LANG`, `LC_ALL`)
без пакета `locales` -- этого хватает для корректной работы с не-ASCII в логах и
I/O. На JRE 17 без этого `file.encoding` уходит в ASCII. Прод-фронты
(nginx-alpine, статика) локаль не задают -- она им не нужна.

На локаль и collation базы образ приложения не влияет: PostgreSQL -- отдельный
контейнер, кодировка фиксируется при initdb внутри postgres-образа.

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
теряются при пересоздании пода или перезапуске ВМ.

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

Основной способ поднять dev-сервер -- запустить скрипт `dev-start.sh` из каталога
компонента внутри пода (через VS Code Remote или `kubectl exec`). Скрипты лежат
рядом с исходниками и попадают в под вместе с клоном в `/workspace`.

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
Основной путь -- запуск `dev-start.sh` внутри пода.

### Тонкости команд запуска

Команды в `dev-start.sh` подобраны под поведение инструментов в поде:

- Фронт app1 (Vite): зависимости ставятся через `npm`, а не corepack/pnpm --
  corepack/pnpm в поде падает на записи кеша (`.cache/node/corepack`). `vite`
  берётся из локального `./node_modules/.bin`.
- Фронт app2 (Angular): `ng` берётся из локального `./node_modules/.bin` --
  `npx ng` тянет посторонний пакет.
- Бек app2 (uvicorn): запускается без `--reload`. В detached-запуске
  `--reload` не выживает: супервизор сбрасывается, когда процесс
  переусыновляется к PID 1.
- Слушать обязательно `0.0.0.0:8080` -- это `targetPort` dev-Service.
- dev-серверы фронтов отвечают через ingress по nip.io только при заданном
  `allowedHosts` (`.nip.io`): у Vite -- в
  [vite.config.ts](../../apps/app1-java-react/frontend/vite.config.ts), у
  Angular -- в [angular.json](../../apps/app2-python-angular/frontend/angular.json)
  (`serve.options.allowedHosts`).

## Обновление рабочей копии (git pull по SSH)

Штатный способ обновить исходники в `/workspace` -- `git pull` по SSH из каталога
рабочей копии от пользователя `app`. Приватный ключ монтируется Secret'ом
`id-rsa-vcs` в `~/.ssh/id_rsa`. dev-образы (`Dockerfile.dev`) запекают в
`/etc/ssh/ssh_config` блок для `github.com` (`StrictHostKeyChecking no`,
`UserKnownHostsFile=/dev/null`), поэтому `git pull` работает без `known_hosts`:

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
- [Операции kube_ci](kube-ci-operations.md)
- [Управление секретами](secrets.md)
- [Спецификации Kubernetes](../kubernetes/specifications.md)
- [Доставка в Kubernetes](../concepts/delivery-to-k8s.md)
- [Компромиссы и безопасность схемы](../concepts/security-and-tradeoffs.md)
- [app1-java-react](../products/app1-java-react.md)
