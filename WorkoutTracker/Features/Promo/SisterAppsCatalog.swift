import Foundation

struct SisterApp: Identifiable, Equatable, Sendable {
    let id: String
    let nameKey: String
    let taglineKey: String
    let symbolName: String
    let accent: Accent
    let appStoreId: String
    let urlScheme: String?

    enum Accent: String, Sendable {
        case peach, sage, lavender
    }
}

enum SisterAppsCatalog {
    static let all: [SisterApp] = [
        SisterApp(
            id: "foodtracker",
            nameKey: "Food Tracker",
            taglineKey: "Smart nutrition & AI coach",
            symbolName: "fork.knife",
            accent: .peach,
            appStoreId: "6778506345",
            urlScheme: "foodtracker://"
        ),
        SisterApp(
            id: "yoga",
            nameKey: "Yoga Coach & relax",
            taglineKey: "Daily yoga, breath, and calm",
            symbolName: "figure.yoga",
            accent: .sage,
            appStoreId: "6795662863",
            urlScheme: nil
        ),
        SisterApp(
            id: "fitrpg",
            nameKey: "FitRPG",
            taglineKey: "Real reps. Real damage.",
            symbolName: "shield.lefthalf.filled",
            accent: .lavender,
            appStoreId: "6785639478",
            urlScheme: nil
        ),
    ]

    static func appStoreURL(for app: SisterApp) -> URL? {
        URL(string: "https://apps.apple.com/app/id\(app.appStoreId)")
    }
}

enum SisterAppsPromoFlags {
    static let seenKey = "hasSeenSisterAppsPromo"
    static let legacyFoodTrackerSeenKey = "hasSeenFoodTrackerPromo"

    static func hasSeenPromo(defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: seenKey) || defaults.bool(forKey: legacyFoodTrackerSeenKey)
    }

    static func markSeen(defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: seenKey)
        defaults.set(true, forKey: legacyFoodTrackerSeenKey)
    }
}
