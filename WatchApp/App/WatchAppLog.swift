import Foundation
import OSLog

enum WatchAppLog: Sendable {
    nonisolated static let subsystem = Bundle.main.bundleIdentifier ?? "com.borisdev.WorkoutTracker.watchkitapp"
    nonisolated static let sync = Logger(subsystem: subsystem, category: "Sync")
    nonisolated static let workout = Logger(subsystem: subsystem, category: "Workout")
    nonisolated static let seed = Logger(subsystem: subsystem, category: "Seed")
}
