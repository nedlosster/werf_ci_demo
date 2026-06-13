#!/bin/bash
#
# Рендеринг всех mermaid диаграмм в PNG
# Использование: ./scripts/diagrams/render-all.sh
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DIAGRAMS_DIR="${PROJECT_ROOT}/docs/diagrams"
OUTPUT_DIR="${PROJECT_ROOT}/docs/pics"

# Проверка наличия mmdc (mermaid-cli)
if ! command -v mmdc &> /dev/null; then
    echo "ОШИБКА: mermaid-cli (mmdc) не установлен"
    echo "Установка: npm install -g @mermaid-js/mermaid-cli"
    exit 1
fi

# Создание выходной директории если не существует
mkdir -p "${OUTPUT_DIR}"

# Счётчики
SUCCESS=0
FAILED=0

echo "Рендеринг диаграмм из ${DIAGRAMS_DIR}"
echo "Выходная папка: ${OUTPUT_DIR}"
echo "---"

# Рендеринг каждого .mmd файла
for mmd_file in "${DIAGRAMS_DIR}"/*.mmd; do
    if [ -f "$mmd_file" ]; then
        filename=$(basename "$mmd_file" .mmd)
        output_file="${OUTPUT_DIR}/${filename}.png"

        echo -n "Рендеринг ${filename}.mmd -> ${filename}.png ... "

        if mmdc -i "$mmd_file" -o "$output_file" -b white -s 2 2>/dev/null; then
            echo "OK"
            ((SUCCESS++)) || true
        else
            echo "ОШИБКА"
            ((FAILED++)) || true
        fi
    fi
done

echo "---"
echo "Завершено: ${SUCCESS} успешно, ${FAILED} с ошибками"

if [ $FAILED -gt 0 ]; then
    exit 1
fi
