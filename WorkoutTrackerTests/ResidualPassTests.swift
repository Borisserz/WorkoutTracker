import XCTest
import SwiftData
@testable import WorkoutTracker

final class ResidualPassTests: XCTestCase {

    func testCNSCalculatorReturnsUnknownWhenHRVAndRHRMissing() {
        let score = CNSCalculator.calculate(
            sleepHours: 8,
            hrv: nil,
            baselineHRV: nil,
            rhr: nil,
            baselineRHR: nil,
            waterCups: 8
        )
        XCTAssertLessThan(score, 0, "Missing vitals must not invent a positive readiness score")
    }

    func testCNSCalculatorDoesNotInventMissingComponentPoints() {
        let withBoth = CNSCalculator.calculate(
            sleepHours: 8, hrv: 60, baselineHRV: 40, rhr: 50, baselineRHR: 60, waterCups: 8
        )
        let missingHRV = CNSCalculator.calculate(
            sleepHours: 8, hrv: nil, baselineHRV: 40, rhr: 50, baselineRHR: 60, waterCups: 8
        )
        XCTAssertGreaterThanOrEqual(withBoth, 0)
        XCTAssertGreaterThanOrEqual(missingHRV, 0)
        XCTAssertLessThan(missingHRV, withBoth, "Nil HRV must score 0 for that component, not invent points")
    }

