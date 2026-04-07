#!/bin/bash

TEMP_FILE="workouttracker_code.tmp"
> "$TEMP_FILE"

echo "🔍 Сбор кода WorkoutTracker (БЕЗ локализации)..."

# 1. Конфиги
CONFIG_FILES=(
    "README.md"
    "WorkoutTracker/Info.plist"
    "WorkoutTracker/WorkoutTracker.entitlements"
)

files_to_read=""

for file in "${CONFIG_FILES[@]}"; do
    if [ -f "$file" ]; then
        files_to_read="$files_to_read$file"$'\n'
    fi
done

# 2. Только .swift файлы
if [ -d "WorkoutTracker" ]; then
    src_code=$(find WorkoutTracker -type f -name '*.swift' -not -path "*/.*" 2>/dev/null)
    if [ -n "$src_code" ]; then
        files_to_read="$files_to_read$src_code"$'\n'
    fi
else
    echo "❌ Папка 'WorkoutTracker' не найдена."
    exit 1
fi

# Чтение и запись
echo "$files_to_read" | sed '/^\s*$/d' | while IFS= read -r file; do
    if [ -f "$file" ]; then
        echo "📄 Добавляю: $file"
        echo -e "\n============================================================" >> "$TEMP_FILE"
        echo "FILE: $file" >> "$TEMP_FILE"
        echo -e "============================================================\n" >> "$TEMP_FILE"
        cat "$file" >> "$TEMP_FILE"
    fi
done

if command -v pbcopy > /dev/null; then
    cat "$TEMP_FILE" | pbcopy
    echo "✅ Код (Swift + Configs) в буфере обмена."
else
    echo "✅ Готово. Результат в: $TEMP_FILE"
fi

rm "$TEMP_FILE"
