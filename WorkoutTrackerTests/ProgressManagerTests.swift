import Testing
@testable import WorkoutTracker
import Foundation

@Suite("Progress Manager Tests")
struct ProgressManagerTests {
    
    @Test("Test Initial XP and Level")
    @MainActor
    func testInitialProgress() async throws {
        // Since it loads from UserDefaults, let's clear UserDefaults for test
        UserDefaults.standard.removeObject(forKey: "userLevel")
        UserDefaults.standard.removeObject(forKey: "userTotalXP")
        
        let manager = ProgressManager()
        #expect(manager.level == 1)
        #expect(manager.totalXP == 0)
        #expect(manager.currentTitle == "Rookie")
    }

    @Test("Test Adding XP")
    @MainActor
    func testAddingXP() async throws {
        UserDefaults.standard.removeObject(forKey: "userLevel")
        UserDefaults.standard.removeObject(forKey: "userTotalXP")
        let manager = ProgressManager()
        
        let workout = Workout()
        workout.durationSeconds = 3600 // 60 mins -> 300 XP
        let exercise = Exercise(type: .strength, setsList: [WorkoutSet(), WorkoutSet()]) // 2 sets -> 20 XP
        workout.exercises = [exercise]
        
        let breakdown = manager.addXP(for: workout, prCount: 1) // 1 PR -> 50 XP
        // Base 150 + 300 + 20 + 50 = 520
        
        #expect(breakdown.baseXP == 150)
        #expect(breakdown.durationXP == 300)
        #expect(breakdown.setsXP == 20)
        #expect(breakdown.prXP == 50)
        #expect(manager.totalXP >= 520)
    }
}
