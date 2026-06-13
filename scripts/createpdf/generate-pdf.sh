#!/bin/bash
#
# Генерация единого PDF из нескольких Markdown файлов с оглавлением
# Использование:
#   ./scripts/createpdf/generate-pdf.sh <doc-order.txt> <output-name> [title] [subtitle]
#
# Пример:
#   ./scripts/createpdf/generate-pdf.sh \
#       scripts/createpdf/doc-order-finblock.txt \
#       finblock \
#       "Финансовая модель CMDB" \
#       "Сервисно-финансовая надстройка над CMDB"
#
# Особенности:
#   - Каждый документ начинается с новой страницы
#   - Заголовок раздела "## Имя" в doc-order.txt создаёт разрыв с заголовком
#   - Автоматическое оглавление (TOC) через wkhtmltopdf
#   - Титульная страница с title/subtitle
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DOCS_DIR="${PROJECT_ROOT}/docs"
OUTPUT_DIR="${DOCS_DIR}/pdf"
STYLE_FILE="${SCRIPT_DIR}/style.css"
TOC_XSL="${SCRIPT_DIR}/toc.xsl"

DOC_ORDER_FILE="${1:-}"
OUTPUT_NAME="${2:-}"
TITLE="${3:-CMDB Documentation}"
SUBTITLE="${4:-}"

if [[ -z "$DOC_ORDER_FILE" || -z "$OUTPUT_NAME" ]]; then
    echo "Usage: $0 <doc-order.txt> <output-name> [title] [subtitle]"
    exit 1
fi

OUTPUT_FILE="${OUTPUT_DIR}/${OUTPUT_NAME}.pdf"
TEMP_FILE="${DOCS_DIR}/.combined-${OUTPUT_NAME}.md"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

check_dependencies() {
    log_step "Проверка зависимостей..."
    local missing=false
    if ! command -v pandoc &> /dev/null; then
        log_error "pandoc не установлен (apt-get install -y pandoc)"
        missing=true
    fi
    if ! command -v wkhtmltopdf &> /dev/null; then
        log_error "wkhtmltopdf не установлен (apt-get install -y wkhtmltopdf)"
        missing=true
    fi
    $missing && exit 1
    log_info "pandoc: $(pandoc --version | head -1)"
    log_info "wkhtmltopdf: $(wkhtmltopdf --version 2>&1 | head -1)"
}

check_doc_order() {
    if [ ! -f "$DOC_ORDER_FILE" ]; then
        log_error "Файл порядка документов не найден: $DOC_ORDER_FILE"
        exit 1
    fi
}

