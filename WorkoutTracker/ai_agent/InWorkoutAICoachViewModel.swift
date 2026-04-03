
internal import SwiftUI
import SwiftData
import Observation

struct InWorkoutChatMessage: Identifiable, Equatable, Codable {
    var id = UUID()
    let isUser: Bool
    let text: String
    let adjustment: InWorkoutResponseDTO?
    var isAnimating: Bool = false
    
    enum CodingKeys: String, CodingKey {
        case id, isUser, text, adjustment, isAnimating
    }
    
    static func == (lhs: InWorkoutChatMessage, rhs: InWorkoutChatMessage) -> Bool { lhs.id == rhs.id }
}

@Observable // ✅ РЕФАКТОРИНГ: Заменяем ObservableObject
@MainActor
final class InWorkoutAICoachViewModel {
    var chatHistory: [InWorkoutChatMessage] = []
    var isGenerating: Bool = false
    var inputText: String = ""
    var focusedExerciseName: String? = nil
    
    @ObservationIgnored // Игнорируем внутреннее состояние для UI
    private var currentTask: Task<Void, Never>? = nil
    
    // ✅ ИСПРАВЛЕНИЕ: Зависимости через DI
    private let workoutService: WorkoutService
    private let aiLogicService: AILogicService
    private let analyticsService: AnalyticsService
    private let exerciseCatalogService: ExerciseCatalogService

    init(workoutService: WorkoutService, aiLogicService: AILogicService, analyticsService: AnalyticsService, exerciseCatalogService: ExerciseCatalogService) {
        self.workoutService = workoutService
        self.aiLogicService = aiLogicService
        self.analyticsService = analyticsService
        self.exerciseCatalogService = exerciseCatalogService
    }
    
    deinit { currentTask?.cancel() }
    
    func sendMessage(currentWorkout: Workout) async {
        let prompt = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, !isGenerating else { return }
        
        guard NetworkManager.shared.checkConnection() else {
            let noNetMessage = InWorkoutChatMessage(isUser: false, text: String(localized: "Internet connection required. Please check your network."), adjustment: nil, isAnimating: false)
            withAnimation { chatHistory.append(noNetMessage) }
            return
        }
        
        let userMessage = InWorkoutChatMessage(isUser: true, text: prompt, adjustment: nil, isAnimating: false)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            chatHistory.append(userMessage)
            inputText = ""
        }
        
        let contexts = await buildWorkoutContext(workout: currentWorkout)
        let savedTone = UserDefaults.standard.string(forKey: Constants.UserDefaultsKeys.aiCoachTone.rawValue) ?? Constants.AIConstants.defaultTone
        await requestAdjustment(prompt: prompt, workoutContext: contexts.workoutContext, catalogContext: contexts.catalogContext, tone: savedTone, weightUnit: UnitsManager.shared.weightUnitString(), currentWorkout: currentWorkout)
    }
    
    func triggerProactiveFeedback(for set: WorkoutSet?, isLastSet: Bool, isPR: Bool, prLevel: String?, in exerciseName: String, currentWorkout: Workout, weightUnit: String) async {
        guard !isGenerating, currentWorkout.isActive else { return }
        guard isLastSet || isPR else { return }
        guard NetworkManager.shared.checkConnection() else { return }
        
        var prompt = ""
        if let s = set { prompt = "System update: I just completed set \(s.index) of \(exerciseName)." } else { prompt = "System update: I just completed an exercise: \(exerciseName)." }
        
        if isPR {
            prompt += " I just hit a new Personal Record: \(prLevel ?? "New Record")! Congratulate me briefly and motivate me."
        } else {
            prompt += " Give me a short motivating feedback or form tip."
        }
        
        let contexts = await buildWorkoutContext(workout: currentWorkout)
        let savedTone = UserDefaults.standard.string(forKey: Constants.UserDefaultsKeys.aiCoachTone.rawValue) ?? Constants.AIConstants.defaultTone
        await requestAdjustment(prompt: prompt, workoutContext: contexts.workoutContext, catalogContext: contexts.catalogContext, tone: savedTone, weightUnit: weightUnit, currentWorkout: currentWorkout)
    }
    
    private func buildWorkoutContext(workout: Workout) async -> (workoutContext: String, catalogContext: String) {
        var context = "STATUS: \(workout.isActive ? "ACTIVE WORKOUT" : "COMPLETED WORKOUT")\nWorkout: \(workout.title)\nDuration: \(workout.durationSeconds / 60) mins.\nEffort: \(workout.effortPercentage)%\n\n--- COMPLETED EXERCISES ---"
        let completed = workout.exercises.filter { $0.isCompleted }
        if completed.isEmpty { context += "\nNone yet." }
        for ex in completed { context += "\n- \(ex.name): \(ex.setsList.count) sets done." }
        
        var catalogCtx = ""
        if workout.isActive {
            let remaining = workout.exercises.filter { !$0.isCompleted }
            context += "\n\n--- REMAINING EXERCISES ---\n"
            for ex in remaining {
                let doneSets = ex.setsList.filter { $0.isCompleted }.count
                context += "- \(ex.name): \(doneSets)/\(ex.setsCount) sets done.\n"
            }
            
            // Получаем объединенный каталог через exerciseCatalogService
            let standardExercises = Exercise.catalog.values.flatMap { $0 }
            let customExercises = (try? await exerciseCatalogService.fetchCustomExercises())?.map { $0.name } ?? []
            let allAvailableExercises = standardExercises + customExercises
            
            for (group, exercises) in Exercise.catalog {
                let filtered = exercises.filter { allAvailableExercises.contains($0) }
                if !filtered.isEmpty {
                    catalogCtx += "\(group): \(filtered.joined(separator: ", "))\n"
                }
            }
        }
        return (context, catalogCtx)
    }
    
    private func requestAdjustment(prompt: String, workoutContext: String, catalogContext: String, tone: String, weightUnit: String, currentWorkout: Workout) async {
        isGenerating = true
        currentTask?.cancel()
        currentTask = Task { [weak self] in
            guard let self else { return }
            do {
                let dto = try await self.aiLogicService.analyzeActiveWorkout(userMessage: prompt, workoutContext: workoutContext, catalogContext: catalogContext, tone: tone, weightUnit: weightUnit)
                guard !Task.isCancelled else { return }
                
                let isNone = dto.actionType == .none || dto.actionType == .unknown
                let aiMessage = InWorkoutChatMessage(isUser: false, text: dto.explanation, adjustment: isNone ? nil : dto, isAnimating: true)
                
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    withAnimation(.spring()) { self.chatHistory.append(aiMessage); self.isGenerating = false }
                }
                
                // Сохраняем историю чата в WorkoutStore
                try await self.workoutService.updateWorkoutChatHistory(workout: currentWorkout, history: self.chatHistory.map { $0.toAIChatMessage() })
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    let errorMsg = (error as? AILogicError)?.errorDescription ?? error.localizedDescription
                    self.chatHistory.append(InWorkoutChatMessage(isUser: false, text: errorMsg, adjustment: nil, isAnimating: false))
                    self.isGenerating = false
                }
            }
        }
    }
    
    func applyAIAdjustment(_ adjustment: InWorkoutResponseDTO, to workout: Workout) async {
        await workoutService.applyAIAdjustment(adjustment, to: workout)
    }
}

extension InWorkoutChatMessage {
    func toAIChatMessage() -> AIChatMessage {
        AIChatMessage(id: self.id, isUser: self.isUser, text: self.text, proposedWorkout: nil, isAnimating: false)
    }
}
