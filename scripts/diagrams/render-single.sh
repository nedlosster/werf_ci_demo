#!/bin/bash
#
# Рендеринг одной mermaid диаграммы в PNG
# Использование: ./scripts/diagrams/render-single.sh <имя-диаграммы>
# Пример: ./scripts/diagrams/render-single.sh paasadapter-architecture
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DIAGRAMS_DIR="${PROJECT_ROOT}/docs/diagrams"
OUTPUT_DIR="${PROJECT_ROOT}/docs/pics"

# Проверка аргументов
if [ $# -eq 0 ]; then
    echo "Использование: $0 <имя-диаграммы>"
    echo "Пример: $0 paasadapter-architecture"
    echo ""
    echo "Доступные диаграммы:"
    for mmd_file in "${DIAGRAMS_DIR}"/*.mmd; do
        if [ -f "$mmd_file" ]; then
            basename "$mmd_file" .mmd
        fi
    done
    exit 1
fi

DIAGRAM_NAME="$1"
INPUT_FILE="${DIAGRAMS_DIR}/${DIAGRAM_NAME}.mmd"
OUTPUT_FILE="${OUTPUT_DIR}/${DIAGRAM_NAME}.png"

# Проверка наличия mmdc (mermaid-cli)
if ! command -v mmdc &> /dev/null; then
    echo "ОШИБКА: mermaid-cli (mmdc) не установлен"
    echo "Установка: npm install -g @mermaid-js/mermaid-cli"
    exit 1
fi

# Проверка существования входного файла
if [ ! -f "$INPUT_FILE" ]; then
    echo "ОШИБКА: Файл не найден: ${INPUT_FILE}"
    exit 1
fi

# Создание выходной директории если не существует
mkdir -p "${OUTPUT_DIR}"

echo "Рендеринг ${DIAGRAM_NAME}.mmd -> ${DIAGRAM_NAME}.png"

if mmdc -i "$INPUT_FILE" -o "$OUTPUT_FILE" -b white -s 2; then
    echo "Успешно: ${OUTPUT_FILE}"
else
    echo "ОШИБКА при рендеринге"
    exit 1
fi
