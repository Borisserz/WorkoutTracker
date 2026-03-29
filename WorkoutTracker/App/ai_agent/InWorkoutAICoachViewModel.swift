//
//  InWorkoutAICoachViewModel.swift
//  WorkoutTracker
//

internal import SwiftUI
import SwiftData
import Combine

// MARK: - Message Model
struct InWorkoutChatMessage: Identifiable, Equatable {
    let id = UUID()
    let isUser: Bool
    let text: String
    let adjustment: InWorkoutResponseDTO?
    
    var isAnimating: Bool = false
    
    static func == (lhs: InWorkoutChatMessage, rhs: InWorkoutChatMessage) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - ViewModel
@MainActor
final class InWorkoutAICoachViewModel: ObservableObject {
    @Published var chatHistory: [InWorkoutChatMessage] = []
    @Published var isGenerating: Bool = false
    @Published var inputText: String = ""
    
    private let aiService = AILogicService(apiKey: Secrets.geminiApiKey)
    
    init() {
        chatHistory.append(InWorkoutChatMessage(
            isUser: false,
            text: String(localized: "I'm analyzing your current session. How are you feeling? Need to drop the weight or add a finisher?"),
            adjustment: nil
        ))
    }
    
    func sendMessage(currentWorkout: Workout) {
        let prompt = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, !isGenerating else { return }
        
        let userMessage = InWorkoutChatMessage(isUser: true, text: prompt, adjustment: nil)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            chatHistory.append(userMessage)
            inputText = ""
        }
        
        let workoutContext = buildWorkoutContext(workout: currentWorkout)
        requestAdjustment(prompt: prompt, context: workoutContext)
    }
    
    private func buildWorkoutContext(workout: Workout) -> String {
        var context = """
        Current Workout: \(workout.title)
        Duration so far: \(workout.durationSeconds / 60) minutes.
        Effort so far: \(workout.effortPercentage)%
        
        EXERCISES LOGGED SO FAR:
        """
        
        for ex in workout.exercises {
            let completedSets = ex.setsList.filter { $0.isCompleted }
            context += "\n- \(ex.name): \(completedSets.count)/\(ex.setsCount) sets done. "
            if let maxW = completedSets.compactMap({ $0.weight }).max() {
                context += "Max weight: \(maxW)kg."
            }
        }
        return context
    }
    
    private func requestAdjustment(prompt: String, context: String) {
        isGenerating = true
        
        Task {
            do {
                let dto = try await aiService.analyzeActiveWorkout(userMessage: prompt, workoutContext: context)
                
                let aiMessage = InWorkoutChatMessage(
                    isUser: false,
                    text: dto.explanation,
                    // Передаем DTO только если actionType не "none"
                    adjustment: dto.actionType == "none" ? nil : dto
                )
                
                await MainActor.run {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        self.chatHistory.append(aiMessage)
                        self.isGenerating = false
                    }
                }
            } catch {
                await MainActor.run {
                    let errorMessage = InWorkoutChatMessage(
                        isUser: false,
                        text: String(localized: "Oops: \(error.localizedDescription)"),
                        adjustment: nil
                    )
                    withAnimation {
                        self.chatHistory.append(errorMessage)
                        self.isGenerating = false
                    }
                }
            }
        }
    }
}
