

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

        self.cachedAchievements = AchievementCalculator.calculateAchievements(
            totalWorkouts: stats.totalWorkouts,
            totalVolume: stats.totalVolume,
            totalDistance: stats.totalDistance,
            earlyWorkouts: stats.earlyWorkouts,
            nightWorkouts: stats.nightWorkouts,
            streak: currentStreak,
            unitsManager: unitsManager
        )

        let bgContext = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<Workout>(predicate: #Predicate<Workout> { $0.endTime != nil })
        let allWorkouts = (try? bgContext.fetch(descriptor)) ?? []

        let records = await analyticsService.getAllPersonalRecords(workouts: allWorkouts, unitsManager: unitsManager)
        let forecasts = await analyticsService.getProgressForecast(workouts: allWorkouts)

        self.cachedPersonalRecords = records
        self.topForecast = forecasts.first
        self.isLoading = false
    }
}
