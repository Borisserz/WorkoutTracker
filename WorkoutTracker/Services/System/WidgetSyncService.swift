import Foundation
import SwiftData
import WidgetKit

actor WidgetSyncService {
    private let workoutStore: WorkoutStoreProtocol
    private let modelContainer: ModelContainer

    init(workoutStore: WorkoutStoreProtocol, modelContainer: ModelContainer) {
        self.workoutStore = workoutStore
        self.modelContainer = modelContainer
    }

    func updateWidgetData() async {
        let bgContext = ModelContext(modelContainer)
        let sixWeeksAgo = Calendar.current.date(byAdding: .weekOfYear, value: -6, to: Date())!
        var desc = FetchDescriptor<Workout>(predicate: #Predicate<Workout> { $0.endTime != nil && $0.date >= sixWeeksAgo }, sortBy: [SortDescriptor(\.date, order: .reverse)])
        desc.fetchLimit = 100
        guard let workouts = try? bgContext.fetch(desc) else { return }

        // Streak needs full history — a 6-week window undercounts long streaks.
        var streakDesc = FetchDescriptor<Workout>(
            predicate: #Predicate<Workout> { $0.endTime != nil },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        streakDesc.fetchLimit = 500
        let streakWorkouts = (try? bgContext.fetch(streakDesc)) ?? workouts
        let currentStreak = calculateWorkoutStreak(workouts: streakWorkouts)
        var points: [WidgetData.WeeklyPoint] = []
        let cal = Calendar.current
        for i in (0...5).reversed() {
            if let date = cal.date(byAdding: .weekOfYear, value: -i, to: Date()) {
                let interval = CalendarDateIntervals.intervalOrFallback(.weekOfYear, containing: date, calendar: cal)
                let count = workouts.filter { interval.contains($0.date) }.count
                let fmt = DateFormatter()
                fmt.dateFormat = "M/d"
                points.append(WidgetData.WeeklyPoint(label: fmt.string(from: interval.start), count: count))
            }
        }

        let totalVolumeKg = workouts.reduce(0.0) { $0 + $1.totalStrengthVolume }
        let totalVolumeTons = totalVolumeKg / 1000.0
        // Honesty: no in-app tip/muscles producer — never copy stale App Group values forever.
        WidgetDataManager.save(
            streak: currentStreak,
            weeklyStats: points,
            recoveredMuscles: [],
            aiTip: "",
            totalVolumeTons: totalVolumeTons
        )
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func calculateWorkoutStreak(workouts: [Workout]) -> Int {
        guard !workouts.isEmpty else { return 0 }
        let maxRestDaysAllowed = UserDefaults.standard.integer(forKey: Constants.UserDefaultsKeys.streakRestDays.rawValue)
        let maxRestDays = maxRestDaysAllowed > 0 ? maxRestDaysAllowed : 2

        let sortedWorkouts = workouts.sorted(by: { $0.date > $1.date })
        let calendar = Calendar.current
        var uniqueWorkoutDays: [Date] = []

        for workout in sortedWorkouts {
            if !uniqueWorkoutDays.contains(where: { calendar.isDate($0, inSameDayAs: workout.date) }) {
                uniqueWorkoutDays.append(workout.date)
            }
        }

        if uniqueWorkoutDays.isEmpty { return 0 }
        let mostRecentWorkoutDate = uniqueWorkoutDays[0]
        if calendar.dateComponents([.day], from: mostRecentWorkoutDate, to: Date()).day ?? 0 > maxRestDays { return 0 }

        var currentStreak = 1
        var lastDate = mostRecentWorkoutDate
        guard uniqueWorkoutDays.count > 1 else { return 1 }

        for i in 1..<uniqueWorkoutDays.count {
            let currentDate = uniqueWorkoutDays[i]
            let daysBetween = calendar.dateComponents([.day], from: currentDate, to: lastDate).day ?? 0
            if daysBetween <= maxRestDays + 1 {
                currentStreak += 1; lastDate = currentDate
            } else { break }
        }
        return currentStreak
    }
}
