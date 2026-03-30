//
//  InWorkoutAICoachViewModel.swift
//  WorkoutTracker
//

internal import SwiftUI
import SwiftData
import Combine

struct InWorkoutChatMessage: Identifiable, Equatable {
    let id = UUID()
    let isUser: Bool
    let text: String
    let adjustment: InWorkoutResponseDTO?
    var isAnimating: Bool = false
    
    static func == (lhs: InWorkoutChatMessage, rhs: InWorkoutChatMessage) -> Bool { lhs.id == rhs.id }
}

@MainActor
final class InWorkoutAICoachViewModel: ObservableObject {
    @Published var chatHistory: [InWorkoutChatMessage] = []
    @Published var isGenerating: Bool = false
    @Published var inputText: String = ""
    @Published var focusedExerciseName: String? = nil
    
    // 🚩 Храним ссылку на Task
    private var currentTask: Task<Void, Never>? = nil
    private let aiService = AILogicService(apiKey: Secrets.geminiApiKey)
    
    // 🚩 Очищаем при выгрузке
    deinit {
        currentTask?.cancel()
        print("♻️ InWorkoutAICoachViewModel deallocated, tasks cancelled")
    }
    
    func sendMessage(currentWorkout: Workout, catalog: [String: [String]]) {
        let prompt = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, !isGenerating else { return }
        
        // 🚩 FAST FAIL: Проверка сети перед отправкой ручного запроса
        guard NetworkManager.shared.checkConnection() else {
            let noNetMessage = InWorkoutChatMessage(
                isUser: false,
                text: String(localized: "Internet connection required. Please check your network."),
                adjustment: nil
            )
            withAnimation { chatHistory.append(noNetMessage) }
            return
        }
        
        let userMessage = InWorkoutChatMessage(isUser: true, text: prompt, adjustment: nil)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            chatHistory.append(userMessage)
            inputText = ""
        }
        
        let workoutContext = buildWorkoutContext(workout: currentWorkout, catalog: catalog)
        let savedTone = UserDefaults.standard.string(forKey: "aiCoachTone") ?? "Мотивационный"
        requestAdjustment(prompt: prompt, context: workoutContext, tone: savedTone)
    }
    
    func triggerProactiveFeedback(for set: WorkoutSet, in exerciseName: String, currentWorkout: Workout, catalog: [String: [String]]) {
        guard !isGenerating, currentWorkout.isActive else { return }
        
        // 🚩 FAST FAIL: Проверка сети (Тихий выход, чтобы не спамить ошибками после каждого подхода без интернета)
        guard NetworkManager.shared.checkConnection() else {
            return
        }
        
        let prompt = "System update: I just completed set \(set.index) of \(exerciseName). Give me a short motivating feedback or form tip."
        let workoutContext = buildWorkoutContext(workout: currentWorkout, catalog: catalog)
        let savedTone = UserDefaults.standard.string(forKey: "aiCoachTone") ?? "Мотивационный"
        requestAdjustment(prompt: prompt, context: workoutContext, tone: savedTone)
    }
    
    private func buildWorkoutContext(workout: Workout, catalog: [String: [String]]) -> String {
        var context = """
        STATUS: \(workout.isActive ? "ACTIVE WORKOUT" : "COMPLETED WORKOUT")
        Workout: \(workout.title)
        Duration: \(workout.durationSeconds / 60) mins.
        Effort: \(workout.effortPercentage)%
        
        --- COMPLETED EXERCISES ---
        """
        let completed = workout.exercises.filter { $0.isCompleted }
        if completed.isEmpty { context += "\nNone yet." }
        for ex in completed { context += "\n- \(ex.name): \(ex.setsList.count) sets done." }
        
        if workout.isActive {
            let remaining = workout.exercises.filter { !$0.isCompleted }
            context += "\n\n--- REMAINING EXERCISES ---\n"
            for ex in remaining {
                let doneSets = ex.setsList.filter { $0.isCompleted }.count
                context += "- \(ex.name): \(doneSets)/\(ex.setsCount) sets done.\n"
            }
            
            context += "\n\n--- AVAILABLE EXERCISES CATALOG (FOR REPLACEMENTS) ---\n"
            for (group, exercises) in catalog {
                context += "\(group): \(exercises.joined(separator: ", "))\n"
            }
        }
        
        return context
    }
    
    private func requestAdjustment(prompt: String, context: String, tone: String) {
        isGenerating = true
        currentTask?.cancel()
        
        // 🚩 Используем [weak self]
        currentTask = Task { [weak self] in
            guard let self else { return }
            do {
                let dto = try await self.aiService.analyzeActiveWorkout(userMessage: prompt, workoutContext: context, tone: tone)
                guard !Task.isCancelled else { return }
                
                let aiMessage = InWorkoutChatMessage(isUser: false, text: dto.explanation, adjustment: dto.actionType == "none" ? nil : dto)
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    withAnimation(.spring()) {
                        self.chatHistory.append(aiMessage)
                        self.isGenerating = false
                    }
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.chatHistory.append(InWorkoutChatMessage(isUser: false, text: "Ошибка: \(error.localizedDescription)", adjustment: nil))
                    self.isGenerating = false
                }
            }
        }
    }
}
