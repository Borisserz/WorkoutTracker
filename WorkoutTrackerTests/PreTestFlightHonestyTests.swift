import XCTest
@testable import WorkoutTracker

final class PreTestFlightHonestyTests: XCTestCase {

    func testMissingBodyWeightDoesNotInventSeventyFiveKilograms() {
        let workout = Workout()
        workout.durationSeconds = 3600
        let exercise = Exercise(type: .strength, setsList: [
            WorkoutSet(index: 1, isCompleted: true),
            WorkoutSet(index: 2, isCompleted: true),
            WorkoutSet(index: 3, isCompleted: true)
        ])
        workout.exercises = [exercise]

        let unset = CalorieCalculator.calculate(for: workout, userWeight: 0)
        let known = CalorieCalculator.calculate(for: workout, userWeight: 75)
        XCTAssertEqual(unset, 0, "Unset body weight must not burn calories as a 75 kg athlete")
        XCTAssertGreaterThan(known, unset)
    }

    func testPartialRecoveryMapDoesNotClaimTheOtherChainIsReady() {
        let report = BodyAnalysisEngine.generateReport(
            cnsScore: 80,
            recoveryDict: ["chest": 40],
            recentWorkouts: [Workout(title: "Chest", date: Date().addingTimeInterval(-3600))]
        )
        let blob = [
            report.executiveAssessment,
            report.nextWorkoutAdvice.recentStrainSummary,
            report.nextWorkoutAdvice.physiologicalRationale,
            report.recommendedRestrictions
        ].joined(separator: " ")
        XCTAssertFalse(blob.localizedCaseInsensitiveContains("fully restored"))
        XCTAssertFalse(blob.localizedCaseInsensitiveContains("fully ready"))
        XCTAssertFalse(blob.localizedCaseInsensitiveContains("fully replenished"))
        XCTAssertFalse(blob.contains("-1"))
    }

    func testMeasuredEightyPercentIsNotCalledAboveEightyFive() {
        let keys = ["chest", "upper-back", "quadriceps", "hamstring", "lower-back", "triceps", "biceps"]
        let recovery = Dictionary(uniqueKeysWithValues: keys.map { ($0, 80) })
        let report = BodyAnalysisEngine.generateReport(
            cnsScore: 80,
            recoveryDict: recovery,
            recentWorkouts: [Workout(title: "Mixed", date: Date().addingTimeInterval(-3600))]
        )
        let blob = report.executiveAssessment + " " + report.nextWorkoutAdvice.recentStrainSummary
        XCTAssertFalse(blob.localizedCaseInsensitiveContains("above 85%"))
        XCTAssertFalse(blob.contains("-1"))
    }

    func testPullAdviceDoesNotQuoteUnmeasuredBackAsAPercent() {
        let report = BodyAnalysisEngine.generateReport(
            cnsScore: 82,
            recoveryDict: [
                "chest": 50, "triceps": 50,
                "quadriceps": 90, "hamstring": 90,
                "deltoids": 90, "abs": 90, "gluteal": 90, "calves": 90
            ],
            recentWorkouts: [Workout(title: "Push", date: Date().addingTimeInterval(-3600))]
        )
        let blob = report.nextWorkoutAdvice.physiologicalRationale + " " + report.executiveAssessment
        XCTAssertFalse(blob.contains("-1"))
        XCTAssertFalse(blob.localizedCaseInsensitiveContains("peak contractile"))
    }

    func testCardioMinutesStoreAsSeconds() {
        XCTAssertEqual(SetTimeCodec.storedSeconds(fromDisplay: 30, field: .minutes), 1800)
        XCTAssertEqual(SetTimeCodec.displayValue(fromStoredSeconds: 1800, field: .minutes), 30)
        XCTAssertEqual(SetTimeCodec.storedSeconds(fromDisplay: 45, field: .seconds), 45)
        XCTAssertEqual(SetTimeCodec.displayValue(fromStoredSeconds: 45, field: .seconds), 45)
    }

    func testRestButtonLabelMatchesTheDurationItStarts() {
        let hard = RestDurationPolicy.manualButtonSeconds(
            pendingTemplateRest: nil,
            pendingEffort: 9,
            pendingType: .strength,
            userDefaultRest: 0
        )
        XCTAssertEqual(hard, 180)

        let idle = RestDurationPolicy.manualButtonSeconds(
            pendingTemplateRest: nil,
            pendingEffort: nil,
            pendingType: nil,
            userDefaultRest: 0
        )
        XCTAssertEqual(idle, 60)

        let saved = RestDurationPolicy.manualButtonSeconds(
            pendingTemplateRest: nil,
            pendingEffort: nil,
            pendingType: nil,
            userDefaultRest: 75
        )
        XCTAssertEqual(saved, 75)
    }

