// ============================================================
// FILE: WorkoutTracker/ai_agent/AICoachViewModel.swift
// ============================================================

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
    
    // ✅ ИСПРАВЛЕНИЕ: Зависимости через DI
    private let workoutService: WorkoutService
    private let aiLogicService: AILogicService
    private let analyticsService: AnalyticsService
    private let exerciseCatalogService: ExerciseCatalogService
    private let progressManager: ProgressManager
    
    init(workoutService: WorkoutService, aiLogicService: AILogicService, analyticsService: AnalyticsService, exerciseCatalogService: ExerciseCatalogService, progressManager: ProgressManager) {
        self.workoutService = workoutService
        self.aiLogicService = aiLogicService
        self.analyticsService = analyticsService
        self.exerciseCatalogService = exerciseCatalogService
        self.progressManager = progressManager
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
    
    func sendMessage(userWeight: Double, uiText: String? = nil, aiPrompt: String? = nil) async {
        
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
            await workoutService.saveAIChatSession(newSession) // Делегировано сервису
            currentSession = newSession
        }
        currentSession?.messages.append(userMessage)
        
        // Синхронизируем состояние сессии в БД
        if let session = currentSession {
            await workoutService.saveAIChatSession(session)
        }
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            chatHistory.append(userMessage)
            if uiText == nil { inputText = "" }
        }
        
        if isFirstMessage {
            Task.detached { [weak self] in
                guard let self else { return }
                if let newTitle = try? await self.aiLogicService.generateChatTitle(for: actualPrompt) {
                    await MainActor.run { [weak self] in
                        if let session = self?.currentSession {
                            session.title = newTitle.replacingOccurrences(of: "\"", with: "")
                            // Синхронизируем обновленное название
                            Task { await self?.workoutService.saveAIChatSession(session) }
                        }
                    }
                }
            }
        }
        
        await requestWorkout(prompt: actualPrompt, userWeight: userWeight)
    }
    
    private func requestWorkout(prompt: String, userWeight: Double) async {
        isGenerating = true
        let savedTone = UserDefaults.standard.string(forKey: Constants.UserDefaultsKeys.aiCoachTone.rawValue) ?? Constants.AIConstants.defaultTone
        
        // Получаем данные через AnalyticsService
        let workouts = await analyticsService.fetchRecentWorkoutsForAnalytics()
        let recoveryStatus = await analyticsService.calculateRecovery(hours: nil, workouts: workouts)
        let prCache = await analyticsService.getAllPersonalRecords(workouts: workouts, unitsManager: UnitsManager.shared).reduce(into: [String:Double]()) { $0[$1.exerciseName] = Double($1.value.filter("0123456789.".contains)) ?? 0 }
        let allAvailableExercises = (try? await exerciseCatalogService.fetchCustomExercises())?.map { $0.name } ?? []
        
        let userContext = UserProfileContext(
            weightKg: UnitsManager.shared.convertToKilograms(userWeight),
            experienceLevel: "Intermediate",
            favoriteMuscles: [],
            recentPRs: prCache,
            language: Locale.current.language.languageCode?.identifier == "ru" ? "Russian" : "English",
            workoutsThisWeek: await analyticsService.getStats(for: Calendar.current.dateInterval(of: .weekOfYear, for: Date())!, workouts: workouts).workoutCount,
            currentStreak: await analyticsService.calculateWorkoutStreak(workouts: workouts),
            fatiguedMuscles: recoveryStatus.filter { $0.recoveryPercentage < 50 }.map { $0.muscleGroup },
            availableExercises: Exercise.catalog.values.flatMap { $0 } + allAvailableExercises,
            aiCoachTone: savedTone,
            weightUnit: UnitsManager.shared.weightUnitString()
        )
        
        currentTask = Task { [weak self] in
            guard let self else { return }
            do {
                let response = try await self.aiLogicService.generateWorkoutPlan(userRequest: prompt, userProfile: userContext)
                guard !Task.isCancelled else { return }
                
                let aiMessage = AIChatMessage(isUser: false, text: response.text, proposedWorkout: response.workout, isAnimating: true)
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        self.chatHistory.append(aiMessage)
                        self.currentSession?.messages.append(aiMessage)
                        self.isGenerating = false
                    }
                    if let session = self.currentSession {
                        Task { await self.workoutService.saveAIChatSession(session) }
                    }
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
                        if let session = self.currentSession {
                            Task { await self.workoutService.saveAIChatSession(session) }
                        }
                        self.isGenerating = false
                    }
                }
            }
        }
    }
    
    func acceptWorkout(dto: GeneratedWorkoutDTO, onStart: @escaping (Workout) -> Void) async {
        await workoutService.startGeneratedWorkout(dto)
        
        // После старта, нам нужно получить последнюю тренировку, чтобы вернуть ее в onStart
        if let latestWorkout = await workoutService.fetchLatestWorkout() {
            onStart(latestWorkout)
        } else {
            workoutService.showError(title: "Error", message: "Failed to retrieve the generated workout.")
        }
    }
}
