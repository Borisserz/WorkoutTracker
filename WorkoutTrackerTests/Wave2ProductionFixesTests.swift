import Foundation
import SwiftData
import Testing
@testable import WorkoutTracker

@Suite("Wave 2 Production Fixes Tests")
struct Wave2ProductionFixesTests {

    @Test("StatsWidget currentWeekCount reads only the current week, not a 6-week sum")
    func testWidgetCurrentWeekCount() {
        let points = [
            WidgetData.WeeklyPoint(label: "10/6", count: 3),
            WidgetData.WeeklyPoint(label: "10/13", count: 4),
            WidgetData.WeeklyPoint(label: "10/20", count: 2),
            WidgetData.WeeklyPoint(label: "10/27", count: 5),
            WidgetData.WeeklyPoint(label: "11/3", count: 3),
            WidgetData.WeeklyPoint(label: "11/10", count: 2)
        ]
        #expect(WidgetData.currentWeekCount(from: points) == 2)
        #expect(WidgetData.currentWeekCount(from: []) == 0)
    }

    @Test("ProgressManager.resetProgress clears level and XP in memory and UserDefaults")
    @MainActor
    func testProgressManagerResetProgress() {
        let pm = ProgressManager()
        defer { pm.resetProgress() }

        let w = Workout(title: "Test", date: Date())
        w.totalStrengthVolume = 5000
        _ = pm.addXP(for: w, prCount: 2)
        #expect(pm.totalXP > 0)

        pm.resetProgress()
        #expect(pm.level == 1)
        #expect(pm.totalXP == 0)
        #expect(UserDefaults.standard.integer(forKey: "userTotalXP") == 0)
        #expect(UserDefaults.standard.integer(forKey: "userLevel") == 1)
    }

    @Test("CSV export escapes fields once without double wrapping quotes")
    @MainActor
    func testCSVExportSingleQuotesOnlyOnce() throws {
        let workout = Workout(title: "Leg Day, Heavy", date: Date())
        workout.endTime = workout.date.addingTimeInterval(1800)
        workout.durationSeconds = 1800
        let ex = Exercise(name: "Squat \"Deep\"", muscleGroup: "Legs, Quads", type: .strength, sets: 1, reps: 5, weight: 100)
        workout.exercises.append(ex)

        let url = DataManager.shared.exportAllDataToCSV(
            workouts: [workout],
            weightEntries: [],
            goals: [],
            measurements: []
        )
        let exportedURL = try #require(url)
        let csv = try String(contentsOf: exportedURL, encoding: .utf8)

        #expect(csv.contains(",\"Leg Day, Heavy\","))
        #expect(!csv.contains("\"\"Leg Day, Heavy\"\""))
        #expect(csv.contains("\"Squat \"\"Deep\"\"\""))
        #expect(csv.contains(",\"Legs, Quads\","))
    }

    @Test("AnalyticsService.fetchStatsData excludes unfinished active workouts")
    @MainActor
    func testFetchStatsDataExcludesActiveWorkouts() async throws {
        let schema = Schema([
            Workout.self, WorkoutPreset.self, ExerciseNote.self, UserStats.self,
            ExerciseStat.self, MuscleStat.self, WeightEntry.self, MuscleColorPreference.self,
            AIChatSession.self, BodyMeasurement.self, ExerciseDictionaryItem.self, UserGoal.self
        ])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let context = ModelContext(container)

        let now = Date()
        let finished = Workout(title: "Done", date: now.addingTimeInterval(-3600))
        finished.endTime = now
        finished.durationSeconds = 1800
        finished.totalStrengthVolume = 2000
        context.insert(finished)

        let active = Workout(title: "Still Active", date: now.addingTimeInterval(-600))
        active.endTime = nil
        active.totalStrengthVolume = 9000
        context.insert(active)
        try context.save()

        let store = WorkoutStore(modelContainer: container)
        let analytics = AnalyticsService(workoutStore: store, modelContainer: container)
        let currentInterval = DateInterval(start: now.addingTimeInterval(-86400), end: now.addingTimeInterval(60))
        let prevInterval = DateInterval(start: now.addingTimeInterval(-172800), end: now.addingTimeInterval(-86400))

        let stats = await analytics.fetchStatsData(
            period: .week,
            metric: .volume,
            currentInterval: currentInterval,
            previousInterval: prevInterval,
            prCache: [:]
        )
        #expect(stats.currentStats.workoutCount == 1)
        #expect(stats.currentStats.totalVolume == 2000)
    }

    @Test("Watch startWorkout deduplicates same UUID and saveToHistory heals missed start")
    @MainActor
    func testWatchStartDedupAndSaveToHistoryFallback() async throws {
        let schema = Schema([
            Workout.self, WorkoutPreset.self, ExerciseNote.self, UserStats.self,
            ExerciseStat.self, MuscleStat.self, WeightEntry.self, MuscleColorPreference.self,
            AIChatSession.self, BodyMeasurement.self, ExerciseDictionaryItem.self, UserGoal.self
        ])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let di = DIContainer(modelContainer: container)
        let appState = di.appState
        let service = di.workoutService
        _ = service // keep alive

        let wid = UUID()
        let startPayload = LiveSyncPayload(action: .startWorkout, workoutID: wid.uuidString, workoutTitle: "Watch Push", exercises: [])
        NotificationCenter.default.post(name: NSNotification.Name("LiveWorkoutSyncEvent"), object: nil, userInfo: ["payload": startPayload])
        for _ in 0..<40 {
            let ctx = ModelContext(container)
            if ((try? ctx.fetch(FetchDescriptor<Workout>(predicate: #Predicate { $0.id == wid })).first) != nil) { break }
            try await Task.sleep(for: .milliseconds(50))
        }
        NotificationCenter.default.post(name: NSNotification.Name("LiveWorkoutSyncEvent"), object: nil, userInfo: ["payload": startPayload])
        try await Task.sleep(for: .milliseconds(300))

        // Duplicate start with same UUID must never surface a false "Workout in progress" error alert.
        #expect(appState.currentError == nil)

        // Also test saveToHistory when no prior startWorkout row exists for a new UUID.
        let orphanID = UUID()
        let savePayload = LiveSyncPayload(
            action: .saveToHistory,
            workoutID: orphanID.uuidString,
            workoutTitle: "Offline Watch Run",
            exercises: [
                ExerciseDTO(
                    name: "Bench Press",
                    muscleGroup: "Chest",
                    type: .strength,
                    category: .press,
                    effort: 8,
                    isCompleted: true,
                    setsList: [WorkoutSetDTO(index: 1, weight: 80, reps: 5, distance: nil, time: nil, isCompleted: true, type: .normal)],
                    subExercises: [],
                    sets: 1,
                    reps: 5,
                    recommendedWeightKg: 80
                )
            ],
            durationSeconds: 1450,
            healthKitSavedOnWatch: true
        )
        NotificationCenter.default.post(name: NSNotification.Name("LiveWorkoutSyncEvent"), object: nil, userInfo: ["payload": savePayload])
        var saved: Workout?
        for _ in 0..<60 {
            let checkContext = ModelContext(container)
            if let found = try checkContext.fetch(FetchDescriptor<Workout>(predicate: #Predicate { $0.id == orphanID })).first,
               found.endTime != nil {
                saved = found
                break
            }
            try await Task.sleep(for: .milliseconds(50))
        }

        let unwrappedSaved = try #require(saved)
        #expect(unwrappedSaved.endTime != nil)
        #expect(unwrappedSaved.durationSeconds == 1450)
        #expect(unwrappedSaved.exercises.count == 1)
    }
}
