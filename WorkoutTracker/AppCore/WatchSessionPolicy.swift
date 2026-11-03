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

    /// Finish snackbar sets `endTime` with `durationSeconds == 0`. Skip finalize until grace elapses
    /// so Hub resume / cleanup cannot process the orphan during undo (default snackbar ~3.5s).
    static func shouldProcessFinishOrphan(
        endTime: Date,
        now: Date = Date(),
        graceSeconds: TimeInterval = 15
    ) -> Bool {
        now.timeIntervalSince(endTime) >= graceSeconds
    }

    /// Phone reserves a short window after allowing Watch `canStartWorkout` so phone Hub start loses the race.
    static func isWatchStartReservationActive(until: Date?, now: Date = Date()) -> Bool {
        guard let until else { return false }
        return now < until
    }

    static let watchStartReservationSeconds: TimeInterval = 8

    /// User-facing copy when an HK workout session fails mid-run (or after start).
    /// Keep in sync with Watch-target `WatchSessionPolicy`.
    static var healthKitSessionFailureMessage: String {
        String(localized: "HealthKit workout session failed. Try again.")
    }
}
