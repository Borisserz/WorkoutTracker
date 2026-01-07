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
    
    // MARK: - Private Stored Properties (только для Codable)
    // Эти поля используются только для декодирования старых JSON файлов
    private var _sets: Int = 0
    private var _reps: Int = 0
    private var _weight: Double = 0
    private var _distance: Double? = nil
    private var _timeSeconds: Int? = nil
    
    // MARK: - Computed Properties (синхронизированы с setsList)
    
    /// Количество сетов (синхронизировано с setsList)
    var sets: Int {
        get {
            // Если setsList не пустой, берем количество из него
            if !setsList.isEmpty {
                return setsList.count
            }
            // Fallback для старых данных (только при загрузке)
            return _sets
        }
        set {
            // При записи обновляем setsList
            _sets = newValue
            syncSetsListFromLegacyFields()
        }
    }
    
    /// Количество повторов (берется из первого сета или fallback)
    var reps: Int {
        get {
            // Если setsList не пустой, берем из первого сета
            if let firstSet = setsList.first, let firstReps = firstSet.reps {
                return firstReps
            }
            // Fallback для старых данных
            return _reps
        }
        set {
            // При записи обновляем все сеты в setsList
            _reps = newValue
            syncSetsListFromLegacyFields()
        }
    }
    
    /// Вес (берется из первого сета или fallback)
    var weight: Double {
        get {
            // Если setsList не пустой, берем из первого сета
            if let firstSet = setsList.first, let firstWeight = firstSet.weight {
                return firstWeight
            }
            // Fallback для старых данных
            return _weight
        }
        set {
            // При записи обновляем все сеты в setsList
            _weight = newValue
            syncSetsListFromLegacyFields()
        }
    }
    
    /// Дистанция (берется из первого сета или fallback)
    var distance: Double? {
        get {
            // Если setsList не пустой, берем из первого сета
            if let firstSet = setsList.first, let firstDistance = firstSet.distance {
                return firstDistance
            }
            // Fallback для старых данных
            return _distance
        }
        set {
            // При записи обновляем все сеты в setsList
            _distance = newValue
            syncSetsListFromLegacyFields()
        }
    }
    
    /// Время в секундах (берется из первого сета или fallback)
    var timeSeconds: Int? {
        get {
            // Если setsList не пустой, берем из первого сета
            if let firstSet = setsList.first, let firstTime = firstSet.time {
                return firstTime
            }
            // Fallback для старых данных
            return _timeSeconds
        }
        set {
            // При записи обновляем все сеты в setsList
            _timeSeconds = newValue
            syncSetsListFromLegacyFields()
        }
    }
    
    // MARK: - Helper Methods
    
    /// Синхронизирует setsList на основе старых полей (вызывается при записи в старые поля)
    /// ВАЖНО: Этот метод используется только для обратной совместимости при редактировании через старые поля.
    /// В новом коде следует работать напрямую с setsList.
    private mutating func syncSetsListFromLegacyFields() {
        // Если setsList пустой, создаем сеты на основе старых полей
        if setsList.isEmpty && _sets > 0 {
            setsList = []
            for i in 1..._sets {
                setsList.append(WorkoutSet(
                    index: i,
                    weight: _weight >= 0 ? _weight : nil,
                    reps: _reps >= 0 ? _reps : nil,
                    distance: _distance,
                    time: _timeSeconds,
                    isCompleted: false,
                    type: .normal
                ))
            }
        } else if !setsList.isEmpty {
            // Если setsList не пустой, обновляем количество сетов (добавляем/удаляем)
            // и обновляем значения только если они действительно изменились
            let currentCount = setsList.count
            let targetCount = _sets
            
            if targetCount > currentCount {
                // Добавляем новые сеты
                for i in (currentCount + 1)...targetCount {
                    let lastSet = setsList.last
                    setsList.append(WorkoutSet(
                        index: i,
                        weight: type == .strength ? (_weight >= 0 ? _weight : lastSet?.weight) : nil,
                        reps: type == .strength ? (_reps >= 0 ? _reps : lastSet?.reps) : nil,
                        distance: type == .cardio ? (_distance ?? lastSet?.distance) : nil,
                        time: type == .cardio || type == .duration ? (_timeSeconds ?? lastSet?.time) : nil,
                        isCompleted: false,
                        type: .normal
                    ))
                }
            } else if targetCount < currentCount {
                // Удаляем лишние сеты (с конца)
                setsList.removeLast(currentCount - targetCount)
                // Обновляем индексы
                for i in 0..<setsList.count {
                    setsList[i].index = i + 1
                }
            }
            
            // Обновляем значения в существующих сетах только если они действительно изменились
            // Это нужно для обратной совместимости при редактировании через старые поля
            // (например, в PresetEditorView или EditExerciseView)
            for i in 0..<setsList.count {
                if type == .strength {
                    if _weight >= 0 { setsList[i].weight = _weight }
                    if _reps >= 0 { setsList[i].reps = _reps }
                } else if type == .cardio {
                    if let dist = _distance { setsList[i].distance = dist }
                    if let time = _timeSeconds { setsList[i].time = time }
                } else if type == .duration {
                    if let time = _timeSeconds { setsList[i].time = time }
                }
            }
        }
    }
    
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
        self.effort = effort
        self.subExercises = subExercises
        self.isCompleted = isCompleted
        
        // Сохраняем в private stored properties для обратной совместимости
        self._sets = sets
        self._reps = reps
        self._weight = weight
        self._distance = distance
        self._timeSeconds = timeSeconds
        
        // Если передан setsList, используем его, иначе создаем на основе старых полей
        if !setsList.isEmpty {
            self.setsList = setsList
        } else if subExercises.isEmpty && sets > 0 {
            // Если при создании список сетов пустой, создаем их на основе переданных простых параметров.
            // Это нужно, чтобы при добавлении упражнения в UI сразу появлялись строчки.
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
        } else {
            self.setsList = []
        }
    }

    // Decoder (Загрузка из JSON)
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        muscleGroup = try container.decode(String.self, forKey: .muscleGroup)
        
        // Декодируем в private stored properties
        _sets = try container.decode(Int.self, forKey: .sets)
        _reps = try container.decode(Int.self, forKey: .reps)
        _weight = try container.decode(Double.self, forKey: .weight)
        _distance = try container.decodeIfPresent(Double.self, forKey: .distance)
        _timeSeconds = try container.decodeIfPresent(Int.self, forKey: .timeSeconds)
        
        effort = try container.decode(Int.self, forKey: .effort)
        subExercises = try container.decodeIfPresent([Exercise].self, forKey: .subExercises) ?? []
        
        type = try container.decodeIfPresent(ExerciseType.self, forKey: .type) ?? .strength
        isCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
        
        // ВАЖНО: Пробуем загрузить новый список сетов (setsList)
        if let loadedSets = try container.decodeIfPresent([WorkoutSet].self, forKey: .setsList) {
            setsList = loadedSets
        } else {
            // МИГРАЦИЯ: Если в файле нет setsList (старая версия приложения),
            // создаем сеты на основе старых полей (_sets, _reps, _weight).
            var newSets: [WorkoutSet] = []
            if _sets > 0 {
                for i in 1..._sets {
                    // Считаем старые упражнения выполненными (isCompleted: true), так как это история
                    newSets.append(WorkoutSet(
                        index: i,
                        weight: _weight,
                        reps: _reps,
                        distance: _distance,
                        time: _timeSeconds,
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
        try container.encode(isCompleted, forKey: .isCompleted)
        
        // 1. Сохраняем актуальный список сетов (основной источник истины)
        try container.encode(setsList, forKey: .setsList)
        
        // 2. Синхронизируем и сохраняем старые поля для обратной совместимости.
        // Берем данные из setsList (или используем fallback значения).
        let syncSets = setsList.isEmpty ? _sets : setsList.count
        let syncReps = setsList.first?.reps ?? _reps
        let syncWeight = setsList.first?.weight ?? _weight
        let syncDistance = setsList.first?.distance ?? _distance
        let syncTimeSeconds = setsList.first?.time ?? _timeSeconds
        
        try container.encode(syncSets, forKey: .sets)
        try container.encode(syncReps, forKey: .reps)
        try container.encode(syncWeight, forKey: .weight)
        try container.encode(syncDistance, forKey: .distance)
        try container.encode(syncTimeSeconds, forKey: .timeSeconds)
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
    var isFavorite: Bool = false
    
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
