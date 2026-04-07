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

// Структура истории для передачи в actor
public struct ExerciseHistoryContext: Sendable {
    let weight: Double
    let reps: Int
}

public struct SmartGeneratorConfig: Sendable {
    let targetMuscles: Set<String>
    let durationMinutes: Double
    let difficulty: WorkoutDifficulty
    let equipment: WorkoutEquipment
    let history: [String: ExerciseHistoryContext] // <--- Передаем историю
}

/// Чистый локальный генератор тренировок
actor LocalWorkoutGeneratorService {
    
    static let shared = LocalWorkoutGeneratorService()
    private init() {}
    
    func generateWorkout(config: SmartGeneratorConfig) -> [ExerciseDTO] {
        var generatedExercises: [ExerciseDTO] = []
        
        // В среднем 1 силовое упражнение = 5 минут. Кардио = выделенное время.
        let targetExerciseCount = max(2, min(Int(config.durationMinutes / 5.0), 10))
        let musclesToTrain = config.targetMuscles.isEmpty ? ["Chest", "Back", "Legs", "Shoulders", "Arms", "Core"] : Array(config.targetMuscles)
        let exercisesPerMuscle = max(1, targetExerciseCount / musclesToTrain.count)
        
        var remainingExercises = targetExerciseCount
        
        for muscle in musclesToTrain.shuffled() {
            guard remainingExercises > 0 else { break }
            let countToPick = min(exercisesPerMuscle, remainingExercises)
            
            // Получаем список упражнений и сортируем умно: сначала те, что есть в истории (70% шанс), затем новые (30% шанс)
            let pool = filterCatalog(for: muscle, equipment: config.equipment)
            let sortedPool = pool.sorted { ex1, ex2 in
                let hasHistory1 = config.history[ex1] != nil
                let hasHistory2 = config.history[ex2] != nil
                if hasHistory1 && !hasHistory2 { return Double.random(in: 0...1) > 0.3 } // 70% шанс, что знакомое упражнение будет выше
                if !hasHistory1 && hasHistory2 { return Double.random(in: 0...1) < 0.3 }
                return Bool.random()
            }
            
            let selectedNames = Array(sortedPool.prefix(countToPick))
            
            for name in selectedNames {
                let exerciseType: ExerciseType = (muscle == "Cardio" || name == "Plank" || name == "Running") ? (muscle == "Cardio" ? .cardio : .duration) : .strength
                
                // Вытягиваем историю, если есть
                let historyData = config.history[name]
                
                // 1. Формируем сеты
                var setsList: [WorkoutSetDTO] = []
                
                if exerciseType == .strength {
                    let setsCount = config.difficulty.setsPerExercise
                    let reps = historyData?.reps ?? (config.difficulty == .advanced ? 6 : 10)
                    let weight = historyData?.weight ?? estimateBaseWeight(for: name, difficulty: config.difficulty, equipment: config.equipment)
                    
                    for i in 1...setsCount {
                        setsList.append(WorkoutSetDTO(index: i, weight: weight > 0 ? weight : nil, reps: reps, distance: nil, time: nil, isCompleted: false, type: .normal))
                    }
                } else if exerciseType == .cardio || exerciseType == .duration {
                    // Кардио или планка = 1 подход на время
                    let durationSeconds = Int((config.durationMinutes / Double(targetExerciseCount)) * 60)
                    setsList.append(WorkoutSetDTO(index: 1, weight: nil, reps: nil, distance: nil, time: durationSeconds, isCompleted: false, type: .normal))
                }
                
                // 2. Создаем DTO
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
    
    private func filterCatalog(for muscle: String, equipment: WorkoutEquipment) -> [String] {
        let allExercises = Exercise.catalog[muscle] ?? []
        switch equipment {
        case .fullGym: return allExercises
        case .dumbbellsOnly: return allExercises.filter { !$0.lowercased().contains("barbell") && !$0.lowercased().contains("machine") && !$0.lowercased().contains("cable") }
        case .bodyweight: return allExercises.filter { ["push up", "pull-up", "plank", "crunch", "squat", "lunges", "running"].contains(where: $0.lowercased().contains) }
        }
    }
    
    private func estimateBaseWeight(for exercise: String, difficulty: WorkoutDifficulty, equipment: WorkoutEquipment) -> Double {
        if equipment == .bodyweight { return 0.0 }
        let baseWeight = 20.0
        let multiplier: Double = difficulty == .advanced ? 2.5 : (difficulty == .intermediate ? 1.5 : 1.0)
        let isHeavyCompound = exercise.lowercased().contains("squat") || exercise.lowercased().contains("deadlift") || exercise.lowercased().contains("bench")
        return isHeavyCompound ? baseWeight * multiplier * 1.5 : baseWeight * multiplier * 0.6
    }
}
