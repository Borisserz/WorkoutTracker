//
//  DashboardViewModel.swift
//  WorkoutTracker
//

internal import SwiftUI
import SwiftData
import Observation

@Observable
@MainActor
final class DashboardViewModel {
    
    var lastPerformancesCache: [String: Exercise] = [:]
    var personalRecordsCache: [String: Double] = [:]
    var recoveryStatus: [MuscleRecoveryStatus] = []
    
    var dashboardMuscleData: [MuscleCountDTO] = []
    var dashboardTotalExercises: Int = 0
    var dashboardTopExercises: [ExerciseCountDTO] = []
    
    var streakCount: Int = 0
    var bestWeekStats = PeriodStats()
    var bestMonthStats = PeriodStats()
    
    var weakPoints: [WeakPoint] = []
    var recommendations: [Recommendation] = []
    
    private let analyticsService: AnalyticsService
    
    init(analyticsService: AnalyticsService) {
            self.analyticsService = analyticsService
            // ❌ УДАЛИЛ: Task { for await _ in await WorkoutEventBus.shared.updates ... }
        }
        
    
    func refreshAllCaches() {
        Task {
            do {
                let cacheDTO = try await analyticsService.fetchDashboardCache()
                
                self.personalRecordsCache = cacheDTO.personalRecords
                self.dashboardTotalExercises = cacheDTO.dashboardTotalExercises
                self.dashboardTopExercises = cacheDTO.dashboardTopExercises
                self.dashboardMuscleData = cacheDTO.dashboardMuscleData
                self.streakCount = cacheDTO.streakCount
                
                var newPerformancesCache: [String: Exercise] = [:]
                for (name, data) in cacheDTO.lastPerformances {
                    if let dto = try? JSONDecoder().decode(ExerciseDTO.self, from: data) {
                        newPerformancesCache[name] = Exercise(from: dto)
                    }
                }
                self.lastPerformancesCache = newPerformancesCache
                self.recoveryStatus = cacheDTO.recoveryStatus
                self.bestWeekStats = cacheDTO.bestWeekStats
                self.bestMonthStats = cacheDTO.bestMonthStats
                self.weakPoints = cacheDTO.weakPoints
                self.recommendations = cacheDTO.recommendations
            } catch {
                print("Failed to refresh caches: \(error)")
            }
        }
    }
}
