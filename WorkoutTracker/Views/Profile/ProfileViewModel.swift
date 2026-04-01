//
//  ProfileViewModel.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 1.04.26.
//


internal import SwiftUI
import SwiftData
import Observation

@Observable
@MainActor
final class ProfileViewModel {
    
    // Стейты, которые раньше засоряли View
    var cachedAchievements: [Achievement] = []
    var cachedPersonalRecords: [WorkoutViewModel.BestResult] = []
    var topForecast: WorkoutViewModel.ProgressForecast?
    var isLoading: Bool = false
    
    func loadProfileData(
        stats: UserStats,
        currentStreak: Int,
        unitsManager: UnitsManager,
        modelContainer: ModelContainer
    ) {
        self.isLoading = true
        
        // 1. Быстрые синхронные вычисления ачивок
        self.cachedAchievements = AchievementCalculator.calculateAchievements(
            totalWorkouts: stats.totalWorkouts,
            totalVolume: stats.totalVolume,
            totalDistance: stats.totalDistance,
            earlyWorkouts: stats.earlyWorkouts,
            nightWorkouts: stats.nightWorkouts,
            streak: currentStreak,
            unitsManager: unitsManager
        )
        
        // 2. Тяжелые асинхронные запросы (Рекорды и ИИ Прогнозы) выносим в фон
        Task.detached(priority: .userInitiated) {
            let bgContext = ModelContext(modelContainer)
            let descriptor = FetchDescriptor<Workout>(
                predicate: #Predicate<Workout> { $0.endTime != nil }
            )
            
            let bgWorkouts = (try? bgContext.fetch(descriptor)) ?? []
            
            // В фоновом потоке считаем тяжелую математику
            let records = StatisticsManager.getAllPersonalRecords(workouts: bgWorkouts, unitsManager: UnitsManager.shared)
            let forecasts = AnalyticsManager.getProgressForecast(workouts: bgWorkouts)
            let topF = forecasts.first
            
            // Возвращаем результат в MainActor (UI)
            await MainActor.run {
                self.cachedPersonalRecords = records
                self.topForecast = topF
                self.isLoading = false
            }
        }
    }
}
