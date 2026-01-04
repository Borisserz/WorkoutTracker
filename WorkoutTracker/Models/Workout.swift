//
//  WorkoutTrackerModels.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 24.12.25.
//
//  Основные модели данных приложения:
//  - Workout (Тренировка)
//  - Exercise (Упражнение)
//  - WorkoutSet (Подход/Сет)
//  - WorkoutPreset (Шаблон тренировки)
//

import Foundation
internal import SwiftUI // Нужно для Color в SetType

// MARK: - Enums

// --- 1. Типы сетов ---
enum SetType: String, Codable, CaseIterable {
    case normal = "N"
    case warmup = "W"     // Разминка (желтый)
    case failure = "F"    // Отказ (красный)
    
    var color: Color {
        switch self {
        case .normal: return .blue
        case .warmup: return .yellow
        case .failure: return .red
        }
    }
}

// --- 2. Типы упражнений ---
enum ExerciseType: String, Codable, CaseIterable, Identifiable {
    case strength = "Strength"   // Вес x Повторы
    case cardio = "Cardio"       // Дистанция + Время
    case duration = "Duration"   // Только Время
    
    var id: String { self.rawValue }
}

// MARK: - Models

// --- 3. Структура одного Сета ---
struct WorkoutSet: Identifiable, Codable, Hashable {
    var id = UUID()
    var index: Int
    
    // Данные (опциональные, т.к. зависят от типа упражнения)
    var weight: Double?
    var reps: Int?
    var distance: Double? // Для кардио (км)
    var time: Int?        // Для статики/кардио (секунды)
    
    var isCompleted: Bool = false
    var type: SetType = .normal
}

// --- 4. Основная структура Exercise ---
struct Exercise: Identifiable, Codable, Hashable {
    
    // MARK: - Properties
    var id = UUID()
    var name: String
    var muscleGroup: String
    var type: ExerciseType = .strength
    var effort: Int = 5
    var isCompleted: Bool = false // Флаг завершения упражнения
    
    // НОВОЕ ПОЛЕ: Список сетов (Основной источник истины)
    var setsList: [WorkoutSet] = []
    
    // Для супер-сетов
    var subExercises: [Exercise] = []
    
    // СТАРЫЕ ПОЛЯ (Оставляем для совместимости JSON, но логика теперь в setsList)
    var sets: Int
    var reps: Int
    var weight: Double
    var distance: Double?
    var timeSeconds: Int?
    
    // MARK: - Computed Properties
    
    var isSuperset: Bool {
        return !subExercises.isEmpty
    }
    
    /// Расчет объема (тоннажа/дистанции/времени).
    /// Считаем только завершенные сеты, исключая разминку.
    var computedVolume: Double {
        if isSuperset {
            return subExercises.reduce(0.0) { $0 + $1.computedVolume }
        }
        
        // Суммируем объем каждого сета
        return setsList.reduce(0.0) { partialResult, set in
            // Разминку и незавершенные не считаем
            if set.type == .warmup || !set.isCompleted { return partialResult }
            
            switch type {
            case .strength:
                return partialResult + ((set.weight ?? 0) * Double(set.reps ?? 0))
            case .cardio:
                // Условный объем: 1 км = 1000 единиц
                return partialResult + ((set.distance ?? 0) * 1000)
            case .duration:
                // Условный объем: 1 минута = 10 единиц
                return partialResult + (Double(set.time ?? 0) / 6.0)
            }
        }
    }
    
    // MARK: - Codable Implementation
    
    enum CodingKeys: String, CodingKey {
        case id, name, muscleGroup, type, sets, reps, weight, effort, subExercises, distance, timeSeconds
        case setsList // Добавили новый ключ
        case isCompleted // Флаг завершения упражнения
    }
    
