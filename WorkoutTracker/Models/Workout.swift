//
//  Workout.swift
//  WorkoutTracker
//
//  Main Data Models (SwiftData):
//  Optimized to prevent OOM/N+1 performance issues by using stored aggregates.
//

import Foundation
import SwiftData
internal import SwiftUI // Required for Color mapping in SetType

// MARK: - Enums (Codable for SwiftData)

enum SetType: String, Codable, CaseIterable {
    case normal = "N"
    case warmup = "W"
    case failure = "F"
    
    var color: Color {
        switch self {
        case .normal: return .blue
        case .warmup: return .yellow
        case .failure: return .red
        }
    }
}

enum ExerciseType: String, Codable, CaseIterable, Identifiable {
    case strength = "Strength"
    case cardio = "Cardio"
    case duration = "Duration"
    
    var id: String { self.rawValue }
}

enum ExerciseCategory: String, Codable, CaseIterable {
    // Note: Raw values for enums must be literals, so we don't use Constants here.
    case squat = "Squat"
    case press = "Press"
    case deadlift = "Deadlift"
    case pull = "Pull"
    case curl = "Curl"
    case core = "Core"
    case cardio = "Cardio"
    case other = "Other"
    
    static func determine(from name: String) -> ExerciseCategory {
        let lower = name.lowercased()
        if lower.contains("squat") { return .squat }
        if lower.contains("bench") || lower.contains("press") { return .press }
        if lower.contains("deadlift") { return .deadlift }
        if lower.contains("pull") || lower.contains("row") { return .pull }
        if lower.contains("curl") { return .curl }
        if lower.contains("plank") || lower.contains("crunch") { return .core }
        return .other
    }
}

// MARK: - SwiftData Models

@Model
class WorkoutSet: Identifiable {
    var id: UUID = UUID()
    var index: Int = 0
    var weight: Double? = nil
    var reps: Int? = nil
    var distance: Double? = nil
    var time: Int? = nil
    var isCompleted: Bool = false
    var type: SetType = SetType.normal
    
    var exercise: Exercise? = nil
    
    init(id: UUID = UUID(), index: Int, weight: Double? = nil, reps: Int? = nil, distance: Double? = nil, time: Int? = nil, isCompleted: Bool = false, type: SetType = .normal) {
        self.id = id
        self.index = index
        self.weight = weight
        self.reps = reps
        self.distance = distance
        self.time = time
        self.isCompleted = isCompleted
        self.type = type
    }
    
    func duplicate() -> WorkoutSet {
        return WorkoutSet(id: UUID(), index: index, weight: weight, reps: reps, distance: distance, time: time, isCompleted: isCompleted, type: type)
    }
}

@Model
class Exercise: Identifiable {
    var id: UUID = UUID()
    var name: String = ""
    var muscleGroup: String = ""
    var type: ExerciseType = ExerciseType.strength
    @Attribute var category: ExerciseCategory = ExerciseCategory.other
    var effort: Int = 5
    var isCompleted: Bool = false
    
    // MARK: - Stored Aggregates (Performance Optimization)
    @Attribute var setsCount: Int = 0
    @Attribute var firstSetReps: Int = 0
    @Attribute var firstSetWeight: Double = 0.0
    @Attribute var firstSetDistance: Double? = nil
    @Attribute var firstSetTimeSeconds: Int? = nil
    @Attribute var exerciseVolume: Double = 0.0
    
    @Relationship(deleteRule: .cascade, inverse: \WorkoutSet.exercise)
    var setsList: [WorkoutSet] = []
    
    @Relationship(deleteRule: .cascade, inverse: \Exercise.parentExercise)
    var subExercises: [Exercise] = []
    
    var parentExercise: Exercise? = nil
    var workout: Workout? = nil
    var preset: WorkoutPreset? = nil
    
