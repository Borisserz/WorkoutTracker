import Foundation
import OSLog

enum WatchAppLog {
    static let subsystem = Bundle.main.bundleIdentifier ?? "com.borisdev.WorkoutTracker.watchkitapp"
    static let sync = Logger(subsystem: subsystem, category: "Sync")
    static let workout = Logger(subsystem: subsystem, category: "Workout")
    static let seed = Logger(subsystem: subsystem, category: "Seed")
}
