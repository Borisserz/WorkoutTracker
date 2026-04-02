//
//  AICoachViewModel.swift
//  WorkoutTracker
//

internal import SwiftUI
import Combine
import SwiftData
import ActivityKit
import Observation

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

struct AIChatMessage: Identifiable, Equatable, Codable {
    var id = UUID()
    let isUser: Bool
    let text: String
    let proposedWorkout: GeneratedWorkoutDTO?
    var isAnimating: Bool = false
    
    enum CodingKeys: String, CodingKey { case id, isUser, text, proposedWorkout }
    static func == (lhs: AIChatMessage, rhs: AIChatMessage) -> Bool { lhs.id == rhs.id }
}

@Observable
@MainActor
final class AICoachViewModel {
    var chatHistory: [AIChatMessage] = []
    var isGenerating: Bool = false
    var inputText: String = ""
    var currentSession: AIChatSession? = nil
    
    private var currentTask: Task<Void, Never>? = nil
    private let aiService = AILogicService(apiKey: Secrets.geminiApiKey)
    
    private let modelContainer: ModelContainer
    private var context: ModelContext { modelContainer.mainContext }
    
    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }
    
    func loadSession(_ session: AIChatSession) {
        currentTask?.cancel()
        self.isGenerating = false
        self.currentSession = session
        self.chatHistory = session.messages.map {
            var msg = $0; msg.isAnimating = false; return msg
        }
    }
    
    func clearChat() {
        currentTask?.cancel()
        self.isGenerating = false
        self.currentSession = nil
        self.chatHistory.removeAll()
        self.inputText = ""
    }
    
    // ✅ ИЗМЕНЕНИЕ: Теперь принимаем dashboardViewModel
    func sendMessage(workoutViewModel: WorkoutViewModel, dashboardViewModel: DashboardViewModel, catalogViewModel: CatalogViewModel, userWeight: Double, uiText: String? = nil, aiPrompt: String? = nil) {
        
        guard NetworkManager.shared.checkConnection() else {
            let noNetMessage = AIChatMessage(isUser: false, text: String(localized: "Internet connection required. Please check your network."), proposedWorkout: nil, isAnimating: false)
            chatHistory.append(noNetMessage)
            return
        }
        
        let displayText = uiText ?? inputText
        let actualPrompt = aiPrompt ?? displayText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !displayText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !isGenerating else { return }
        
        let userMessage = AIChatMessage(isUser: true, text: displayText, proposedWorkout: nil, isAnimating: false)
        var isFirstMessage = false
        
        if currentSession == nil {
            isFirstMessage = true
            let newSession = AIChatSession(title: "Новый чат...", date: Date(), messages: [])
            context.insert(newSession)
            currentSession = newSession
        }
        currentSession?.messages.append(userMessage)
        currentSession?.date = Date()
        try? context.save()
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            chatHistory.append(userMessage)
            if uiText == nil { inputText = "" }
        }
        
        if isFirstMessage {
            Task.detached { [weak self] in
                guard let self else { return }
                if let newTitle = try? await self.aiService.generateChatTitle(for: actualPrompt) {
                    await MainActor.run { [weak self] in
                        if let session = self?.currentSession {
                            session.title = newTitle.replacingOccurrences(of: "\"", with: "")
                            try? context.save()
                        }
                    }
                }
            }
        }
        
        // ✅ Передаем dashboardViewModel дальше
        requestWorkout(prompt: actualPrompt, workoutViewModel: workoutViewModel, dashboardViewModel: dashboardViewModel, catalogViewModel: catalogViewModel, userWeight: userWeight)
    }
    
    // ✅ ИЗМЕНЕНИЕ: Параметры берутся из dashboardViewModel
    private func requestWorkout(prompt: String, workoutViewModel: WorkoutViewModel, dashboardViewModel: DashboardViewModel, catalogViewModel: CatalogViewModel, userWeight: Double) {
        
        isGenerating = true
        let savedTone = UserDefaults.standard.string(forKey: Constants.UserDefaultsKeys.aiCoachTone.rawValue) ?? Constants.AIConstants.defaultTone
        
        // ✅ ДАННЫЕ ТЕПЕРЬ ИЗ dashboardViewModel
        let workoutsThisWeek = dashboardViewModel.bestWeekStats.workoutCount
        let currentStreak = dashboardViewModel.streakCount
        let fatiguedMuscles = dashboardViewModel.recoveryStatus.filter { $0.recoveryPercentage < 50 }.map { $0.muscleGroup }
        
        let allAvailableExercises = catalogViewModel.combinedCatalog.values.flatMap { $0 }
        
        let userContext = UserProfileContext(
            weightKg: UnitsManager.shared.convertToKilograms(userWeight),
            experienceLevel: "Intermediate",
            favoriteMuscles: [],
            recentPRs: dashboardViewModel.personalRecordsCache, // ✅
            language: Locale.current.language.languageCode?.identifier == "ru" ? "Russian" : "English",
            workoutsThisWeek: workoutsThisWeek,
            currentStreak: currentStreak,
            fatiguedMuscles: fatiguedMuscles,
            availableExercises: allAvailableExercises,
            aiCoachTone: savedTone,
            weightUnit: UnitsManager.shared.weightUnitString()
        )
        
        currentTask = Task { [weak self] in
            guard let self else { return }
            do {
                let response = try await self.aiService.generateWorkoutPlan(userRequest: prompt, userProfile: userContext)
                guard !Task.isCancelled else { return }
                
                let aiMessage = AIChatMessage(isUser: false, text: response.text, proposedWorkout: response.workout, isAnimating: true)
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        self.chatHistory.append(aiMessage)
                        self.currentSession?.messages.append(aiMessage)
                        self.isGenerating = false
                    }
                    try? context.save()
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    let errorMsg = (error as? AILogicError)?.errorDescription ?? error.localizedDescription
                    let errorMessage = AIChatMessage(isUser: false, text: errorMsg, proposedWorkout: nil, isAnimating: false)
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
    
    func acceptWorkout(dto: GeneratedWorkoutDTO, onStart: @escaping (Workout) -> Void) {
        var exercises: [Exercise] = []
        
        for exDTO in dto.exercises {
            let exerciseType = ExerciseType(rawValue: exDTO.type) ?? .strength
            let category = ExerciseCategory.determine(from: exDTO.name)
            
            let newExercise = Exercise(name: exDTO.name, muscleGroup: exDTO.muscleGroup, type: exerciseType, category: category, sets: exDTO.sets, reps: exDTO.reps, weight: exDTO.recommendedWeightKg ?? 0, effort: 5, setsList: [], isCompleted: false)
            context.insert(newExercise)
            
            var setsList: [WorkoutSet] = []
            for i in 1...max(1, exDTO.sets) {
                let set = WorkoutSet(index: i, weight: exDTO.recommendedWeightKg, reps: exerciseType == .strength ? exDTO.reps : nil, distance: exerciseType == .cardio ? (exDTO.recommendedWeightKg ?? 0) : nil, time: exerciseType == .duration ? exDTO.reps : nil, isCompleted: false, type: .normal)
                
                set.exercise = newExercise
                context.insert(set)
                setsList.append(set)
            }
            
            newExercise.setsList = setsList
            newExercise.updateAggregates()
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
