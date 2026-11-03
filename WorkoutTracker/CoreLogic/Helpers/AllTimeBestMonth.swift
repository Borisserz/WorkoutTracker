import Foundation

/// One finished session reduced to the scalars the all-time month card needs.
struct FinishedSessionSample: Sendable, Equatable {
    var date: Date
    var volumeKg: Double
    var reps: Int
    var durationMinutes: Int
    var distanceMeters: Double
}

/// Picks the calendar month with the most finished sessions across the full history.
enum AllTimeBestMonth {
    static func rank(samples: [FinishedSessionSample], calendar: Calendar = .current) -> PeriodStats {
        guard !samples.isEmpty else { return PeriodStats() }

        var grouped: [Date: [FinishedSessionSample]] = [:]
        for sample in samples {
            guard let interval = calendar.dateInterval(of: .month, for: sample.date) else { continue }
            grouped[interval.start, default: []].append(sample)
        }

        var best = PeriodStats()
        var bestStart = Date.distantFuture
        for (start, monthSamples) in grouped {
            let stats = periodStats(from: monthSamples)
            let winsCount = stats.workoutCount > best.workoutCount
            let tiesOnEarlierMonth = stats.workoutCount == best.workoutCount && start < bestStart
            if winsCount || tiesOnEarlierMonth {
                best = stats
                bestStart = start
            }
        }
        return best
    }

    private static func periodStats(from samples: [FinishedSessionSample]) -> PeriodStats {
        var stats = PeriodStats()
        stats.workoutCount = samples.count
        for sample in samples {
            stats.totalVolume += sample.volumeKg
            stats.totalReps += sample.reps
            stats.totalDuration += sample.durationMinutes
            stats.totalDistance += sample.distanceMeters
        }
        return stats
    }
}
