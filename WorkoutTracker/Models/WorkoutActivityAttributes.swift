

import Foundation
import ActivityKit

struct WorkoutActivityAttributes: ActivityAttributes {

    public struct ContentState: Codable, Hashable {
        var startTime: Date
        var restTimerEndTime: Date?
        var currentExerciseName: String?
        var upcomingWeight: String?

        /// Safe countdown range when `restTimerEndTime` is strictly in the future; `nil` once expired.
        func activeRestRange(now: Date = Date()) -> ClosedRange<Date>? {
            guard let restEnd = restTimerEndTime, restEnd > now else { return nil }
            return now...restEnd
        }

        /// Safe elapsed-time range preventing `lowerBound > upperBound` on clock skew.
        func activeWorkoutRange(now: Date = Date()) -> ClosedRange<Date> {
            min(startTime, now)...Date.distantFuture
        }
    }

    var workoutTitle: String
}
