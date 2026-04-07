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
    var generatedExercises: [ExerciseDTO] = [] // Теперь DTO!
    
    var path = NavigationPath()
    let availableMuscles = ["Chest", "Back", "Legs", "Shoulders", "Arms", "Core", "Cardio"]
    
    func toggleMuscle(_ muscle: String) {
        if targetMuscles.contains(muscle) { targetMuscles.remove(muscle) } else { targetMuscles.insert(muscle) }
        UISelectionFeedbackGenerator().selectionChanged()
    }
    
    // Передаем кэш из Dashboard
    func generateWorkout(historyCache: [String: Exercise]) async {
        isGenerating = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        // Превращаем историю в простой словарь для Actor'а
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
        
        try? await Task.sleep(for: .seconds(0.8)) // Короткая пауза для анимации
        
        self.generatedExercises = exercises
        self.isGenerating = false
        self.path.append("ResultView")
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    
    func applyQuickPreset(name: String, muscles: [String], duration: Double, equipment: WorkoutEquipment, historyCache: [String: Exercise]) {
        self.targetMuscles = Set(muscles)
        self.durationMinutes = duration
        self.equipment = equipment
        Task { await generateWorkout(historyCache: historyCache) }
    }
}
