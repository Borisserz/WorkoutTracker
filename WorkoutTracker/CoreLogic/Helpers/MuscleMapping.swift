//
//  MuscleMapping.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 24.12.25.
//
//  Справочник для маппинга названий упражнений в технические идентификаторы мышц (slugs).
//  Используется для отрисовки тепловой карты (Heatmap) тела.
//


import Foundation
import SwiftData // Для PersistentIdentifier, если понадобится

struct MuscleMapping {
    
    // MARK: - Constants
    
    /// Старый ключ для UserDefaults (используется только для миграции)
    private static let customMappingKey = "CustomExerciseMappings"
    
    private static var customMappingsFileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("CustomExerciseMappings.json")
    }
    
    // Блокировка для потокобезопасного доступа к кэшу
    private static let cacheLock = NSLock()
    
    // Кэш в оперативной памяти для быстрого доступа
    private static var _cachedCustomMappings: [String: [String]]?
    
    // MARK: - Standard Mappings
    static let exerciseToMuscles: [String: [String]] = [
            
            // --- Chest ---
            "Around The World":                 ["chest", "deltoids"],
            "Bench Press":                      ["chest", "triceps", "deltoids"],
            "Cable Crossover":                  ["chest"],
            "Cable Flyes":                      ["chest"],
            "Chest Dips":                       ["chest", "triceps", "deltoids"],
            "Chest Press Machine":              ["chest", "triceps", "deltoids"],
            "Close Grip Pushups":               ["chest", "triceps"],
            "Decline Bench Press":              ["chest", "triceps", "deltoids"],
            "Decline Bench Press (Barbell)":    ["chest", "triceps"],
            "Decline Push-ups":                 ["chest", "triceps", "deltoids", "abs"],
            "Diamond Push Ups":                 ["chest", "triceps", "deltoids"],
            "Dips":                             ["chest", "triceps", "deltoids"],
            "Dumbbell Bench Press":             ["chest", "triceps", "deltoids"],
            "Dumbbell Flyes":                   ["chest"],
            "Dumbbell Pullover":                ["chest", "lats", "triceps"],
            "Floor Press":                      ["chest", "triceps"],
            "Floor Press (Dumbbell)":           ["chest", "triceps"],
            "Hammer Strength Wide Chest":       ["chest", "triceps", "deltoids"],
            "Hex Press (Dumbbell)":             ["chest", "triceps"],
            "High-to-Low Cable Fly":            ["chest", "deltoids"],
            "Incline Bench Press":              ["chest", "triceps", "deltoids"],
            "Incline Dumbbell Flyes":           ["chest", "deltoids"],
            "Incline Dumbbell Press":           ["chest", "triceps", "deltoids"],
            "Low Cable Fly Crossovers":         ["chest", "deltoids"],
            "Machine Chest Press":              ["chest", "triceps", "deltoids"],
            "Pec Deck":                         ["chest"],
            "Plate Squeeze (Svend Press)":      ["chest"],
            "Push Ups":                         ["chest", "triceps", "deltoids", "abs"],
            "Push-up Variations":               ["chest", "triceps", "deltoids", "abs"],
            "Smith Machine Incline Press":      ["chest", "triceps", "deltoids"],
            "Wide Grip Push Ups":               ["chest", "triceps", "deltoids"],
            
            // --- Back ---
            "Barbell Rows":                     ["upper-back", "biceps", "lower-back", "deltoids"],
            "Bent Over Row":                    ["upper-back", "biceps", "lower-back"],
            "Cable Rows":                       ["upper-back", "biceps", "lower-back"],
            "Chest Supported Row":              ["upper-back", "biceps"],
            "Chin-ups":                         ["upper-back", "biceps", "forearm"],
            "Close Grip Lat Pulldown":          ["upper-back", "biceps", "lower-back"],
            "Dead Hang":                        ["forearm", "upper-back"],
            "Deadlift":                         ["hamstring", "gluteal", "lower-back", "trapezius", "forearm"],
            "Deadlift High Pull":               ["shoulders", "trapezius", "gluteal", "hamstring"],
            "Good Mornings":                    ["hamstring", "lower-back", "gluteal"],
            "Gorilla Row (Kettlebell)":         ["upper-back", "lower-back", "biceps"],
            "Hyperextension":                   ["lower-back", "gluteal", "hamstring"],
            "Hyperextensions":                  ["lower-back", "gluteal", "hamstring"],
            "Inverted Row":                     ["upper-back", "biceps"],
            "Landmine Row":                     ["upper-back", "lats", "biceps"],
            "Lat Pulldown":                     ["upper-back", "biceps"],
            "Machine Back Extensions":          ["lower-back", "gluteal"],
            "Machine Row":                      ["upper-back", "biceps", "lats"],
            "Meadows Row":                      ["upper-back", "biceps"],
            "Meadows Rows (Barbell)":           ["upper-back", "lats", "forearm"],
            "Neutral Grip Lat Pulldown":        ["lats", "upper-back", "biceps"],
            "Neutral Grip Pull-ups":            ["lats", "upper-back", "biceps", "forearm"],
            "One-Arm Dumbbell Row":             ["upper-back", "biceps", "lower-back"],
            "Pendlay Row":                      ["upper-back", "lower-back", "biceps", "hamstring"],
            "Pull-ups":                         ["upper-back", "biceps", "forearm"],
            "Rack Pull":                        ["upper-back", "lower-back", "gluteal", "trapezius"],
            "Rack Pulls":                       ["upper-back", "lower-back", "trapezius", "gluteal"],
            "Renegade Rows":                    ["upper-back", "biceps", "abs"],
            "Reverse Grip Lat Pulldown":        ["lats", "upper-back", "biceps"],
            "Scapular Pull Ups":                ["upper-back", "trapezius"],
            "Seated Cable Row":                 ["upper-back", "biceps", "lower-back"],
            "Shrugs":                           ["trapezius"],
            "Straight Arm Lat Pulldown":        ["lats", "upper-back", "triceps"],
            "Straight Arm Pulldown":            ["lats", "upper-back", "triceps"],
            "T-Bar Row":                        ["upper-back", "lower-back", "biceps"],
            "V-Bar Seated Row":                 ["upper-back", "biceps", "lower-back"],
            "Wide Grip Pull-ups":               ["upper-back", "biceps", "forearm"],
            
            // --- Legs ---
            "Assisted Pistol Squats":           ["quadriceps", "gluteal", "core"],
            "Belt Squat":                       ["quadriceps", "gluteal"],
            "Bodyweight Sissy Squats":          ["quadriceps"],
            "Bodyweight Squat":                 ["quadriceps", "gluteal"],
            "Box Jump":                         ["quadriceps", "calves", "gluteal"],
            "Box Squat (Barbell)":              ["quadriceps", "gluteal", "hamstring"],
            "Box Step Ups":                     ["quadriceps", "gluteal"],
            "Bulgarian Split Squat":            ["quadriceps", "gluteal", "hamstring"],
            "Calf Press on Leg Press":          ["calves"],
            "Calf Raises":                      ["calves"],
            "Clamshell":                        ["gluteal"],
            "Curtsy Lunge":                     ["gluteal", "quadriceps"],
            "Frog Pumps (Dumbbell)":            ["gluteal"],
            "Front Squat":                      ["quadriceps", "gluteal", "hamstring", "lower-back"],
            "Glute Bridge":                     ["gluteal", "hamstring"],
            "Glute Ham Raise":                  ["hamstring", "gluteal"],
            "Goblet Squat":                     ["quadriceps", "gluteal", "hamstring"],
            "Hack Squat":                       ["quadriceps", "gluteal", "hamstring"],
            "Hip Abduction (Machine)":          ["gluteal"],
            "Hip Adduction (Machine)":          ["adductors"],
            "Hip Thrusts":                      ["gluteal", "hamstring"],
            "Lateral Squat":                    ["quadriceps", "gluteal", "adductors"],
            "Leg Curls":                        ["hamstring"],
            "Leg Extensions":                   ["quadriceps"],
            "Leg Press":                        ["quadriceps", "gluteal", "hamstring"],
            "Lunges":                           ["quadriceps", "gluteal", "hamstring", "calves"],
            "Lying Leg Curl":                   ["hamstring", "calves"],
            "Overhead Squat":                   ["quadriceps", "gluteal", "shoulders", "core"],
            "Partial Glute Bridge":             ["gluteal", "hamstring"],
            "Pistol Squat":                     ["quadriceps", "gluteal", "hamstring"],
            "Quadruped Hip Extension":          ["gluteal", "hamstring"],
            "Reverse Hyperextension":           ["gluteal", "lower-back", "hamstring"],
            "Romanian Deadlift":                ["hamstring", "gluteal", "lower-back"],
            "Seated Calf Raise":                ["calves"],
            "Seated Leg Curl":                  ["hamstring", "calves"],
            "Single Leg Box Squat":             ["quadriceps", "gluteal"],
            "Single Leg Hip Thrust":            ["gluteal", "hamstring"],
            "Single Leg Press":                 ["quadriceps", "gluteal"],
            "Single Leg RDL":                   ["hamstring", "gluteal", "lower-back"],
            "Sissy Squat":                      ["quadriceps"],
            "Smith Machine Squat":              ["quadriceps", "gluteal", "hamstring"],
            "Split Squat":                      ["quadriceps", "gluteal", "hamstring"],
            "Squat":                            ["quadriceps", "gluteal", "hamstring", "lower-back"],
            "Standing Calf Raise":              ["calves"],
            "Standing Leg Curls":               ["hamstring"],
            "Step-ups":                         ["quadriceps", "gluteal", "hamstring"],
            "Stiff Leg Deadlift":               ["hamstring", "gluteal", "lower-back"],
            "Sumo Squat":                       ["quadriceps", "gluteal", "hamstring", "adductors"],
            "Swiss Ball Leg Curls":             ["hamstring", "gluteal"],
            "Trap Bar Deadlift":                ["quadriceps", "gluteal", "hamstring", "lower-back"],
            "Walking Lunges":                   ["quadriceps", "gluteal", "hamstring", "calves"],
            "Wall Sits":                        ["quadriceps", "gluteal"],
            "Zercher Squat":                    ["quadriceps", "gluteal", "core", "upper-back"],
            
            // --- Shoulders ---
            "Arnold Press":                     ["deltoids", "triceps"],
            "Band Lateral Raise":               ["deltoids"],
            "Cable Lateral Raises":             ["deltoids"],
            "Clean and Press":                  ["deltoids", "trapezius", "legs", "triceps", "core"],
            "Dumbbell Shoulder Press":          ["deltoids", "triceps"],
            "Face Pulls":                       ["deltoids", "trapezius", "upper-back"],
            "Front Plate Raise":                ["deltoids", "chest"],
            "Front Raises":                     ["deltoids"],
            "Handstand Push-ups":               ["deltoids", "triceps"],
            "Kettlebell Halo":                  ["deltoids", "trapezius"],
            "Landmine Press":                   ["deltoids", "chest", "triceps"],
            "Lateral Raises":                   ["deltoids"],
            "Overhead Plate Raise":             ["deltoids", "trapezius"],
            "Overhead Press":                   ["deltoids", "triceps", "trapezius"],
            "Pike Push-ups":                    ["deltoids", "triceps"],
            "Push Press":                       ["deltoids", "triceps", "legs"],
            "Rear Delt Fly":                    ["deltoids", "upper-back", "trapezius"],
            "Rear Delt Flyes":                  ["deltoids", "upper-back"],
            "Reverse Flyes":                    ["upper-back", "deltoids"],
            "Reverse Pec Deck":                 ["deltoids", "upper-back"],
            "Ring Face-Pulls":                  ["deltoids", "upper-back", "trapezius"],
            "Seated Military Press":            ["deltoids", "triceps", "upper-back"],
            "Shoulder Press Machine":           ["deltoids", "triceps"],
            "Shoulder Taps":                    ["abs", "shoulders"],
            "Single Arm Landmine Press":        ["deltoids", "triceps", "core"],
            "Smith Machine Press":              ["deltoids", "triceps"],
            "Turkish Get-up":                   ["deltoids", "abs", "gluteal"],
            "Underhand Front Delt Raise":       ["deltoids", "chest"],
            "Upright Row":                      ["deltoids", "trapezius"],
            "Z Press":                          ["deltoids", "abs", "triceps"],
            
            // --- Arms ---
            "21s Bicep Curl":                   ["biceps", "forearm"],
            "Barbell Curl":                     ["biceps", "forearm"],
            "Behind the Back Wrist Curl":       ["forearm"],
            "Bench Dips":                       ["triceps", "chest", "deltoids"],
            "Bicep Curls":                      ["biceps", "forearm"],
            "Cable Curls":                      ["biceps", "forearm"],
            "Cable Kickbacks":                  ["triceps"],
            "Cable Overhead Triceps Ext":       ["triceps"],
            "Close Grip Bench Press":           ["triceps", "chest", "deltoids"],
            "Concentration Curl":               ["biceps"],
            "Concentration Curls":              ["biceps"],
            "Cross Body Hammer Curl":           ["biceps", "forearm"],
            "Drag Curl":                        ["biceps"],
            "Dumbbell Kickbacks":               ["triceps"],
            "EZ Bar Curl":                      ["biceps", "forearm"],
            "French Press":                     ["triceps"],
            "Hammer Curls":                     ["biceps", "forearm"],
            "Incline Dumbbell Curl":            ["biceps", "forearm"],
            "Machine Bicep Curl":               ["biceps"],
            "Machine Dips":                     ["triceps", "chest", "deltoids"],
            "Machine Preacher Curl":            ["biceps"],
            "Overhead Triceps Extension":       ["triceps"],
            "Pinwheel Curl":                    ["biceps", "forearm"],
            "Preacher Curl":                    ["biceps", "forearm"],
            "Reverse Curl":                     ["forearm", "biceps"],
            "Rope Hammer Curls":                ["biceps", "forearm"],
            "Seated Dumbbell Curl":             ["biceps", "forearm"],
            "Seated Palms Up Wrist Curl":       ["forearm"],
            "Single Arm Triceps Ext":           ["triceps"],
            "Skull Crushers":                   ["triceps"],
            "Spider Curl":                      ["biceps"],
            "Spider Curls":                     ["biceps", "forearm"],
            "Straight Bar Triceps Pushdown":    ["triceps"],
            "Tate Press (Dumbbell)":            ["triceps", "chest"],
            "Tricep Press Machine":             ["triceps"],
            "Triceps Dips":                     ["triceps", "chest", "deltoids"],
            "Triceps Extension":                ["triceps"],
            "Triceps Pushdown":                 ["triceps"],
            "Triceps Rope Pushdown":            ["triceps"],
            "Wrist Roller":                     ["forearm"],
            "Zottman Curl":                     ["biceps", "forearm"],
            "Zottman Curls":                    ["biceps", "forearm"],
            
            // --- Core ---
            "Ab Machine":                       ["abs"],
            "Ab Scissors":                      ["abs"],
            "Ab Wheel":                         ["abs", "lower-back", "lats"],
            "Ab Wheel Rollout":                 ["abs", "obliques"],
            "Bicycle Crunches":                 ["abs", "obliques"],
            "Bird Dog":                         ["abs", "lower-back"],
            "Boat Holds":                       ["abs"],
            "Bosu Jackknife":                   ["abs", "obliques"],
            "Cable Crunches":                   ["abs"],
            "Crunches":                         ["abs"],
            "Dead Bug":                         ["abs"],
            "Decline Crunch":                   ["abs"],
            "Dragon Flag":                      ["abs", "lower-back", "gluteal"],
            "Dragonfly":                        ["abs", "lower-back"],
            "Dumbbell Side Bends":              ["obliques", "abs"],
            "Flutter Kicks":                    ["abs"],
            "Hanging Knee Raises":              ["abs", "obliques"],
            "Knee Raise Parallel Bars":         ["abs"],
            "L-Sit Hold":                       ["abs", "forearm", "triceps"],
            "L-sit":                            ["abs", "obliques"],
            "Landmine 180":                     ["obliques", "abs", "shoulders"],
            "Leg Raises":                       ["abs", "obliques"],
            "Pallof Press":                     ["abs", "obliques"],
            "Plank":                            ["abs", "obliques", "deltoids"],
            "Reverse Crunches":                 ["abs"],
            "Russian Twist":                    ["obliques", "abs"],
            "Russian Twists":                   ["abs", "obliques"],
            "Side Plank":                       ["abs", "obliques", "deltoids"],
            "Sit-ups":                          ["abs"],
            "Spiderman":                        ["abs", "obliques", "shoulders"],
            "Toes to Bar":                      ["abs", "forearm", "hip-flexors"],
            "V-Ups":                            ["abs", "hip-flexors"],
            "Weighted Crunches":                ["abs"],
            "Weighted Decline Crunch":          ["abs"],
            
            // --- Cardio / Full Body / Other ---
            "Air Bike":                         ["legs", "cardio"],
            "Ball Slams":                       ["abs", "shoulders", "legs", "cardio"],
            "Battle Ropes":                     ["forearm", "shoulders", "abs"],
            "Box Jumps":                        ["quadriceps", "gluteal", "calves"],
            "Burpee":                           ["full-body", "cardio"],
            "Burpees":                          ["quadriceps", "gluteal", "chest", "deltoids", "abs"],
            "Clean and Jerk":                   ["legs", "shoulders", "back", "triceps"],
            "Cycling":                          ["quadriceps", "calves"],
            "Downward Dog":                     ["shoulders", "hamstring", "calves"],
            "Elliptical":                       ["quadriceps", "hamstring", "gluteal", "calves"],
            "Farmer's Walk":                    ["forearm", "trapezius", "core", "legs"],
            "HIIT":                             ["quadriceps", "hamstring", "calves", "gluteal", "abs"],
            "High Knees":                       ["quadriceps", "calves", "gluteal"],
            "Jump Rope":                        ["calves", "quadriceps", "deltoids"],
            "Jump Squat":                       ["quadriceps", "gluteal", "cardio"],
            "Jumping Jack":                     ["full-body", "cardio"],
            "Jumping Jacks":                    ["quadriceps", "calves", "deltoids"],
            "Jumping Lunge":                    ["quadriceps", "gluteal", "cardio"],
            "Kettlebell Swings":                ["gluteal", "hamstring", "deltoids"],
            "Kettlebell Turkish Get Up":        ["full-body", "shoulders", "core", "quadriceps"],
            "Lying Neck Curls":                 ["neck"],
            "Lying Neck Extension":             ["neck"],
            "Mountain Climbers":                ["abs", "deltoids", "quadriceps"],
            "Rowing":                           ["upper-back", "biceps", "quadriceps", "hamstring"],
            "Rowing Machine":                   ["upper-back", "biceps", "quadriceps", "hamstring"],
            "Running":                          ["quadriceps", "hamstring", "calves", "gluteal"],
            "Sled Push":                        ["quadriceps", "gluteal", "calves", "cardio"],
            "Snatch":                           ["full-body", "shoulders", "legs", "back"],
            "Split Jerk":                       ["full-body", "shoulders", "legs", "triceps"],
            "Stair Climber":                    ["quadriceps", "gluteal", "calves"],
            "Stretching":                       [],
            "Swimming":                         ["upper-back", "deltoids", "quadriceps"],
            "Thruster":                         ["legs", "shoulders", "triceps", "cardio"],
            "Treadmill":                        ["quadriceps", "hamstring", "calves", "gluteal"],
            "Treadmill Sprints":                ["quadriceps", "hamstring", "calves", "gluteal"],
            "Wall Ball":                        ["legs", "shoulders", "core", "cardio"]
        ]
    
    /// Запасной вариант: если упражнения нет в списке выше,
    static let groupToMuscles: [String: [String]] = [
        "Chest":     ["chest"],
        "Back":      ["upper-back", "lower-back", "trapezius"],
        "Legs":      ["quadriceps", "hamstring", "gluteal", "calves", "adductors"],
        "Shoulders": ["deltoids"],
        "Arms":      ["biceps", "triceps", "forearm"],
        "Core":      ["abs", "obliques"],
        "Cardio":    ["quadriceps", "hamstring", "calves", "cardio"]
    ]
    
    // MARK: - Logic
    
    /// Запускает асинхронную загрузку маппингов для избежания зависания на старте
    static func preload() {
        Task.detached(priority: .background) {
            _ = getCustomMappings()
        }
    }
    
    /// Извлекает пользовательские маппинги из файла или кэша
    private static func getCustomMappings() -> [String: [String]] {
        cacheLock.lock()
        if let cached = _cachedCustomMappings {
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()
        
        var loaded: [String: [String]] = [:]
        
        // Пытаемся прочитать из файла
        if let data = try? Data(contentsOf: customMappingsFileURL),
           let decoded = try? JSONDecoder().decode([String: [String]].self, from: data) {
            loaded = decoded
        }
        // Фоллбэк (миграция): если файла нет, пробуем прочитать из UserDefaults
        else if let dict = UserDefaults.standard.dictionary(forKey: customMappingKey) as? [String: [String]] {
            loaded = dict
            
            // Сразу сохраняем в файл асинхронно
            Task.detached(priority: .background) {
                if let encoded = try? JSONEncoder().encode(dict) {
                    try? encoded.write(to: customMappingsFileURL)
                }
            }
            UserDefaults.standard.removeObject(forKey: customMappingKey)
        }
        
        cacheLock.lock()
        _cachedCustomMappings = loaded
        cacheLock.unlock()
        
        return loaded
    }
    
    /// Обновляет кэш и сохраняет изменения в файл асинхронно. Вызывается из ExerciseCatalogService.
    static func updateCustomMapping(name: String, muscles: [String]?) {
        var currentMap = getCustomMappings()
        if let muscles = muscles {
            currentMap[name] = muscles
        } else {
            currentMap.removeValue(forKey: name)
        }
        
        cacheLock.lock()
        _cachedCustomMappings = currentMap
        cacheLock.unlock()
        
        let mapToSave = currentMap
        Task.detached(priority: .background) {
            if let encoded = try? JSONEncoder().encode(mapToSave) {
                try? encoded.write(to: customMappingsFileURL)
            }
        }
    }
    
    /// Возвращает список задействованных мышц для конкретного упражнения.
    ///
    /// Поиск происходит в следующем порядке:
    /// 1. Стандартный словарь (`exerciseToMuscles`).
    /// 2. Пользовательские упражнения (`FileManager` / `Cache`).
    /// 3. Дефолтный маппинг по группе мышц (`groupToMuscles`).
    static func getMuscles(for exerciseName: String, group: String) -> [String] {
        
        // 1. Сначала ищем в стандартном словаре
        if let muscles = exerciseToMuscles[exerciseName] {
            return muscles
        }
        
        // 2. Если не нашли, ищем в ПОЛЬЗОВАТЕЛЬСКИХ (из кэша/FileManager)
        let customMap = getCustomMappings()
        
        if let customMuscles = customMap[exerciseName] {
            return customMuscles
        }
        
        // 3. Если совсем ничего нет, возвращаем дефолт по группе
        return groupToMuscles[group] ?? []
    }
    
    static func isBackFacing(exerciseName: String) -> Bool {
            let name = exerciseName.lowercased()
            let backKeywords = [
                "deadlift", "row", "pull", "chin", "tricep",
                "glute", "hamstring", "calf", "calves", "back",
                "good morning", "shrug"
            ]
            return backKeywords.contains { name.contains($0) }
        }
}