    init(id: UUID = UUID(), name: String, muscleGroup: String, type: ExerciseType = .strength, category: ExerciseCategory? = nil, sets: Int = 1, reps: Int = 0, weight: Double = 0, distance: Double? = nil, timeSeconds: Int? = nil, effort: Int = 5, subExercises: [Exercise] = [], setsList: [WorkoutSet] = [], isCompleted: Bool = false) {
        self.id = id
        self.name = name
        self.muscleGroup = muscleGroup
        self.type = type
        self.category = category ?? ExerciseCategory.determine(from: name)
        self.effort = effort
        self.isCompleted = isCompleted
        self.subExercises = subExercises
        self.setsList = setsList
        
        if self.setsList.isEmpty && self.subExercises.isEmpty && sets > 0 {
            var generatedSets: [WorkoutSet] = []
            for i in 1...sets {
                generatedSets.append(WorkoutSet(
                    index: i,
                    weight: weight > 0 ? weight : nil,
                    reps: reps > 0 ? reps : nil,
                    distance: distance,
                    time: timeSeconds,
                    isCompleted: false,
                    type: .normal
                ))
            }
            self.setsList = generatedSets
        }
        
        self.updateAggregates()
    }
    
    var sortedSets: [WorkoutSet] {
        setsList.sorted(by: { $0.index < $1.index })
    }
    
    var isSuperset: Bool { !subExercises.isEmpty }
    
    /// To be called by the ViewModel when a set is modified, deleted, or added
    func updateAggregates() {
        self.setsCount = setsList.count
        
        if let firstSet = sortedSets.first {
            self.firstSetReps = firstSet.reps ?? 0
            self.firstSetWeight = firstSet.weight ?? 0.0
            self.firstSetDistance = firstSet.distance
            self.firstSetTimeSeconds = firstSet.time
        } else {
            self.firstSetReps = 0
            self.firstSetWeight = 0.0
            self.firstSetDistance = nil
            self.firstSetTimeSeconds = nil
        }
        
        if isSuperset {
            self.exerciseVolume = subExercises.reduce(0.0) { $0 + $1.exerciseVolume }
        } else {
            self.exerciseVolume = setsList.reduce(0.0) { partialResult, set in
                if set.type == .warmup || !set.isCompleted { return partialResult }
                switch type {
                case .strength: return partialResult + ((set.weight ?? 0) * Double(set.reps ?? 0))
                case .cardio, .duration: return partialResult
                }
            }
        }
    }
    
    func duplicate() -> Exercise {
        let copiedSets = setsList.map { $0.duplicate() }
        let copiedSubs = subExercises.map { $0.duplicate() }
        return Exercise(id: UUID(), name: name, muscleGroup: muscleGroup, type: type, category: category, sets: 0, effort: effort, subExercises: copiedSubs, setsList: copiedSets, isCompleted: isCompleted)
    }
}

@Model
class WorkoutPreset: Identifiable {
    var id: UUID = UUID()
    var name: String = ""
    var icon: String = ""
    
    @Relationship(deleteRule: .cascade, inverse: \Exercise.preset)
    var exercises: [Exercise] = []
    
    init(id: UUID = UUID(), name: String, icon: String, exercises: [Exercise]) {
        self.id = id
        self.name = name
        self.icon = icon
        self.exercises = exercises
    }
}

@Model
class Workout: Identifiable {
    var id: UUID = UUID()
    var title: String = ""
    var date: Date = Date()
    var endTime: Date? = nil
    var icon: String = "figure.run"
    var isFavorite: Bool = false
    @Attribute var aiChatHistoryData: Data? = nil // ИСПРАВЛЕНИЕ: Хранилище чата внутри тренировки
    
    // MARK: - Stored Aggregates (Performance Optimization)
    @Attribute var durationSeconds: Int = 0
    @Attribute var effortPercentage: Int = 0
    @Attribute var totalStrengthVolume: Double = 0.0
    @Attribute var totalCardioDistance: Double = 0.0
    
