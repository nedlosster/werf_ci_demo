#!/bin/bash
# Запуск dev-сервера бекенда app2-python-angular (FastAPI/uvicorn) внутри dev-пода.
# Слушает 0.0.0.0:8080. Зависимости ставим в user-site каждый запуск:
# site-packages пода эфемерны (не на PVC), переживает их только /workspace.
# Запуск из VS Code Remote в поде app2-python-angular-backend-dev-0:
#   ./apps/app2-python-angular/backend/dev-start.sh
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"
pip install --user -e .
exec python -m uvicorn app2.main:app --host 0.0.0.0 --port 8080
