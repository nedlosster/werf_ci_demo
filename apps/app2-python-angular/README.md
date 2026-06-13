# app2-python-angular

Демо-продукт (второй стек, по образцу app1).

| Слой | Стек | Сборка |
|---|---|---|
| frontend | Angular + TypeScript | npm |
| backend | FastAPI (Python 3.12) | pip |
| хранилище | PostgreSQL + pgAdmin (pgAdmin -- dev) | upstream-образы |

## Структура

```
backend/      FastAPI hello-world (Dockerfile prod, Dockerfile.dev, pyproject.toml, src/app2/)
frontend/     Angular hello-world (Dockerfile prod, Dockerfile.dev, angular.json, src/)
.helm/        чарт (configmap, secret, postgres, backend/frontend prod+dev, pgadmin, ingress) + def.sh
.werf-partial/ описание образов (prod+dev, gated по ENVNAME)
werf.yaml, install/prepare-scripts/init-dev-env.sh, scripts/set-version.sh, VERSION
```

## Окружения

- **dev** -- разработка внутри кластера: dev-поды `sleep infinity` + persistent-volumes
  (исходники + кеши + vscode-server). См. [../../docs/dev-in-cluster.md](../../docs/dev-in-cluster.md).
- **prod** -- собранные multi-stage образы, Deployment'ы.

## Версия и эндпоинты

- `./scripts/set-version.sh <X.Y.Z|bump>` синхронизирует `VERSION`,
  `backend/src/app2/_version.py`, `backend/pyproject.toml`, `frontend/package.json`,
  `.helm/Chart.yaml`. `CI_TAG` -- из `VERSION`.
- Бек отдаёт `/api/v1/version`; фронт показывает свою версию (из package.json) и
  версию бека (через REST).
