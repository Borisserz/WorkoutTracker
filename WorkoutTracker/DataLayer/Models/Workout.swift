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
        if lower.contains("bench") || lower.contains("press") || lower.contains("push-up") || lower.contains("pushup") { return .press }
        if lower.contains("deadlift") || lower.contains("good morning") { return .deadlift }
        if lower.contains("pull") || lower.contains("row") || lower.contains("chin") { return .pull }
        if lower.contains("curl") { return .curl }
        if lower.contains("plank") || lower.contains("crunch") || lower.contains("sit-up") { return .core }
        if lower.contains("run") || lower.contains("walk") || lower.contains("bike") || lower.contains("rowing") || lower.contains("jump") { return .cardio }
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
    
    init(id: UUID = UUID(), index: Int = 0, weight: Double? = nil, reps: Int? = nil, distance: Double? = nil, time: Int? = nil, isCompleted: Bool = false, type: SetType = .normal) {
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
    
    var cachedVolume: Double = 0.0
    var cachedMaxWeight: Double = 0.0
    
    @Relationship(deleteRule: .cascade, inverse: \WorkoutSet.exercise)
    var setsList: [WorkoutSet] = []
    
    @Relationship(deleteRule: .cascade, inverse: \Exercise.parentExercise)
    var subExercises: [Exercise] = []
    
    var parentExercise: Exercise? = nil
    var workout: Workout? = nil
    var preset: WorkoutPreset? = nil
    
    init(id: UUID = UUID(), name: String = "", muscleGroup: String = "", type: ExerciseType = .strength, category: ExerciseCategory? = nil, sets: Int = 1, reps: Int = 0, weight: Double = 0.0, distance: Double? = nil, timeSeconds: Int? = nil, effort: Int = 5, subExercises: [Exercise] = [], setsList: [WorkoutSet] = [], isCompleted: Bool = false) {
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
               
               // ✅ FIX: Manually establish inverse relationships to prevent SwiftData detachment bugs
               for set in self.setsList {
                   set.exercise = self
               }
               for sub in self.subExercises {
                   sub.parentExercise = self
               }
           }
           
           // ✅ FIX: Removed @Transient from ALL computed properties.
           // SwiftData breaks getters if @Transient is applied to computed properties.
           var sortedSets: [WorkoutSet] { setsList.sorted(by: { $0.index < $1.index }) }
           var isSuperset: Bool { !subExercises.isEmpty }
           var setsCount: Int { setsList.count }
           var firstSetReps: Int { sortedSets.first?.reps ?? 0 }
           var firstSetWeight: Double { sortedSets.first?.weight ?? 0.0 }
           var firstSetDistance: Double? { sortedSets.first?.distance }
           var firstSetTimeSeconds: Int? { sortedSets.first?.time }
           
           var exerciseVolume: Double {
               if isCompleted && cachedVolume > 0 { return cachedVolume }
               if isSuperset { return subExercises.reduce(0.0) { $0 + $1.exerciseVolume } }
               else {
                   let includeWarmups = UserDefaults.standard.bool(forKey: Constants.UserDefaultsKeys.includeWarmupsInStats.rawValue)
                   
                   return setsList.reduce(0.0) { partialResult, set in
                       if !set.isCompleted { return partialResult }
                       if !includeWarmups && set.type == .warmup { return partialResult }
                       
                       guard let w = set.weight, let r = set.reps else { return partialResult }
                       return type == .strength ? partialResult + (w * Double(r)) : partialResult
                   }
               }
           }
           
           func addSafeSet(_ newSet: WorkoutSet) { newSet.exercise = self; self.setsList.append(newSet) }
           func removeSafeSet(_ set: WorkoutSet) { self.setsList.removeAll(where: { $0.id == set.id }); for (i, s) in sortedSets.enumerated() { s.index = i + 1 } }
           func removeSafeSets(_ setsToRemove: [WorkoutSet]) {
               let idsToRemove = Set(setsToRemove.map { $0.id })
               self.setsList.removeAll(where: { idsToRemove.contains($0.id) })
               for (i, s) in sortedSets.enumerated() { s.index = i + 1 }
           }
           func replaceAllSets(with newSets: [WorkoutSet]) { self.setsList = newSets; for set in newSets { set.exercise = self } }
       }

       @Model
       class WorkoutPreset: Identifiable {
           var id: UUID = UUID()
           var name: String = ""
           var icon: String = ""
           var isSystem: Bool = false
           var folderName: String? = nil
           
           @Relationship(deleteRule: .cascade, inverse: \Exercise.preset)
           var exercises: [Exercise] = []
           
           init(id: UUID = UUID(), name: String = "", icon: String = "", isSystem: Bool = false, folderName: String? = nil, exercises: [Exercise] = []) {
               self.id = id
               self.name = name
               self.icon = icon
               self.isSystem = isSystem
               self.folderName = folderName
               self.exercises = exercises
               
               // ✅ FIX: Establish inverse relationships
               for exercise in self.exercises {
                   exercise.preset = self
               }
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
           
           var durationSeconds: Int = 0
           var effortPercentage: Int = 0
           var totalStrengthVolume: Double = 0.0
           var totalCardioDistance: Double = 0.0
           var totalReps: Int = 0
           
           @Relationship(deleteRule: .cascade, inverse: \Exercise.workout)
           var exercises: [Exercise] = []
           
           init(id: UUID = UUID(), title: String = "", date: Date = Date(), endTime: Date? = nil, icon: String = "figure.run", exercises: [Exercise] = [], isFavorite: Bool = false, aiChatHistoryData: Data? = nil) {
               self.id = id; self.title = title; self.date = date; self.endTime = endTime; self.icon = icon; self.isFavorite = isFavorite; self.exercises = exercises; self.aiChatHistoryData = aiChatHistoryData
               
               // ✅ FIX: Establish inverse relationships
               for exercise in self.exercises {
                   exercise.workout = self
               }
           }
           
           var isActive: Bool { endTime == nil }
       }
// ⚠️ CLOUDKIT FIX: Removed .unique attributes and ensured all default initializers
@Model
class ExerciseNote {
    var exerciseName: String = ""
    var text: String = ""
    init(exerciseName: String = "", text: String = "") { self.exerciseName = exerciseName; self.text = text }
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
    var exerciseName: String = ""
    var maxWeight: Double = 0.0; var totalCount: Int = 0; var lastPerformanceDTO: Data? = nil
    init(exerciseName: String = "", maxWeight: Double = 0.0, totalCount: Int = 0, lastPerformanceDTO: Data? = nil) {
        self.exerciseName = exerciseName; self.maxWeight = maxWeight; self.totalCount = totalCount; self.lastPerformanceDTO = lastPerformanceDTO
    }
}

@Model
class MuscleStat {
    var muscleName: String = ""
    var totalCount: Int = 0
    init(muscleName: String = "", totalCount: Int = 0) { self.muscleName = muscleName; self.totalCount = totalCount }
}
// MARK: - DTOs & Codable Support

struct WorkoutSetDTO: Codable {
    let index: Int; let weight: Double?; let reps: Int?; let distance: Double?; let time: Int?; let isCompleted: Bool; let type: SetType
}

struct ExerciseDTO: Codable, Sendable {
    var name: String
    var muscleGroup: String
    var type: ExerciseType
    var category: ExerciseCategory
    var effort: Int
    var isCompleted: Bool
    
    var setsList: [WorkoutSetDTO]?
    var subExercises: [ExerciseDTO]?
    
    var sets: Int?
    var reps: Int?
    var recommendedWeightKg: Double?
}

// 2. Обновляем инициализатор, чтобы он подхватывал данные из JSON
extension Exercise {
    func toDTO() -> ExerciseDTO {
        ExerciseDTO(
            name: name, muscleGroup: muscleGroup, type: type, category: category, effort: effort, isCompleted: isCompleted,
            setsList: sortedSets.map { $0.toDTO() }, subExercises: subExercises.map { $0.toDTO() }
        )
    }
    
    convenience init(from dto: ExerciseDTO) {
        let safeSets = dto.setsList ?? []
        let safeSubs = dto.subExercises ?? []
        
        self.init(
            name: dto.name,
            muscleGroup: dto.muscleGroup,
            type: dto.type,
            category: dto.category,
            sets: dto.sets ?? 3,
            reps: dto.reps ?? 10,
            weight: dto.recommendedWeightKg ?? 0.0,
            effort: dto.effort,
            subExercises: safeSubs.map { Exercise(from: $0) },
            setsList: safeSets.map { WorkoutSet(from: $0) },
            isCompleted: dto.isCompleted
        )
    }
}
struct WorkoutPresetDTO: Codable {
    let name: String
    let icon: String
    var folderName: String? = nil // ✅ ДОБАВЛЕНО
    let exercises: [ExerciseDTO]
}


extension WorkoutSet {
    func toDTO() -> WorkoutSetDTO {
        WorkoutSetDTO(index: index, weight: weight, reps: reps, distance: distance, time: time, isCompleted: isCompleted, type: type)
    }
    convenience init(from dto: WorkoutSetDTO) {
        self.init(index: dto.index, weight: dto.weight, reps: dto.reps, distance: dto.distance, time: dto.time, isCompleted: dto.isCompleted, type: dto.type)
    }
}


extension WorkoutPreset {
    func toDTO() -> WorkoutPresetDTO {
        WorkoutPresetDTO(name: name, icon: icon, folderName: folderName, exercises: exercises.map { $0.toDTO() })
    }
    convenience init(from dto: WorkoutPresetDTO) {
        self.init(name: dto.name, icon: dto.icon, folderName: dto.folderName, exercises: dto.exercises.map { Exercise(from: $0) })
    }
}

// MARK: - Extensions (Catalog & Examples)
//
//extension Exercise {
//    static let catalog: [String: [String]] = [
//        Constants.MuscleName.chest.rawValue: [
//            "Around The World", "Bench Press", "Cable Crossover", "Cable Flyes", "Chest Dips",
//            "Chest Press Machine", "Close Grip Pushups", "Decline Bench Press", "Decline Bench Press (Barbell)",
//            "Decline Push-ups", "Diamond Push Ups", "Dips", "Dumbbell Bench Press", "Dumbbell Flyes",
//            "Dumbbell Pullover", "Floor Press", "Floor Press (Dumbbell)", "Hammer Strength Wide Chest",
//            "Hex Press (Dumbbell)", "High-to-Low Cable Fly", "Incline Bench Press", "Incline Dumbbell Flyes",
//            "Incline Dumbbell Press", "Low Cable Fly Crossovers", "Machine Chest Press", "Pec Deck",
//            "Plate Squeeze (Svend Press)", "Push Ups", "Push-up Variations", "Smith Machine Incline Press",
//            "Wide Grip Push Ups"
//        ],
//        Constants.MuscleName.back.rawValue: [
//            "Barbell Rows", "Bent Over Row", "Cable Rows", "Chest Supported Row", "Chin-ups",
//            "Close Grip Lat Pulldown", "Dead Hang", "Deadlift", "Deadlift High Pull", "Good Mornings",
//            "Gorilla Row (Kettlebell)", "Hyperextension", "Hyperextensions", "Inverted Row", "Landmine Row",
//            "Lat Pulldown", "Machine Back Extensions", "Machine Row", "Meadows Row", "Meadows Rows (Barbell)",
//            "Neutral Grip Lat Pulldown", "Neutral Grip Pull-ups", "One-Arm Dumbbell Row", "Pendlay Row",
//            "Pull-ups", "Rack Pull", "Rack Pulls", "Renegade Rows", "Reverse Grip Lat Pulldown",
//            "Scapular Pull Ups", "Seated Cable Row", "Shrugs", "Straight Arm Lat Pulldown",
//            "Straight Arm Pulldown", "T-Bar Row", "V-Bar Seated Row", "Wide Grip Pull-ups"
//        ],
//        Constants.MuscleName.legs.rawValue: [
//            "Assisted Pistol Squats", "Belt Squat", "Bodyweight Sissy Squats", "Bodyweight Squat", "Box Jump",
//            "Box Squat (Barbell)", "Box Step Ups", "Bulgarian Split Squat", "Calf Press on Leg Press",
//            "Calf Raises", "Clamshell", "Curtsy Lunge", "Frog Pumps (Dumbbell)", "Front Squat",
//            "Glute Bridge", "Glute Ham Raise", "Goblet Squat", "Hack Squat", "Hip Abduction (Machine)",
//            "Hip Adduction (Machine)", "Hip Thrusts", "Lateral Squat", "Leg Curls", "Leg Extensions",
//            "Leg Press", "Lunges", "Lying Leg Curl", "Overhead Squat", "Partial Glute Bridge",
//            "Pistol Squat", "Quadruped Hip Extension", "Reverse Hyperextension", "Romanian Deadlift",
//            "Seated Calf Raise", "Seated Leg Curl", "Single Leg Box Squat", "Single Leg Hip Thrust",
//            "Single Leg Press", "Single Leg RDL", "Sissy Squat", "Smith Machine Squat", "Split Squat",
//            "Squat", "Standing Calf Raise", "Standing Leg Curls", "Step-ups", "Stiff Leg Deadlift",
//            "Sumo Squat", "Swiss Ball Leg Curls", "Trap Bar Deadlift", "Walking Lunges", "Wall Sits",
//            "Zercher Squat"
//        ],
//        Constants.MuscleName.shoulders.rawValue: [
//            "Arnold Press", "Band Lateral Raise", "Cable Lateral Raises", "Clean and Press",
//            "Dumbbell Shoulder Press", "Face Pulls", "Front Plate Raise", "Front Raises",
//            "Handstand Push-ups", "Kettlebell Halo", "Landmine Press", "Lateral Raises",
//            "Overhead Plate Raise", "Overhead Press", "Pike Push-ups", "Push Press", "Rear Delt Fly",
//            "Rear Delt Flyes", "Reverse Flyes", "Reverse Pec Deck", "Ring Face-Pulls",
//            "Seated Military Press", "Shoulder Press Machine", "Shoulder Taps", "Single Arm Landmine Press",
//            "Smith Machine Press", "Turkish Get-up", "Underhand Front Delt Raise", "Upright Row", "Z Press"
//        ],
//        Constants.MuscleName.arms.rawValue: [
//            "21s Bicep Curl", "Barbell Curl", "Behind the Back Wrist Curl", "Bench Dips", "Bicep Curls",
//            "Cable Curls", "Cable Kickbacks", "Cable Overhead Triceps Ext", "Close Grip Bench Press",
//            "Concentration Curl", "Concentration Curls", "Cross Body Hammer Curl", "Drag Curl",
//            "Dumbbell Kickbacks", "EZ Bar Curl", "French Press", "Hammer Curls", "Incline Dumbbell Curl",
//            "Machine Bicep Curl", "Machine Dips", "Machine Preacher Curl", "Overhead Triceps Extension",
//            "Pinwheel Curl", "Preacher Curl", "Reverse Curl", "Rope Hammer Curls", "Seated Dumbbell Curl",
//            "Seated Palms Up Wrist Curl", "Single Arm Triceps Ext", "Skull Crushers", "Spider Curl",
//            "Spider Curls", "Straight Bar Triceps Pushdown", "Tate Press (Dumbbell)", "Tricep Press Machine",
//            "Triceps Dips", "Triceps Extension", "Triceps Pushdown", "Triceps Rope Pushdown",
//            "Wrist Roller", "Zottman Curl", "Zottman Curls"
//        ],
//        Constants.MuscleName.core.rawValue: [
//            "Ab Machine", "Ab Scissors", "Ab Wheel", "Ab Wheel Rollout", "Bicycle Crunches",
//            "Bird Dog", "Boat Holds", "Bosu Jackknife", "Cable Crunches", "Crunches",
//            "Dead Bug", "Decline Crunch", "Dragon Flag", "Dragonfly", "Dumbbell Side Bends",
//            "Flutter Kicks", "Hanging Knee Raises", "Knee Raise Parallel Bars", "L-Sit Hold",
//            "L-sit", "Landmine 180", "Leg Raises", "Pallof Press", "Plank", "Reverse Crunches",
//            "Russian Twist", "Russian Twists", "Side Plank", "Sit-ups", "Spiderman", "Toes to Bar",
//            "V-Ups", "Weighted Crunches", "Weighted Decline Crunch"
//        ],
//        Constants.MuscleName.cardio.rawValue: [
//            "Air Bike", "Ball Slams", "Battle Ropes", "Box Jumps", "Burpee", "Burpees",
//            "Clean and Jerk", "Cycling", "Downward Dog", "Elliptical", "Farmer's Walk", "HIIT",
//            "High Knees", "Jump Rope", "Jump Squat", "Jumping Jack", "Jumping Jacks", "Jumping Lunge",
//            "Kettlebell Swings", "Kettlebell Turkish Get Up", "Lying Neck Curls", "Lying Neck Extension",
//            "Mountain Climbers", "Rowing", "Rowing Machine", "Running", "Sled Push", "Snatch",
//            "Split Jerk", "Stair Climber", "Stretching", "Swimming", "Thruster", "Treadmill",
//            "Treadmill Sprints", "Wall Ball"
//        ]
//    ]
//}

// ✅ FIX: Added comprehensive default workout templates
extension Workout {
    static var examples: [Workout] {
        [
            Workout(title: "Push Day", date: Date(), icon: "img_chest", exercises: [
                Exercise(name: "Bench Press", muscleGroup: "Chest", sets: 4, reps: 8, weight: 60),
                Exercise(name: "Overhead Press", muscleGroup: "Shoulders", sets: 3, reps: 10, weight: 40),
                Exercise(name: "Triceps Extension", muscleGroup: "Arms", sets: 3, reps: 12, weight: 20)
            ]),
            Workout(title: "Pull Day", date: Date(), icon: "img_back", exercises: [
                Exercise(name: "Pull-ups", muscleGroup: "Back", sets: 4, reps: 8, weight: 0),
                Exercise(name: "Barbell Rows", muscleGroup: "Back", sets: 3, reps: 10, weight: 50),
                Exercise(name: "Barbell Curl", muscleGroup: "Arms", sets: 3, reps: 12, weight: 25)
            ]),
            Workout(title: "Legs Day", date: Date(), icon: "img_legs", exercises: [
                Exercise(name: "Squat", muscleGroup: "Legs", sets: 4, reps: 8, weight: 80),
                Exercise(name: "Leg Press", muscleGroup: "Legs", sets: 3, reps: 12, weight: 120),
                Exercise(name: "Calf Raises", muscleGroup: "Legs", sets: 4, reps: 15, weight: 60)
            ]),
            Workout(title: "Full Body", date: Date(), icon: "img_default", exercises: [
                Exercise(name: "Squat", muscleGroup: "Legs", sets: 3, reps: 10, weight: 60),
                Exercise(name: "Bench Press", muscleGroup: "Chest", sets: 3, reps: 10, weight: 50),
                Exercise(name: "Deadlift", muscleGroup: "Back", sets: 3, reps: 5, weight: 80)
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
extension SetType {
    // Letter or number representation for the UI
    func shortIndicator(index: Int) -> String {
        switch self {
        case .normal: return "\(index)"
        case .warmup: return "W"
        case .failure: return "F"
        }
    }
    
    var title: LocalizedStringKey {
        switch self {
        case .normal: return "Normal Set"
        case .warmup: return "Warm Up Set"
        case .failure: return "Failure Set"
        }
    }
    
    var description: LocalizedStringKey {
        switch self {
        case .normal: return "Standard working set used for tracking volume and progression."
        case .warmup: return "Lighter weight to prepare muscles. Usually excluded from total volume."
        case .failure: return "A set pushed to absolute muscular failure. High fatigue impact."
        }
    }
    
    // Updated colors to match Apple's semantic palette
    var displayColor: Color {
        switch self {
        case .normal: return .primary
        case .warmup: return .orange
        case .failure: return .red
        }
    }
}
