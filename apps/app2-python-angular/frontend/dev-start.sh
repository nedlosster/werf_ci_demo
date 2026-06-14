#!/bin/bash
# Запуск dev-сервера фронтенда app2-python-angular (Angular CLI) внутри dev-пода.
# Слушает 0.0.0.0:8080. ng берём из node_modules: npx ng тянет посторонний
# пакет. Цель serve (host/port) задана в angular.json.
# Запуск из VS Code Remote в поде app2-python-angular-frontend-dev-0:
#   ./apps/app2-python-angular/frontend/dev-start.sh
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"
npm install
exec ./node_modules/.bin/ng serve --host 0.0.0.0 --port 8080
