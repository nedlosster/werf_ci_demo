# Разработка внутри кластера (dev-схема)

dev-вариант продукта разворачивается в Kubernetes как **долгоживущий под-песочница**
(`sleep infinity`), к которому разработчик подключается через **VS Code Remote** и
пишет код прямо в поде. Исходники, кеши пакетов и `.vscode-server` лежат в
persistent-volume'ах, поэтому наработки переживают перезапуск ВМ кластера.

Образец -- cassandra_apps / calligrapher. В демо реализовано для app1-java-react
(бек Spring Boot, фронт React+pnpm); по тому же шаблону делается app2.

## Что разворачивается в dev

`env=dev` (values-dev.yaml) рендерит вместо prod-Deployment'ов:
- `app1-java-react-backend-dev` -- StatefulSet, образ `backend-dev` (полный
  maven+JDK), `sleep infinity`;
- `app1-java-react-frontend-dev` -- StatefulSet, образ `frontend-dev` (полный
  node+pnpm), `sleep infinity`;
- PostgreSQL и pgAdmin (pgAdmin только в dev), ingress.

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

Внутри пода доступны maven/pnpm; сборка и запуск -- руками в поде. `.vscode-server`
ставится один раз и переживает перезапуски (живёт в PVC `homeapp`).

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
