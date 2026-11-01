import Foundation
internal import SwiftUI
import Observation

@Observable
@MainActor
final class SmartGeneratorViewModel {

    var targetMuscles: Set<String> = []
    var durationMinutes: Double = 45.0
    var difficulty: WorkoutDifficulty = .intermediate
    var equipment: WorkoutEquipment = .fullGym

    var isGenerating: Bool = false
    var generatedExercises: [ExerciseDTO] = []
    var generationError: String? = nil

    var path = NavigationPath()
    let availableMuscles = ["Chest", "Back", "Legs", "Shoulders", "Arms", "Core", "Cardio"]

    func toggleMuscle(_ muscle: String) {
        if targetMuscles.contains(muscle) { targetMuscles.remove(muscle) } else { targetMuscles.insert(muscle) }
        HapticManager.shared.selection()
    }

    func generateWorkout(historyCache: [String: Exercise]) async {
        isGenerating = true
        generationError = nil
        HapticManager.shared.impact(.medium)
        TrackingManager.shared.track(.smartBuilderUsed(muscleGroupsSelected: Array(targetMuscles), goal: "custom"))

        var simpleHistory: [String: ExerciseHistoryContext] = [:]
        for (name, ex) in historyCache {
            let maxW = ex.setsList.compactMap { $0.weight }.max() ?? 0.0
            let reps = ex.firstSetReps > 0 ? ex.firstSetReps : 10
            simpleHistory[name] = ExerciseHistoryContext(weight: maxW, reps: reps)
        }

        let config = SmartGeneratorConfig(
            targetMuscles: targetMuscles,
            durationMinutes: durationMinutes,
            difficulty: difficulty,
            equipment: equipment,
            history: simpleHistory
        )

        let exercises = await LocalWorkoutGeneratorService.shared.generateWorkout(config: config)

        try? await Task.sleep(for: .seconds(0.8))

        self.generatedExercises = exercises
        self.isGenerating = false
        guard !exercises.isEmpty else {
            self.generationError = String(localized: "No exercises matched this equipment and muscle mix. Try Full Gym or different muscles.")
            HapticManager.shared.notification(.error)
            return
        }
        self.path.append("ResultView")
        HapticManager.shared.notification(.success)
    }

    func applyQuickPreset(name: String, muscles: [String], duration: Double, equipment: WorkoutEquipment, historyCache: [String: Exercise]) {
        self.targetMuscles = Set(muscles)
        self.durationMinutes = duration
        self.equipment = equipment
        Task { await generateWorkout(historyCache: historyCache) }
    }
}
