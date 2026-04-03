//
//  Workout.swift
//  WorkoutTracker
//
//  Main Data Models (SwiftData):
//  Optimized with Computed Properties to prevent redundant DB writes.
//

import Foundation
import SwiftData
internal import SwiftUI

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
    case squat = "Squat", press = "Press", deadlift = "Deadlift", pull = "Pull", curl = "Curl", core = "Core", cardio = "Cardio", other = "Other"
    
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
    
    // ✅ НОВЫЕ ПОЛЯ ДЛЯ КЭШИРОВАНИЯ (Избавляют от N+1 проблемы)
    var cachedVolume: Double = 0.0
    var cachedMaxWeight: Double = 0.0
    
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
            self.setsList = (1...sets).map { i in
                WorkoutSet(index: i, weight: weight > 0 ? weight : nil, reps: reps > 0 ? reps : nil, distance: distance, time: timeSeconds, isCompleted: false, type: .normal)
            }
        }
    }
    
    // MARK: - 🚀 ОПТИМИЗАЦИЯ: Вычисляемые свойства
    
    @Transient var sortedSets: [WorkoutSet] {
        setsList.sorted(by: { $0.index < $1.index })
    }
    
    @Transient var isSuperset: Bool { !subExercises.isEmpty }
    
    @Transient var setsCount: Int { setsList.count }
    
    @Transient var firstSetReps: Int { sortedSets.first?.reps ?? 0 }
    
    @Transient var firstSetWeight: Double { sortedSets.first?.weight ?? 0.0 }
    
    @Transient var firstSetDistance: Double? { sortedSets.first?.distance }
    
    @Transient var firstSetTimeSeconds: Int? { sortedSets.first?.time }
    
    @Transient var exerciseVolume: Double {
        // Если тренировка завершена, мгновенно отдаем кэш без обращения к сетам (O(1))
        if isCompleted && cachedVolume > 0 {
            return cachedVolume
        }
        
        // Считаем на лету только во время активной тренировки
        if isSuperset {
            return subExercises.reduce(0.0) { $0 + $1.exerciseVolume }
        } else {
            return setsList.reduce(0.0) { partialResult, set in
                if set.type == .warmup || !set.isCompleted { return partialResult }
                guard let w = set.weight, let r = set.reps else { return partialResult }
                return type == .strength ? partialResult + (w * Double(r)) : partialResult
            }
        }
    }
    
    // MARK: - Safe Mutations
    func addSafeSet(_ newSet: WorkoutSet) {
        newSet.exercise = self
        self.setsList.append(newSet)
    }
    
    func removeSafeSet(_ set: WorkoutSet) {
        self.setsList.removeAll(where: { $0.id == set.id })
        for (i, s) in sortedSets.enumerated() { s.index = i + 1 }
    }
    func removeSafeSets(_ setsToRemove: [WorkoutSet]) {
            let idsToRemove = Set(setsToRemove.map { $0.id })
            self.setsList.removeAll(where: { idsToRemove.contains($0.id) })
            // Пересчитываем индексы только ОДИН раз после массового удаления
            for (i, s) in sortedSets.enumerated() { s.index = i + 1 }
        }
    
    func replaceAllSets(with newSets: [WorkoutSet]) {
        self.setsList = newSets
        for set in newSets { set.exercise = self }
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
        self.id = id; self.name = name; self.icon = icon; self.exercises = exercises
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
    var aiChatHistoryData: Data? = nil
    
    // Кэшированные агрегаты (избавляют от проблемы N+1)
    var durationSeconds: Int = 0
    var effortPercentage: Int = 0
    var totalStrengthVolume: Double = 0.0
    var totalCardioDistance: Double = 0.0
    var totalReps: Int = 0 // ✅ НОВОЕ ПОЛЕ ДЛЯ КЭШИРОВАНИЯ
    
    @Relationship(deleteRule: .cascade, inverse: \Exercise.workout)
    var exercises: [Exercise] = []
    
    init(id: UUID = UUID(), title: String, date: Date, endTime: Date? = nil, icon: String = "figure.run", exercises: [Exercise] = [], isFavorite: Bool = false, aiChatHistoryData: Data? = nil) {
        self.id = id; self.title = title; self.date = date; self.endTime = endTime; self.icon = icon; self.isFavorite = isFavorite; self.exercises = exercises; self.aiChatHistoryData = aiChatHistoryData
    }
    
    var isActive: Bool { endTime == nil }
}

@Model
class ExerciseNote {
    @Attribute(.unique) var exerciseName: String = ""
    var text: String = ""
    init(exerciseName: String, text: String) { self.exerciseName = exerciseName; self.text = text }
}

@Model
class UserStats {
    var totalWorkouts: Int = 0; var totalVolume: Double = 0.0; var totalDistance: Double = 0.0
    var earlyWorkouts: Int = 0; var nightWorkouts: Int = 0
    init(totalWorkouts: Int = 0, totalVolume: Double = 0.0, totalDistance: Double = 0.0, earlyWorkouts: Int = 0, nightWorkouts: Int = 0) {
        self.totalWorkouts = totalWorkouts; self.totalVolume = totalVolume; self.totalDistance = totalDistance; self.earlyWorkouts = earlyWorkouts; self.nightWorkouts = nightWorkouts
    }
}

@Model
class ExerciseStat {
    @Attribute(.unique) var exerciseName: String = ""
    var maxWeight: Double = 0.0; var totalCount: Int = 0; var lastPerformanceDTO: Data? = nil
    init(exerciseName: String, maxWeight: Double = 0.0, totalCount: Int = 0, lastPerformanceDTO: Data? = nil) {
        self.exerciseName = exerciseName; self.maxWeight = maxWeight; self.totalCount = totalCount; self.lastPerformanceDTO = lastPerformanceDTO
    }
}

