//
//  DashboardViewModel.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 2.04.26.
//
internal import SwiftUI
import SwiftData
import Observation

@Observable
@MainActor
final class DashboardViewModel {
    
    // MARK: - Published Properties (State)
    var lastPerformancesCache: [String: Exercise] = [:]
    var personalRecordsCache: [String: Double] = [:]
    var recoveryStatus: [WorkoutViewModel.MuscleRecoveryStatus] = []
    
    var dashboardMuscleData: [MuscleCountDTO] = []
    var dashboardTotalExercises: Int = 0
    var dashboardTopExercises: [ExerciseCountDTO] = []
    
    var streakCount: Int = 0
    var bestWeekStats = WorkoutViewModel.PeriodStats()
    var bestMonthStats = WorkoutViewModel.PeriodStats()
    
    var weakPoints: [WorkoutViewModel.WeakPoint] = []
    var recommendations: [WorkoutViewModel.Recommendation] = []
    
    // ✅ ИСПРАВЛЕНИЕ: Используем абстракцию репозитория
    private let repository: any WorkoutRepositoryProtocol
    
    init(repository: any WorkoutRepositoryProtocol) {
        self.repository = repository
    }
    
    // MARK: - Background Cache Refresh
    func refreshAllCaches() {
        Task {
            do {
                // ✅ ИСПРАВЛЕНИЕ: Вызываем метод у внедренного репозитория
                let cacheDTO = try await repository.fetchDashboardCache()
                
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
                
                self.recoveryStatus = cacheDTO.recoveryStatus.map {
                    WorkoutViewModel.MuscleRecoveryStatus(muscleGroup: $0.muscleGroup, recoveryPercentage: $0.recoveryPercentage)
                }
                
                self.bestWeekStats = WorkoutViewModel.PeriodStats(workoutCount: cacheDTO.bestWeekStats.workoutCount, totalReps: cacheDTO.bestWeekStats.totalReps, totalDuration: cacheDTO.bestWeekStats.totalDuration, totalVolume: cacheDTO.bestWeekStats.totalVolume, totalDistance: cacheDTO.bestWeekStats.totalDistance)
                
                self.bestMonthStats = WorkoutViewModel.PeriodStats(workoutCount: cacheDTO.bestMonthStats.workoutCount, totalReps: cacheDTO.bestMonthStats.totalReps, totalDuration: cacheDTO.bestMonthStats.totalDuration, totalVolume: cacheDTO.bestMonthStats.totalVolume, totalDistance: cacheDTO.bestMonthStats.totalDistance)
                
                self.weakPoints = cacheDTO.weakPoints.map {
                    WorkoutViewModel.WeakPoint(muscleGroup: $0.muscleGroup, frequency: $0.frequency, averageVolume: $0.averageVolume, recommendation: $0.recommendation)
                }
                
                self.recommendations = cacheDTO.recommendations.compactMap { dto in
                    let type: WorkoutViewModel.RecommendationType
                    switch dto.typeRawValue {
                    case "frequency": type = .frequency; case "volume": type = .volume; case "balance": type = .balance
                    case "recovery": type = .recovery; case "progression": type = .progression; case "positive": type = .positive
                    default: return nil
                    }
                    return WorkoutViewModel.Recommendation(type: type, title: dto.title, message: dto.message, priority: dto.priority)
                }
            } catch {
                print("Failed to refresh caches via Repository: \(error)")
            }
        }
    }
    
    func rebuildAllStats() {
        Task {
            // ✅ ИСПРАВЛЕНИЕ: Вызываем метод у внедренного репозитория
            await repository.rebuildAllStats()
            self.refreshAllCaches()
        }
    }
}
