import Foundation
import SwiftData
import Testing
@testable import WorkoutTracker

@Suite("Wave 1 Production Fixes Tests")
struct Wave1ProductionFixesTests {

    @Test("1RM calculator stays finite and positive across high rep counts including 37 and 38")
    func testOneRepMaxCalculatorFiniteAt37PlusReps() {
        for formula in RMFormula.allCases {
            for reps in [1, 10, 36, 37, 38, 50, 100] {
                let rm = OneRepMaxCalculator.calculate1RM(weight: 100.0, reps: reps, formula: formula)
                #expect(rm.isFinite, "1RM must be finite for \(formula) at \(reps) reps, got \(rm)")
                #expect(rm >= 100.0, "1RM must be >= weight for \(formula) at \(reps) reps, got \(rm)")

                let targetWeight = OneRepMaxCalculator.calculateWeightForReps(oneRepMax: 100.0, targetReps: reps, formula: formula)
                #expect(targetWeight.isFinite, "Target weight must be finite for \(formula) at \(reps) reps")
                #expect(targetWeight > 0.0, "Target weight must remain positive for \(formula) at \(reps) reps")
            }
        }
    }

    @Test("Live Activity timer helpers guard expired rest ranges and future start times")
    func testWorkoutActivityAttributesSafeTimerRanges() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        let expired = WorkoutActivityAttributes.ContentState(
            startTime: now.addingTimeInterval(-300),
            restTimerEndTime: now.addingTimeInterval(-5),
            currentExerciseName: "Bench Press",
            upcomingWeight: "80 kg"
        )
        #expect(expired.activeRestRange(now: now) == nil)

        let exactNow = WorkoutActivityAttributes.ContentState(
            startTime: now.addingTimeInterval(-300),
            restTimerEndTime: now,
            currentExerciseName: "Bench Press",
            upcomingWeight: "80 kg"
        )
        #expect(exactNow.activeRestRange(now: now) == nil)

        let active = WorkoutActivityAttributes.ContentState(
            startTime: now.addingTimeInterval(-300),
            restTimerEndTime: now.addingTimeInterval(45),
            currentExerciseName: "Bench Press",
            upcomingWeight: "80 kg"
        )
        let range = active.activeRestRange(now: now)
        #expect(range == now...now.addingTimeInterval(45))

