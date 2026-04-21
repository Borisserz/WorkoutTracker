

internal import SwiftUI
import Combine
import SwiftData
import ActivityKit
import Observation

@Observable
@MainActor
final class AICoachViewModel {
    var chatHistory: [AIChatMessage] = []
    var isGenerating: Bool = false
    var inputText: String = ""
    var currentSession: AIChatSession? = nil

    @ObservationIgnored private var currentTask: Task<Void, Never>? = nil

    private let modelContext: ModelContext
    private let workoutService: WorkoutService
    private let aiLogicService: AILogicService
    private let analyticsService: AnalyticsService
    private let exerciseCatalogService: ExerciseCatalogService
    private let progressManager: ProgressManager
    private let appState: AppStateManager

    init(modelContext: ModelContext, workoutService: WorkoutService, aiLogicService: AILogicService, analyticsService: AnalyticsService, exerciseCatalogService: ExerciseCatalogService, progressManager: ProgressManager, appState: AppStateManager) {
        self.modelContext = modelContext
        self.workoutService = workoutService
        self.aiLogicService = aiLogicService
        self.analyticsService = analyticsService
        self.exerciseCatalogService = exerciseCatalogService
        self.progressManager = progressManager
        self.appState = appState
    }

    deinit { currentTask?.cancel() }

    func loadSession(_ session: AIChatSession) {
        currentTask?.cancel()
        self.isGenerating = false
        self.currentSession = session
        self.chatHistory = session.messages.map { var msg = $0; msg.isAnimating = false; return msg }
    }

    func clearChat() {
        currentTask?.cancel()
        self.isGenerating = false
        self.currentSession = nil
        self.chatHistory.removeAll()
        self.inputText = ""
    }

