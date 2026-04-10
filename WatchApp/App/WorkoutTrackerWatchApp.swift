internal import SwiftUI
import SwiftData

@main
struct WorkoutTrackerWatch_Watch_AppApp: App {
    @State private var workoutManager = WatchWorkoutManager()
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Workout.self, WorkoutPreset.self, ExerciseNote.self, UserStats.self,
            ExerciseStat.self, MuscleStat.self, WeightEntry.self, MuscleColorPreference.self,
            AIChatSession.self, BodyMeasurement.self, ExerciseDictionaryItem.self,
            UserGoal.self // ✅ ДОБАВЛЕНА НЕДОСТАЮЩАЯ МОДЕЛЬ
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )
        return try! ModelContainer(for: schema, configurations: [modelConfiguration])
    }()
    
    var body: some Scene {
        WindowGroup {
            WatchWorkoutHubView()
                .environment(workoutManager)
                .modelContainer(sharedModelContainer)
                .task {
                    // ✅ ЗАГРУЖАЕМ БАЗУ УПРАЖНЕНИЙ ПРИ СТАРТЕ
                    await ExerciseDatabaseService.shared.loadDatabase()
                }
        }
    }
}