        let skewedStart = WorkoutActivityAttributes.ContentState(
            startTime: now.addingTimeInterval(30),
            restTimerEndTime: nil,
            currentExerciseName: nil,
            upcomingWeight: nil
        )
        let workoutRange = skewedStart.activeWorkoutRange(now: now)
        #expect(workoutRange.lowerBound <= workoutRange.upperBound)
    }

    @Test("LocalizationHelper applies loaded translations for all 6 non-English languages")
    func testLocalizationHelperTranslatesAllShippedLocales() {
        LocalizationHelper.shared.setTranslations(
            names: ["bench press": "Localized Bench"],
            instructions: ["bench press": ["Step 1"]]
        )
        defer {
            LocalizationHelper.shared.setTranslations(names: [:], instructions: [:])
        }

        for code in ["ru", "de", "es", "fr", "it", "pt", "pt-PT"] {
            #expect(LocalizationHelper.shared.translateName("Bench Press", languageCode: code) == "Localized Bench")
            #expect(LocalizationHelper.shared.translateInstructions(for: "Bench Press", languageCode: code) == ["Step 1"])
        }
        #expect(LocalizationHelper.shared.translateName("Bench Press", languageCode: "en") == "Bench Press")
        #expect(LocalizationHelper.shared.translateInstructions(for: "Bench Press", languageCode: "en") == nil)
    }

    @Test("In-workout AI converts kg <-> lbs cleanly and preserves cardio/duration fields")
    @MainActor
    func testSmartActionUnitsAndGeneratedWorkoutFields() async throws {
        let promptLbs = InWorkoutAIUnitHelper.promptWeightText(storedKg: 60.0, weightUnit: .pounds)
        #expect(promptLbs.hasSuffix("lbs"))
        let numericLbs = Double(promptLbs.replacingOccurrences(of: " lbs", with: "")) ?? 0
        #expect(abs(numericLbs - 132.3) < 0.2)

        let storedFromLbs = InWorkoutAIUnitHelper.canonicalKg(fromModelWeight: 135.0, weightUnit: .pounds)
        #expect(abs(storedFromLbs - 61.235) < 0.1)

        let storedFromKg = InWorkoutAIUnitHelper.canonicalKg(fromModelWeight: 80.0, weightUnit: .kilograms)
        #expect(abs(storedFromKg - 80.0) < 0.001)

        // Cardio & duration exercises generated via GeneratedWorkoutDTO keep time/distance and clamp extreme sets
        let schema = Schema([
            Workout.self, WorkoutPreset.self, ExerciseNote.self, UserStats.self,
            ExerciseStat.self, MuscleStat.self, WeightEntry.self, MuscleColorPreference.self,
            AIChatSession.self, BodyMeasurement.self, ExerciseDictionaryItem.self, UserGoal.self
        ])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let store = WorkoutStore(modelContainer: container)

        let dto = GeneratedWorkoutDTO(
            title: "Cardio + Core",
            aiMessage: "Go",
            exercises: [
                GeneratedExerciseDTO(
                    name: "Running",
                    muscleGroup: "Cardio",
                    type: "Cardio",
                    sets: 1,
                    reps: 0,
                    recommendedWeightKg: nil,
                    restSeconds: nil,
                    durationSeconds: 1200,
                    distanceMeters: 3000
                ),
                GeneratedExerciseDTO(
                    name: "Push-up",
                    muscleGroup: "Chest",
                    type: "Strength",
                    sets: 999,
                    reps: 15,
                    recommendedWeightKg: -20,
                    restSeconds: 60
                )
            ]
        )

        let wid = try await store.createWorkoutFromAI(generated: dto)
        let context = ModelContext(container)
        let workout = try #require(context.model(for: wid) as? Workout)
        #expect(workout.exercises.count == 2)
        let cardio = try #require(workout.exercises.first(where: { $0.name == "Running" }))
        #expect(cardio.setsList.first?.time == 1200)
        #expect(cardio.setsList.first?.distance == 3000)

        let clamped = try #require(workout.exercises.first(where: { $0.name == "Push-up" }))
        #expect(clamped.setsList.count <= 30)
        #expect((clamped.setsList.first?.weight ?? 0) >= 0)

        let proposal = SmartActionDTO(
            action: "reduce_weight",
            exerciseName: "Push-up",
            setsRemaining: 3,
            weightValue: 135.0,
            reasoning: "Adjusted in lbs"
        )
        try await store.applySmartAction(proposal: proposal, inWorkoutID: wid, weightUnit: .pounds)
        let verifyContext = ModelContext(container)
        let refreshedWorkout = try #require(verifyContext.model(for: wid) as? Workout)
        let targetEx = try #require(refreshedWorkout.exercises.first(where: { $0.name == "Push-up" }))
        let updatedKg = targetEx.setsList.first?.weight ?? 0
        #expect(abs(updatedKg - 61.235) < 0.1)
    }

    @Test("Previous performance formatter converts strength weight and cardio distance units accurately")
    @MainActor
    func testPreviousPerformanceFormattingRespectsUnits() {
        let strengthText = ConfigureExerciseViewModel.formatPreviousPerformance(
            exerciseType: .strength,
            setsCount: 3,
            reps: 8,
            maxWeightKg: 100.0,
            distanceMeters: 0,
            durationSeconds: 0,
            weightUnit: .pounds,
            distanceUnit: .miles
        )
        #expect(strengthText.contains("lbs"))
        #expect(!strengthText.contains("100.0 kg"))

        let cardioMetricText = ConfigureExerciseViewModel.formatPreviousPerformance(
            exerciseType: .cardio,
            setsCount: 1,
            reps: 0,
            maxWeightKg: 0,
            distanceMeters: 5000.0,
            durationSeconds: 1500,
            weightUnit: .kilograms,
            distanceUnit: .meters
        )
        #expect(!cardioMetricText.contains("5000.00 km"))
        #expect(cardioMetricText.contains("m"))
    }

    @Test("Equipment classification recognizes dumbbell")
    func testEquipmentClassificationDumbbell() {
        #expect(AnalyticsService.classifyEquipment("dumbbell") == .freeWeights)
        #expect(AnalyticsService.classifyEquipment("Dumbbell Bench") == .freeWeights)
    }

    @Test("Privacy manifest and ReportSheet localizations meet App Store requirements")
    func testPrivacyManifestAndReportSheetLocalizations() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let privacyURL = repoRoot.appendingPathComponent("PrivacyInfo.xcprivacy")
        let privacyXML = try String(contentsOf: privacyURL, encoding: .utf8)
        #expect(privacyXML.contains("NSPrivacyCollectedDataTypePhotosOrVideos"))
        #expect(!privacyXML.contains("PhotosorVideos"))
        #expect(privacyXML.contains("1C8F.1"))
        #expect(privacyXML.contains("CA92.1"))

        let pbxURL = repoRoot.appendingPathComponent("WorkoutTracker.xcodeproj/project.pbxproj")
        let pbx = try String(contentsOf: pbxURL, encoding: .utf8)
        let privacyResourceRefs = pbx.components(separatedBy: "PrivacyInfo.xcprivacy in Resources").count - 1
        #expect(privacyResourceRefs >= 4, "PrivacyInfo.xcprivacy must be bundled in App, Watch, StatsWidget, and WorkoutTimerWidget")

        let reportURL = repoRoot.appendingPathComponent("WorkoutTracker/Auth/ReportSheet.swift")
        let reportSwift = try String(contentsOf: reportURL, encoding: .utf8)
        #expect(!reportSwift.contains("\"report."))
        #expect(!reportSwift.contains("\"common."))

        let xcstringsURL = repoRoot.appendingPathComponent("WorkoutTracker/Localizable.xcstrings")
        let xcData = try Data(contentsOf: xcstringsURL)
        let xcRaw = String(data: xcData, encoding: .utf8) ?? ""
        #expect(!xcRaw.contains("Bericht.Titel"))
        #expect(!xcRaw.contains("informe.título"))
        #expect(!xcRaw.contains("rapport.titre"))
    }
}