    func sendMessage(userWeight: Double, uiText: String? = nil, aiPrompt: String? = nil, isExplicitWorkoutRequest: Bool = false) async {
        let displayText = uiText ?? inputText
        let actualPrompt = aiPrompt ?? displayText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !actualPrompt.isEmpty, !isGenerating else { return }

        let userMessage = AIChatMessage(isUser: true, text: displayText, proposedWorkout: nil, isAnimating: false)
        var isFirstMessage = false

        if currentSession == nil {
            isFirstMessage = true
            let newSession = AIChatSession(title: "New Chat...", date: Date(), messages: [])
            modelContext.insert(newSession)
            currentSession = newSession
            try? modelContext.save()
        }

        if let session = currentSession {
            var updatedMessages = session.messages
            updatedMessages.append(userMessage)
            session.messages = updatedMessages
            try? modelContext.save()
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

        isGenerating = true

        if isExplicitWorkoutRequest {

            await requestWorkoutPlan(prompt: actualPrompt, userWeight: userWeight)
        } else {

            let wantsWorkout = (try? await aiLogicService.classifyIntent(userMessage: actualPrompt)) ?? false

            if wantsWorkout {
                await requestWorkoutPlan(prompt: actualPrompt, userWeight: userWeight)
            } else {
                await streamChat(prompt: actualPrompt, userWeight: userWeight)
            }
        }
    }

    private func updateSessionTitle(_ newTitle: String) async {
        guard let session = currentSession else { return }
        session.title = newTitle.replacingOccurrences(of: "\"", with: "")
        try? modelContext.save()
    }

    private func streamChat(prompt: String, userWeight: Double) async {
           let savedTone = UserDefaults.standard.string(forKey: Constants.UserDefaultsKeys.aiCoachTone.rawValue) ?? Constants.AIConstants.defaultTone

           let aiMessageId = UUID()
           let initialAIMessage = AIChatMessage(id: aiMessageId, isUser: false, text: "", proposedWorkout: nil, isAnimating: false)

           withAnimation { self.chatHistory.append(initialAIMessage) }

           let userContext = UserProfileContext(
               weightKg: UnitsManager.shared.convertToKilograms(userWeight), experienceLevel: "Intermediate", favoriteMuscles: [], recentPRs: [:],
               language: Locale.current.language.languageCode?.identifier == "ru" ? "Russian" : "English",
               workoutsThisWeek: 0, currentStreak: 0, fatiguedMuscles: [], availableExercises: [], aiCoachTone: savedTone, weightUnit: UnitsManager.shared.weightUnitString()
           )

           currentTask?.cancel()
           currentTask = Task {
               do {
                   let stream = try await aiLogicService.streamChatResponse(userRequest: prompt, userProfile: userContext)

                   guard let messageIndex = self.chatHistory.firstIndex(where: { $0.id == aiMessageId }) else {
                       handleError(AILogicError.friendlyError)
                       return
                   }

                   var fullText = ""
                   for try await chunk in stream {
                       try Task.checkCancellation()
                       fullText += chunk

                       withAnimation(.linear(duration: 0.1)) {
                           self.chatHistory[messageIndex].text = fullText
                       }
                   }

                   if let session = self.currentSession {
                       var updatedMessages = session.messages
                       updatedMessages.append(self.chatHistory[messageIndex])
                       session.messages = updatedMessages
                   }
                   try? modelContext.save()
                   self.isGenerating = false

               } catch {
                   self.isGenerating = false

                   self.chatHistory.removeAll { $0.id == aiMessageId }
                   handleError(error)
               }
           }
       }

    private func requestWorkoutPlan(prompt: String, userWeight: Double) async {
        let savedTone = UserDefaults.standard.string(forKey: Constants.UserDefaultsKeys.aiCoachTone.rawValue) ?? Constants.AIConstants.defaultTone
        let savedRecoveryHours = UserDefaults.standard.double(forKey: Constants.UserDefaultsKeys.userRecoveryHours.rawValue)
        let fullRecoveryHours = savedRecoveryHours > 0 ? savedRecoveryHours : 48.0

        let workouts = await analyticsService.fetchRecentWorkoutsForAnalytics()
        let recoveryStatus = await analyticsService.calculateRecovery(hours: fullRecoveryHours, workouts: workouts)
        let prCache = await analyticsService.getAllPersonalRecords(workouts: workouts, unitsManager: UnitsManager.shared).reduce(into: [String:Double]()) { $0[$1.exerciseName] = Double($1.value.filter("0123456789.".contains)) ?? 0 }

        let customExercises = (try? await exerciseCatalogService.fetchCustomExercises())?.map { $0.name } ?? []
        var relevantExercises = await ExerciseDatabaseService.shared.getRelevantExercisesContext(for: prompt, equipmentPref: "any", limit: 25)
        relevantExercises.append(contentsOf: customExercises.prefix(5))

        let userContext = UserProfileContext(
            weightKg: UnitsManager.shared.convertToKilograms(userWeight), experienceLevel: "Intermediate", favoriteMuscles: [], recentPRs: prCache,
            language: Locale.current.language.languageCode?.identifier == "ru" ? "Russian" : "English",
            workoutsThisWeek: 0, currentStreak: 0, fatiguedMuscles: recoveryStatus.filter { $0.recoveryPercentage < 50 }.map { $0.muscleGroup },
            availableExercises: relevantExercises, aiCoachTone: savedTone, weightUnit: UnitsManager.shared.weightUnitString()
        )

        currentTask?.cancel()
        currentTask = Task {
            do {
                let response = try await aiLogicService.generateWorkoutPlan(userRequest: prompt, userProfile: userContext)
                try Task.checkCancellation()

                let aiMessage = AIChatMessage(isUser: false, text: response.text, proposedWorkout: response.workout, isAnimating: true)

                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    self.chatHistory.append(aiMessage)
                    if let session = self.currentSession {
                        var updatedMessages = session.messages
                        updatedMessages.append(aiMessage)
                        session.messages = updatedMessages
                    }
                    self.isGenerating = false
                }
                try? modelContext.save()

            } catch {
                self.isGenerating = false
                handleError(error)
            }
        }
    }

    private func handleError(_ error: Error) {
        let errorMsg = (error as? AILogicError)?.errorDescription ?? error.localizedDescription
        let errorMessage = AIChatMessage(isUser: false, text: errorMsg, proposedWorkout: nil, isAnimating: false)

        withAnimation {
            self.chatHistory.append(errorMessage)
            if let session = self.currentSession {
                var updatedMessages = session.messages
                updatedMessages.append(errorMessage)
                session.messages = updatedMessages
            }
        }
        try? modelContext.save()
    }

    func acceptWorkout(dto: GeneratedWorkoutDTO, completion: @escaping (Workout) -> Void) async {
        await workoutService.startGeneratedWorkout(dto)
        if let newWorkout = await workoutService.fetchLatestWorkout() {
            completion(newWorkout)
        }
    }
}
