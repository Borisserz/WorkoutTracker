

internal import SwiftUI
import SwiftData
import Observation

@Observable
@MainActor
final class InWorkoutAICoachViewModel {
    var activeProposal: SmartActionDTO? = nil
    var isProcessing: Bool = false
    var activeCommandId: String? = nil

    @ObservationIgnored private var currentTask: Task<Void, Never>? = nil

    private let workoutService: WorkoutService
    private let aiLogicService: AILogicService
    private let exerciseCatalogService: ExerciseCatalogService
    private let appState: AppStateManager

    init(workoutService: WorkoutService, aiLogicService: AILogicService, analyticsService: AnalyticsService, exerciseCatalogService: ExerciseCatalogService, appState: AppStateManager) {
        self.workoutService = workoutService
        self.aiLogicService = aiLogicService
        self.exerciseCatalogService = exerciseCatalogService
        self.appState = appState
    }

    deinit { currentTask?.cancel() }

    func sendSmartCommand(_ command: String, currentWorkout: Workout) {
        guard !isProcessing, currentWorkout.isActive else { return }

        isProcessing = true
        activeCommandId = command
        activeProposal = nil
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        currentTask?.cancel()
        currentTask = Task {
            do {
                let context = await buildWorkoutContext(currentWorkout, userCommand: command)
                let weightUnit = UnitsManager.shared.weightUnitString()
                let language = Locale.current.language.languageCode?.identifier == "ru" ? "Russian" : "English"

                let result = try await aiLogicService.processSmartAction(
                    commandType: command,
                    workoutContext: context.workout,
                    catalogContext: context.catalog,
                    weightUnit: weightUnit,
                    language: language 
                )

                guard !Task.isCancelled else {
                    self.isProcessing = false; self.activeCommandId = nil; return
                }

                self.activeProposal = result
                self.isProcessing = false
                self.activeCommandId = nil

                let successGen = UINotificationFeedbackGenerator()
                successGen.notificationOccurred(.success)

            } catch {
                self.isProcessing = false
                self.activeCommandId = nil
                self.appState.showError(title: "AI Error", message: "Could not reach the Coach. Please check your connection and try again.")
            }
        }
    }

    func applyActiveProposal(to workout: Workout) {
        guard let proposal = activeProposal else { return }
        Task {
            await workoutService.applySmartAction(proposal, to: workout)
            withAnimation(.spring()) { self.activeProposal = nil }
        }
    }

    func discardProposal() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { activeProposal = nil }
    }

    private func buildWorkoutContext(_ workout: Workout, userCommand: String) async -> (workout: String, catalog: String) {
        guard let activeEx = workout.exercises.first(where: { !$0.isCompleted }) else {
            return ("Workout is already completed.", "")
        }

        let remainingSetsCount = activeEx.setsList.filter({ !$0.isCompleted }).count
        let currentWeight = activeEx.setsList.last(where: { $0.weight != nil })?.weight ?? 0.0
        let unit = UnitsManager.shared.weightUnitString()

        let workoutContextString = """
        CURRENT EXERCISE: \(activeEx.name) (Target: \(activeEx.muscleGroup))
        REMAINING SETS: \(remainingSetsCount)
        CURRENT WEIGHT: \(currentWeight) \(unit)
        """

        let combinedQuery = "\(activeEx.muscleGroup) \(userCommand)"

        let relevantCatalog = await ExerciseDatabaseService.shared.getRelevantExercisesContext(
            for: combinedQuery,
            equipmentPref: "any",
            limit: 15
        )

        let catalogString = relevantCatalog.joined(separator: ", ")

        return (workout: workoutContextString, catalog: catalogString)
    }
}
