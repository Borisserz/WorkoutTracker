//
//  AICoachViewModel.swift
//  WorkoutTracker
//

internal import SwiftUI
import Combine
import SwiftData
import ActivityKit

// MARK: - SwiftData Model
@Model
final class AIChatSession {
    @Attribute(.unique) var id: UUID
    var title: String
    var date: Date
    var messages: [AIChatMessage]
    
    init(id: UUID = UUID(), title: String = "New Chat", date: Date = Date(), messages: [AIChatMessage] = []) {
        self.id = id
        self.title = title
        self.date = date
        self.messages = messages
    }
}

// MARK: - Chat Message Model
struct AIChatMessage: Identifiable, Equatable, Codable {
    var id = UUID()
    let isUser: Bool
    let text: String
    let proposedWorkout: GeneratedWorkoutDTO?
    var isAnimating: Bool = false
    
    enum CodingKeys: String, CodingKey {
        case id, isUser, text, proposedWorkout
    }
    
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
    
    @Published var currentSession: AIChatSession? = nil
    
    private var currentTask: Task<Void, Never>? = nil
    private var typewriterTask: Task<Void, Never>? = nil // Для управления анимацией печати
    
    private let aiService = AILogicService(apiKey: Secrets.geminiApiKey)
    
    init() {}
    
    // MARK: - Session Management
    
    func loadSession(_ session: AIChatSession) {
        currentTask?.cancel()
        typewriterTask?.cancel()
        self.isGenerating = false
        self.currentSession = session
        self.chatHistory = session.messages
    }
    
    func clearChat() {
        currentTask?.cancel()
        typewriterTask?.cancel()
        self.isGenerating = false
        self.currentSession = nil
        self.chatHistory.removeAll()
        self.inputText = ""
    }
    
    // MARK: - Messaging
    
    /// Отправка сообщения с возможностью передать скрытый расширенный промпт для AI
    func sendMessage(workoutViewModel: WorkoutViewModel, userWeight: Double, uiText: String? = nil, aiPrompt: String? = nil, context: ModelContext) {
            let displayText = uiText ?? inputText
            let actualPrompt = aiPrompt ?? displayText.trimmingCharacters(in: .whitespacesAndNewlines)
            
            guard !displayText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !isGenerating else { return }
            
            let userMessage = AIChatMessage(isUser: true, text: displayText, proposedWorkout: nil)
            
            var isFirstMessage = false
            
            if currentSession == nil {
                isFirstMessage = true
                // Временное название, пока ИИ придумывает красивое
                let newSession = AIChatSession(title: "Новый чат...", date: Date(), messages: [])
                context.insert(newSession)
                currentSession = newSession
            }
            
            currentSession?.messages.append(userMessage)
            currentSession?.date = Date()
            try? context.save()
            
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                chatHistory.append(userMessage)
                if uiText == nil {
                    inputText = ""
                }
            }
            
            // Фоновая генерация названия чата
            if isFirstMessage {
                Task.detached {
                    if let newTitle = try? await self.aiService.generateChatTitle(for: actualPrompt) {
                        await MainActor.run {
                            if let session = self.currentSession {
                                session.title = newTitle.replacingOccurrences(of: "\"", with: "")
                                try? context.save()
                            }
                        }
                    }
                }
            }
            
