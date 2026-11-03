import Foundation
import SwiftData

public enum WorkoutDifficulty: String, CaseIterable, Sendable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"

    var setsPerExercise: Int {
        switch self { case .beginner: return 3; case .intermediate: return 4; case .advanced: return 5 }
    }
}

public enum WorkoutEquipment: String, CaseIterable, Sendable {
    case fullGym = "Full Gym"
    case dumbbellsOnly = "Dumbbells Only"
    case bodyweight = "Bodyweight"
}

public struct ExerciseHistoryContext: Sendable {
    let weight: Double
    let reps: Int
}

public struct SmartGeneratorConfig: Sendable {
    let targetMuscles: Set<String>
    let durationMinutes: Double
    let difficulty: WorkoutDifficulty
    let equipment: WorkoutEquipment
    let history: [String: ExerciseHistoryContext] 
}

actor LocalWorkoutGeneratorService {

    static let shared = LocalWorkoutGeneratorService()
    private init() {}

    func generateWorkout(config: SmartGeneratorConfig) async -> [ExerciseDTO] {
        var generatedExercises: [ExerciseDTO] = []

        let targetExerciseCount = max(2, min(Int(config.durationMinutes / 5.0), 10))
        let musclesToTrain = config.targetMuscles.isEmpty ? ["Chest", "Back", "Legs", "Shoulders", "Arms", "Core"] : Array(config.targetMuscles)
        let exercisesPerMuscle = max(1, targetExerciseCount / musclesToTrain.count)

        var remainingExercises = targetExerciseCount

        for muscle in musclesToTrain.shuffled() {
            guard remainingExercises > 0 else { break }
            let countToPick = min(exercisesPerMuscle, remainingExercises)

            let pool = await filterCatalog(for: muscle, equipment: config.equipment)

            let scoredPool = pool.map { ex -> (String, Double) in
                let hasHistory = config.history[ex] != nil
                let score = (hasHistory ? 10.0 : 0.0) + Double.random(in: 0...5.0)
                return (ex, score)
            }
            
            let selectedNames = scoredPool.sorted(by: { $0.1 > $1.1 })
                .prefix(countToPick)
                .map { $0.0 }

            for name in selectedNames {
                let exerciseType: ExerciseType = (muscle == "Cardio" || name == "Plank" || name == "Running") ? (muscle == "Cardio" ? .cardio : .duration) : .strength
                let historyData = config.history[name]
                var setsList: [WorkoutSetDTO] = []

                if exerciseType == .strength {
                    let setsCount = config.difficulty.setsPerExercise
                    let reps = historyData?.reps ?? (config.difficulty == .advanced ? 6 : 10)
                    let weight = historyData?.weight

                    for i in 1...setsCount {
                        setsList.append(WorkoutSetDTO(index: i, weight: (weight ?? 0) > 0 ? weight : nil, reps: reps, distance: nil, time: nil, isCompleted: false, type: .normal))
                    }
                } else if exerciseType == .cardio || exerciseType == .duration {
                    let durationSeconds = Int((config.durationMinutes / Double(targetExerciseCount)) * 60)
                    setsList.append(WorkoutSetDTO(index: 1, weight: nil, reps: nil, distance: nil, time: durationSeconds, isCompleted: false, type: .normal))
                }

                let newExDTO = ExerciseDTO(
                    name: name,
                    muscleGroup: muscle,
                    type: exerciseType,
                    category: ExerciseCategory.determine(from: name),
                    effort: config.difficulty == .advanced ? 8 : 6,
                    isCompleted: false,
                    setsList: setsList,
                    subExercises: []
                )
                generatedExercises.append(newExDTO)
                remainingExercises -= 1
            }
        }

        return generatedExercises
    }

    private func filterCatalog(for muscle: String, equipment: WorkoutEquipment) async -> [String] {

        let catalog = await ExerciseDatabaseService.shared.getCatalog()
        let allExercises = catalog[muscle] ?? []

        switch equipment {
        case .fullGym:
            return allExercises
        case .dumbbellsOnly:
            return allExercises.filter {
                let low = $0.lowercased()
                return !low.contains("barbell") && !low.contains("machine") && !low.contains("cable")
            }
        case .bodyweight:
            return allExercises.filter { name in
                let low = name.lowercased()
                    .replacingOccurrences(of: "-", with: " ")
                    .replacingOccurrences(of: "_", with: " ")
                let tokens = ["push up", "pushup", "pull up", "pullup", "chin up", "plank", "crunch", "sit up", "squat", "lunge", "running", "burpee", "dip", "mountain climber", "jumping jack"]
                let looksMachine = low.contains("machine") || low.contains("cable") || low.contains("barbell") || low.contains("smith")
                return !looksMachine && tokens.contains(where: low.contains)
            }
        }
    }

    }
