#!/usr/bin/env bash
# Единая версия app1-java-react во всех файлах (схема respoolman).
# Источник истины -- ./VERSION; CI_TAG в .helm/def.sh читает его же.
#
#   ./scripts/set-version.sh <X.Y.Z>   -- установить версию
#   ./scripts/set-version.sh bump      -- инкремент patch
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

VERSION_FILE="$PROJECT_DIR/VERSION"
POM="$PROJECT_DIR/backend/pom.xml"
PACKAGE_JSON="$PROJECT_DIR/frontend/package.json"
CHART="$PROJECT_DIR/.helm/Chart.yaml"

get_current() { tr -d '[:space:]' < "$VERSION_FILE"; }

apply_version() {
    local ver="$1" cur="$2"
    echo "$ver" > "$VERSION_FILE"
    # pom.xml: меняем именно проектную версию (совпадает с текущей $cur;
    # версия parent 3.2.5 не совпадает -- не затрагивается)
    sed -i "s|<version>${cur}</version>|<version>${ver}</version>|" "$POM"
    # package.json
    sed -i "s|\"version\": \"${cur}\"|\"version\": \"${ver}\"|" "$PACKAGE_JSON"
    # Chart.yaml: version + appVersion
    sed -i "s|^version: .*|version: ${ver}|" "$CHART"
    sed -i "s|^appVersion: .*|appVersion: \"${ver}\"|" "$CHART"
    echo "Версия ${cur} -> ${ver} (VERSION, pom.xml, package.json, Chart.yaml)"
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
    git -C "$PROJECT_DIR" add VERSION backend/pom.xml frontend/package.json .helm/Chart.yaml 2>/dev/null || true
fi
