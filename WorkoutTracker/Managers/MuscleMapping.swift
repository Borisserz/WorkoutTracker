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

struct MuscleMapping {
    
    // MARK: - Constants
    
    /// Ключ для сохранения пользовательских маппингов в UserDefaults
    private static let customMappingKey = "CustomExerciseMappings"
    
    // MARK: - Standard Mappings
    
    /// Словарь: Название упражнения 
    static let exerciseToMuscles: [String: [String]] = [
        
        // --- Chest ---
        "Bench Press":              ["chest", "triceps", "deltoids"],
        "Push Ups":                 ["chest", "triceps", "deltoids", "abs"],
        "Incline Dumbbell Press":   ["chest", "triceps", "deltoids"],
        "Dips":                     ["chest", "triceps", "deltoids"],
        "Dumbbell Flyes":           ["chest"],
        "Cable Crossover":          ["chest"],
        "Decline Bench Press":      ["chest", "triceps", "deltoids"],
        "Chest Press Machine":      ["chest", "triceps", "deltoids"],
        "Pec Deck":                 ["chest"],
        "Incline Bench Press":      ["chest", "triceps", "deltoids"],
        "Diamond Push Ups":         ["chest", "triceps", "deltoids"],
        "Wide Grip Push Ups":       ["chest", "triceps", "deltoids"],
        "Cable Flyes":              ["chest"],
        "Push-up Variations":       ["chest", "triceps", "deltoids", "abs"],
        "Chest Dips":               ["chest", "triceps", "deltoids"],
        
        // --- Back ---
        "Pull-ups":                 ["upper-back", "biceps", "forearm"],
        "Deadlift":                 ["hamstring", "gluteal", "lower-back", "trapezius", "forearm"],
        "Barbell Rows":             ["upper-back", "biceps", "lower-back", "deltoids"],
        "Lat Pulldown":             ["upper-back", "biceps"],
        "T-Bar Row":                ["upper-back", "lower-back", "biceps"],
        "Cable Rows":               ["upper-back", "biceps", "lower-back"],
        "One-Arm Dumbbell Row":     ["upper-back", "biceps", "lower-back"],
        "Chin-ups":                 ["upper-back", "biceps", "forearm"],
        "Wide Grip Pull-ups":       ["upper-back", "biceps", "forearm"],
        "Seated Cable Row":         ["upper-back", "biceps", "lower-back"],
        "Bent Over Row":            ["upper-back", "biceps", "lower-back"],
        "Shrugs":                   ["trapezius"],
        "Good Mornings":            ["hamstring", "lower-back", "gluteal"],
        "Rack Pulls":               ["upper-back", "lower-back", "trapezius", "gluteal"],
        "Renegade Rows":            ["upper-back", "biceps", "abs"],
        "Inverted Row":             ["upper-back", "biceps"],
        "Hyperextensions":          ["lower-back", "gluteal", "hamstring"],
        "Meadows Row":              ["upper-back", "biceps"],
        
        // --- Legs ---
        "Squat":                    ["quadriceps", "gluteal", "hamstring", "lower-back"],
        "Leg Press":                ["quadriceps", "gluteal", "hamstring"],
        "Lunges":                   ["quadriceps", "gluteal", "hamstring", "calves"],
        "Calf Raises":              ["calves"],
        "Romanian Deadlift":        ["hamstring", "gluteal", "lower-back"],
        "Bulgarian Split Squat":    ["quadriceps", "gluteal", "hamstring"],
        "Leg Curls":                ["hamstring"],
        "Leg Extensions":           ["quadriceps"],
        "Hack Squat":               ["quadriceps", "gluteal", "hamstring"],
        "Front Squat":              ["quadriceps", "gluteal", "hamstring", "lower-back"],
        "Walking Lunges":           ["quadriceps", "gluteal", "hamstring", "calves"],
        "Step-ups":                 ["quadriceps", "gluteal", "hamstring"],
        "Glute Bridge":             ["gluteal", "hamstring"],
        "Hip Thrusts":              ["gluteal", "hamstring"],
        "Goblet Squat":             ["quadriceps", "gluteal", "hamstring"],
        "Pistol Squat":             ["quadriceps", "gluteal", "hamstring"],
        "Sumo Squat":               ["quadriceps", "gluteal", "hamstring", "adductors"],
        "Stiff Leg Deadlift":       ["hamstring", "gluteal", "lower-back"],
        "Seated Calf Raise":        ["calves"],
        "Standing Calf Raise":      ["calves"],
        "Wall Sits":                ["quadriceps", "gluteal"],
        "Quadruped Hip Extension":  ["gluteal", "hamstring"],
        
        // --- Shoulders ---
        "Overhead Press":           ["deltoids", "triceps", "trapezius"],
        "Lateral Raises":           ["deltoids"],
        "Face Pulls":               ["deltoids", "trapezius", "upper-back"],
        "Arnold Press":             ["deltoids", "triceps"],
        "Reverse Flyes":            ["upper-back", "deltoids"],
        "Front Raises":             ["deltoids"],
        "Upright Row":              ["deltoids", "trapezius"],
        "Pike Push-ups":            ["deltoids", "triceps"],
        "Shoulder Press Machine":   ["deltoids", "triceps"],
        "Cable Lateral Raises":     ["deltoids"],
        "Rear Delt Flyes":          ["deltoids", "upper-back"],
        "Push Press":               ["deltoids", "triceps", "legs"],
        "Handstand Push-ups":       ["deltoids", "triceps"],
        "Landmine Press":           ["deltoids", "chest", "triceps"],
        "Turkish Get-up":           ["deltoids", "abs", "gluteal"],
        
        // --- Arms ---
        "Barbell Curl":             ["biceps", "forearm"],
        "Triceps Extension":        ["triceps"],
        "Hammer Curls":             ["biceps", "forearm"],
        "Bicep Curls":              ["biceps", "forearm"],
        "Triceps Dips":             ["triceps", "chest", "deltoids"],
        "Close Grip Bench Press":   ["triceps", "chest", "deltoids"],
        "Preacher Curl":            ["biceps", "forearm"],
        "Concentration Curls":      ["biceps"],
        "Cable Curls":              ["biceps", "forearm"],
        "Triceps Pushdown":         ["triceps"],
        "Overhead Triceps Extension": ["triceps"],
        "Spider Curls":             ["biceps", "forearm"],
        "Rope Hammer Curls":        ["biceps", "forearm"],
        "Skull Crushers":           ["triceps"],
        "French Press":             ["triceps"],
        "Zottman Curls":            ["biceps", "forearm"],
        "Cable Kickbacks":          ["triceps"],
        
        // --- Core ---
        "Plank":                    ["abs", "obliques", "deltoids"],
        "Crunches":                 ["abs"],
        "Leg Raises":               ["abs", "obliques"],
        "Russian Twists":           ["abs", "obliques"],
        "Bicycle Crunches":         ["abs", "obliques"],
        "Hanging Knee Raises":      ["abs", "obliques"],
        "Dead Bug":                 ["abs"],
        "Bird Dog":                 ["abs", "lower-back"],
        "Side Plank":               ["abs", "obliques", "deltoids"],
        "Ab Wheel Rollout":         ["abs", "obliques"],
        "Sit-ups":                  ["abs"],
        "L-sit":                    ["abs", "obliques"],
        "Dragon Flag":              ["abs", "obliques"],
        "Toes to Bar":              ["abs", "obliques"],
        "Cable Crunches":           ["abs"],
        "Pallof Press":             ["abs", "obliques"],
        
        // --- Cardio & Duration ---
        "Running":                  ["quadriceps", "hamstring", "calves", "gluteal"],
        "Cycling":                  ["quadriceps", "calves"],
        "Rowing":                   ["upper-back", "biceps", "quadriceps", "hamstring"],
        "Jump Rope":                ["calves", "quadriceps", "deltoids"],
        "Stretching":               [],
        "Treadmill":                ["quadriceps", "hamstring", "calves", "gluteal"],
        "Elliptical":               ["quadriceps", "hamstring", "gluteal", "calves"],
        "HIIT":                     ["quadriceps", "hamstring", "calves", "gluteal", "abs"],
        "Burpees":                  ["quadriceps", "gluteal", "chest", "deltoids", "abs"],
        "Jumping Jacks":            ["quadriceps", "calves", "deltoids"],
        "High Knees":               ["quadriceps", "calves", "gluteal"],
        "Mountain Climbers":        ["abs", "deltoids", "quadriceps"],
        "Battle Ropes":             ["deltoids", "abs", "upper-back"],
        "Box Jumps":                ["quadriceps", "gluteal", "calves"],
        "Swimming":                 ["upper-back", "deltoids", "quadriceps"],
        "Stair Climber":            ["quadriceps", "gluteal", "calves"],
        "Kettlebell Swings":        ["gluteal", "hamstring", "deltoids"],
        "Rowing Machine":           ["upper-back", "biceps", "quadriceps", "hamstring"],
        "Treadmill Sprints":        ["quadriceps", "hamstring", "calves", "gluteal"]
    ]
    
