#!/bin/bash
# Запуск dev-сервера фронтенда app1-java-react (Vite) внутри dev-пода.
# Слушает 0.0.0.0:8080. Ставим зависимости через npm: corepack/pnpm в поде
# падает на записи кеша (.cache/node/corepack). vite берём из node_modules.
# Запуск из VS Code Remote в поде app1-java-react-frontend-dev-0:
#   ./apps/app1-java-react/frontend/dev-start.sh
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"
npm install
exec ./node_modules/.bin/vite --host 0.0.0.0 --port 8080
