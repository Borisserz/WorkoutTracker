import json
import urllib.request

# 1. Загружаем твой текущий exercises.json
local_db_path = "WorkoutTracker/DataLayer/LocalDB/exercises.json"
with open(local_db_path, "r") as f:
    local_exercises = json.load(f)

# 2. Скачиваем exercises.json из hasaneyldrm/exercises-dataset
url = "https://raw.githubusercontent.com/hasaneyldrm/exercises-dataset/main/data/exercises.json"
req = urllib.request.Request(url)
with urllib.request.urlopen(req) as response:
    hasan_exercises = json.loads(response.read().decode())

# 3. Создаем словарь (hash map) по имени упражнения в нижнем регистре
hasan_dict = {}
for ex in hasan_exercises:
    name_key = ex["name"].lower().strip()
    hasan_dict[name_key] = ex

# 4. Скрещиваем базы
matched_count = 0
for ex in local_exercises:
    name_key = ex["name"].lower().strip()
    
    # Пытаемся найти совпадение по имени
    if name_key in hasan_dict:
        hasan_ex = hasan_dict[name_key]
        gif_path = hasan_ex["gif_url"] # e.g. "videos/0001-2gPfomN.gif"
        
        # Формируем прямую ссылку на github raw, чтобы работало прямо сейчас без Firebase!
        raw_url = f"https://raw.githubusercontent.com/hasaneyldrm/exercises-dataset/main/{gif_path}"
        ex["gifUrl"] = raw_url
        matched_count += 1
    else:
        # Для дебага, если имя чуть-чуть отличается
        # Попробуем найти подстроку
        for h_key, h_ex in hasan_dict.items():
            if name_key in h_key or h_key in name_key:
                raw_url = f"https://raw.githubusercontent.com/hasaneyldrm/exercises-dataset/main/{h_ex['gif_url']}"
                ex["gifUrl"] = raw_url
                matched_count += 1
                break

print(f"✅ Успешно сопоставлено и добавлено видео для {matched_count} из {len(local_exercises)} упражнений!")

# 5. Сохраняем обратно в твой exercises.json
with open(local_db_path, "w") as f:
    json.dump(local_exercises, f, indent=2, ensure_ascii=False)

print("✅ Файл exercises.json обновлен!")