    @Relationship(deleteRule: .cascade, inverse: \Exercise.workout)
    var exercises: [Exercise] = []
    
    init(id: UUID = UUID(), title: String, date: Date, endTime: Date? = nil, icon: String = "figure.run", exercises: [Exercise] = [], isFavorite: Bool = false, aiChatHistoryData: Data? = nil) {
        self.id = id
        self.title = title
        self.date = date
        self.endTime = endTime
        self.icon = icon
        self.isFavorite = isFavorite
        self.exercises = exercises
        self.aiChatHistoryData = aiChatHistoryData
        
        self.durationSeconds = 0
        self.effortPercentage = 0
        self.totalStrengthVolume = 0.0
        self.totalCardioDistance = 0.0
    }
    
    var isActive: Bool { endTime == nil }
}

@Model
class ExerciseNote {
    @Attribute(.unique) var exerciseName: String = ""
    var text: String = ""
    
    init(exerciseName: String, text: String) {
        self.exerciseName = exerciseName
        self.text = text
    }
}

// MARK: - Aggregated Stats (Protects from OOM)

@Model
class UserStats {
    var totalWorkouts: Int = 0
    var totalVolume: Double = 0.0
    var totalDistance: Double = 0.0
    var earlyWorkouts: Int = 0
    var nightWorkouts: Int = 0
    
    init(totalWorkouts: Int = 0, totalVolume: Double = 0.0, totalDistance: Double = 0.0, earlyWorkouts: Int = 0, nightWorkouts: Int = 0) {
        self.totalWorkouts = totalWorkouts
        self.totalVolume = totalVolume
        self.totalDistance = totalDistance
        self.earlyWorkouts = earlyWorkouts
        self.nightWorkouts = nightWorkouts
    }
}

@Model
class ExerciseStat {
    @Attribute(.unique) var exerciseName: String = ""
    var maxWeight: Double = 0.0
    var totalCount: Int = 0
    var lastPerformanceDTO: Data? = nil
    
    init(exerciseName: String, maxWeight: Double = 0.0, totalCount: Int = 0, lastPerformanceDTO: Data? = nil) {
        self.exerciseName = exerciseName
        self.maxWeight = maxWeight
        self.totalCount = totalCount
        self.lastPerformanceDTO = lastPerformanceDTO
    }
}

@Model
class MuscleStat {
    @Attribute(.unique) var muscleName: String = ""
    var totalCount: Int = 0
    
    init(muscleName: String, totalCount: Int = 0) {
        self.muscleName = muscleName
        self.totalCount = totalCount
    }
}

// MARK: - DTOs for Export/Import (Codable Support)

struct WorkoutSetDTO: Codable {
    let index: Int
    let weight: Double?
    let reps: Int?
    let distance: Double?
    let time: Int?
    let isCompleted: Bool
    let type: SetType
}

struct ExerciseDTO: Codable {
    let name: String
    let muscleGroup: String
    let type: ExerciseType
    let category: ExerciseCategory
    let effort: Int
    let isCompleted: Bool
    let setsList: [WorkoutSetDTO]
    let subExercises: [ExerciseDTO]
}

struct WorkoutPresetDTO: Codable {
    let name: String
    let icon: String
    let exercises: [ExerciseDTO]
}

extension WorkoutSet {
    func toDTO() -> WorkoutSetDTO {
        WorkoutSetDTO(
            index: index,
            weight: weight,
            reps: reps,
            distance: distance,
            time: time,
            isCompleted: isCompleted,
            type: type
        )
    }
    
    convenience init(from dto: WorkoutSetDTO) {
        self.init(
            id: UUID(),
            index: dto.index,
            weight: dto.weight,
            reps: dto.reps,
            distance: dto.distance,
            time: dto.time,
            isCompleted: dto.isCompleted,
            type: dto.type
        )
    }
}

