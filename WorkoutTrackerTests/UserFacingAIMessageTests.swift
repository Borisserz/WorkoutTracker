import Foundation
import Testing
@testable import WorkoutTracker

@Suite("User-facing AI errors")
struct UserFacingAIMessageTests {

    @Test("offline URLError maps to friendly copy, not raw localizedDescription")
    func offlineIsFriendly() {
        let error = URLError(.notConnectedToInternet)
        #expect(error.userFacingAIMessage == String(localized: "You're offline. Check your connection and try again."))
        #expect(error.userFacingAIMessage != error.localizedDescription)
    }

    @Test("timedOut URLError maps to friendly timeout copy")
    func timeoutIsFriendly() {
        let error = URLError(.timedOut)
        #expect(error.userFacingAIMessage == String(localized: "The request timed out. Check your connection and try again."))
    }

    @Test("HTTP 400 uses the catalog string, not the server body")
    func badRequestIsCatalogCopy() {
        let error = AILogicError.apiError(statusCode: 400, message: "payload too large")
        #expect(error.userFacingAIMessage == String(localized: "The request was invalid or too large. Please try asking a shorter question."))
        #expect(!error.userFacingAIMessage.contains("payload too large"))
    }

    @Test("AILogicError prefers its own description")
    func aiLogicConsent() {
        let error = AILogicError.aiConsentRequired
        #expect(error.userFacingAIMessage == error.errorDescription)
    }

    @Test("unknown errors stay generic, never leak internals")
    func unknownIsGeneric() {
        struct Weird: Error {}
        #expect(Weird().userFacingAIMessage == String(localized: "Something went wrong. Please try again."))
    }
}
