import json

# Paths
en_db_path = "WorkoutTracker/DataLayer/LocalDB/exercises.json"
ru_db_path = "WorkoutTracker/DataLayer/LocalDB/exercises_ru.json"

# Load EN
with open(en_db_path, "r") as f:
    en_exercises = json.load(f)

# Create ID -> gifUrl mapping
gif_map = {}
for ex in en_exercises:
    if "id" in ex and "gifUrl" in ex:
        gif_map[ex["id"]] = ex["gifUrl"]

# Load RU
with open(ru_db_path, "r") as f:
    ru_exercises = json.load(f)

# Update RU
matched = 0
for ex in ru_exercises:
    ex_id = ex.get("id")
    if ex_id in gif_map:
        ex["gifUrl"] = gif_map[ex_id]
        matched += 1

# Save RU
with open(ru_db_path, "w") as f:
    json.dump(ru_exercises, f, indent=2, ensure_ascii=False)

print(f"✅ Updated {matched} Russian exercises with gifUrl!")
