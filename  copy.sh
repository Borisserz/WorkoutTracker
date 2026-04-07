#!/bin/bash

TEMP_FILE="workouttracker_lang.tmp"
> "$TEMP_FILE"

echo "🌍 Сбор файлов локализации (.xcstrings)..."

if [ -d "WorkoutTracker" ]; then
    # Ищем только .xcstrings
    lang_files=$(find WorkoutTracker -type f -name '*.xcstrings' -not -path "*/.*" 2>/dev/null)
    
    if [ -z "$lang_files" ]; then
        echo "❌ Файлы локализации не найдены."
        exit 1
    fi
else
    echo "❌ Папка 'WorkoutTracker' не найдена."
    exit 1
fi

echo "$lang_files" | while IFS= read -r file; do
    if [ -f "$file" ]; then
        echo "🌐 Добавляю перевод: $file"
        echo -e "\n============================================================" >> "$TEMP_FILE"
        echo "LOCALIZATION FILE: $file" >> "$TEMP_FILE"
        echo -e "============================================================\n" >> "$TEMP_FILE"
        cat "$file" >> "$TEMP_FILE"
    fi
done

if command -v pbcopy > /dev/null; then
    cat "$TEMP_FILE" | pbcopy
    echo "✅ Локализация скопирована в буфер обмена."
else
    echo "✅ Готово. Файлы перевода в: $TEMP_FILE"
fi

rm "$TEMP_FILE"