extension Exercise {
    func toDTO() -> ExerciseDTO {
        ExerciseDTO(
            name: name,
            muscleGroup: muscleGroup,
            type: type,
            category: category,
            effort: effort,
            isCompleted: isCompleted,
            setsList: sortedSets.map { $0.toDTO() },
            subExercises: subExercises.map { $0.toDTO() }
        )
    }
    
    convenience init(from dto: ExerciseDTO) {
        self.init(
            id: UUID(),
            name: dto.name,
            muscleGroup: dto.muscleGroup,
            type: dto.type,
            category: dto.category,
            sets: 0,
            effort: dto.effort,
            subExercises: dto.subExercises.map { Exercise(from: $0) },
            setsList: dto.setsList.map { WorkoutSet(from: $0) },
            isCompleted: dto.isCompleted
        )
        self.updateAggregates()
    }
}

extension WorkoutPreset {
    func toDTO() -> WorkoutPresetDTO {
        WorkoutPresetDTO(
            name: name,
            icon: icon,
            exercises: exercises.map { $0.toDTO() }
        )
    }
    
    convenience init(from dto: WorkoutPresetDTO) {
        self.init(
            id: UUID(),
            name: dto.name,
            icon: dto.icon,
            exercises: dto.exercises.map { Exercise(from: $0) }
        )
    }
}
// MARK: - Extensions (Data & Catalog)
extension Exercise {
    static let catalog: [String: [String]] = [
        Constants.MuscleName.chest.rawValue: [
            "Bench Press", "Push Ups", // "Incline Dumbbell Press", "Dips",
            // "Dumbbell Flyes", "Cable Crossover", "Decline Bench Press",
            // "Chest Press Machine", "Pec Deck", "Incline Bench Press",
            // "Diamond Push Ups", "Wide Grip Push Ups", "Cable Flyes",
            // "Push-up Variations", "Chest Dips", "Landmine Press"
        ],
        Constants.MuscleName.back.rawValue: [
            "Pull-ups", "Deadlift", "Barbell Rows", // "Lat Pulldown",
            // "T-Bar Row", "Cable Rows", "One-Arm Dumbbell Row",
            // "Chin-ups", "Wide Grip Pull-ups", "Seated Cable Row",
            // "Bent Over Row", "Face Pulls", "Reverse Flyes",
            // "Shrugs", "Good Mornings", "Rack Pulls", "Renegade Rows",
            // "Inverted Row", "Hyperextensions", "Meadows Row"
        ],
        Constants.MuscleName.legs.rawValue: [
            "Squat", "Leg Press", "Lunges", // "Calf Raises",
            // "Romanian Deadlift", "Bulgarian Split Squat", "Leg Curls",
            // "Leg Extensions", "Hack Squat", "Front Squat",
            // "Walking Lunges", "Step-ups", "Glute Bridge",
            // "Hip Thrusts", "Goblet Squat", "Pistol Squat",
            // "Sumo Squat", "Stiff Leg Deadlift", "Seated Calf Raise",
            // "Standing Calf Raise", "Wall Sits", "Quadruped Hip Extension"
        ],
        Constants.MuscleName.shoulders.rawValue: [
            "Overhead Press", "Lateral Raises", // "Face Pulls",
            // "Arnold Press", "Reverse Flyes", "Front Raises",
            // "Upright Row", "Pike Push-ups", "Shoulder Press Machine",
            // "Cable Lateral Raises", "Rear Delt Flyes", "Push Press",
            // "Handstand Push-ups", "Landmine Press", "Turkish Get-up"
        ],
        Constants.MuscleName.arms.rawValue: [
            "Barbell Curl", "Triceps Extension", // "Hammer Curls",
            // "Bicep Curls", "Triceps Dips", "Close Grip Bench Press",
            // "Preacher Curl", "Concentration Curls", "Cable Curls",
            // "Triceps Pushdown", "Overhead Triceps Extension",
            // "Spider Curls", "Rope Hammer Curls", "Skull Crushers",
            // "French Press", "Zottman Curls", "Cable Kickbacks"
        ],
        Constants.MuscleName.core.rawValue: [
            "Plank", "Crunches", // "Leg Raises",
            // "Russian Twists", "Mountain Climbers", "Bicycle Crunches",
            // "Hanging Knee Raises", "Dead Bug", "Bird Dog",
            // "Side Plank", "Ab Wheel Rollout", "Sit-ups",
            // "L-sit", "Dragon Flag", "Toes to Bar",
            // "Cable Crunches", "Pallof Press", "Turkish Get-up"
        ],
        Constants.MuscleName.cardio.rawValue: [
            "Running", "Cycling", // "Rowing", "Jump Rope", "Stretching",
            // "Treadmill", "Elliptical", "HIIT", "Burpees",
            // "Jumping Jacks", "High Knees", "Mountain Climbers",
            // "Battle Ropes", "Box Jumps", "Swimming", "Stair Climber",
            // "Kettlebell Swings", "Rowing Machine", "Treadmill Sprints"
        ]
    ]
}

