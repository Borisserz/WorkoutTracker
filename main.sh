#!/bin/bash

TEMP_FILE="workouttracker_main_code.tmp"
> "$TEMP_FILE" # Очищаем файл

echo "🔍 Начинаю сбор кода ТОЛЬКО из основной папки WorkoutTracker..."

# 1. Берем только конфиги основного приложения и корень
CONFIG_FILES=(
    "README.md"
    "WorkoutTracker/Info.plist"
    "WorkoutTracker/WorkoutTracker.entitlements"
)

files_to_read=""

# Добавляем конфиги, если они существуют
for file in "${CONFIG_FILES[@]}"; do
    if [ -f "$file" ]; then
        files_to_read="$files_to_read$file"$'\n'
    fi
done

# 2. Ищем исходники (.swift) и локализацию (.xcstrings) ТОЛЬКО в папке WorkoutTracker
if [ -d "WorkoutTracker" ]; then
    src_code=$(find WorkoutTracker -type f \( -name '*.swift' -o -name '*.xcstrings' \) \
        -not -path "*/.*" 2>/dev/null)
        
    if [ -n "$src_code" ]; then
        files_to_read="$files_to_read$src_code"$'\n'
    fi
else
    echo "❌ Папка 'WorkoutTracker' не найдена. Убедись, что запускаешь скрипт из корня проекта."
    exit 1
fi

# Проверка на пустоту
if [ -z "$files_to_read" ]; then
    echo "❌ Файлы не найдены."
    exit 1
fi

# Читаем и записываем
echo "$files_to_read" | sed '/^\s*$/d' | while IFS= read -r file; do
    if [ -f "$file" ]; then
        echo "📄 Добавляю: $file"
        echo -e "\n============================================================" >> "$TEMP_FILE"
        echo "FILE: $file" >> "$TEMP_FILE"
        echo -e "============================================================\n" >> "$TEMP_FILE"
        cat "$file" >> "$TEMP_FILE"
        echo -e "\n" >> "$TEMP_FILE"
    fi
done

# Копирование в буфер обмена
if command -v pbcopy > /dev/null; then
    cat "$TEMP_FILE" | pbcopy
    echo "✅ Готово! Код основного приложения WorkoutTracker в буфере обмена."
else
    echo "❌ Утилита копирования pbcopy не найдена (ты точно на Mac?). Результат в файле: $TEMP_FILE"
    exit 1
fi

# Удаляем временный файл
rm "$TEMP_FILE"