            requestWorkout(prompt: actualPrompt, workoutViewModel: workoutViewModel, userWeight: userWeight, context: context)
        }
    
    private func requestWorkout(prompt: String, workoutViewModel: WorkoutViewModel, userWeight: Double, context: ModelContext) {
            isGenerating = true
        let savedTone = UserDefaults.standard.string(forKey: "aiCoachTone") ?? "Мотивационный"
            let workoutsThisWeek = workoutViewModel.bestWeekStats.workoutCount
            let currentStreak = workoutViewModel.streakCount
            let fatiguedMuscles = workoutViewModel.recoveryStatus
                .filter { $0.recoveryPercentage < 50 }
                .map { $0.muscleGroup }
            
            // НОВОЕ: Достаем все упражнения (стандартные + созданные пользователем) в единый плоский массив
            let allAvailableExercises = workoutViewModel.combinedCatalog.values.flatMap { $0 }
            
            let userContext = UserProfileContext(
                weightKg: UnitsManager.shared.convertToKilograms(userWeight),
                experienceLevel: "Intermediate",
                favoriteMuscles: [],
                recentPRs: workoutViewModel.personalRecordsCache,
                language: Locale.current.language.languageCode?.identifier == "ru" ? "Russian" : "English",
                workoutsThisWeek: workoutsThisWeek,
                currentStreak: currentStreak,
                fatiguedMuscles: fatiguedMuscles,
                availableExercises: allAvailableExercises,
                aiCoachTone: savedTone
            )
        
        currentTask = Task {
            do {
                let response = try await aiService.generateWorkoutPlan(userRequest: prompt, userProfile: userContext)
                guard !Task.isCancelled else { return }
                
                // Создаем пустой "каркас" сообщения перед началом анимации
                let aiMessage = AIChatMessage(
                    isUser: false,
                    text: "",
                    proposedWorkout: response.workout
                )
                
                await MainActor.run {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        self.chatHistory.append(aiMessage)
                        self.currentSession?.messages.append(aiMessage)
                        self.isGenerating = false // Отключаем пульсирующие точки
                    }
                    // Запускаем печатную машинку
                    self.startTypewriter(text: response.text, messageId: aiMessage.id, proposedWorkout: response.workout, context: context)
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    let errorMessage = AIChatMessage(
                        isUser: false,
                        text: String(localized: "Oops, something went wrong: \(error.localizedDescription)"),
                        proposedWorkout: nil
                    )
                    withAnimation {
                        self.chatHistory.append(errorMessage)
                        self.currentSession?.messages.append(errorMessage)
                        try? context.save()
                        self.isGenerating = false
                    }
                }
            }
        }
    }
    
    // MARK: - Typewriter Effect
    private func startTypewriter(text: String, messageId: UUID, proposedWorkout: GeneratedWorkoutDTO?, context: ModelContext) {
        typewriterTask?.cancel()
        
        typewriterTask = Task {
            var currentText = ""
            let chars = Array(text)
            
            for (index, char) in chars.enumerated() {
                guard !Task.isCancelled else { break }
                currentText.append(char)
                
                // Обновляем UI пачками (каждые 3 символа) для плавности и защиты от лагов Скролла
                if index % 3 == 0 || index == chars.count - 1 {
                    await MainActor.run {
                        if let idx = self.chatHistory.firstIndex(where: { $0.id == messageId }) {
                            self.chatHistory[idx] = AIChatMessage(
                                id: messageId,
                                isUser: false,
                                text: currentText,
                                proposedWorkout: proposedWorkout
                            )
                        }
                    }
                }
                
                // Скорость "печатания" (около 12 мс на символ)
                try? await Task.sleep(nanoseconds: 12_000_000)
            }
            
            // Финальное сохранение полностью напечатанного сообщения в SwiftData
            await MainActor.run {
                if let session = self.currentSession, let idx = session.messages.firstIndex(where: { $0.id == messageId }) {
                    session.messages[idx] = AIChatMessage(
                        id: messageId,
                        isUser: false,
                        text: text,
                        proposedWorkout: proposedWorkout
                    )
                    try? context.save()
                }
            }
        }
    }
    
    // MARK: - Workout Acceptance
    func acceptWorkout(dto: GeneratedWorkoutDTO, container: ModelContainer, onStart: @escaping (Workout) -> Void) {
        // Логика формирования тренировки остается без изменений
        let context = ModelContext(container)
        var exercises: [Exercise] = []
        for exDTO in dto.exercises {
            let exerciseType = ExerciseType(rawValue: exDTO.type) ?? .strength
            let category = ExerciseCategory.determine(from: exDTO.name)
            var setsList: [WorkoutSet] = []
            
            for i in 1...max(1, exDTO.sets) {
                let set = WorkoutSet(index: i, weight: exDTO.recommendedWeightKg, reps: exerciseType == .strength ? exDTO.reps : nil, distance: exerciseType == .cardio ? (exDTO.recommendedWeightKg ?? 0) : nil, time: exerciseType == .duration ? exDTO.reps : nil, isCompleted: false, type: .normal)
                context.insert(set)
                setsList.append(set)
            }
            
            let newExercise = Exercise(name: exDTO.name, muscleGroup: exDTO.muscleGroup, type: exerciseType, category: category, sets: exDTO.sets, reps: exDTO.reps, weight: exDTO.recommendedWeightKg ?? 0, effort: 5, setsList: setsList, isCompleted: false)
            context.insert(newExercise)
            exercises.append(newExercise)
        }
        
        let newWorkout = Workout(title: dto.title, date: Date(), icon: "brain.head.profile", exercises: exercises)
        context.insert(newWorkout)
        try? context.save()
        
        let attributes = WorkoutActivityAttributes(workoutTitle: newWorkout.title)
        let state = WorkoutActivityAttributes.ContentState(startTime: Date())
        _ = try? Activity<WorkoutActivityAttributes>.request(attributes: attributes, content: .init(state: state, staleDate: nil), pushType: nil)
        
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        onStart(newWorkout)
    }
}
