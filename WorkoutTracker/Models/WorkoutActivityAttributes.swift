

import Foundation
import ActivityKit

struct WorkoutActivityAttributes: ActivityAttributes {

    public struct ContentState: Codable, Hashable {
        var startTime: Date
        var restTimerEndTime: Date?
        var currentExerciseName: String?
        var upcomingWeight: String?
    }

    var workoutTitle: String
}