    // Инициализатор
    init(id: UUID = UUID(), name: String, muscleGroup: String, type: ExerciseType = .strength, sets: Int = 1, reps: Int = 0, weight: Double = 0, distance: Double? = nil, timeSeconds: Int? = nil, effort: Int = 5, subExercises: [Exercise] = [], setsList: [WorkoutSet] = [], isCompleted: Bool = false) {
        self.id = id
        self.name = name
        self.muscleGroup = muscleGroup
        self.type = type
        self.sets = sets
        self.reps = reps
        self.weight = weight
        self.distance = distance
        self.timeSeconds = timeSeconds
        self.effort = effort
        self.subExercises = subExercises
        self.setsList = setsList
        self.isCompleted = isCompleted
        
        // Если при создании список сетов пустой, создаем их на основе переданных простых параметров.
        // Это нужно, чтобы при добавлении упражнения в UI сразу появлялись строчки.
        if self.setsList.isEmpty && subExercises.isEmpty && sets > 0 {
            for i in 1...sets {
                self.setsList.append(WorkoutSet(
                    index: i,
                    weight: weight,
                    reps: reps,
                    distance: distance,
                    time: timeSeconds,
                    isCompleted: false, // При создании сеты не выполнены
                    type: .normal
                ))
            }
        }
    }

    // Decoder (Загрузка из JSON)
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        muscleGroup = try container.decode(String.self, forKey: .muscleGroup)
        sets = try container.decode(Int.self, forKey: .sets)
        reps = try container.decode(Int.self, forKey: .reps)
        weight = try container.decode(Double.self, forKey: .weight)
        effort = try container.decode(Int.self, forKey: .effort)
        subExercises = try container.decodeIfPresent([Exercise].self, forKey: .subExercises) ?? []
        
        type = try container.decodeIfPresent(ExerciseType.self, forKey: .type) ?? .strength
        distance = try container.decodeIfPresent(Double.self, forKey: .distance)
        timeSeconds = try container.decodeIfPresent(Int.self, forKey: .timeSeconds)
        isCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
        
        // ВАЖНО: Пробуем загрузить новый список сетов (setsList)
        if let loadedSets = try container.decodeIfPresent([WorkoutSet].self, forKey: .setsList) {
            setsList = loadedSets
        } else {
            // МИГРАЦИЯ: Если в файле нет setsList (старая версия приложения),
            // создаем сеты на основе старых полей (sets, reps, weight).
            var newSets: [WorkoutSet] = []
            if sets > 0 {
                for i in 1...sets {
                    // Считаем старые упражнения выполненными (isCompleted: true), так как это история
                    newSets.append(WorkoutSet(
                        index: i,
                        weight: weight,
                        reps: reps,
                        distance: distance,
                        time: timeSeconds,
                        isCompleted: true,
                        type: .normal
                    ))
                }
            }
            setsList = newSets
        }
    }
    
    // Encoder (Сохранение в JSON)
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(muscleGroup, forKey: .muscleGroup)
        try container.encode(type, forKey: .type)
        try container.encode(effort, forKey: .effort)
        try container.encode(subExercises, forKey: .subExercises)
        try container.encode(distance, forKey: .distance)
        try container.encode(timeSeconds, forKey: .timeSeconds)
        try container.encode(isCompleted, forKey: .isCompleted)
        
        // 1. Сохраняем актуальный список сетов
        try container.encode(setsList, forKey: .setsList)
        
        // 2. Обновляем старые поля "для вида" (Backwards Compatibility).
        // Берем данные из первого сета или нули.
        try container.encode(setsList.count, forKey: .sets)
        try container.encode(setsList.first?.reps ?? 0, forKey: .reps)
        try container.encode(setsList.first?.weight ?? 0.0, forKey: .weight)
    }
}

// --- 5. Шаблон тренировки (Preset) ---
struct WorkoutPreset: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var icon: String
    var exercises: [Exercise]
}

// --- 6. Тренировка (Workout) ---
struct Workout: Identifiable, Codable {
    var id = UUID()
    var title: String
    var date: Date
    var endTime: Date? = nil
    var icon: String = "figure.run"
    var exercises: [Exercise]
    
    // MARK: - Computed Properties
    
    
    
    var isActive: Bool {
        return endTime == nil
    }
    
    var duration: Int {
        let end = endTime ?? Date()
        let diff = end.timeIntervalSince(date)
        return Int(diff / 60)
    }
    