extension Workout {
    static var examples: [Workout] {
        [
            Workout(
                title: "Full Body",
                date: Date(),
                endTime: Date().addingTimeInterval(3600),
                icon: "img_default",
                exercises: [
                    Exercise(name: "Squat", muscleGroup: Constants.MuscleName.legs.rawValue, sets: 4, reps: 8, weight: 90, effort: 9),
                    Exercise(name: "Bench Press", muscleGroup: Constants.MuscleName.chest.rawValue, sets: 4, reps: 8, weight: 75, effort: 9),
                    Exercise(name: "Barbell Rows", muscleGroup: Constants.MuscleName.back.rawValue, sets: 4, reps: 8, weight: 70, effort: 8),
                    Exercise(name: "Overhead Press", muscleGroup: Constants.MuscleName.shoulders.rawValue, sets: 3, reps: 10, weight: 35, effort: 8),
                    Exercise(name: "Barbell Curl", muscleGroup: Constants.MuscleName.arms.rawValue, sets: 3, reps: 10, weight: 25, effort: 7),
                    Exercise(name: "Plank", muscleGroup: Constants.MuscleName.core.rawValue, type: .duration, sets: 3, reps: 0, weight: 0, timeSeconds: 60, effort: 6)
                ]
            ),
            Workout(
                title: "Push",
                date: Date(),
                endTime: Date().addingTimeInterval(3600),
                icon: "img_chest2",
                exercises: [
                    Exercise(name: "Bench Press", muscleGroup: Constants.MuscleName.chest.rawValue, sets: 4, reps: 6, weight: 85, effort: 10),
                    Exercise(name: "Incline Dumbbell Press", muscleGroup: Constants.MuscleName.chest.rawValue, sets: 3, reps: 10, weight: 32, effort: 8),
                    Exercise(name: "Dips", muscleGroup: Constants.MuscleName.chest.rawValue, sets: 3, reps: 12, weight: 0, effort: 8),
                    Exercise(name: "Overhead Press", muscleGroup: Constants.MuscleName.shoulders.rawValue, sets: 4, reps: 8, weight: 42, effort: 9),
                    Exercise(name: "Lateral Raises", muscleGroup: Constants.MuscleName.shoulders.rawValue, sets: 3, reps: 15, weight: 12, effort: 7),
                    Exercise(name: "Triceps Extension", muscleGroup: Constants.MuscleName.arms.rawValue, sets: 3, reps: 12, weight: 22, effort: 7),
                    Exercise(name: "Close Grip Bench Press", muscleGroup: Constants.MuscleName.arms.rawValue, sets: 3, reps: 10, weight: 65, effort: 8)
                ]
            ),
            Workout(
                title: "Pull",
                date: Date(),
                endTime: Date().addingTimeInterval(3600),
                icon: "img_back2",
                exercises: [
                    Exercise(name: "Deadlift", muscleGroup: Constants.MuscleName.back.rawValue, sets: 4, reps: 5, weight: 120, effort: 10),
                    Exercise(name: "Pull-ups", muscleGroup: Constants.MuscleName.back.rawValue, sets: 4, reps: 8, weight: 0, effort: 9),
                    Exercise(name: "Barbell Rows", muscleGroup: Constants.MuscleName.back.rawValue, sets: 4, reps: 8, weight: 75, effort: 8),
                    Exercise(name: "Lat Pulldown", muscleGroup: Constants.MuscleName.back.rawValue, sets: 3, reps: 10, weight: 60, effort: 7),
                    Exercise(name: "Face Pulls", muscleGroup: Constants.MuscleName.shoulders.rawValue, sets: 3, reps: 15, weight: 25, effort: 6),
                    Exercise(name: "Barbell Curl", muscleGroup: Constants.MuscleName.arms.rawValue, sets: 4, reps: 10, weight: 28, effort: 8),
                    Exercise(name: "Hammer Curls", muscleGroup: Constants.MuscleName.arms.rawValue, sets: 3, reps: 12, weight: 22, effort: 7)
                ]
            ),
            Workout(
                title: "Legs",
                date: Date(),
                endTime: Date().addingTimeInterval(3600),
                icon: "img_legs",
                exercises: [
                    Exercise(name: "Squat", muscleGroup: Constants.MuscleName.legs.rawValue, sets: 5, reps: 5, weight: 110, effort: 10),
                    Exercise(name: "Romanian Deadlift", muscleGroup: Constants.MuscleName.legs.rawValue, sets: 4, reps: 8, weight: 85, effort: 9),
                    Exercise(name: "Leg Press", muscleGroup: Constants.MuscleName.legs.rawValue, sets: 4, reps: 12, weight: 130, effort: 8),
                    Exercise(name: "Bulgarian Split Squat", muscleGroup: Constants.MuscleName.legs.rawValue, sets: 3, reps: 10, weight: 30, effort: 8),
                    Exercise(name: "Leg Curls", muscleGroup: Constants.MuscleName.legs.rawValue, sets: 3, reps: 12, weight: 45, effort: 7),
                    Exercise(name: "Leg Extensions", muscleGroup: Constants.MuscleName.legs.rawValue, sets: 3, reps: 15, weight: 55, effort: 7),
                    Exercise(name: "Standing Calf Raise", muscleGroup: Constants.MuscleName.legs.rawValue, sets: 4, reps: 15, weight: 55, effort: 6)
                ]
            )
        ]
    }
}
// MARK: - UI Display Helpers
extension Exercise {
    
    /// Генерирует красивую строку с деталями упражнения для списков
    func formattedDetails(unitsManager: UnitsManager) -> String {
        switch type {
        case .strength:
            if firstSetWeight > 0 {
                let weightStr = unitsManager.displayWeightWithUnit(forKg: firstSetWeight)
                return "\(setsCount)s x \(firstSetReps)r • \(weightStr)"
            } else {
                return "\(setsCount)s x \(firstSetReps)r"
            }
            
        case .cardio:
            if let dist = firstSetDistance, dist > 0 {
                let distStr = unitsManager.displayDistanceWithUnit(forMeters: dist)
                let timeStr = formatTime(firstSetTimeSeconds ?? 0)
                return "\(distStr) in \(timeStr)"
            } else {
                return "\(setsCount) sets"
            }
            
        case .duration:
            if let timeSeconds = firstSetTimeSeconds, timeSeconds > 0 {
                return "\(setsCount) sets x \(formatTime(timeSeconds))"
            } else {
                return "\(setsCount) sets"
            }
        }
    }
    
    private func formatTime(_ totalSeconds: Int) -> String {
        let m = totalSeconds / 60
        let s = totalSeconds % 60
        return String(format: "%d:%02d", m, s)
    }
}
