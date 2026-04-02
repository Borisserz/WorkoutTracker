//
//  ProfileViewModel.swift
//  WorkoutTracker
//

internal import SwiftUI
import SwiftData
import Observation

@Observable
@MainActor
final class ProfileViewModel {
    
    var cachedAchievements: [Achievement] = []
    var cachedPersonalRecords: [BestResult] = []
    var topForecast: ProgressForecast?
    var isLoading: Bool = false
    
    private let analyticsService: AnalyticsService
    
    init(analyticsService: AnalyticsService) {
        self.analyticsService = analyticsService
    }
    
    func loadProfileData(
        stats: UserStats,
        currentStreak: Int,
        unitsManager: UnitsManager,
        modelContainer: ModelContainer
    ) async {
        self.isLoading = true
        
        // 1. Ачивки считаются синхронно (логика внутри AchievementCalculator)
        self.cachedAchievements = AchievementCalculator.calculateAchievements(
            totalWorkouts: stats.totalWorkouts,
            totalVolume: stats.totalVolume,
            totalDistance: stats.totalDistance,
            earlyWorkouts: stats.earlyWorkouts,
            nightWorkouts: stats.nightWorkouts,
            streak: currentStreak,
            unitsManager: unitsManager
        )
        
        // 2. Раньше мы вызывали StatisticsManager / AnalyticsManager.
        // Теперь мы вызываем AnalyticsService (актор), что гораздо безопаснее.
        
        let bgContext = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<Workout>(predicate: #Predicate<Workout> { $0.endTime != nil })
        let allWorkouts = (try? bgContext.fetch(descriptor)) ?? []

        // Вызываем методы актора (функционал тот же самый, просто теперь он внутри сервиса)
        let records = await analyticsService.getAllPersonalRecords(workouts: allWorkouts, unitsManager: unitsManager)
        let forecasts = await analyticsService.getProgressForecast(workouts: allWorkouts)
        
        self.cachedPersonalRecords = records
        self.topForecast = forecasts.first
        self.isLoading = false
    }
}
