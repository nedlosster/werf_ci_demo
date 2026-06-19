#!/usr/bin/env bash
# Рендер страниц документации для встраивания в docs/demo/talk-deck.html.
# Каждый .md рендерится pandoc-ом в docs/demo/embed/<slug>.html со стилем embed.css.
# Идемпотентен: повторный запуск перезаписывает страницы. Запускать при правке доков.
set -euo pipefail

cd "$(dirname "$0")/../.."          # корень репозитория
EMBED_DIR="docs/demo/embed"
mkdir -p "$EMBED_DIR"

# slug -> путь .md от корня репозитория
declare -A DOCS=(
  [readme]="docs/README.md"
  [overview]="docs/products/overview.md"
  [delivery-to-k8s]="docs/concepts/delivery-to-k8s.md"
  [werf-intro]="docs/concepts/werf-intro.md"
  [application-contract]="docs/concepts/application-contract.md"
  [dev-in-cluster]="docs/delivery/dev-in-cluster.md"
  [dev-in-cluster-vs-tools]="docs/delivery/dev-in-cluster-vs-tools.md"
  [dev-workflow-cycle]="docs/delivery/dev-workflow-cycle.md"
  [app1-java-react]="docs/products/app1-java-react.md"
  [dev-caches-and-volumes]="docs/delivery/dev-caches-and-volumes.md"
  [kube-ci-operations]="docs/delivery/kube-ci-operations.md"
  [dev-prod]="docs/delivery/dev-prod.md"
  [security-and-tradeoffs]="docs/concepts/security-and-tradeoffs.md"
  [integrations]="docs/integrations/README.md"
  [secrets]="docs/delivery/secrets.md"
  [qa-bank]="docs/demo/qa-bank.md"
)

n=0
for slug in "${!DOCS[@]}"; do
  src="${DOCS[$slug]}"
  if [[ ! -f "$src" ]]; then
    echo "ПРОПУСК: нет $src" >&2
    continue
  fi
  pandoc "$src" -s -c embed.css \
    --metadata title="$(basename "$src")" \
    -o "$EMBED_DIR/$slug.html"
  n=$((n+1))
done

echo "Готово: $n страниц в $EMBED_DIR/"
