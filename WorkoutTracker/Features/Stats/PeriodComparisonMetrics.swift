import Foundation

/// Pure period totals for Progress comparison math (unit-tested).
enum PeriodComparisonMetrics {
    static func metricValue(
        _ stats: PeriodStats,
        metric: StatsView.GraphMetric,
        units: UnitsManager
    ) -> Double {
        switch metric {
        case .count: return Double(stats.workoutCount)
        case .volume: return units.convertFromKilograms(stats.totalVolume)
        case .time: return Double(stats.totalDuration) / 60.0
        case .distance: return stats.totalDistance
        }
    }
}
