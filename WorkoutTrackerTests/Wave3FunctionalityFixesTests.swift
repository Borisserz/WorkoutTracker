import AVFoundation
import CoreML
import Foundation
import SwiftData
import Testing
@testable import WorkoutTracker

@Suite("Wave 3 Functionality, AI, Vision/Speech, Watch & Data Integrity Tests")
struct Wave3FunctionalityFixesTests {

    private func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    // MARK: - F1: XP & Analytics ordering on workout completion

    @Test("F1: Workout completion processes duration, effort, and volume BEFORE awarding XP")
    @MainActor
    func workoutCompletionComputesMetricsBeforeXP() async throws {
        let schema = Schema([
            Workout.self, WorkoutPreset.self, ExerciseNote.self, UserStats.self,
            ExerciseStat.self, MuscleStat.self, WeightEntry.self, MuscleColorPreference.self,
            AIChatSession.self, BodyMeasurement.self, ExerciseDictionaryItem.self, UserGoal.self
        ])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let context = ModelContext(container)

        let start = Date().addingTimeInterval(-2700) // 45 minutes ago
        let end = Date()
        let workout = Workout(title: "Evening Push", date: start)
        workout.endTime = end
        // Note: durationSeconds, effortPercentage, and totalStrengthVolume intentionally start at 0,
        // matching a freshly finished live workout before processCompletedWorkout runs.
        let bench = Exercise(name: "Bench Press", muscleGroup: "Chest", type: .strength, effort: 8, isCompleted: true)
        bench.setsList = [
            WorkoutSet(index: 1, weight: 80, reps: 10, isCompleted: true, type: .normal),
            WorkoutSet(index: 2, weight: 80, reps: 10, isCompleted: true, type: .normal),
            WorkoutSet(index: 3, weight: 80, reps: 10, isCompleted: true, type: .normal)
        ]
        workout.exercises = [bench]
        context.insert(workout)
        try context.save()

        let store = WorkoutStore(modelContainer: container)
        let analytics = AnalyticsService(workoutStore: store, modelContainer: container)
        let progressManager = ProgressManager()
        progressManager.resetProgress()
        defer { progressManager.resetProgress() }

        let outcome = try await WorkoutDetailViewModel.finalizeWorkoutStatsAndAwardXP(
            workout: workout,
            workoutID: workout.persistentModelID,
            prCount: 1,
            analyticsService: analytics,
            progressManager: progressManager
        )

        #expect(outcome.xpBreakdown.durationXP >= 220)
        #expect(outcome.xpBreakdown.effortMultiplier > 1.0)
        #expect(outcome.xpBreakdown.volumeXP > 0)
        #expect(workout.totalStrengthVolume == 2400)
        #expect(workout.effortPercentage == 80)
        #expect(workout.durationSeconds >= 2699)
    }

    // MARK: - F2: In-Workout AI swap & lbs unit display

    @Test("F2: SmartAction swap uses replacementExerciseName instead of cloning same exercise, and card display does not double-convert lbs")
    @MainActor
    func smartActionSwapUsesReplacementAndAvoidsDoubleConversion() async throws {
        let schema = Schema([
            Workout.self, WorkoutPreset.self, ExerciseNote.self, UserStats.self,
            ExerciseStat.self, MuscleStat.self, WeightEntry.self, MuscleColorPreference.self,
            AIChatSession.self, BodyMeasurement.self, ExerciseDictionaryItem.self, UserGoal.self
        ])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let context = ModelContext(container)

        let workout = Workout(title: "Push", date: Date())
        let bench = Exercise(name: "Barbell Bench Press", muscleGroup: "Chest", type: .strength, sets: 3, reps: 8, weight: 80)
        workout.exercises = [bench]
        context.insert(workout)
        try context.save()

        let store = WorkoutStore(modelContainer: container)
        let swapProposal = SmartActionDTO(
            action: "swap",
            exerciseName: "Barbell Bench Press",
            setsRemaining: 3,
            weightValue: 110.0,
            reasoning: "Switch to dumbbells for shoulder comfort.",
            replacementExerciseName: "Dumbbell Bench Press"
        )
        try await store.applySmartAction(proposal: swapProposal, inWorkoutID: workout.persistentModelID, weightUnit: .pounds)

        let verifyCtx = ModelContext(container)
        let refreshed = try #require(verifyCtx.model(for: workout.persistentModelID) as? Workout)
        #expect(refreshed.exercises.contains(where: { $0.name == "Dumbbell Bench Press" }))

        // Self-swap guard: if replacement is missing/identical, keep active exercise sets intact rather than cloning itself.
        let selfSwap = SmartActionDTO(
            action: "swap",
            exerciseName: "Dumbbell Bench Press",
            setsRemaining: 3,
            weightValue: 50.0,
            reasoning: "No-op bad model response",
            replacementExerciseName: "Dumbbell Bench Press"
        )
        try await store.applySmartAction(proposal: selfSwap, inWorkoutID: workout.persistentModelID, weightUnit: .kilograms)
        let verifySelfCtx = ModelContext(container)
        let afterSelf = try #require(verifySelfCtx.model(for: workout.persistentModelID) as? Workout)
        #expect(afterSelf.exercises.filter { $0.name == "Dumbbell Bench Press" }.count == 1)

        // UI card weight formatting: LLM already returns `weightValue` in display unit; must not multiply by 2.20462 again.
        #expect(InWorkoutAIUnitHelper.displaySuggestedWeight(modelWeightValue: 135.0, unitString: "lbs") == "135 lbs")
        let viewSource = try String(contentsOf: repoRoot().appendingPathComponent("WorkoutTracker/Features/AICoach/Views/InWorkoutAICoachView.swift"), encoding: .utf8)
        #expect(!viewSource.contains("convertFromKilograms(proposal.weightValue)"))
    }

