import Foundation

/// Watch-target copy of phone `WatchSessionPolicy` (synchronized roots are separate).
enum WatchSessionPolicy {

    static func phoneAllowsWatchStart(
        isSessionStartBlocked: Bool,
        hasModelContainer: Bool,
        freshActiveWorkoutCount: Int
    ) -> Bool {
        if isSessionStartBlocked { return false }
        guard hasModelContainer else { return false }
        return freshActiveWorkoutCount == 0
    }

    static func watchMayAttemptStart(
        sessionActivated: Bool,
        isReachable: Bool,
        hasCompanionApp: Bool
    ) -> WatchStartAttempt {
        guard sessionActivated else { return .refuse }
        if !isReachable {
            return hasCompanionApp ? .refuse : .allowStandalone
        }
        return .askPhone
    }

    static func watchMayStartAfterPhoneHandshake(
        phoneAllowed: Bool?,
        transportFailed: Bool,
        hasCompanionApp: Bool
    ) -> Bool {
        if transportFailed {
            return !hasCompanionApp
        }
        return phoneAllowed ?? false
    }

    enum WatchStartAttempt: Equatable {
        case refuse
        case allowStandalone
        case askPhone
    }

    /// Keep in sync with phone `WatchSessionPolicy` (separate Watch target root).
    static func shouldProcessFinishOrphan(
        endTime: Date,
        now: Date = Date(),
        graceSeconds: TimeInterval = 15
    ) -> Bool {
        now.timeIntervalSince(endTime) >= graceSeconds
    }

    static func isWatchStartReservationActive(until: Date?, now: Date = Date()) -> Bool {
        guard let until else { return false }
        return now < until
    }

    static let watchStartReservationSeconds: TimeInterval = 8

    /// Keep in sync with phone `WatchSessionPolicy` (separate Watch target root).
    static var healthKitSessionFailureMessage: String {
        String(localized: "HealthKit workout session failed. Try again.")
    }
}
