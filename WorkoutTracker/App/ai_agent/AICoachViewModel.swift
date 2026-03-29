//
//  AICoachViewModel.swift
//  WorkoutTracker
//

internal import SwiftUI
import Combine
import SwiftData
import ActivityKit

// MARK: - Chat Message Model
struct AIChatMessage: Identifiable, Equatable {
    let id = UUID()
    let isUser: Bool
    let text: String
    let proposedWorkout: GeneratedWorkoutDTO?
    var isAnimating: Bool = false
    
    static func == (lhs: AIChatMessage, rhs: AIChatMessage) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - AI Coach View Model
@MainActor
final class AICoachViewModel: ObservableObject {
    @Published var chatHistory: [AIChatMessage] = []
    @Published var isGenerating: Bool = false
    @Published var inputText: String = ""
    
    private let aiService = AILogicService(apiKey: Secrets.geminiApiKey)
    
    init() {
        chatHistory.append(AIChatMessage(
            isUser: false,
            text: String(localized: "Hi! I'm your AI Coach. Tell me what you want to train today, how much time you have, or what equipment is available."),
            proposedWorkout: nil
        ))
    }
    
    func sendMessage(workoutViewModel: WorkoutViewModel, userWeight: Double) {
        let prompt = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, !isGenerating else { return }
        
        let userMessage = AIChatMessage(isUser: true, text: prompt, proposedWorkout: nil)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            chatHistory.append(userMessage)
            inputText = ""
        }
        
        requestWorkout(prompt: prompt, workoutViewModel: workoutViewModel, userWeight: userWeight)
    }
    
    private func requestWorkout(prompt: String, workoutViewModel: WorkoutViewModel, userWeight: Double) {
        isGenerating = true
        
        // Собираем контекст пользователя
        let userContext = UserProfileContext(
            weightKg: UnitsManager.shared.convertToKilograms(userWeight),
            experienceLevel: "Intermediate", // Можно брать из настроек
            favoriteMuscles: [],
            recentPRs: workoutViewModel.personalRecordsCache,
            language: Locale.current.language.languageCode?.identifier == "ru" ? "Russian" : "English"
        )
        
        Task {
            do {
                // Запрос к реальному API
                let dto = try await aiService.generateWorkoutPlan(userRequest: prompt, userProfile: userContext)
                
                let aiMessage = AIChatMessage(
                    isUser: false,
                    text: dto.aiMessage,
                    proposedWorkout: dto
                )
                
                await MainActor.run {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        self.chatHistory.append(aiMessage)
                        self.isGenerating = false
                    }
                }
            } catch {
                await MainActor.run {
                    let errorMessage = AIChatMessage(
                        isUser: false,
                        text: String(localized: "Oops, something went wrong: \(error.localizedDescription)"),
                        proposedWorkout: nil
                    )
                    withAnimation {
                        self.chatHistory.append(errorMessage)
                        self.isGenerating = false
                    }
                }
            }
        }
    }
    
    // Сохранение тренировки в SwiftData
    func acceptWorkout(dto: GeneratedWorkoutDTO, container: ModelContainer, onStart: @escaping (Workout) -> Void) {
        let context = ModelContext(container)
        
        var exercises: [Exercise] = []
        for exDTO in dto.exercises {
            let exerciseType = ExerciseType(rawValue: exDTO.type) ?? .strength
            let category = ExerciseCategory.determine(from: exDTO.name)
            
            var setsList: [WorkoutSet] = []
            for i in 1...max(1, exDTO.sets) {
                let set = WorkoutSet(
                    index: i,
                    weight: exDTO.recommendedWeightKg,
                    reps: exerciseType == .strength ? exDTO.reps : nil,
                    distance: exerciseType == .cardio ? (exDTO.recommendedWeightKg ?? 0) : nil,
                    time: exerciseType == .duration ? exDTO.reps : nil,
                    isCompleted: false,
                    type: .normal
                )
                context.insert(set)
                setsList.append(set)
            }
            
            let newExercise = Exercise(
                name: exDTO.name,
                muscleGroup: exDTO.muscleGroup,
                type: exerciseType,
                category: category,
                sets: exDTO.sets,
                reps: exDTO.reps,
                weight: exDTO.recommendedWeightKg ?? 0,
                effort: 5,
                setsList: setsList,
                isCompleted: false
            )
            context.insert(newExercise)
            exercises.append(newExercise)
        }
        
        let newWorkout = Workout(
            title: dto.title,
            date: Date(),
            icon: "brain.head.profile",
            exercises: exercises
        )
        context.insert(newWorkout)
        try? context.save()
        
        // Запуск Live Activity
        let attributes = WorkoutActivityAttributes(workoutTitle: newWorkout.title)
        let state = WorkoutActivityAttributes.ContentState(startTime: Date())
        _ = try? Activity<WorkoutActivityAttributes>.request(
            attributes: attributes,
            content: .init(state: state, staleDate: nil),
            pushType: nil
        )
        
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        onStart(newWorkout)
    }
}