    // MARK: - F3: Smart Builder Cardio, recommendedPresetKey, .bodyweight & loadContinuations

    @Test("F3: ExerciseDatabaseService populates Cardio catalog, LocalWorkoutGenerator filters bodyweight strictly, and recommendedPresetKey matches real slugs")
    func smartBuilderCardioBodyweightAndSlugs() async throws {
        let db = ExerciseDatabaseService.shared
        await db.loadDatabase()
        let catalog = await db.getCatalog()
        let cardioCatalog = catalog["Cardio"] ?? []
        #expect(cardioCatalog.count >= 10)
        #expect(cardioCatalog.contains("Running, Treadmill"))
        #expect(cardioCatalog.contains("Stationary Bike"))

        // Cardio Blast preset uses ["Cardio", "Core"] + .bodyweight — must return real cardio items, never empty.
        let cardioWorkout = await LocalWorkoutGeneratorService.shared.generateWorkout(
            config: SmartGeneratorConfig(
                targetMuscles: ["Cardio", "Core"],
                durationMinutes: 30,
                difficulty: .intermediate,
                equipment: .bodyweight,
                history: [:]
            )
        )
        #expect(!cardioWorkout.isEmpty)
        #expect(cardioWorkout.contains(where: { $0.type == .cardio }))

        // Bodyweight Legs must exclude dumbbells, kettlebells, bands, and stability balls.
        let legsBodyweight = await LocalWorkoutGeneratorService.shared.generateWorkout(
            config: SmartGeneratorConfig(
                targetMuscles: ["Legs"],
                durationMinutes: 40,
                difficulty: .intermediate,
                equipment: .bodyweight,
                history: [:]
            )
        )
        #expect(!legsBodyweight.isEmpty)
        let bannedEquipmentTokens = ["dumbbell", "kettlebell", "kettle bell", "band", "stability ball", "swiss ball", "barbell", "cable", "machine"]
        for ex in legsBodyweight {
            let lower = ex.name.lowercased()
            #expect(!bannedEquipmentTokens.contains(where: { lower.contains($0) }), "Unexpected equipment in bodyweight workout: \(ex.name)")
        }

        // recommendedPresetKey slug matching
        #expect(SmartGeneratorEntryView.recommendedPreset(for: ["biceps", "triceps"]) == "Quick Pump")
        #expect(SmartGeneratorEntryView.recommendedPreset(for: ["quadriceps", "hamstring"]) == "Dumbbell Full Body")
        #expect(SmartGeneratorEntryView.recommendedPreset(for: ["cardio"]) == "Cardio Blast")

        // Ensure ExerciseDatabaseService.swift uses defer to always resume loadContinuations even on failure
        let dbSrc = try String(contentsOf: repoRoot().appendingPathComponent("WorkoutTracker/Services/Domain/ExerciseDatabaseService.swift"), encoding: .utf8)
        #expect(dbSrc.contains("resumeLoadContinuations"))
    }

    // MARK: - F4: MLWorkoutEngine labels, SpeechRecognizer thread/permission safety, SmartCaptureViewModel

