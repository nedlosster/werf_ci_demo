#!/bin/bash
#
# Генерация PDF из одного Markdown файла
# Использование: ./scripts/createpdf/generate-single-pdf.sh <имя-файла>
# Пример: ./scripts/createpdf/generate-single-pdf.sh CLOUD_API_SPEC
#
# Особенности:
# - Без оглавления (TOC)
# - Поддержка картинок (относительные пути из docs/)
# - Стандартные стили проекта
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DOCS_DIR="${PROJECT_ROOT}/docs"
OUTPUT_DIR="${DOCS_DIR}/pdf"
STYLE_FILE="${SCRIPT_DIR}/style-single.css"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Проверка зависимостей
check_dependencies() {
    local missing=false

    if ! command -v pandoc &> /dev/null; then
        log_error "pandoc не установлен"
        log_info "Установите: sudo apt-get install -y pandoc"
        missing=true
    fi

    if ! command -v wkhtmltopdf &> /dev/null; then
        log_error "wkhtmltopdf не установлен"
        log_info "Установите: sudo apt-get install -y wkhtmltopdf"
        missing=true
    fi

    if $missing; then
        exit 1
    fi
}

# Показать справку
show_help() {
    echo "Генерация PDF из одного Markdown файла"
    echo ""
    echo "Использование: $0 <имя-файла>"
    echo ""
    echo "Примеры:"
    echo "  $0 CLOUD_API_SPEC           # docs/CLOUD_API_SPEC.md -> docs/pdf/CLOUD_API_SPEC.pdf"
    echo "  $0 ARCHITECTURE             # docs/ARCHITECTURE.md -> docs/pdf/ARCHITECTURE.pdf"
    echo "  $0 paasapi/VM               # docs/paasapi/VM.md -> docs/pdf/paasapi-VM.pdf"
    echo ""
    echo "Доступные документы в docs/:"
    for md_file in "${DOCS_DIR}"/*.md; do
        if [ -f "$md_file" ]; then
            basename "$md_file" .md
        fi
    done
}

# Основная функция
main() {
    local input_name="$1"

    if [ -z "$input_name" ]; then
        show_help
        exit 1
    fi

    check_dependencies

    # Определение путей
    local input_file="${DOCS_DIR}/${input_name}.md"
    local output_name=$(echo "$input_name" | sed 's|/|-|g')
    local output_file="${OUTPUT_DIR}/${output_name}.pdf"
    local temp_html="${DOCS_DIR}/.single-temp.html"

    if [ ! -f "$input_file" ]; then
        log_error "Файл не найден: $input_file"
        exit 1
    fi

    # Создание CSS если не существует
    if [ ! -f "$STYLE_FILE" ]; then
        create_style_file
    fi

    mkdir -p "$OUTPUT_DIR"

    log_info "Конвертация: $input_file"

    # Переходим в docs/ для корректных относительных путей к картинкам
    cd "$DOCS_DIR"

    # Конвертация Markdown -> HTML
    pandoc \
        "${input_name}.md" \
        -o "$temp_html" \
        --css="$STYLE_FILE" \
        --standalone \
        --metadata title="$(basename "$input_name")"

    # Конвертация HTML -> PDF
    wkhtmltopdf \
        --enable-local-file-access \
        --margin-top 15mm \
        --margin-bottom 20mm \
        --margin-left 15mm \
        --margin-right 15mm \
        --footer-center "[page]/[topage]" \
        --footer-font-size 10 \
        --footer-spacing 5 \
        "$temp_html" \
        "$output_file"

    cd - > /dev/null

    # Очистка
    rm -f "$temp_html"

    if [ -f "$output_file" ]; then
        local size=$(du -h "$output_file" | cut -f1)
        log_info "PDF создан: $output_file ($size)"
    else
        log_error "Не удалось создать PDF"
        exit 1
    fi
}

# Создание CSS файла для одиночных документов
create_style_file() {
    log_info "Создание файла стилей: $STYLE_FILE"

    cat > "$STYLE_FILE" << 'CSSEOF'
/* Стили для одиночного PDF документа */

/* Основные настройки */
body {
    font-family: 'DejaVu Sans', 'Liberation Sans', Arial, sans-serif;
    font-size: 14pt;
    line-height: 1.6;
    color: #333;
    max-width: 100%;
}

/* Заголовки */
h1 {
    font-size: 24pt;
    font-weight: bold;
    margin-top: 20pt;
    margin-bottom: 12pt;
    color: #1a1a1a;
    border-bottom: 2px solid #333;
    padding-bottom: 8pt;
}

h2 {
    font-size: 20pt;
    font-weight: bold;
    margin-top: 18pt;
    margin-bottom: 10pt;
    color: #2a2a2a;
}

h3 {
    font-size: 16pt;
    font-weight: bold;
    margin-top: 14pt;
    margin-bottom: 8pt;
    color: #3a3a3a;
}

h4 {
    font-size: 14pt;
    font-weight: bold;
    margin-top: 12pt;
    margin-bottom: 6pt;
}

/* Параграфы */
p {
    font-size: 14pt;
    margin-bottom: 10pt;
}

/* Списки */
ul, ol {
    font-size: 14pt;
    margin-bottom: 10pt;
}

li {
    margin-bottom: 4pt;
}

/* Код */
code {
    font-family: 'DejaVu Sans Mono', 'Liberation Mono', 'Courier New', monospace;
    font-size: 12pt;
    background-color: #f5f5f5;
    padding: 2pt 4pt;
    border-radius: 3pt;
}

pre {
    font-family: 'DejaVu Sans Mono', 'Liberation Mono', 'Courier New', monospace;
    font-size: 11pt;
    background-color: #f5f5f5;
    padding: 12pt;
    border-radius: 4pt;
    border: 1px solid #ddd;
    overflow-x: auto;
    line-height: 1.4;
    white-space: pre-wrap;
    word-wrap: break-word;
}

pre code {
    padding: 0;
    background-color: transparent;
}

/* Таблицы */
table {
    font-size: 12pt;
    border-collapse: collapse;
    width: 100%;
    margin-bottom: 14pt;
}

th, td {
    border: 1px solid #ccc;
    padding: 8pt 10pt;
    text-align: left;
}

th {
    background-color: #f0f0f0;
    font-weight: bold;
}

tr:nth-child(even) {
    background-color: #fafafa;
}

/* Цитаты (blockquote) */
blockquote {
    font-size: 13pt;
    border-left: 4px solid #666;
    padding-left: 16pt;
    margin-left: 0;
    color: #555;
    font-style: italic;
}

/* Изображения */
img {
    max-width: 100%;
    height: auto;
    display: block;
    margin: 15pt auto;
}

/* Ссылки */
a {
    color: #0066cc;
    text-decoration: none;
}

/* Горизонтальная линия */
hr {
    border: none;
    border-top: 1px solid #ccc;
    margin: 20pt 0;
}

/* Чек-листы */
input[type="checkbox"] {
    margin-right: 8pt;
}
CSSEOF
}

# Обработка аргументов
case "${1:-}" in
    --help|-h)
        show_help
        exit 0
        ;;
    *)
        main "$1"
        ;;
esac
