import Foundation

/// Safe Calendar date-interval helpers — never force-unwrap `dateInterval` / `date(byAdding:)`.
enum CalendarDateIntervals {
    static func interval(
        _ component: Calendar.Component,
        containing date: Date,
        calendar: Calendar = .current
    ) -> DateInterval? {
        calendar.dateInterval(of: component, for: date)
    }

    /// Falls back to a synthetic window when Calendar cannot form an interval (rare calendar configs).
    static func intervalOrFallback(
        _ component: Calendar.Component,
        containing date: Date,
        calendar: Calendar = .current,
        fallbackDays: Int = 7
    ) -> DateInterval {
        if let interval = calendar.dateInterval(of: component, for: date) {
            return interval
        }
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: max(1, fallbackDays), to: start) ?? start.addingTimeInterval(86400)
        return DateInterval(start: start, end: end)
    }

    static func previousInterval(
        _ component: Calendar.Component,
        before date: Date,
        calendar: Calendar = .current,
        fallbackDays: Int = 7
    ) -> DateInterval {
        let offset: (Calendar.Component, Int)
        switch component {
        case .weekOfYear: offset = (.day, -7)
        case .month: offset = (.month, -1)
        case .year: offset = (.year, -1)
        default: offset = (.day, -fallbackDays)
        }
        let shifted = calendar.date(byAdding: offset.0, value: offset.1, to: date) ?? date.addingTimeInterval(TimeInterval(-86400 * fallbackDays))
        return intervalOrFallback(component, containing: shifted, calendar: calendar, fallbackDays: fallbackDays)
    }

    static func groupWorkouts(
        _ workouts: [Workout],
        by component: Calendar.Component,
        calendar: Calendar = .current
    ) -> [DateInterval: [Workout]] {
        var grouped: [DateInterval: [Workout]] = [:]
        for workout in workouts {
            guard let interval = calendar.dateInterval(of: component, for: workout.date) else { continue }
            grouped[interval, default: []].append(workout)
        }
        return grouped
    }
}
