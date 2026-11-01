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
            UserGoal.self
        ])

        let diskConfig = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )
        do {
            return try ModelContainer(for: schema, configurations: [diskConfig])
        } catch {
            // Release-safe fallback: never crash the Watch app if the store fails to open.
            let memoryConfig = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )
            do {
                return try ModelContainer(for: schema, configurations: [memoryConfig])
            } catch {
                preconditionFailure("Watch ModelContainer could not be created: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            WatchWorkoutHubView()
                .environment(workoutManager)
                .modelContainer(sharedModelContainer)
                .task {
                    #if DEBUG
                    ScreenshotSeeder.seedIfNeeded(sharedModelContainer.mainContext)
                    #endif
                    await ExerciseDatabaseService.shared.loadDatabase()
                }
        }
    }
}
