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

    func testCNSAppStorageDefaultIsUnmeasuredNotInvented() {
        XCTAssertEqual(Constants.CNS.unmeasuredAppStorageDefault, -1)
        XCTAssertLessThan(Constants.CNS.unmeasuredAppStorageDefault, 0)
        XCTAssertNotEqual(Constants.CNS.unmeasuredAppStorageDefault, 85)
    }

    func testCNSStatusTreatsNegativeAsNotMeasured() {
        let status = CNSCalculator.getStatus(for: Constants.CNS.unmeasuredAppStorageDefault)
        XCTAssertFalse(status.text.localizedCaseInsensitiveContains("depleted"))
        XCTAssertFalse(status.text.localizedCaseInsensitiveContains("fatigue"))
        XCTAssertTrue(
            status.text.localizedCaseInsensitiveContains("not measured")
            || status.text.localizedCaseInsensitiveContains("unmeasured")
        )
    }

    func testCNSCoachGreetingDoesNotInventFatigueForUnmeasured() {
        let greeting = CNSCalculator.coachGreeting(for: Constants.CNS.unmeasuredAppStorageDefault)
        XCTAssertFalse(greeting.contains("-1"))
        XCTAssertFalse(greeting.localizedCaseInsensitiveContains("fatigue noted"))
        XCTAssertTrue(
            greeting.localizedCaseInsensitiveContains("not measured")
            || greeting.localizedCaseInsensitiveContains("Health")
        )
    }

    func testHistoryFilterLocalizedTitlesAreCatalogKeys() {
        XCTAssertEqual(HistoryFilter.all.localizedTitleKey, "All")
        XCTAssertEqual(HistoryFilter.favorites.localizedTitleKey, "Favorites")
        XCTAssertEqual(HistoryFilter.month.localizedTitleKey, "This month")
        XCTAssertEqual(HistoryFilter.threeMonths.localizedTitleKey, "3 months")
        XCTAssertEqual(HistoryFilter.year.localizedTitleKey, "This year")
    }

    func testAILogicErrorServerMessageDoesNotBlameGoogle() {
        let message = AILogicError.apiError(statusCode: 503, message: "upstream").errorDescription ?? ""
        XCTAssertFalse(message.localizedCaseInsensitiveContains("Google"))
        XCTAssertTrue(
            message.localizedCaseInsensitiveContains("AI")
            || message.localizedCaseInsensitiveContains("coach")
            || message.localizedCaseInsensitiveContains("try again")
        )
    }

    func testBodyAnalysisTreatsUnknownCNSAsNotMeasured() {
        let report = BodyAnalysisEngine.generateReport(
            cnsScore: Constants.CNS.unmeasuredAppStorageDefault,
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
        // Empty history + empty recovery map → not measured (never invent 100% peak).
        XCTAssertEqual(report.overallReadiness, -1)
        XCTAssertFalse(report.executiveAssessment.localizedCaseInsensitiveContains("peak readiness"))
        XCTAssertFalse(report.recommendedRestrictions.localizedCaseInsensitiveContains("peak readiness"))
    }

    func testRestFatigueEstimatorDoesNotUnlockWithoutSleep() {
        XCTAssertFalse(RestFatigueEstimator.showsMeasuredFatigue(hasSleepData: false))
        XCTAssertNil(RestFatigueEstimator.displayLoadPercent(hasSleepData: false, sleepHours: 7.5, waterCups: 4))
        XCTAssertEqual(
            RestFatigueEstimator.displayLoadPercent(hasSleepData: true, sleepHours: 7.5, waterCups: 4),
            Int(RestFatigueEstimator.cnsLoad(sleepHours: 7.5, waterCups: 4))
        )
    }

    func testRestFatigueDefaultLoadIsNotZeroButMustStayLocal() {
        // Defaults invent a non-zero load — UI must gate with hasSleepData (displayLoadPercent nil).
        let load = RestFatigueEstimator.cnsLoad(sleepHours: 7.5, waterCups: 4)
        XCTAssertGreaterThan(load, 0)
        XCTAssertNil(RestFatigueEstimator.displayLoadPercent(hasSleepData: false, sleepHours: 7.5, waterCups: 4))
    }

    func testAICoachQuickPromptsAvoidFakeNutritionProduct() {
        let prompts = AICoachView.defaultQuickPromptTexts
        XCTAssertFalse(prompts.contains(where: { $0.localizedCaseInsensitiveContains("Nutrition tip") }))
        XCTAssertTrue(prompts.contains(where: {
            $0.localizedCaseInsensitiveContains("recovery") || $0.localizedCaseInsensitiveContains("sleep")
        }))
    }

    func testHubExploreCTAUsesExploreNavigationNotHistoryTab() {
        XCTAssertEqual(WorkoutHubView.exploreProgramsTabAction, .openExplore)
        XCTAssertNotEqual(WorkoutHubView.exploreProgramsTabAction, .openHistoryTab)
    }

    func testOverviewStreakCopyUsesCatalogKeys() {
        XCTAssertEqual(OverviewHeaderView.streakCatalogKey(for: 1), "1-day streak")
        XCTAssertEqual(OverviewHeaderView.streakCatalogKey(for: 5), "%lld-day streak")
    }

    func testCalendarDateIntervalsNeverForceUnwrapsCurrentWeek() {
        let now = Date()
        let interval = CalendarDateIntervals.intervalOrFallback(.weekOfYear, containing: now)
        XCTAssertLessThanOrEqual(interval.start, now)
        XCTAssertGreaterThan(interval.end, interval.start)
        let previous = CalendarDateIntervals.previousInterval(.weekOfYear, before: now)
        XCTAssertLessThanOrEqual(previous.end, interval.end)
    }

    func testLibraryFilterUsesStableIdsNotDisplayEnglish() {
        XCTAssertEqual(LibraryFilter.all.rawValue, "all")
        XCTAssertEqual(LibraryFilter.saved.rawValue, "saved")
        XCTAssertNotEqual(LibraryFilter.saved.rawValue, "Saved Workouts")
        // Touch localized titles so catalog keys stay wired.
        _ = LibraryFilter.allCases.map(\.localizedTitleKey)
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

    /// Finish snackbar sets endTime with durationSeconds==0; cleanup must not finalize during undo grace.
    @MainActor
    func testFindActiveCleanupSkipsRecentFinishSnackbarOrphan() async throws {
        let (di, context) = try makeInMemoryDI()
        let stats = UserStats(totalWorkouts: 0, totalVolume: 0, totalDistance: 0)
        context.insert(stats)
        try context.save()

        let pid = try await di.workoutStore.createWorkout(title: "Snackbar pending", fromPresetID: nil, isAIGenerated: false)
        let workout = try XCTUnwrap(context.model(for: pid) as? Workout)
        let exercise = Exercise(name: "Squat", muscleGroup: "Legs", type: .strength)
        let set = WorkoutSet(index: 0, weight: 100, reps: 5, isCompleted: true)
        context.insert(exercise)
        context.insert(set)
        exercise.addSafeSet(set)
        workout.exercises = [exercise]
        workout.endTime = Date()
        workout.durationSeconds = 0
        try context.save()

        _ = try await di.workoutStore.findActiveWorkoutsAndCleanup()

        let refreshed = try XCTUnwrap(context.model(for: pid) as? Workout)
        XCTAssertEqual(refreshed.durationSeconds, 0, "Recent finish-orphan must stay unprocessed during undo grace")
        let after = try XCTUnwrap((try context.fetch(FetchDescriptor<UserStats>())).first)
        XCTAssertEqual(after.totalWorkouts, 0, "Stats must not apply during snackbar undo window")
    }

    /// Crash-recovery orphans older than grace must still finalize.
    @MainActor
    func testFindActiveCleanupProcessesStaleFinishOrphan() async throws {
        let (di, context) = try makeInMemoryDI()
        let stats = UserStats(totalWorkouts: 0, totalVolume: 0, totalDistance: 0)
        context.insert(stats)
        try context.save()

        let pid = try await di.workoutStore.createWorkout(title: "Killed mid-finish", fromPresetID: nil, isAIGenerated: false)
        let workout = try XCTUnwrap(context.model(for: pid) as? Workout)
        let exercise = Exercise(name: "Bench", muscleGroup: "Chest", type: .strength)
        let set = WorkoutSet(index: 0, weight: 80, reps: 5, isCompleted: true)
        context.insert(exercise)
        context.insert(set)
        exercise.addSafeSet(set)
        workout.exercises = [exercise]
        workout.date = Date().addingTimeInterval(-3600)
        workout.endTime = Date().addingTimeInterval(-120)
        workout.durationSeconds = 0
        try context.save()

        _ = try await di.workoutStore.findActiveWorkoutsAndCleanup()

        // Assert via stats (cross-context); duration is set inside @ModelActor processCompletedWorkout.
        let after = try XCTUnwrap((try context.fetch(FetchDescriptor<UserStats>())).first)
        XCTAssertEqual(after.totalWorkouts, 1, "Stale finish-orphan must be finalized")
        try await di.workoutStore.processCompletedWorkout(workoutID: pid) // idempotent if already done
        let afterIdempotent = try XCTUnwrap((try context.fetch(FetchDescriptor<UserStats>())).first)
        XCTAssertEqual(afterIdempotent.totalWorkouts, 1, "Re-process must not double-count")
    }

    /// Abandoned zero-progress sessions (≥30m) must not block new starts forever.
    @MainActor
    func testFindActiveCleanupDiscardsAbandonedZeroProgressZombie() async throws {
        let (di, context) = try makeInMemoryDI()
        let pid = try await di.workoutStore.createWorkout(title: "Abandoned preset", fromPresetID: nil, isAIGenerated: false)
        let workout = try XCTUnwrap(context.model(for: pid) as? Workout)
        let exercise = Exercise(name: "Squat", muscleGroup: "Legs", type: .strength, sets: 3, reps: 5)
        context.insert(exercise)
        workout.exercises = [exercise]
        workout.date = Date().addingTimeInterval(-40 * 60)
        try context.save()

        let activeIDs = try await di.workoutStore.findActiveWorkoutsAndCleanup()
        XCTAssertTrue(activeIDs.isEmpty, "Zero-progress session older than 30m must be discarded")
        let stillOpen = try context.fetch(FetchDescriptor<Workout>(predicate: #Predicate { $0.endTime == nil }))
        XCTAssertTrue(stillOpen.isEmpty)
    }

    /// Legacy / race leftovers: two open sessions under 12h must collapse to the newest.
    @MainActor
    func testFindActiveWorkoutsHealsMultipleFreshActivesToNewest() async throws {
        let (di, context) = try makeInMemoryDI()
        let older = Workout(title: "Older active", date: Date().addingTimeInterval(-3600), exercises: [])
        let newer = Workout(title: "Newer active", date: Date(), exercises: [])
        context.insert(older)
        context.insert(newer)
        try context.save()

        let activeIDs = try await di.workoutStore.findActiveWorkoutsAndCleanup()
        XCTAssertEqual(activeIDs.count, 1)
        let kept = try XCTUnwrap(context.model(for: activeIDs[0]) as? Workout)
        XCTAssertEqual(kept.title, "Newer active")

        let stillOpen = try context.fetch(FetchDescriptor<Workout>(predicate: #Predicate { $0.endTime == nil }))
        XCTAssertEqual(stillOpen.count, 1)
        XCTAssertEqual(stillOpen.first?.title, "Newer active")
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

    @MainActor
    func testLegendaryFallbackBodyweightSampleHasNoBarbellsOrWeights() throws {
        let bodyweight = LegendaryFallbackCatalog.routines.first {
            $0.shortVibe.localizedCaseInsensitiveContains("no equipment")
                || $0.loreDescription.localizedCaseInsensitiveContains("bodyweight")
        }
        let routine = try XCTUnwrap(bodyweight)
        for exercise in routine.exercises {
            let name = exercise.name.lowercased()
            XCTAssertFalse(name.contains("barbell"), "Bodyweight sample must not list barbell lifts")
            XCTAssertNil(exercise.recommendedWeightKg, "Bodyweight sample must not invent loaded weights")
        }
    }

    @MainActor
    func testLegendaryFallbackCopyDoesNotClaimExactPublishedPrograms() {
        for routine in LegendaryFallbackCatalog.routines {
            let lore = routine.loreDescription.lowercased()
            XCTAssertFalse(lore.contains("exact"), "Sample lore must not claim exact published protocols: \(routine.title)")
            XCTAssertTrue(
                lore.contains("inspired") || lore.contains("sample") || lore.contains("taste"),
                "Sample lore should signal inspired/sample: \(routine.title)"
            )
        }
    }

    /// Bundled offline Legendary must not ship third-party program / celebrity brand names (App Store risk).
    @MainActor
    func testLegendaryFallbackAvoidsTrademarkBrandNames() {
        let banned = ["athlean", "xero", "arnold", "mentzer", "goggins"]
        for routine in LegendaryFallbackCatalog.routines {
            let blob = "\(routine.title) \(routine.eraTitle) \(routine.shortVibe) \(routine.loreDescription)".lowercased()
            for token in banned {
                XCTAssertFalse(
                    blob.contains(token),
                    "Offline Legendary must not include '\(token)': \(routine.title)"
                )
            }
        }
    }

    func testGestureConfidenceThresholdIsConservative() {
        XCTAssertGreaterThanOrEqual(
            GestureTuning.confidenceThreshold,
            0.5,
            "Low Vision confidence causes false set confirms in gym lighting"
        )
    }

    @MainActor
    func testMockProgramCatalogAvoidsCelebrityBrandProgramTitles() {
        let banned = ["arnold", "athlean", "mentzer", "goggins"]
        for program in MockProgramCatalog.shared.featuredPrograms {
            let blob = "\(program.title) \(program.description)".lowercased()
            for token in banned {
                XCTAssertFalse(blob.contains(token), "Mock Explore catalog must not include '\(token)': \(program.title)")
            }
        }
    }

    func testEffortScaleClampsOutOfRangeValues() {
        XCTAssertEqual(EffortScale.clamp(50), 10)
        XCTAssertEqual(EffortScale.clamp(0), 1)
        XCTAssertEqual(EffortScale.clamp(5), 5)
    }

    func testRestDurationPolicyPrefersTemplateRestOverEffortHeuristic() {
        XCTAssertEqual(
            RestDurationPolicy.suggestedSeconds(templateRestSeconds: 45, effort: 9, exerciseType: .strength),
            45
        )
        XCTAssertEqual(
            RestDurationPolicy.suggestedSeconds(templateRestSeconds: nil, effort: 9, exerciseType: .strength),
            180
        )
        XCTAssertEqual(
            RestDurationPolicy.suggestedSeconds(templateRestSeconds: nil, effort: 50, exerciseType: .strength),
            180,
            "Out-of-range effort must clamp before heuristic"
        )
        XCTAssertNil(
            RestDurationPolicy.suggestedSeconds(templateRestSeconds: nil, effort: 5, exerciseType: .cardio)
        )
    }

    func testRestDurationPolicyResolveFallsBackToUserDefault() {
        XCTAssertEqual(
            RestDurationPolicy.resolveSeconds(
                templateRestSeconds: nil,
                effort: 5,
                exerciseType: .cardio,
                userDefaultRest: 75
            ),
            75
        )
        XCTAssertEqual(
            RestDurationPolicy.resolveSeconds(
                templateRestSeconds: nil,
                effort: 5,
                exerciseType: .cardio,
                userDefaultRest: 0
            ),
            60
        )
    }

    func testExerciseDTOClampsEffortAndKeepsRestSeconds() throws {
        let dto = ExerciseDTO(
            name: "Squat",
            muscleGroup: "Legs",
            type: .strength,
            category: .squat,
            effort: 50,
            isCompleted: false,
            restSeconds: 120
        )
        XCTAssertEqual(dto.effort, 10)
        XCTAssertEqual(dto.restSeconds, 120)
        let data = try JSONEncoder().encode(dto)
        let decoded = try JSONDecoder().decode(ExerciseDTO.self, from: data)
        XCTAssertEqual(decoded.effort, 10)
        XCTAssertEqual(decoded.restSeconds, 120)
    }

    @MainActor
    func testProcessCompletedWorkoutIsIdempotent() async throws {
        let (di, context) = try makeInMemoryDI()
        context.insert(UserStats(totalWorkouts: 0, totalVolume: 0, totalDistance: 0))
        try context.save()

        let pid = try await di.workoutStore.createWorkout(title: "Once", fromPresetID: nil, isAIGenerated: false)
        let workout = try XCTUnwrap(context.model(for: pid) as? Workout)
        let exercise = Exercise(name: "Row", muscleGroup: "Back", type: .strength)
        context.insert(exercise)
        let set = WorkoutSet(index: 0, weight: 60, reps: 8, isCompleted: true)
        context.insert(set)
        exercise.addSafeSet(set)
        workout.exercises = [exercise]
        try context.save()

        try await di.workoutStore.processCompletedWorkout(workoutID: pid)
        try await di.workoutStore.processCompletedWorkout(workoutID: pid)

        let stats = try XCTUnwrap((try context.fetch(FetchDescriptor<UserStats>())).first)
        XCTAssertEqual(stats.totalWorkouts, 1, "Double process must not double-count lifetime workouts")
    }

    func testBodyAnalysisDoesNotPrintNegativeReadinessPercent() {
        let report = BodyAnalysisEngine.generateReport(
            cnsScore: 55,
            recoveryDict: [:],
            recentWorkouts: [Workout(title: "Past", date: Date().addingTimeInterval(-86400))]
        )
        XCTAssertFalse(
            report.nextWorkoutAdvice.recentStrainSummary.contains("-1%"),
            "Empty recovery + low CNS must not interpolate average readiness -1%"
        )
    }

    func testRecoveryMapDoesNotPadUntrainedMusclesTo100() async {
        let schema = Schema([
            Workout.self, WorkoutPreset.self, ExerciseNote.self, UserStats.self,
            ExerciseStat.self, MuscleStat.self, WeightEntry.self, MuscleColorPreference.self,
            AIChatSession.self, BodyMeasurement.self, ExerciseDictionaryItem.self, UserGoal.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        let workout = Workout(title: "Chest only", date: Date().addingTimeInterval(-3600))
        workout.endTime = Date()
        workout.durationSeconds = 3600
        let exercise = Exercise(name: "Bench", muscleGroup: "Chest", type: .strength, effort: 8)
        let set = WorkoutSet(index: 0, weight: 60, reps: 8, isCompleted: true)
        context.insert(workout)
        context.insert(exercise)
        context.insert(set)
        exercise.addSafeSet(set)
        workout.exercises = [exercise]
        try! context.save()

        let store = WorkoutStore(modelContainer: container)
        let analytics = AnalyticsService(workoutStore: store, modelContainer: container)
        let recovery = await analytics.calculateRecovery(hours: 48, workouts: [workout])
        let slugs = Set(recovery.map(\.muscleGroup))
        XCTAssertTrue(slugs.contains("chest") || recovery.contains(where: { $0.muscleGroup.lowercased().contains("chest") }))
        XCTAssertFalse(slugs.contains("hair"), "Must not invent 100% recovery for unused anatomy slugs")
        XCTAssertFalse(slugs.contains("feet"))
    }

    @MainActor
    func testPeriodComparisonUsesPeriodTotalsNotChartEdges() {
        let previous = PeriodStats(workoutCount: 2, totalReps: 0, totalDuration: 3600, totalVolume: 1000, totalDistance: 0)
        let current = PeriodStats(workoutCount: 4, totalReps: 0, totalDuration: 7200, totalVolume: 2000, totalDistance: 0)
        let units = UnitsManager.shared
        let prevVal = PeriodComparisonMetrics.metricValue(previous, metric: .count, units: units)
        let currVal = PeriodComparisonMetrics.metricValue(current, metric: .count, units: units)
        XCTAssertEqual(prevVal, 2)
        XCTAssertEqual(currVal, 4)
        let volumePrev = PeriodComparisonMetrics.metricValue(previous, metric: .volume, units: units)
        let volumeCurr = PeriodComparisonMetrics.metricValue(current, metric: .volume, units: units)
        XCTAssertGreaterThan(volumeCurr, volumePrev)
    }

    @MainActor
    func testExerciseFormattedDetailsAvoidsMiddleDotSlop() {
        let exercise = Exercise(
            name: "Bench",
            muscleGroup: "Chest",
            type: .strength,
            sets: 3,
            reps: 8,
            weight: 60
        )
        let details = exercise.formattedDetails(unitsManager: UnitsManager.shared)
        XCTAssertFalse(details.contains("·"), "Anti-slop: no decorative middle dots in set summaries")
        XCTAssertTrue(details.contains(","), "Prefer comma separators for weight metadata")
    }

    func testCalorieCalculatorDoesNotInventOneHourWhenDurationMissing() {
        let workout = Workout(title: "Short", date: Date().addingTimeInterval(-600))
        workout.endTime = Date()
        workout.durationSeconds = 0
        let exercise = Exercise(name: "Curl", muscleGroup: "Arms", type: .strength, setsList: [
            WorkoutSet(index: 1, isCompleted: true)
        ])
        workout.exercises = [exercise]

        let cals = CalorieCalculator.calculate(for: workout, userWeight: 80)
        // 600s wall clock ≪ invented 3600s resting calories (~154+)
        XCTAssertLessThan(cals, 80, "Missing durationSeconds must use endTime-date, not invent 3600s")
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
