//
//  DIContainer.swift
//  WorkoutTracker
//

import Foundation
import SwiftData
import Observation

@Observable
final class DIContainer: @unchecked Sendable {
    let modelContainer: ModelContainer
    
    // Core Services
    let appState: AppStateManager
    let liveActivityManager: LiveActivityManager
    
    // ✅ РЕПОЗИТОРИИ
    let catalogRepository: CatalogRepository
    let userRepository: UserRepository
    let workoutStore: WorkoutStore
    let presetRepository: PresetRepository // Добавили репозиторий пресетов
    
    // ✅ СЕРВИСЫ
    let analyticsService: AnalyticsService
    let exerciseCatalogService: ExerciseCatalogService
    let aiLogicService: AILogicService
    let widgetSyncService: WidgetSyncService
    let notificationManager: NotificationManager
    let progressManager: ProgressManager
    
    let workoutService: WorkoutService
    let presetService: PresetService

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        
        self.appState = AppStateManager()
        self.liveActivityManager = LiveActivityManager()
        
        // 1. Инициализируем репозитории БД
        self.catalogRepository = CatalogRepository(modelContainer: modelContainer)
        self.userRepository = UserRepository(modelContainer: modelContainer)
        self.workoutStore = WorkoutStore(modelContainer: modelContainer)
        self.presetRepository = PresetRepository(modelContainer: modelContainer) // Инициализируем новый репозиторий
        
        self.notificationManager = NotificationManager.shared
        self.progressManager = ProgressManager()
        
        // 2. Инициализируем сеть и ИИ
        let geminiClient = GeminiNetworkClient() // Больше не прокидываем apiKey!
        self.aiLogicService = AILogicService(networkClient: geminiClient)
        
        // 3. Инициализируем бизнес-сервисы
        self.analyticsService = AnalyticsService(workoutStore: self.workoutStore, modelContainer: modelContainer)
        self.exerciseCatalogService = ExerciseCatalogService(catalogRepository: self.catalogRepository, workoutStore: self.workoutStore)
        self.widgetSyncService = WidgetSyncService(workoutStore: self.workoutStore, modelContainer: modelContainer)
        
        self.workoutService = WorkoutService(
            workoutStore: self.workoutStore,
            analyticsService: self.analyticsService,
            exerciseCatalogService: self.exerciseCatalogService,
            widgetSyncService: self.widgetSyncService,
            aiLogicService: self.aiLogicService,
            notificationManager: self.notificationManager,
            progressManager: self.progressManager,
            appState: self.appState,
            liveActivityManager: self.liveActivityManager
        )
        
        // ✅ ИСПРАВЛЕНИЕ ОШИБКИ ЗДЕСЬ: передаем presetRepository вместо workoutStore
        self.presetService = PresetService(
            presetRepository: self.presetRepository,
            appState: self.appState
        )
        
        // Предзагрузка маппинга
        MuscleMapping.preload()
        MuscleColorManager.shared.initialize(modelContainer: modelContainer)
    }
    
    // MARK: - ViewModels Factory
    
    @MainActor func makeAICoachViewModel() -> AICoachViewModel {
        AICoachViewModel(
            modelContext: modelContainer.mainContext, // ✅ ПЕРЕДАЕМ MAIN CONTEXT
            workoutService: workoutService,
            aiLogicService: aiLogicService,
            analyticsService: analyticsService,
            exerciseCatalogService: exerciseCatalogService,
            progressManager: progressManager,
            appState: appState
        )
    }
    
    @MainActor func makeUserStatsViewModel() -> UserStatsViewModel {
        UserStatsViewModel(userRepository: userRepository, progressManager: progressManager)
    }
    
    @MainActor func makeDashboardViewModel() -> DashboardViewModel { DashboardViewModel(analyticsService: analyticsService) }
    @MainActor func makeCatalogViewModel() -> CatalogViewModel { CatalogViewModel(exerciseCatalogService: exerciseCatalogService) }
    @MainActor func makeStatsViewModel() -> StatsViewModel { StatsViewModel(analyticsService: analyticsService) }
    @MainActor func makeWorkoutDetailViewModel() -> WorkoutDetailViewModel { WorkoutDetailViewModel(workoutService: workoutService, analyticsService: analyticsService, exerciseCatalogService: exerciseCatalogService, appState: appState) }
    @MainActor func makeExerciseHistoryViewModel(exerciseName: String) -> ExerciseHistoryViewModel { ExerciseHistoryViewModel(exerciseName: exerciseName, analyticsService: analyticsService) }
    @MainActor func makeWorkoutListViewModel() -> WorkoutListViewModel { WorkoutListViewModel() }
    @MainActor func makeProfileViewModel() -> ProfileViewModel { ProfileViewModel(analyticsService: analyticsService) }
}