    @MainActor
    func testWidgetDataDecoderDoesNotInventMusclesOrTip() throws {
        let json = """
        {"streak":2,"weeklyTarget":3,"weeklyStats":[],"totalVolumeTons":1.5}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(WidgetData.self, from: json)
        XCTAssertEqual(decoded.streak, 2)
        XCTAssertTrue(decoded.recoveredMuscles.isEmpty)
        XCTAssertTrue(decoded.aiTip.isEmpty)
        XCTAssertEqual(decoded.totalVolumeTons, 1.5, accuracy: 0.001)
    }

    func testBodyAnalysisTreatsUnknownCNSAsNotMeasured() {
        let report = BodyAnalysisEngine.generateReport(
            cnsScore: -1,
            recoveryDict: ["chest": 90, "upper-back": 90, "quadriceps": 90, "hamstring": 90, "lower-back": 90, "triceps": 90, "biceps": 90, "deltoids": 90, "abs": 90, "calves": 90, "gluteal": 90],
            recentWorkouts: []
        )
        XCTAssertFalse(report.cnsStatusTitle.localizedCaseInsensitiveContains("Optimal"))
        XCTAssertTrue(
            report.cnsStatusTitle.localizedCaseInsensitiveContains("not measured")
            || report.cnsStatusTitle.localizedCaseInsensitiveContains("Baseline")
        )
    }

    func testAppearanceModeStillLockedDark() {
        XCTAssertEqual(AppearanceMode.resolved("system"), "dark")
        XCTAssertEqual(AppearanceMode.lockedRawValue, "dark")
    }

    func testBodyAnalysisDoesNotInventPrimeMusclesWithoutRecoveryMap() {
        let report = BodyAnalysisEngine.generateReport(
            cnsScore: -1,
            recoveryDict: [:],
            recentWorkouts: []
        )
        XCTAssertTrue(report.primeMuscles.isEmpty)
        XCTAssertTrue(report.recoveringMuscles.isEmpty)
        XCTAssertTrue(report.cnsStatusTitle.localizedCaseInsensitiveContains("not measured"))
        // Fresh athlete with no history may show baseline muscular readiness 100,
        // but must not invent prime-muscle rows without a recovery map.
        XCTAssertEqual(report.overallReadiness, 100)
    }

    func testWidgetLoadFallbackDoesNotInventTip() {
        let suite = UserDefaults(suiteName: WidgetDataManager.suiteName)
        suite?.removeObject(forKey: WidgetDataManager.key)
        let loaded = WidgetDataManager.load()
        XCTAssertTrue(loaded.aiTip.isEmpty)
        XCTAssertTrue(loaded.recoveredMuscles.isEmpty)
        XCTAssertEqual(loaded.streak, 0)
    }

    @MainActor
    func testWidgetSavePreservesEmptyRecoveryWithoutInventingMuscles() {
        let suite = UserDefaults(suiteName: WidgetDataManager.suiteName)
        suite?.removeObject(forKey: WidgetDataManager.key)
        WidgetDataManager.save(
            streak: 3,
            weeklyStats: [],
            recoveredMuscles: [],
            aiTip: "",
            totalVolumeTons: 0
        )
        let loaded = WidgetDataManager.load()
        XCTAssertTrue(loaded.recoveredMuscles.isEmpty)
        XCTAssertTrue(loaded.aiTip.isEmpty)
        XCTAssertEqual(loaded.streak, 3)
    }

    func testExportBundleIncludesExtendedKeys() throws {
        let bundle = DataManager.ExportBundle(
            exportedAt: Date(),
            appVersion: "test",
            workouts: [],
            weightEntries: [],
            goals: [],
            bodyMeasurements: [],
            customPresets: [],
            exerciseNotes: [],
            aiChatSessions: [],
            muscleColors: ["chest": "#34C759"]
        )
        let data = try JSONEncoder().encode(bundle)
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertTrue(json.contains("customPresets"))
        XCTAssertTrue(json.contains("exerciseNotes"))
        XCTAssertTrue(json.contains("aiChatSessions"))
        XCTAssertTrue(json.contains("muscleColors"))
        XCTAssertTrue(json.contains("chest"))
    }

    /// Concurrent starts must serialize: only one active session survives the race at `hasActiveWorkout` await.
    @MainActor
    func testConcurrentCreateWorkoutAllowsOnlyOneActiveSession() async throws {
        let schema = Schema([
            Workout.self, WorkoutPreset.self, ExerciseNote.self, UserStats.self,
            ExerciseStat.self, MuscleStat.self, WeightEntry.self, MuscleColorPreference.self,
            AIChatSession.self, BodyMeasurement.self, ExerciseDictionaryItem.self, UserGoal.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let di = DIContainer(modelContainer: container)

        async let first = di.workoutService.createWorkout(title: "Race A", presetID: nil, isAIGenerated: false)
        async let second = di.workoutService.createWorkout(title: "Race B", presetID: nil, isAIGenerated: false)
        let results = await [first, second]

        let successes = results.compactMap { $0 }
        XCTAssertEqual(successes.count, 1, "Exactly one create must win the start race")

        let activeIDs = try await di.workoutStore.findActiveWorkoutsAndCleanup()
        XCTAssertEqual(activeIDs.count, 1, "Store must contain a single active workout")
    }

    @MainActor
    func testDeleteUnfinishedWorkoutDoesNotDecrementUserStats() async throws {
        let (di, context) = try makeInMemoryDI()
        let stats = UserStats(totalWorkouts: 5, totalVolume: 1000, totalDistance: 0)
        context.insert(stats)
        try context.save()

        let pid = try await di.workoutStore.createWorkout(title: "Ghost", fromPresetID: nil, isAIGenerated: false)
        let workout = try XCTUnwrap(context.model(for: pid) as? Workout)
        XCTAssertNil(workout.endTime)

        try await di.workoutStore.deleteWorkout(id: workout.id)

        let refreshed = try XCTUnwrap((try context.fetch(FetchDescriptor<UserStats>())).first)
        XCTAssertEqual(refreshed.totalWorkouts, 5, "Canceling an unfinished session must not under-count lifetime stats")
        XCTAssertEqual(refreshed.totalVolume, 1000, accuracy: 0.001)
    }

    @MainActor
    func testDeleteProcessedWorkoutDecrementsUserStats() async throws {
        let (di, context) = try makeInMemoryDI()
        let stats = UserStats(totalWorkouts: 2, totalVolume: 0, totalDistance: 0)
        context.insert(stats)
        try context.save()

        let pid = try await di.workoutStore.createWorkout(title: "Done", fromPresetID: nil, isAIGenerated: false)
        let workout = try XCTUnwrap(context.model(for: pid) as? Workout)
        let exercise = Exercise(name: "Squat", muscleGroup: "Legs", type: .strength)
        context.insert(exercise)
        let set = WorkoutSet(index: 0, weight: 100, reps: 5, isCompleted: true)
        context.insert(set)
        exercise.addSafeSet(set)
        workout.exercises = [exercise]
        try context.save()

        try await di.workoutStore.processCompletedWorkout(workoutID: pid)
        let afterProcess = try XCTUnwrap((try context.fetch(FetchDescriptor<UserStats>())).first)
        XCTAssertEqual(afterProcess.totalWorkouts, 3)

        try await di.workoutStore.deleteWorkout(id: workout.id)
        let afterDelete = try XCTUnwrap((try context.fetch(FetchDescriptor<UserStats>())).first)
        XCTAssertEqual(afterDelete.totalWorkouts, 2, "Deleting a processed workout should reverse its stats contribution")
    }

    @MainActor
    func testCreateWorkoutBlockedWhileFinishTransitionPending() async throws {
        let (di, _) = try makeInMemoryDI()
        di.workoutService.beginFinishTransition()
        defer { di.workoutService.endFinishTransition() }

        let id = await di.workoutService.createWorkout(title: "During undo window", presetID: nil, isAIGenerated: false)
        XCTAssertNil(id, "Finish undo window must block a second active session")
    }

    func testProactiveProposalReturnsNilWhenRecoveryEmpty() {
        let proposal = WorkoutGenerationService.generateProactiveProposal(
            recoveryStatus: [],
            catalog: ["Legs": ["Squat"]]
        )
        XCTAssertNil(proposal, "Empty recovery must not invent 100% and emit Heavy Legs")
    }

    func testLegendaryFallbackXEROIsBodyweightOnly() throws {
        let xero = LegendaryFallbackCatalog.routines.first { $0.title.contains("XERO") }
        let routine = try XCTUnwrap(xero)
        XCTAssertTrue(
            routine.shortVibe.localizedCaseInsensitiveContains("no equipment")
            || routine.loreDescription.localizedCaseInsensitiveContains("bodyweight")
        )
        for exercise in routine.exercises {
            let name = exercise.name.lowercased()
            XCTAssertFalse(name.contains("barbell"), "XERO offline fallback must not list barbell lifts")
            XCTAssertNil(exercise.recommendedWeightKg, "XERO offline fallback must not invent loaded weights")
        }
    }

    @MainActor
    private func makeInMemoryDI() throws -> (DIContainer, ModelContext) {
        let schema = Schema([
            Workout.self, WorkoutPreset.self, ExerciseNote.self, UserStats.self,
            ExerciseStat.self, MuscleStat.self, WeightEntry.self, MuscleColorPreference.self,
            AIChatSession.self, BodyMeasurement.self, ExerciseDictionaryItem.self, UserGoal.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return (DIContainer(modelContainer: container), ModelContext(container))
    }
}
