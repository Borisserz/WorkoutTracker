internal import SwiftUI
import SwiftData
import Observation // ✅ РЕФАКТОРИНГ: Добавлено

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
    // ✅ РЕФАКТОРИНГ: Удалены все @Published
    var chatHistory: [InWorkoutChatMessage] = []
    var isGenerating: Bool = false
    var inputText: String = ""
    var focusedExerciseName: String? = nil
    
    @ObservationIgnored // Игнорируем внутреннее состояние для UI
    private var currentTask: Task<Void, Never>? = nil
    
    @ObservationIgnored
    private let aiService = AILogicService(apiKey: Secrets.geminiApiKey)
    
    deinit { currentTask?.cancel() }
    
    func sendMessage(currentWorkout: Workout, catalog: [String: [String]]) {
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
        
        let contexts = buildWorkoutContext(workout: currentWorkout, catalog: catalog)
        let savedTone = UserDefaults.standard.string(forKey: Constants.UserDefaultsKeys.aiCoachTone.rawValue) ?? Constants.AIConstants.defaultTone
        requestAdjustment(prompt: prompt, workoutContext: contexts.workoutContext, catalogContext: contexts.catalogContext, tone: savedTone, weightUnit: UnitsManager.shared.weightUnitString())
    }
    
    func triggerProactiveFeedback(for set: WorkoutSet?, isLastSet: Bool, isPR: Bool, prLevel: String?, in exerciseName: String, currentWorkout: Workout, catalog: [String: [String]], weightUnit: String) {
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
        
        let contexts = buildWorkoutContext(workout: currentWorkout, catalog: catalog)
        let savedTone = UserDefaults.standard.string(forKey: Constants.UserDefaultsKeys.aiCoachTone.rawValue) ?? Constants.AIConstants.defaultTone
        requestAdjustment(prompt: prompt, workoutContext: contexts.workoutContext, catalogContext: contexts.catalogContext, tone: savedTone, weightUnit: weightUnit)
    }
    
    private func buildWorkoutContext(workout: Workout, catalog: [String: [String]]) -> (workoutContext: String, catalogContext: String) {
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
            for (group, exercises) in catalog { catalogCtx += "\(group): \(exercises.joined(separator: ", "))\n" }
        }
        return (context, catalogCtx)
    }
    
    private func requestAdjustment(prompt: String, workoutContext: String, catalogContext: String, tone: String, weightUnit: String) {
        isGenerating = true
        currentTask?.cancel()
        currentTask = Task { [weak self] in
            guard let self else { return }
            do {
                let dto = try await self.aiService.analyzeActiveWorkout(userMessage: prompt, workoutContext: workoutContext, catalogContext: catalogContext, tone: tone, weightUnit: weightUnit)
                guard !Task.isCancelled else { return }
                
                // ✅ РЕФАКТОРИНГ: Безопасная проверка Enum
                let isNone = dto.actionType == .none || dto.actionType == .unknown
                let aiMessage = InWorkoutChatMessage(isUser: false, text: dto.explanation, adjustment: isNone ? nil : dto, isAnimating: true)
                
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    withAnimation(.spring()) { self.chatHistory.append(aiMessage); self.isGenerating = false }
                }
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
}
