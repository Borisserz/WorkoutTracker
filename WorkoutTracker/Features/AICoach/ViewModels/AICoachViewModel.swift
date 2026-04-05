// ============================================================
// FILE: WorkoutTracker/Features/AICoach/ViewModels/AICoachViewModel.swift
// ============================================================

internal import SwiftUI
import Combine
import SwiftData
import ActivityKit
import Observation

// ВНИМАНИЕ: AIChatSession и AIChatMessage перенесены в DataLayer/Models/AIChatModels.swift

@Observable
@MainActor
final class AICoachViewModel {
    var chatHistory: [AIChatMessage] = []
    var isGenerating: Bool = false
    var inputText: String = ""
    var currentSession: AIChatSession? = nil
    
    @ObservationIgnored private var currentTask: Task<Void, Never>? = nil
    
    private let workoutService: WorkoutService
    private let userRepository: UserRepositoryProtocol
    private let aiLogicService: AILogicService
    private let analyticsService: AnalyticsService
    private let exerciseCatalogService: ExerciseCatalogService
    private let progressManager: ProgressManager
    private let appState: AppStateManager
    
    init(workoutService: WorkoutService,
         userRepository: UserRepositoryProtocol,
         aiLogicService: AILogicService,
         analyticsService: AnalyticsService,
         exerciseCatalogService: ExerciseCatalogService,
         progressManager: ProgressManager,
         appState: AppStateManager) {
        
        self.workoutService = workoutService
        self.userRepository = userRepository
        self.aiLogicService = aiLogicService
        self.analyticsService = analyticsService
        self.exerciseCatalogService = exerciseCatalogService
        self.progressManager = progressManager
        self.appState = appState
    }
    
    deinit {
        currentTask?.cancel()
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
            try? await userRepository.saveAIChatSession(newSession)
            currentSession = newSession
        }
        
        currentSession?.messages.append(userMessage)
        if let session = currentSession {
            try? await userRepository.saveAIChatSession(session)
        }
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            chatHistory.append(userMessage)
            if uiText == nil { inputText = "" }
        }
        
        if isFirstMessage {
            Task.detached {
                if let newTitle = try? await self.aiLogicService.generateChatTitle(for: actualPrompt) {
                    await self.updateSessionTitle(newTitle)
                }
            }
        }
        
        await requestWorkout(prompt: actualPrompt, userWeight: userWeight)
    }
    
    private func updateSessionTitle(_ newTitle: String) async {
        guard let session = currentSession else { return }
        session.title = newTitle.replacingOccurrences(of: "\"", with: "")
        try? await userRepository.saveAIChatSession(session)
    }
    
    private func requestWorkout(prompt: String, userWeight: Double) async {
        isGenerating = true
        let savedTone = UserDefaults.standard.string(forKey: Constants.UserDefaultsKeys.aiCoachTone.rawValue) ?? Constants.AIConstants.defaultTone
        
        let savedRecoveryHours = UserDefaults.standard.double(forKey: Constants.UserDefaultsKeys.userRecoveryHours.rawValue)
        let fullRecoveryHours = savedRecoveryHours > 0 ? savedRecoveryHours : 48.0
        
        let workouts = await analyticsService.fetchRecentWorkoutsForAnalytics()
        let recoveryStatus = await analyticsService.calculateRecovery(hours: fullRecoveryHours, workouts: workouts)
        
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
        
        currentTask?.cancel()
        currentTask = Task {
            do {
                let response = try await aiLogicService.generateWorkoutPlan(userRequest: prompt, userProfile: userContext)
                try Task.checkCancellation()
                
                let aiMessage = AIChatMessage(isUser: false, text: response.text, proposedWorkout: response.workout, isAnimating: true)
                
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    self.chatHistory.append(aiMessage)
                    self.currentSession?.messages.append(aiMessage)
                    self.isGenerating = false
                }
                
                if let session = self.currentSession {
                    try? await userRepository.saveAIChatSession(session)
                }
                
            } catch is CancellationError {
                // Task cancelled
            } catch {
                handleError(error)
            }
        }
    }
    
    private func handleError(_ error: Error) {
        let errorMsg = (error as? AILogicError)?.errorDescription ?? error.localizedDescription
        let errorMessage = AIChatMessage(isUser: false, text: errorMsg, proposedWorkout: nil, isAnimating: false)
        
        withAnimation {
            self.chatHistory.append(errorMessage)
            self.currentSession?.messages.append(errorMessage)
            self.isGenerating = false
        }
        
        if let session = self.currentSession {
            Task { try? await userRepository.saveAIChatSession(session) }
        }
    }
    
    func acceptWorkout(dto: GeneratedWorkoutDTO, onStart: @escaping (Workout) -> Void) async {
        await workoutService.startGeneratedWorkout(dto)
        
        if let latestWorkout = await workoutService.fetchLatestWorkout() {
            onStart(latestWorkout)
        } else {
            appState.showError(title: "Error", message: "Failed to retrieve the generated workout.")
        }
    }
}
