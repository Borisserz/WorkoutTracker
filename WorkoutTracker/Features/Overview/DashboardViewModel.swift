internal import SwiftUI
import SwiftData
import Observation
import Combine

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

    var todaySteps: Int = 0
    var todayWaterLiters: Double = 0.0

    var streakCount: Int = 0
    var bestWeekStats = PeriodStats()
    var bestMonthStats = PeriodStats()

    var weakPoints: [WeakPoint] = []
    var recommendations: [Recommendation] = []

    private let analyticsService: AnalyticsService
    @ObservationIgnored private var cancellable: AnyCancellable?

    init(analyticsService: AnalyticsService) {
        self.analyticsService = analyticsService

        self.cancellable = NotificationCenter.default.publisher(for: .workoutCompletedEvent)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in

                self?.refreshAllCaches()
            }
    }

    func refreshAllCaches() {
        Task {
            do {

                try? await HealthKitManager.shared.requestAuthorization()
                let fetchedSteps = (try? await HealthKitManager.shared.fetchSteps()) ?? 0
                let fetchedWater = (try? await HealthKitManager.shared.fetchWaterLiters()) ?? 0.0

                let cacheDTO = try await analyticsService.fetchDashboardCache()
                let currentCatalog = await ExerciseDatabaseService.shared.getCatalog()

                let proposal = WorkoutGenerationService.generateProactiveProposal(
                    recoveryStatus: cacheDTO.recoveryStatus,
                    catalog: currentCatalog
                )

                await MainActor.run {
                    self.todaySteps = fetchedSteps
                    self.todayWaterLiters = fetchedWater

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
                }
            } catch {
                print("Failed to refresh caches: \(error)")
            }
        }
    }
}