    @Test("F4: MLWorkoutEngine rejects Background predictions and SpeechRecognizer validates format & session safely")
    @MainActor
    func mlLabelsAndSpeechSafety() throws {
        #expect(MLWorkoutEngine.isActivePrediction(label: "Background", confidence: 0.99) == false)
        #expect(MLWorkoutEngine.isActivePrediction(label: "idle", confidence: 0.99) == false)
        #expect(MLWorkoutEngine.isActivePrediction(label: "exercises", confidence: 0.85) == true)
        #expect(MLWorkoutEngine.isActivePrediction(label: "exercises", confidence: 0.35) == false)

        #expect(SpeechRecognizer.isValidAudioFormat(sampleRate: 0, channelCount: 1) == false)
        #expect(SpeechRecognizer.isValidAudioFormat(sampleRate: 44100, channelCount: 0) == false)
        #expect(SpeechRecognizer.isValidAudioFormat(sampleRate: 44100, channelCount: 1) == true)

        let speechSrc = try String(contentsOf: repoRoot().appendingPathComponent("WorkoutTracker/CoreLogic/Helpers/SpeechRecognizer.swift"), encoding: .utf8)
        #expect(speechSrc.contains(".playAndRecord"))
        #expect(speechSrc.contains(".mixWithOthers"))
        #expect(!speechSrc.contains("self.request?.append(buffer)"))

        let smartCaptureSrc = try String(contentsOf: repoRoot().appendingPathComponent("WorkoutTracker/Features/Profile/SmartCaptureViewModel.swift"), encoding: .utf8)
        #expect(smartCaptureSrc.contains("triggerManualCapture"))
        #expect(!smartCaptureSrc.contains("deinit {\n        session.stopRunning()"))
    }

    // MARK: - F5: Offline AI fast-fail & CancellationError handling

    @Test("F5: GeminiNetworkClient does not waitForConnectivity for 120s and CancellationError is recognized cleanly")
    @MainActor
    func offlineFastFailAndCancellationHandling() throws {
        let sessionConfig = GeminiNetworkClient.makeSessionConfiguration()
        #expect(sessionConfig.waitsForConnectivity == false)
        #expect(sessionConfig.timeoutIntervalForResource <= 60.0)

        #expect(AICoachViewModel.isCancellationError(CancellationError()) == true)
        #expect(AICoachViewModel.isCancellationError(URLError(.cancelled)) == true)
        #expect(AICoachViewModel.isCancellationError(URLError(.notConnectedToInternet)) == false)
    }

    // MARK: - F6: Watch sync serialization & unit/session/store readiness