    /// Запасной вариант: если упражнения нет в списке выше,
    static let groupToMuscles: [String: [String]] = [
        "Chest":     ["chest"],
        "Back":      ["upper-back", "lower-back", "trapezius"],
        "Legs":      ["quadriceps", "hamstring", "gluteal", "calves", "adductors"],
        "Shoulders": ["deltoids", "trapezius"],
        "Arms":      ["biceps", "triceps", "forearm"],
        "Core":      ["abs", "obliques"],
        "Cardio":    ["quadriceps", "hamstring", "calves"]
    ]
    
    // MARK: - Logic
    
    /// Возвращает список задействованных мышц для конкретного упражнения.
    ///
    /// Поиск происходит в следующем порядке:
    /// 1. Стандартный словарь (`exerciseToMuscles`).
    /// 2. Пользовательские упражнения (`UserDefaults`).
    /// 3. Дефолтный маппинг по группе мышц (`groupToMuscles`).
    static func getMuscles(for exerciseName: String, group: String) -> [String] {
        
        // 1. Сначала ищем в стандартном словаре
        if let muscles = exerciseToMuscles[exerciseName] {
            return muscles
        }
        
        // 2. Если не нашли, ищем в ПОЛЬЗОВАТЕЛЬСКИХ (из UserDefaults)
        // Мы сохраняем карту "Имя -> [Мышцы]" в UserDefaults при создании CustomExercise
        let customMap = UserDefaults.standard.dictionary(forKey: customMappingKey) as? [String: [String]] ?? [:]
        
        if let customMuscles = customMap[exerciseName] {
            return customMuscles
        }
        
        // 3. Если совсем ничего нет, возвращаем дефолт по группе
        return groupToMuscles[group] ?? []
    }
}
