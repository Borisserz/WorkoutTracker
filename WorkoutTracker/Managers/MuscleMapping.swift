import Foundation

struct MuscleMapping {
    
    // Словарь: Название упражнения -> Список слагов (slug) из BodyData
    static let exerciseToMuscles: [String: [String]] = [
        
        // --- Chest ---
        "Bench Press": ["chest", "triceps", "deltoids"],
        "Push Ups": ["chest", "triceps", "deltoids", "abs"],
        "Incline Dumbbell Press": ["chest", "triceps", "deltoids"],
        "Dips": ["chest", "triceps", "deltoids"],
        
        // --- Back ---
        "Pull-ups": ["upper-back", "biceps", "forearm"], // upper-back выполняет роль широчайших
        "Deadlift": ["hamstring", "gluteal", "lower-back", "trapezius", "forearm"],
        "Barbell Rows": ["upper-back", "biceps", "lower-back", "deltoids"],
        "Lat Pulldown": ["upper-back", "biceps"],
        
        // --- Legs ---
        "Squat": ["quadriceps", "gluteal", "hamstring", "lower-back"],
        "Leg Press": ["quadriceps", "gluteal", "hamstring"],
        "Lunges": ["quadriceps", "gluteal", "hamstring", "calves"],
        "Calf Raises": ["calves"],
        
        // --- Shoulders ---
        "Overhead Press": ["deltoids", "triceps", "trapezius"],
        "Lateral Raises": ["deltoids"],
        "Face Pulls": ["deltoids", "trapezius", "upper-back"],
        
        // --- Arms ---
        "Barbell Curl": ["biceps", "forearm"],
        "Triceps Extension": ["triceps"],
        "Hammer Curls": ["biceps", "forearm"],
        
        // --- Core ---
        "Plank": ["abs", "obliques", "deltoids"],
        "Crunches": ["abs"],
        "Leg Raises": ["abs", "obliques"]
    ]
    
    // Запасной вариант: если упражнения нет в списке выше,
    // красим мышцы по названию группы (Muscle Group)
    static let groupToMuscles: [String: [String]] = [
        "Chest": ["chest"],
        "Back": ["upper-back", "lower-back", "trapezius"],
        "Legs": ["quadriceps", "hamstring", "gluteal", "calves", "adductors"],
        "Shoulders": ["deltoids", "trapezius"],
        "Arms": ["biceps", "triceps", "forearm"],
        "Core": ["abs", "obliques"]
    ]
    
    // Функция получения мышц теперь ищет и в пользовательских сохранениях
       static func getMuscles(for exerciseName: String, group: String) -> [String] {
           // 1. Сначала ищем в стандартном словаре
           if let muscles = exerciseToMuscles[exerciseName] {
               return muscles
           }
           
           // 2. Если не нашли, ищем в ПОЛЬЗОВАТЕЛЬСКИХ (из UserDefaults)
           // Мы сохраняем карту "Имя -> [Мышцы]" в UserDefaults
           let customMap = UserDefaults.standard.dictionary(forKey: "CustomExerciseMappings") as? [String: [String]] ?? [:]
           if let customMuscles = customMap[exerciseName] {
               return customMuscles
           }
           
           // 3. Если совсем ничего нет, возвращаем дефолт по группе
           return groupToMuscles[group] ?? []
       }
   }
