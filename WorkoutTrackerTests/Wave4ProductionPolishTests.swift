import Foundation
import Testing
@testable import WorkoutTracker

@Suite("Wave 4 Production Polish Tests")
struct Wave4ProductionPolishTests {

    @Test("BodyAnalysisEngine cites CNS percentage rather than high muscle readiness when CNS is fatigued")
    func testBodyAnalysisEngineAvoidsReadinessContradictionOnLowCNS() {
        let workout = Workout(title: "Heavy Push", date: Date().addingTimeInterval(-3600))
        workout.endTime = Date()
        let report = BodyAnalysisEngine.generateReport(
            cnsScore: 58,
            recoveryDict: [
                "chest": 90,
                "upper-back": 90,
                "quadriceps": 90,
                "hamstring": 90,
                "lower-back": 90,
                "triceps": 90,
                "biceps": 90
            ],
            recentWorkouts: [workout]
        )

        #expect(!report.nextWorkoutAdvice.recentStrainSummary.contains("90%"))
        #expect(report.nextWorkoutAdvice.recentStrainSummary.contains("58%"))
    }

    @Test("Active workout thumb cockpit offers Add Exercise instead of All sets done on empty session")
    @MainActor
    func testThumbCockpitReturnsAddExerciseWhenWorkoutIsEmpty() {
        #expect(WorkoutDetailThumbPolicy.action(for: []) == .addExercise)

        let ex = Exercise(name: "Bench Press", muscleGroup: "Chest", type: .strength, sets: 1, reps: 8, weight: 60)
        #expect(WorkoutDetailThumbPolicy.action(for: [ex]) == .completeSet(exercise: ex, setIndex: 1, set: ex.sortedSets[0]))

        ex.sortedSets[0].isCompleted = true
        #expect(WorkoutDetailThumbPolicy.action(for: [ex]) == .finishExercise(ex))

        ex.isCompleted = true
        #expect(WorkoutDetailThumbPolicy.action(for: [ex]) == .finishWorkout)
    }

    @Test("LocalizationHelper maps shipped locale codes to English AI language names")
    func testLocalizationHelperAILanguageNameSupportsAllShippedLocales() {
        #expect(LocalizationHelper.shared.getAILanguageName(for: "en") == "English")
        #expect(LocalizationHelper.shared.getAILanguageName(for: "ru") == "Russian")
        #expect(LocalizationHelper.shared.getAILanguageName(for: "de") == "German")
        #expect(LocalizationHelper.shared.getAILanguageName(for: "es") == "Spanish")
        #expect(LocalizationHelper.shared.getAILanguageName(for: "fr") == "French")
    }

    @Test("SpeechRecognizer exposes non-empty localized error messages for permission and availability states")
    func testSpeechRecognizerExposesLocalizedUserFacingMessages() {
        #expect(!SpeechRecognizer.ErrorReason.speechNotAuthorized.localizedMessage.isEmpty)
        #expect(!SpeechRecognizer.ErrorReason.microphoneRequired.localizedMessage.isEmpty)
        #expect(!SpeechRecognizer.ErrorReason.unavailableForLocale.localizedMessage.isEmpty)
    }
}
