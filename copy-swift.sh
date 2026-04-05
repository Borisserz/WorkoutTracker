#!/bin/bash

TEMP_FILE="all_swift_code.tmp"
> "$TEMP_FILE" # Очищаем файл

echo "🔍 Начинаю сбор кода проекта WorkoutTracker (включая WatchApp)..."

# 1. Важные файлы конфигурации
CONFIG_FILES=(
    "README.md"
    "WorkoutTracker/Info.plist"
    "WorkoutTracker/WorkoutTracker.entitlements"
    "StatsWidget/Info.plist"
    "StatsWidget/StatsWidgetExtension.entitlements"
    "WorkoutTimerWidget/Info.plist"
    "WatchApp/Info.plist"  # <--- Добавлено для часов
    "Package.swift"
    "Podfile"
)

files_to_read=""

# Добавляем конфиги, если они существуют
for file in "${CONFIG_FILES[@]}"; do
    if [ -f "$file" ]; then
        files_to_read="$files_to_read$file"$'\n'
    fi
done

# 2. Ищем исходный код (.swift) и файлы локализации (.xcstrings)
# Добавлена папка WatchApp в список поиска
src_code=$(find WorkoutTracker StatsWidget WorkoutTimerWidget WatchApp -type f \( -name '*.swift' -o -name '*.xcstrings' \) \
    -not -path "*/Pods/*" \
    -not -path "*/.build/*" \
    -not -path "*/DerivedData/*" \
    -not -path "*/.*" 2>/dev/null)

if [ -n "$src_code" ]; then
    files_to_read="$files_to_read$src_code"$'\n'
fi

# Проверка на пустоту
if [ -z "$files_to_read" ]; then
    echo "❌ Файлы не найдены. Убедись, что запускаешь скрипт из корня проекта."
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
    echo "✅ Готово! Весь код (включая WatchApp) в буфере обмена (macOS)."
elif command -v clip.exe > /dev/null; then
    cat "$TEMP_FILE" | clip.exe
    echo "✅ Готово! Весь код в буфере обмена (Windows)."
elif command -v xclip > /dev/null; then
    cat "$TEMP_FILE" | xclip -selection clipboard
    echo "✅ Готово! Весь код в буфере обмена (Linux)."
else
    echo "❌ Утилита копирования не найдена. Результат сохранен в файле: $TEMP_FILE"
    exit 1
fi

rm "$TEMP_FILE"
