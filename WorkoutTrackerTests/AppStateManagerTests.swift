import Testing
@testable import WorkoutTracker
import Foundation

@Suite("App State Manager Tests")
struct AppStateManagerTests {
    
    @Test("Test Show and Clear Error")
    @MainActor
    func testShowAndClearError() async throws {
        let manager = AppStateManager()
        
        #expect(manager.currentError == nil)
        
        manager.showError(title: "Test Error", message: "This is a test")
        
        #expect(manager.currentError != nil)
        #expect(manager.currentError?.title == "Test Error")
        
        manager.clearError()
        #expect(manager.currentError == nil)
    }

    @Test("Test Initial State")
    @MainActor
    func testInitialState() async throws {
        let manager = AppStateManager()
        #expect(manager.selectedTab == 2)
        #expect(manager.isInsideActiveWorkout == false)
        #expect(manager.showGuestSignUpPrompt == false)
    }
}
