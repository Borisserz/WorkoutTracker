import json

def classify(item):
    name = item.get("name", "").lower()
    force = (item.get("force") or "").lower()
    mechanic = (item.get("mechanic") or "").lower()
    pm = item.get("primaryMuscles", [])
    primary = pm[0].lower() if pm else ""

    if "curl" in name and "leg" not in name: return "elbowFlexion"
    if "squat" in name or "thruster" in name or "wall sit" in name: return "squat"
    if "deadlift" in name or "good morning" in name or "hyperextension" in name: return "hinge"
    if "lunge" in name or "step-up" in name or "step up" in name: return "lunge"
    if "calf raise" in name or "calves" in name: return "calfRaise"
    if "lateral raise" in name or "front raise" in name or "fly" in name: return "lateralRaise"

    if primary in ["chest", "pectorals"]:
        return "horizontalPress" if force == "push" else "unsupported"
    elif primary in ["shoulders", "delts", "deltoids"]:
        return "verticalPress" if force == "push" else "lateralRaise"
    elif primary in ["middle back", "lats", "upper back", "traps", "trapezius"]:
        if force == "pull":
            return "horizontalPull" if "row" in name else "verticalPull"
        return "unsupported"
    elif primary == "triceps": return "elbowExtension"
    elif primary == "biceps": return "elbowFlexion"
    elif primary in ["quadriceps", "quads", "glutes", "gluteal"]:
        return "squat" if mechanic == "compound" else "unsupported"
    elif primary in ["hamstrings", "hamstring", "lower back", "lower-back"]:
        return "hinge"
    elif primary in ["abdominals", "abs", "core", "obliques"]:
        return "coreFlexion"
    
    return "unsupported"

with open('./WorkoutTracker/DataLayer/LocalDB/exercises.json', 'r') as f:
    data = json.load(f)

supported = []
for item in data:
    pattern = classify(item)
    if pattern != "unsupported":
        supported.append((item.get("name"), pattern))

print(f"Total supported: {len(supported)}")
for name, pattern in supported:
    print(f"- {name} ({pattern})")

