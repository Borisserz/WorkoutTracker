import Testing
import AuthenticationServices
@testable import WorkoutTracker

@Suite("CNS Calculator Tests")
struct CNSCalculatorTests {

    @Test("Optimal conditions yield max score")
    func optimalConditions() {
        let score = CNSCalculator.calculate(
            sleepHours: 8.0,
            hrv: 60.0,
            baselineHRV: 40.0,
            rhr: 50.0,
            baselineRHR: 60.0,
            waterCups: 8
        )
        
        #expect(score > 80.0, "Score should be optimal (>80)")
    }

    @Test("Poor conditions yield low score")
    func poorConditions() {
        let score = CNSCalculator.calculate(
            sleepHours: 4.0,
            hrv: 20.0,
            baselineHRV: 50.0,
            rhr: 80.0,
            baselineRHR: 60.0,
            waterCups: 2
        )
        
        #expect(score < 50.0, "Score should be low (<50)")
    }
}

@Suite("Auth session and hydration")
struct AuthAndHydrationTests {

    @Test("Finished bootstrap does not block a new guest session")
    func signOutStartsNewAnonymousSession() {
        let afterSignOut = AnonymousBootstrapPlan.afterCachedTask(hasCurrentUser: false)
        #expect(afterSignOut == .beginAnonymousSignIn)
    }

    @Test("In-flight bootstrap is awaited while a user is still missing")
    func inFlightBootstrapIsAwaited() {
        let step = AnonymousBootstrapPlan.next(hasCurrentUser: false, hasCachedTask: true)
        #expect(step == .awaitCachedTask)
    }

    @Test("Apple cancel is not an auth failure")
    func appleCancelIsIgnored() {
        let error = NSError(
            domain: ASAuthorizationError.errorDomain,
            code: ASAuthorizationError.canceled.rawValue
        )
        #expect(AuthFlow.isCancellation(error))
        let other = NSError(domain: ASAuthorizationError.errorDomain, code: ASAuthorizationError.failed.rawValue)
        #expect(!AuthFlow.isCancellation(other))
    }

    @Test("Logged water wins over Health, including an explicit reset")
    func hydrationDisplayOwnership() {
        #expect(HydrationLog.displayLiters(stored: nil, health: 1.2) == 1.2)
        #expect(HydrationLog.displayLiters(stored: 0.5, health: 1.2) == 0.5)
        #expect(HydrationLog.displayLiters(stored: 0, health: 1.2) == 0)
    }
}

@Suite("Recovery daily badge")
struct RecoveryDailyCheckTests {
    @Test("Badge returns the next calendar day")
    func badgeClearsOnlyForToday() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let today = RecoveryDailyCheck.todayKey(now: now, calendar: calendar)
        let yesterday = RecoveryDailyCheck.todayKey(now: now.addingTimeInterval(-86_400), calendar: calendar)
        #expect(RecoveryDailyCheck.isDue(storedDay: "", now: now, calendar: calendar))
        #expect(!RecoveryDailyCheck.isDue(storedDay: today, now: now, calendar: calendar))
        #expect(RecoveryDailyCheck.isDue(storedDay: yesterday, now: now, calendar: calendar))
    }
}
