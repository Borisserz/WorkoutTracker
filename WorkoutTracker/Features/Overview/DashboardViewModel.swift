internal import SwiftUI
import OSLog
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
    private var waterRevision = 0

    var streakCount: Int = 0
    var totalWorkouts: Int = 0
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
            let trace = TrackingManager.shared.startTrace(name: "dashboard_cache_refresh")
            do {

                try? await HealthKitManager.shared.requestAuthorization()
                // After Health sheet (if any) returns — ask for notifications once, not stacked.
                await MainActor.run {
                    NotificationManager.shared.requestPermission()
                }
                let fetchedSteps = (try? await HealthKitManager.shared.fetchSteps()) ?? 0
                let fetchedWater = (try? await HealthKitManager.shared.fetchWaterLiters()) ?? 0.0

                let cacheDTO = try await analyticsService.fetchDashboardCache()
                let currentCatalog = await ExerciseDatabaseService.shared.getCatalog()

                let proposal = WorkoutGenerationService.generateProactiveProposal(
                    recoveryStatus: cacheDTO.recoveryStatus,
                    catalog: currentCatalog
                )

                let revision = self.waterRevision
                let stored = HydrationLog.storedLiters()

                await MainActor.run {
                    self.todaySteps = fetchedSteps
                    if revision == self.waterRevision {
                        self.todayWaterLiters = HydrationLog.displayLiters(stored: stored, health: fetchedWater)
                    }

                    self.proactiveProposal = proposal
                    if let prop = proposal {
                        TrackingManager.shared.track(.proactiveWorkoutShown(reason: prop.workout.title))
                    }
                    self.personalRecordsCache = cacheDTO.personalRecords
                    self.dashboardTotalExercises = cacheDTO.dashboardTotalExercises
                    self.dashboardTopExercises = cacheDTO.dashboardTopExercises
                    self.dashboardMuscleData = cacheDTO.dashboardMuscleData
                    self.streakCount = cacheDTO.streakCount
                    self.totalWorkouts = cacheDTO.totalWorkouts
                    
                    TrackingManager.shared.setUserProperty(name: "current_streak", value: String(cacheDTO.streakCount))
                    TrackingManager.shared.setUserProperty(name: "total_workouts", value: String(cacheDTO.totalWorkouts))

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
                    trace?.stop()
                }
            } catch {
                AppLog.ui.error("Dashboard cache refresh error: \(error.localizedDescription, privacy: .public)")
                trace?.stop()
            }
        }
    }

    func addWater(liters: Double) {
        waterRevision += 1
        let base = HydrationLog.storedLiters() ?? todayWaterLiters
        let updated = max(0.0, base + liters)
        HydrationLog.write(updated)
        todayWaterLiters = updated
        let added = liters
        Task {
            try? await HealthKitManager.shared.saveDietaryWater(liters: added)
        }
    }

    func resetWater() {
        waterRevision += 1
        HydrationLog.write(0)
        todayWaterLiters = 0.0
    }
}

enum HydrationLog {
    static let suiteName = "group.com.borisdev.WorkoutTracker"

    static func storageKey(for date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return "water_liters_\(formatter.string(from: date))"
    }

    static func defaults() -> UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }

    /// `nil` means the app has not logged water today, so Health can fill in.
    /// An explicit `0` is a reset and must stay `0`.
    static func storedLiters(on date: Date = Date()) -> Double? {
        let key = storageKey(for: date)
        let store = defaults()
        guard store.object(forKey: key) != nil else { return nil }
        return store.double(forKey: key)
    }

    static func write(_ liters: Double, on date: Date = Date()) {
        defaults().set(max(0, liters), forKey: storageKey(for: date))
    }

    static func displayLiters(stored: Double?, health: Double) -> Double {
        if let stored { return max(0, stored) }
        return max(0, health)
    }
}