    func testUnsetProfileMetricsStayBlankAndPoundsConvert() {
        let defaults = UserDefaults(suiteName: "PreTestFlightHonestyTests.metrics")!
        defaults.removePersistentDomain(forName: "PreTestFlightHonestyTests.metrics")
        XCTAssertNil(BodyMetricStore.weightKilograms(in: defaults))
        XCTAssertNil(BodyMetricStore.heightCentimeters(in: defaults))

        let blankWeight = ProfileMetricsFormatter.weight(storedKg: nil, unit: .pounds)
        XCTAssertEqual(blankWeight.value, "—")
        XCTAssertEqual(blankWeight.unit, "")

        let pounds = ProfileMetricsFormatter.weight(storedKg: 75, unit: .pounds)
        XCTAssertEqual(pounds.unit, "lbs")
        XCTAssertEqual(pounds.value, String(format: "%.1f", 75 * 2.20462))

        let inches = ProfileMetricsFormatter.height(storedCm: 180, unit: .inches)
        XCTAssertEqual(inches.unit, "in")
        XCTAssertEqual(inches.value, String(format: "%.0f", (180 / 2.54).rounded()))

        defaults.set(80.0, forKey: Constants.UserDefaultsKeys.userBodyWeight.rawValue)
        XCTAssertEqual(BodyMetricStore.weightKilograms(in: defaults), 80)
    }

    func testWatchHealthPayloadSkipsASecondPhoneSave() throws {
        let saved = LiveSyncPayload(
            action: .saveToHistory,
            workoutID: "w1",
            healthKitSavedOnWatch: true
        )
        let data = try JSONEncoder().encode(saved)
        let decoded = try JSONDecoder().decode(LiveSyncPayload.self, from: data)
        XCTAssertEqual(decoded.healthKitSavedOnWatch, true)

        let legacy = #"{"action":"saveToHistory","workoutID":"w1"}"#.data(using: .utf8)!
        let old = try JSONDecoder().decode(LiveSyncPayload.self, from: legacy)
        XCTAssertNotEqual(old.healthKitSavedOnWatch, true)
    }

    func testWeeklyReviewPromptUsesTheSelectedFocusAndRealProfile() {
        let request = WeeklyReviewPromptBuilder.userRequest(focus: "Muscle balance", statsBlock: "Chest 40%")
        XCTAssertTrue(request.contains("Muscle balance"))
        XCTAssertFalse(request.contains("(selectedFocus)"))

        let profile = WeeklyReviewPromptBuilder.profile(
            userName: "Boris",
            weightKg: 0,
            weightUnit: "lbs",
            tone: "motivational",
            workoutsThisWeek: 3,
            currentStreak: 4,
            language: "Russian"
        )
        XCTAssertEqual(profile.aiCoachTone, "motivational")
        XCTAssertEqual(profile.weightUnit, "lbs")
        XCTAssertEqual(profile.weightKg, 0)
        XCTAssertEqual(profile.experienceLevel, "Not specified")
        XCTAssertEqual(profile.workoutsThisWeek, 3)
        XCTAssertEqual(profile.currentStreak, 4)
        XCTAssertNotEqual(profile.experienceLevel, "Pro")
    }

    func testWarmupSetDoesNotCloseAStrengthGoal() {
        XCTAssertFalse(
            StrengthGoalMatcher.isMet(
                setType: .warmup,
                isCompleted: true,
                weight: 100,
                reps: 5,
                targetWeight: 100,
                targetReps: 5
            )
        )
        XCTAssertTrue(
            StrengthGoalMatcher.isMet(
                setType: .normal,
                isCompleted: true,
                weight: 100,
                reps: 5,
                targetWeight: 100,
                targetReps: 5
            )
        )
    }

    func testAnalyticsEventsOmitBodyLoadAndExerciseNames() {
        let logged = TrackingManager.Event.setLogged(exerciseName: "Squat", weight: 100, reps: 5, setType: "normal").parameters
        XCTAssertEqual(logged?["set_type"] as? String, "normal")
        XCTAssertNil(logged?["weight"])
        XCTAssertNil(logged?["reps"])
        XCTAssertNil(logged?["exercise_name"])

        let weighed = TrackingManager.Event.weightLogged(value: 75, unit: "kg", source: "profile").parameters
        XCTAssertNil(weighed?["value"])
        XCTAssertEqual(weighed?["unit"] as? String, "kg")
    }
}