@Model
class MuscleStat {
    @Attribute(.unique) var muscleName: String = ""
    var totalCount: Int = 0
    init(muscleName: String, totalCount: Int = 0) { self.muscleName = muscleName; self.totalCount = totalCount }
}

// MARK: - DTOs & Codable Support

struct WorkoutSetDTO: Codable {
    let index: Int; let weight: Double?; let reps: Int?; let distance: Double?; let time: Int?; let isCompleted: Bool; let type: SetType
}

struct ExerciseDTO: Codable {
    let name: String; let muscleGroup: String; let type: ExerciseType; let category: ExerciseCategory; let effort: Int; let isCompleted: Bool; let setsList: [WorkoutSetDTO]; let subExercises: [ExerciseDTO]
}

struct WorkoutPresetDTO: Codable {
    let name: String; let icon: String; let exercises: [ExerciseDTO]
}

extension WorkoutSet {
    func toDTO() -> WorkoutSetDTO {
        WorkoutSetDTO(index: index, weight: weight, reps: reps, distance: distance, time: time, isCompleted: isCompleted, type: type)
    }
    convenience init(from dto: WorkoutSetDTO) {
        self.init(index: dto.index, weight: dto.weight, reps: dto.reps, distance: dto.distance, time: dto.time, isCompleted: dto.isCompleted, type: dto.type)
    }
}

extension Exercise {
    func toDTO() -> ExerciseDTO {
        ExerciseDTO(name: name, muscleGroup: muscleGroup, type: type, category: category, effort: effort, isCompleted: isCompleted, setsList: sortedSets.map { $0.toDTO() }, subExercises: subExercises.map { $0.toDTO() })
    }
    convenience init(from dto: ExerciseDTO) {
        self.init(name: dto.name, muscleGroup: dto.muscleGroup, type: dto.type, category: dto.category, effort: dto.effort, subExercises: dto.subExercises.map { Exercise(from: $0) }, setsList: dto.setsList.map { WorkoutSet(from: $0) }, isCompleted: dto.isCompleted)
    }
}

extension WorkoutPreset {
    func toDTO() -> WorkoutPresetDTO {
        WorkoutPresetDTO(name: name, icon: icon, exercises: exercises.map { $0.toDTO() })
    }
    convenience init(from dto: WorkoutPresetDTO) {
        self.init(name: dto.name, icon: dto.icon, exercises: dto.exercises.map { Exercise(from: $0) })
    }
}

// MARK: - Extensions (Catalog & Examples)

extension Exercise {
    static let catalog: [String: [String]] = [
        Constants.MuscleName.chest.rawValue: ["Bench Press", "Push Ups"],
        Constants.MuscleName.back.rawValue: ["Pull-ups", "Deadlift", "Barbell Rows"],
        Constants.MuscleName.legs.rawValue: ["Squat", "Leg Press", "Lunges"],
        Constants.MuscleName.shoulders.rawValue: ["Overhead Press", "Lateral Raises"],
        Constants.MuscleName.arms.rawValue: ["Barbell Curl", "Triceps Extension"],
        Constants.MuscleName.core.rawValue: ["Plank", "Crunches"],
        Constants.MuscleName.cardio.rawValue: ["Running", "Cycling"]
    ]
}

extension Workout {
    static var examples: [Workout] {
        [
            Workout(title: "Full Body", date: Date(), icon: "img_default", exercises: [
                Exercise(name: "Squat", muscleGroup: "Legs", sets: 3, reps: 10, weight: 60),
                Exercise(name: "Bench Press", muscleGroup: "Chest", sets: 3, reps: 10, weight: 50)
            ])
        ]
    }
}

// MARK: - UI Display Helpers

extension Exercise {
    func formattedDetails(unitsManager: UnitsManager) -> String {
        switch type {
        case .strength:
            return firstSetWeight > 0 ? "\(setsCount)s x \(firstSetReps)r • \(unitsManager.displayWeightWithUnit(forKg: firstSetWeight))" : "\(setsCount)s x \(firstSetReps)r"
        case .cardio:
            if let dist = firstSetDistance, dist > 0 {
                return "\(unitsManager.displayDistanceWithUnit(forMeters: dist)) in \(formatTime(firstSetTimeSeconds ?? 0))"
            }
            return "\(setsCount) sets"
        case .duration:
            return "\(setsCount) sets x \(formatTime(firstSetTimeSeconds ?? 0))"
        }
    }
    
    private func formatTime(_ totalSeconds: Int) -> String {
        String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
    }
}
struct WorkoutDTO: Codable {
    let id: UUID
    let title: String
    let date: Date
    let endTime: Date?
    let icon: String
    let isFavorite: Bool
    let durationSeconds: Int
    let effortPercentage: Int
    let totalStrengthVolume: Double
    let totalCardioDistance: Double
    let exercises: [ExerciseDTO]
}

extension Workout {
    func toDTO() -> WorkoutDTO {
        WorkoutDTO(
            id: id,
            title: title,
            date: date,
            endTime: endTime,
            icon: icon,
            isFavorite: isFavorite,
            durationSeconds: durationSeconds,
            effortPercentage: effortPercentage,
            totalStrengthVolume: totalStrengthVolume,
            totalCardioDistance: totalCardioDistance,
            exercises: exercises.map { $0.toDTO() }
        )
    }
}