    var effortPercentage: Int {
        if exercises.isEmpty { return 0 }
        let totalEffort = exercises.reduce(0) { $0 + $1.effort }
        let average = Double(totalEffort) / Double(exercises.count)
        return Int(average * 10)
    }
}

// MARK: - Extensions (Data & Catalog)

// КАТАЛОГ УПРАЖНЕНИЙ
extension Exercise {
    static let catalog: [String: [String]] = [
        "Chest": [
            "Bench Press", "Push Ups", "Incline Dumbbell Press", "Dips",
            "Dumbbell Flyes", "Cable Crossover", "Decline Bench Press",
            "Chest Press Machine", "Pec Deck", "Incline Bench Press",
            "Diamond Push Ups", "Wide Grip Push Ups", "Cable Flyes",
            "Push-up Variations", "Chest Dips", "Landmine Press"
        ],
        "Back": [
            "Pull-ups", "Deadlift", "Barbell Rows", "Lat Pulldown",
            "T-Bar Row", "Cable Rows", "One-Arm Dumbbell Row",
            "Chin-ups", "Wide Grip Pull-ups", "Seated Cable Row",
            "Bent Over Row", "Face Pulls", "Reverse Flyes",
            "Shrugs", "Good Mornings", "Rack Pulls", "Renegade Rows",
            "Inverted Row", "Hyperextensions", "Meadows Row"
        ],
        "Legs": [
            "Squat", "Leg Press", "Lunges", "Calf Raises",
            "Romanian Deadlift", "Bulgarian Split Squat", "Leg Curls",
            "Leg Extensions", "Hack Squat", "Front Squat",
            "Walking Lunges", "Step-ups", "Glute Bridge",
            "Hip Thrusts", "Goblet Squat", "Pistol Squat",
            "Sumo Squat", "Stiff Leg Deadlift", "Seated Calf Raise",
            "Standing Calf Raise", "Wall Sits", "Quadruped Hip Extension"
        ],
        "Shoulders": [
            "Overhead Press", "Lateral Raises", "Face Pulls",
            "Arnold Press", "Reverse Flyes", "Front Raises",
            "Upright Row", "Pike Push-ups", "Shoulder Press Machine",
            "Cable Lateral Raises", "Rear Delt Flyes", "Push Press",
            "Handstand Push-ups", "Landmine Press", "Turkish Get-up"
        ],
        "Arms": [
            "Barbell Curl", "Triceps Extension", "Hammer Curls",
            "Bicep Curls", "Triceps Dips", "Close Grip Bench Press",
            "Preacher Curl", "Concentration Curls", "Cable Curls",
            "Triceps Pushdown", "Overhead Triceps Extension",
            "Spider Curls", "Rope Hammer Curls", "Skull Crushers",
            "French Press", "Zottman Curls", "Cable Kickbacks"
        ],
        "Core": [
            "Plank", "Crunches", "Leg Raises",
            "Russian Twists", "Mountain Climbers", "Bicycle Crunches",
            "Hanging Knee Raises", "Dead Bug", "Bird Dog",
            "Side Plank", "Ab Wheel Rollout", "Sit-ups",
            "L-sit", "Dragon Flag", "Toes to Bar",
            "Cable Crunches", "Pallof Press", "Turkish Get-up"
        ],
        "Cardio": [
            "Running", "Cycling", "Rowing", "Jump Rope", "Stretching",
            "Treadmill", "Elliptical", "HIIT", "Burpees",
            "Jumping Jacks", "High Knees", "Mountain Climbers",
            "Battle Ropes", "Box Jumps", "Swimming", "Stair Climber",
            "Kettlebell Swings", "Rowing Machine", "Treadmill Sprints"
        ]
    ]
}

