import Foundation

/// Pure Watch ↔ phone session gates (unit-tested; no WCSession).
enum WatchSessionPolicy {

    /// Phone reply to Watch `canStartWorkout`.
    static func phoneAllowsWatchStart(
        isSessionStartBlocked: Bool,
        hasModelContainer: Bool,
        freshActiveWorkoutCount: Int
    ) -> Bool {
        if isSessionStartBlocked { return false }
        guard hasModelContainer else { return false }
        return freshActiveWorkoutCount == 0
    }

    /// Watch-side decision before talking to the phone.
    /// - Companion installed but unreachable → refuse (avoid dual active).
    /// - No companion → allow Watch-only standalone.
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

    /// After `sendMessage` reply or transport error.
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
}
