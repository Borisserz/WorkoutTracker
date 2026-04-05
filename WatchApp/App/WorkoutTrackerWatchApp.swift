// ============================================================
// FILE: WatchApp/WorkoutTrackerWatchApp.swift
// ============================================================
internal import SwiftUI
import SwiftData

@main
struct WorkoutTrackerWatch_Watch_AppApp: App {
    @State private var workoutManager = WatchWorkoutManager()
    
    // Инициализация SwiftData Container для синхронизации пресетов через CloudKit
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Workout.self, WorkoutPreset.self, ExerciseNote.self, UserStats.self,
            ExerciseStat.self, MuscleStat.self, WeightEntry.self, MuscleColorPreference.self,
            AIChatSession.self, BodyMeasurement.self, ExerciseDictionaryItem.self
        ])
        // ✅ ИСПРАВЛЕНИЕ: ставим .none вместо .automatic, так как нет аккаунта разраба
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
                .modelContainer(sharedModelContainer) // Передаем общий контейнер
        }
    }
}