// ПРИМЕРЫ ТРЕНИРОВОК
extension Workout {
    static let examples = [

        // Новые шаблоны
        Workout(
            title: "Full Body",
            date: Date(),
            endTime: Date().addingTimeInterval(3600),
            icon: "img_default",
            exercises: [
                Exercise(name: "Squat", muscleGroup: "Legs", sets: 4, reps: 8, weight: 90, effort: 9),
                Exercise(name: "Bench Press", muscleGroup: "Chest", sets: 4, reps: 8, weight: 75, effort: 9),
                Exercise(name: "Barbell Rows", muscleGroup: "Back", sets: 4, reps: 8, weight: 70, effort: 8),
                Exercise(name: "Overhead Press", muscleGroup: "Shoulders", sets: 3, reps: 10, weight: 35, effort: 8),
                Exercise(name: "Barbell Curl", muscleGroup: "Arms", sets: 3, reps: 10, weight: 25, effort: 7),
                Exercise(name: "Plank", muscleGroup: "Core", type: .duration, sets: 3, reps: 0, weight: 0, timeSeconds: 60, effort: 6)
            ]
        ),
        Workout(
            title: "Push",
            date: Date(),
            endTime: Date().addingTimeInterval(3600),
            icon: "img_chest2",
            exercises: [
                Exercise(name: "Bench Press", muscleGroup: "Chest", sets: 4, reps: 6, weight: 85, effort: 10),
                Exercise(name: "Incline Dumbbell Press", muscleGroup: "Chest", sets: 3, reps: 10, weight: 32, effort: 8),
                Exercise(name: "Dips", muscleGroup: "Chest", sets: 3, reps: 12, weight: 0, effort: 8),
                Exercise(name: "Overhead Press", muscleGroup: "Shoulders", sets: 4, reps: 8, weight: 42, effort: 9),
                Exercise(name: "Lateral Raises", muscleGroup: "Shoulders", sets: 3, reps: 15, weight: 12, effort: 7),
                Exercise(name: "Triceps Extension", muscleGroup: "Arms", sets: 3, reps: 12, weight: 22, effort: 7),
                Exercise(name: "Close Grip Bench Press", muscleGroup: "Arms", sets: 3, reps: 10, weight: 65, effort: 8)
            ]
        ),
        Workout(
            title: "Pull",
            date: Date(),
            endTime: Date().addingTimeInterval(3600),
            icon: "img_back2",
            exercises: [
                Exercise(name: "Deadlift", muscleGroup: "Back", sets: 4, reps: 5, weight: 120, effort: 10),
                Exercise(name: "Pull-ups", muscleGroup: "Back", sets: 4, reps: 8, weight: 0, effort: 9),
                Exercise(name: "Barbell Rows", muscleGroup: "Back", sets: 4, reps: 8, weight: 75, effort: 8),
                Exercise(name: "Lat Pulldown", muscleGroup: "Back", sets: 3, reps: 10, weight: 60, effort: 7),
                Exercise(name: "Face Pulls", muscleGroup: "Shoulders", sets: 3, reps: 15, weight: 25, effort: 6),
                Exercise(name: "Barbell Curl", muscleGroup: "Arms", sets: 4, reps: 10, weight: 28, effort: 8),
                Exercise(name: "Hammer Curls", muscleGroup: "Arms", sets: 3, reps: 12, weight: 22, effort: 7)
            ]
        ),
        Workout(
            title: "Legs",
            date: Date(),
            endTime: Date().addingTimeInterval(3600),
            icon: "img_legs",
            exercises: [
                Exercise(name: "Squat", muscleGroup: "Legs", sets: 5, reps: 5, weight: 110, effort: 10),
                Exercise(name: "Romanian Deadlift", muscleGroup: "Legs", sets: 4, reps: 8, weight: 85, effort: 9),
                Exercise(name: "Leg Press", muscleGroup: "Legs", sets: 4, reps: 12, weight: 130, effort: 8),
                Exercise(name: "Bulgarian Split Squat", muscleGroup: "Legs", sets: 3, reps: 10, weight: 30, effort: 8),
                Exercise(name: "Leg Curls", muscleGroup: "Legs", sets: 3, reps: 12, weight: 45, effort: 7),
                Exercise(name: "Leg Extensions", muscleGroup: "Legs", sets: 3, reps: 15, weight: 55, effort: 7),
                Exercise(name: "Standing Calf Raise", muscleGroup: "Legs", sets: 4, reps: 15, weight: 55, effort: 6)
            ]
        )
    ]
}
