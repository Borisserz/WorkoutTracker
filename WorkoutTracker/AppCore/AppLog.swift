import Foundation
import OSLog

/// Central `os.Logger` facades — prefer these over `print` (silent in Release consoles unless enabled).
enum AppLog {
    static let subsystem = Bundle.main.bundleIdentifier ?? "com.borisdev.WorkoutTracker"

    static let analytics = Logger(subsystem: subsystem, category: "Analytics")
    static let health = Logger(subsystem: subsystem, category: "HealthKit")
    static let watch = Logger(subsystem: subsystem, category: "Watch")
    static let firestore = Logger(subsystem: subsystem, category: "Firestore")
    static let remoteConfig = Logger(subsystem: subsystem, category: "RemoteConfig")
    static let data = Logger(subsystem: subsystem, category: "Data")
    static let export = Logger(subsystem: subsystem, category: "Export")
    static let liveActivity = Logger(subsystem: subsystem, category: "LiveActivity")
    static let ml = Logger(subsystem: subsystem, category: "MLVision")
    static let speech = Logger(subsystem: subsystem, category: "Speech")
    static let ui = Logger(subsystem: subsystem, category: "UI")
    static let session = Logger(subsystem: subsystem, category: "Session")
    static let migration = Logger(subsystem: subsystem, category: "Migration")
    static let app = Logger(subsystem: subsystem, category: "App")
    static let catalog = Logger(subsystem: subsystem, category: "Catalog")
    static let presets = Logger(subsystem: subsystem, category: "Presets")
}
