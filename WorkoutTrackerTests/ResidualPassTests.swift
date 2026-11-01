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
}
