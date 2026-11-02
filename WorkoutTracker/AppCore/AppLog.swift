import Foundation
import OSLog

/// Central `os.Logger` facades — prefer these over `print` (silent in Release consoles unless enabled).
enum AppLog: Sendable {
    nonisolated static let subsystem = Bundle.main.bundleIdentifier ?? "com.borisdev.WorkoutTracker"

    nonisolated static let analytics = Logger(subsystem: subsystem, category: "Analytics")
    nonisolated static let health = Logger(subsystem: subsystem, category: "HealthKit")
    nonisolated static let watch = Logger(subsystem: subsystem, category: "Watch")
    nonisolated static let firestore = Logger(subsystem: subsystem, category: "Firestore")
    nonisolated static let remoteConfig = Logger(subsystem: subsystem, category: "RemoteConfig")
    nonisolated static let data = Logger(subsystem: subsystem, category: "Data")
    nonisolated static let export = Logger(subsystem: subsystem, category: "Export")
    nonisolated static let liveActivity = Logger(subsystem: subsystem, category: "LiveActivity")
    nonisolated static let ml = Logger(subsystem: subsystem, category: "MLVision")
    nonisolated static let speech = Logger(subsystem: subsystem, category: "Speech")
    nonisolated static let ui = Logger(subsystem: subsystem, category: "UI")
    nonisolated static let session = Logger(subsystem: subsystem, category: "Session")
    nonisolated static let migration = Logger(subsystem: subsystem, category: "Migration")
    nonisolated static let app = Logger(subsystem: subsystem, category: "App")
    nonisolated static let catalog = Logger(subsystem: subsystem, category: "Catalog")
    nonisolated static let presets = Logger(subsystem: subsystem, category: "Presets")
}