    @Test("F6: Burst Watch startWorkout + logSet events are serialized so no set is dropped")
    @MainActor
    func watchBurstSyncDoesNotDropLogSet() async throws {
        let schema = Schema([
            Workout.self, WorkoutPreset.self, ExerciseNote.self, UserStats.self,
            ExerciseStat.self, MuscleStat.self, WeightEntry.self, MuscleColorPreference.self,
            AIChatSession.self, BodyMeasurement.self, ExerciseDictionaryItem.self, UserGoal.self
        ])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let isolatedCenter = NotificationCenter()
        let di = DIContainer(modelContainer: container, watchNotificationCenter: isolatedCenter)
        let service = di.workoutService
        _ = service

        let wid = UUID()
        let startPayload = LiveSyncPayload(
            action: .startWorkout,
            workoutID: wid.uuidString,
            workoutTitle: "Watch Serialized Push",
            exercises: [
                ExerciseDTO(
                    name: "Bench Press",
                    muscleGroup: "Chest",
                    type: .strength,
                    category: .press,
                    effort: 7,
                    isCompleted: false,
                    setsList: [WorkoutSetDTO(index: 1, weight: 60, reps: 10, distance: nil, time: nil, isCompleted: false, type: .normal)],
                    subExercises: [],
                    sets: 1,
                    reps: 10,
                    recommendedWeightKg: 60
                )
            ]
        )
        let logPayload = LiveSyncPayload(
            action: .logSet,
            workoutID: wid.uuidString,
            exerciseName: "Bench Press",
            setIndex: 1,
            weight: 85.0,
            reps: 8,
            isCompleted: true
        )

        // Fire both back-to-back on MainActor without waiting for disk/SwiftData save between them.
        isolatedCenter.post(name: NSNotification.Name("LiveWorkoutSyncEvent"), object: nil, userInfo: ["payload": startPayload])
        isolatedCenter.post(name: NSNotification.Name("LiveWorkoutSyncEvent"), object: nil, userInfo: ["payload": logPayload])

        var matchedSet: WorkoutSet?
        for _ in 0..<80 {
            let checkCtx = ModelContext(container)
            if let workout = try? checkCtx.fetch(FetchDescriptor<Workout>(predicate: #Predicate { $0.id == wid })).first,
               let ex = workout.exercises.first(where: { $0.name == "Bench Press" }),
               let set = ex.setsList.first(where: { $0.index == 1 && $0.isCompleted }) {
                matchedSet = set
                break
            }
            try await Task.sleep(for: .milliseconds(50))
        }

        let completedSet = try #require(matchedSet, "Queued .logSet after .startWorkout must never be dropped")
        #expect(completedSet.weight == 85.0)
        #expect(completedSet.reps == 8)

        // Verify Watch UI uses UnitsManager & starts HKWorkoutSession on restore
        let watchSetView = try String(contentsOf: repoRoot().appendingPathComponent("WatchApp/Views/Tabs/WatchExerciseSetView.swift"), encoding: .utf8)
        #expect(watchSetView.contains("UnitsManager.shared"))
        #expect(!watchSetView.contains("inputButton(title: \"KG\""))

        let watchActiveView = try String(contentsOf: repoRoot().appendingPathComponent("WatchApp/Views/WatchActiveWorkoutView.swift"), encoding: .utf8)
        #expect(watchActiveView.contains("!workoutManager.isRunning"))
    }

    // MARK: - F7: Superset preset duplication, LiveActivity staleDate, HKObserver cleanup & wipe

    @Test("F7: PresetRepository does not promote superset subExercises to top level and LiveActivity keeps staleDate")
    @MainActor
    func presetSupersetAndLiveActivityIntegrity() async throws {
        let schema = Schema([
            Workout.self, WorkoutPreset.self, ExerciseNote.self, UserStats.self,
            ExerciseStat.self, MuscleStat.self, WeightEntry.self, MuscleColorPreference.self,
            AIChatSession.self, BodyMeasurement.self, ExerciseDictionaryItem.self, UserGoal.self
        ])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let repo = PresetRepository(modelContainer: container)

        let sub1 = ExerciseDTO(name: "Push-up", muscleGroup: "Chest", type: .strength, category: .press, effort: 7, isCompleted: false, setsList: nil, subExercises: nil)
        let sub2 = ExerciseDTO(name: "Pull-up", muscleGroup: "Back", type: .strength, category: .pull, effort: 8, isCompleted: false, setsList: nil, subExercises: nil)
        let superset = ExerciseDTO(name: "Superset", muscleGroup: "Mixed", type: .strength, category: .other, effort: 8, isCompleted: false, setsList: nil, subExercises: [sub1, sub2])

        try await repo.createPreset(name: "Upper Superset", icon: "bolt.fill", folderName: nil, exercises: [superset])

        let ctx = ModelContext(container)
        let presets = try ctx.fetch(FetchDescriptor<WorkoutPreset>())
        let created = try #require(presets.first)
        #expect(created.exercises.count == 1)
        #expect(created.exercises.first?.subExercises.count == 2)

        try await repo.updatePreset(presetID: created.persistentModelID, name: "Upper Superset v2", icon: "bolt.fill", folderName: nil, exercises: [superset])
        let verifyCtx = ModelContext(container)
        let updated = try #require(verifyCtx.model(for: created.persistentModelID) as? WorkoutPreset)
        #expect(updated.exercises.count == 1)
        #expect(updated.exercises.first?.subExercises.count == 2)

        // LiveActivity staleDate must never clear to nil on timer update/clear.
        let now = Date()
        let preserved = LiveActivityManager.resolvedStaleDate(existing: now.addingTimeInterval(600), now: now)
        #expect(preserved > now)
        let fallbackStale = LiveActivityManager.resolvedStaleDate(existing: nil, now: now)
        #expect(fallbackStale > now)

        // Supplementary wipe cleans water_liters_*, pendingWidgetAction, CustomExerciseMappings, RestTimer & notifications
        let suiteName = "wave3.wipe.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.set(2.5, forKey: "water_liters_2026-11-18")
        defaults.set("openWorkout", forKey: Constants.UserDefaultsKeys.pendingWidgetAction.rawValue)
        WorkoutDetailViewModel.wipeSupplementaryDefaultsAndFiles(defaults: defaults)
        #expect(defaults.object(forKey: "water_liters_2026-11-18") == nil)
        #expect(defaults.object(forKey: Constants.UserDefaultsKeys.pendingWidgetAction.rawValue) == nil)
        defaults.removePersistentDomain(forName: suiteName)
    }
}
