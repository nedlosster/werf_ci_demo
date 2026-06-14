#!/bin/bash
# Запуск dev-сервера бекенда app1-java-react (Spring Boot) внутри dev-пода.
# Слушает 0.0.0.0:8080 (context-path /api); actuator -- на 8081.
# Запуск из VS Code Remote в поде app1-java-react-backend-dev-0:
#   ./apps/app1-java-react/backend/dev-start.sh
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"
exec mvn -q -DskipTests spring-boot:run
