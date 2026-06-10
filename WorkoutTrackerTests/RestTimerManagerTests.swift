import Testing
@testable import WorkoutTracker
import Foundation

@Suite("Rest Timer Manager Tests")
struct RestTimerManagerTests {

    @Test("Test Starting Timer")
    @MainActor
    func testStartTimer() async throws {
        let manager = RestTimerManager()
        
        manager.startRestTimer(duration: 60)
        
        #expect(manager.isRestTimerActive == true)
        #expect(manager.restTimeRemaining == 60)
        #expect(manager.initialRestTime == 60)
        #expect(manager.restTimerFinished == false)
    }

    @Test("Test Adding Time")
    @MainActor
    func testAddingTime() async throws {
        let manager = RestTimerManager()
        manager.startRestTimer(duration: 60)
        
        manager.addRestTime(15)
        
        #expect(manager.initialRestTime == 75)
        #expect(manager.restTimeRemaining == 75)
    }
    
    @Test("Test Subtracting Time")
    @MainActor
    func testSubtractingTime() async throws {
        let manager = RestTimerManager()
        manager.startRestTimer(duration: 60)
        
        manager.subtractRestTime(15)
        
        #expect(manager.restTimeRemaining == 45)
    }

    @Test("Test Subtracting Time to Zero finishes timer")
    @MainActor
    func testSubtractingTimeBelowZero() async throws {
        let manager = RestTimerManager()
        manager.startRestTimer(duration: 60)
        
        manager.subtractRestTime(65)
        
        #expect(manager.restTimeRemaining == 0)
        #expect(manager.restTimerFinished == true)
    }
    
    @Test("Test Stop Timer")
    @MainActor
    func testStopTimer() async throws {
        let manager = RestTimerManager()
        manager.startRestTimer(duration: 60)
        
        manager.stopRestTimer()
        
        #expect(manager.isRestTimerActive == false)
        #expect(manager.restTimerFinished == false)
    }
}
