internal import SwiftUI
import SwiftData
import Observation
import Combine // ✅ FIX: Импортируем Combine для подписки на уведомления

@Observable
@MainActor
final class DashboardViewModel {
    
    var lastPerformancesCache: [String: Exercise] = [:]
    var personalRecordsCache: [String: Double] = [:]
    var recoveryStatus: [MuscleRecoveryStatus] = []
    var proactiveProposal: ProactiveWorkoutProposal? = nil
    var dashboardMuscleData: [MuscleCountDTO] = []
    var dashboardTotalExercises: Int = 0
    var dashboardTopExercises: [ExerciseCountDTO] = []
    
    var streakCount: Int = 0
    var bestWeekStats = PeriodStats()
    var bestMonthStats = PeriodStats()
    
    var weakPoints: [WeakPoint] = []
    var recommendations: [Recommendation] = []
    
    private let analyticsService: AnalyticsService
    @ObservationIgnored private var cancellable: AnyCancellable?
    
    init(analyticsService: AnalyticsService) {
        self.analyticsService = analyticsService
        // ✅ FIX: Устанавливаем "слушателя" для события завершения тренировки.
        // Это полностью отделяет Dashboard от WorkoutDetailView.
        self.cancellable = NotificationCenter.default.publisher(for: .workoutCompletedEvent)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                // Как только тренировка завершена, немедленно запускаем полное обновление кэшей.
                self?.refreshAllCaches()
            }
    }
    func refreshAllCaches() {
            Task {
                do {
                    // 1. Получаем свежие данные из базы (фоновый актор)
                    let cacheDTO = try await analyticsService.fetchDashboardCache()
                    
                    // 2. ✅ ИСПРАВЛЕНИЕ: Берем recoveryStatus из свежего DTO
                    let proposal = WorkoutGenerationService.generateProactiveProposal(
                        recoveryStatus: cacheDTO.recoveryStatus,
                        catalog: Exercise.catalog
                    )
                    
                    // 3. ✅ ИСПРАВЛЕНИЕ: Сохраняем в State ViewModel-и
                    self.proactiveProposal = proposal
                    
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
