

import Foundation
import ActivityKit

struct WorkoutActivityAttributes: ActivityAttributes {

    public struct ContentState: Codable, Hashable {
        var startTime: Date
    }

    var workoutTitle: String
}
