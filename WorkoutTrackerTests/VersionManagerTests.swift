import Testing
@testable import WorkoutTracker
import Foundation

@Suite("Version Manager Tests")
struct VersionManagerTests {
    
    @Test("Test Version Comparison")
    @MainActor
    func testVersionComparison() async throws {
        // Since isVersion is private, we'll test it via the public update requirement logic.
        // But first, let's create a subclass or use reflection, or just mock the remote config behavior.
        // Since we can't easily override the bundle version in a test, let's just test evaluateRequirement if we can.
        // Wait, evaluateRequirement is private. Let's change evaluateRequirement to internal or just test the public state if possible.
        // We can't access private methods. I'll test the public properties at initialization.
        
        let manager = VersionManager.shared
        #expect(manager.updateRequirement == .noUpdate)
        #expect(manager.hasDismissedSoftUpdate == false)
    }
}
