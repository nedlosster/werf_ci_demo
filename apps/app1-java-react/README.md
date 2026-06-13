# app1-java-react

Демо-продукт (эталон наполнения).

| Слой | Стек | Сборка |
|---|---|---|
| frontend | React + Vite + TypeScript | pnpm |
| backend | Spring Boot (Java 17) | maven |
| хранилище | PostgreSQL + pgAdmin (pgAdmin -- dev) | upstream-образы |

## Структура

```
backend/      Spring Boot hello-world (Dockerfile prod, Dockerfile.dev, pom.xml, src/)
frontend/     React+Vite hello-world (Dockerfile prod, Dockerfile.dev, package.json, src/)
.helm/        чарт (configmap, secret, postgres, backend/frontend prod+dev, pgadmin, ingress) + def.sh
.werf-partial/ описание образов (backend/frontend, prod+dev, gated по ENVNAME)
werf.yaml     werf-проект
install/prepare-scripts/init-dev-env.sh   инициализация dev-пода (clone, кеши)
scripts/set-version.sh  единая версия (VERSION -> pom.xml/package.json/Chart.yaml)
VERSION       источник истины версии
```

## Окружения

- **dev** -- разработка внутри кластера: dev-поды `sleep infinity` + persistent-volumes
  (исходники + кеши + vscode-server), VS Code Remote. См.
  [../../docs/dev-in-cluster.md](../../docs/dev-in-cluster.md).
- **prod** -- собранные multi-stage образы, Deployment'ы, реплики.

Переключение -- через `values-<env>.yaml` (kube_ci подгружает по ENVNAME).

## Версия

```bash
./scripts/set-version.sh 0.2.0   # или bump
```
Синхронизирует `VERSION`, `backend/pom.xml`, `frontend/package.json`,
`.helm/Chart.yaml`. `CI_TAG` (тег образов werf) читается из `VERSION`.
