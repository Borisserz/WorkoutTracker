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
    let workoutStore: WorkoutStore
    let analyticsService: AnalyticsService
    let exerciseCatalogService: ExerciseCatalogService
    let aiLogicService: AILogicService
    let widgetSyncService: WidgetSyncService
    let notificationManager: NotificationManager
    let progressManager: ProgressManager
    
    let workoutService: WorkoutService

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        
        self.workoutStore = WorkoutStore(modelContainer: modelContainer)
        self.notificationManager = NotificationManager.shared
        self.progressManager = ProgressManager()
        self.aiLogicService = AILogicService(apiKey: Secrets.geminiApiKey)
        
        self.analyticsService = AnalyticsService(workoutStore: self.workoutStore, modelContainer: modelContainer)
        self.exerciseCatalogService = ExerciseCatalogService(workoutStore: self.workoutStore)
        self.widgetSyncService = WidgetSyncService(workoutStore: self.workoutStore, modelContainer: modelContainer)
        
        self.workoutService = WorkoutService(
            workoutStore: self.workoutStore,
            analyticsService: self.analyticsService,
            exerciseCatalogService: self.exerciseCatalogService,
            widgetSyncService: self.widgetSyncService,
            aiLogicService: self.aiLogicService,
            notificationManager: self.notificationManager,
            progressManager: self.progressManager
        )
        
        MuscleMapping.preload()
        MuscleColorManager.shared.initialize(modelContainer: modelContainer)
    }
    @MainActor func makeAICoachViewModel() -> AICoachViewModel {
            AICoachViewModel(
                workoutService: workoutService,
                aiLogicService: aiLogicService,
                analyticsService: analyticsService,
                exerciseCatalogService: exerciseCatalogService,
                progressManager: progressManager
            )
        }
    @MainActor func makeDashboardViewModel() -> DashboardViewModel { DashboardViewModel(analyticsService: analyticsService) }
    @MainActor func makeUserStatsViewModel() -> UserStatsViewModel { UserStatsViewModel(workoutStore: workoutStore, progressManager: progressManager) }
    @MainActor func makeCatalogViewModel() -> CatalogViewModel { CatalogViewModel(exerciseCatalogService: exerciseCatalogService) }
  @MainActor func makeStatsViewModel() -> StatsViewModel { StatsViewModel(analyticsService: analyticsService) }
    @MainActor func makeWorkoutDetailViewModel() -> WorkoutDetailViewModel { WorkoutDetailViewModel(workoutService: workoutService, analyticsService: analyticsService, exerciseCatalogService: exerciseCatalogService) }
    @MainActor func makeExerciseHistoryViewModel(exerciseName: String) -> ExerciseHistoryViewModel { ExerciseHistoryViewModel(exerciseName: exerciseName, analyticsService: analyticsService) }
    @MainActor func makeWorkoutListViewModel() -> WorkoutListViewModel { WorkoutListViewModel() }
    @MainActor func makeProfileViewModel() -> ProfileViewModel { ProfileViewModel(analyticsService: analyticsService) }
}