create_combined_markdown() {
    log_step "Объединение документов..."
    mkdir -p "$OUTPUT_DIR"
    > "$TEMP_FILE"

    local first=true
    while IFS= read -r line || [ -n "$line" ]; do
        [[ -z "$line" ]] && continue

        # Заголовок раздела (## Title)
        if [[ "$line" =~ ^##[[:space:]](.+)$ ]]; then
            local section_title="${BASH_REMATCH[1]}"
            if ! $first; then
                echo "" >> "$TEMP_FILE"
                echo '<div class="page-break"></div>' >> "$TEMP_FILE"
                echo "" >> "$TEMP_FILE"
            fi
            echo "<div class=\"section-header\">${section_title}</div>" >> "$TEMP_FILE"
            echo "" >> "$TEMP_FILE"
            echo "# ${section_title}" >> "$TEMP_FILE"
            echo "" >> "$TEMP_FILE"
            first=false
            continue
        fi

        # Комментарии
        [[ "$line" =~ ^# ]] && continue

        local filepath="${DOCS_DIR}/${line}"
        if [ ! -f "$filepath" ]; then
            log_warn "Файл не найден: $line"
            continue
        fi

        if ! $first; then
            echo "" >> "$TEMP_FILE"
            echo '<div class="page-break"></div>' >> "$TEMP_FILE"
            echo "" >> "$TEMP_FILE"
        fi
        first=false

        local anchor_id=$(echo "$line" | sed 's/[\/\.]/-/g' | sed 's/^-*//')
        echo "<a id=\"${anchor_id}\"></a>" >> "$TEMP_FILE"
        echo "" >> "$TEMP_FILE"
        echo "<div class=\"file-header\">docs/${line}</div>" >> "$TEMP_FILE"
        echo "" >> "$TEMP_FILE"
        cat "$filepath" >> "$TEMP_FILE"
        echo "" >> "$TEMP_FILE"
        log_info "  + $line"
    done < "$DOC_ORDER_FILE"

    # Разрешение путей к изображениям. В склейке статьи лежат в docs/.combined-*.md,
    # а pandoc запускается из docs/, поэтому относительные ссылки ../pics/ и pics/
    # из статей указывают мимо docs/pics/. Переписываем их в абсолютный путь.
    sed -i "s|](\.\./pics/|](${DOCS_DIR}/pics/|g" "$TEMP_FILE"
    sed -i "s|](pics/|](${DOCS_DIR}/pics/|g" "$TEMP_FILE"

    # Удаление markdown-ссылок (но не изображений)
    local tmp="${TEMP_FILE}.cv"
    cp "$TEMP_FILE" "$tmp"
    sed -i 's|!\[|__IMG_OPEN__|g' "$tmp"
    sed -i 's|\[\([^]]*\)\]([^)]*)|\1|g' "$tmp"
    sed -i 's|__IMG_OPEN__|![|g' "$tmp"
    mv "$tmp" "$TEMP_FILE"
}

create_title_html() {
    local out="$1"
    local date=$(date +"%d.%m.%Y")
    cat > "$out" <<TITLEHTML
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
body { font-family: 'DejaVu Sans', Arial, sans-serif; text-align: center; padding-top: 200px; }
.title { font-size: 32pt; font-weight: bold; color: #1a1a1a; border-top: 3px solid #333; border-bottom: 3px solid #333; padding: 25px 0; margin: 0 50px 30px 50px; }
.subtitle { font-size: 16pt; color: #555; font-style: italic; margin-bottom: 80px; padding: 0 60px; }
.date { font-size: 12pt; color: #888; }
</style>
</head>
<body>
<div class="title">${TITLE}</div>
<div class="subtitle">${SUBTITLE}</div>
<div class="date">Дата генерации: ${date}</div>
</body>
</html>
TITLEHTML
}

generate_pdf() {
    log_step "Генерация PDF..."
    cd "$DOCS_DIR"

    local TITLE_HTML="${DOCS_DIR}/.title-${OUTPUT_NAME}.html"
    local CONTENT_HTML="${DOCS_DIR}/.content-${OUTPUT_NAME}.html"

    create_title_html "$TITLE_HTML"

    pandoc "$TEMP_FILE" -o "$CONTENT_HTML" \
        --css="$STYLE_FILE" \
        --metadata title="$TITLE" \
        --standalone

    wkhtmltopdf \
        --enable-local-file-access \
        --margin-top 15mm --margin-bottom 20mm \
        --margin-left 15mm --margin-right 15mm \
        cover "$TITLE_HTML" \
        toc --xsl-style-sheet "$TOC_XSL" \
        "$CONTENT_HTML" \
            --footer-center "[page]/[topage]" \
            --footer-font-size 10 \
            --footer-spacing 5 \
        "$OUTPUT_FILE"

    cd - > /dev/null
    rm -f "$TEMP_FILE" "$TITLE_HTML" "$CONTENT_HTML"

    if [ -f "$OUTPUT_FILE" ]; then
        local size=$(du -h "$OUTPUT_FILE" | cut -f1)
        log_info "PDF создан: $OUTPUT_FILE ($size)"
    else
        log_error "Не удалось создать PDF"
        exit 1
    fi
}

check_dependencies
check_doc_order
create_combined_markdown
generate_pdf
log_info "Готово"
