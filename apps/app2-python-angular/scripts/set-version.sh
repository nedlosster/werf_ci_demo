#!/usr/bin/env bash
# Единая версия app2-python-angular во всех файлах (схема respoolman).
# Источник истины -- ./VERSION; CI_TAG в .helm/def.sh читает его же.
#
#   ./scripts/set-version.sh <X.Y.Z>   -- установить версию
#   ./scripts/set-version.sh bump      -- инкремент patch
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

VERSION_FILE="$PROJECT_DIR/VERSION"
VERSION_PY="$PROJECT_DIR/backend/src/app2/_version.py"
PYPROJECT="$PROJECT_DIR/backend/pyproject.toml"
PACKAGE_JSON="$PROJECT_DIR/frontend/package.json"
CHART="$PROJECT_DIR/.helm/Chart.yaml"

get_current() { tr -d '[:space:]' < "$VERSION_FILE"; }

apply_version() {
    local ver="$1" cur="$2"
    echo "$ver" > "$VERSION_FILE"
    sed -i "s|__version__ = \"${cur}\"|__version__ = \"${ver}\"|" "$VERSION_PY"
    sed -i "s|^version = \"${cur}\"|version = \"${ver}\"|" "$PYPROJECT"
    sed -i "s|\"version\": \"${cur}\"|\"version\": \"${ver}\"|" "$PACKAGE_JSON"
    sed -i "s|^version: .*|version: ${ver}|" "$CHART"
    sed -i "s|^appVersion: .*|appVersion: \"${ver}\"|" "$CHART"
    echo "Версия ${cur} -> ${ver} (VERSION, _version.py, pyproject.toml, package.json, Chart.yaml)"
}

[ $# -eq 1 ] || { echo "Использование: $0 <X.Y.Z|bump>"; exit 1; }

CUR="$(get_current)"
if [ "$1" = "bump" ]; then
    IFS='.' read -r MA MI PA <<< "$CUR"
    NEW="${MA}.${MI}.$((PA + 1))"
else
    NEW="$1"
    [[ "$NEW" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Ошибка: версия не semver X.Y.Z"; exit 1; }
fi

apply_version "$NEW" "$CUR"

if [ "$1" = "bump" ]; then
    git -C "$PROJECT_DIR" add VERSION backend/src/app2/_version.py backend/pyproject.toml frontend/package.json .helm/Chart.yaml 2>/dev/null || true
fi
