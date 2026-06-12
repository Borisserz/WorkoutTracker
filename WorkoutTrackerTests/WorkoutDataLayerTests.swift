import Testing
import Foundation
@testable import WorkoutTracker

@Suite("Workout Data Layer Tests")
struct WorkoutDataLayerTests {

    @Test("Exercise creation maps correctly to DTO")
    func testExerciseDTO() {
        let exercise = Exercise(
            name: "Squat",
            muscleGroup: "Legs",
            sets: 3,
            reps: 10,
            weight: 100.0,
            effort: 8
        )
        
        let dto = exercise.toDTO()
        #expect(dto.name == "Squat")
        #expect(dto.muscleGroup == "Legs")
        #expect(dto.setsList?.count == 3)
        #expect(dto.setsList?.first?.weight == 100.0)
        #expect(dto.setsList?.first?.reps == 10)
    }

    @Test("Workout DTO calculation")
    func testWorkoutVolumeCalculation() {
        let exercise1 = Exercise(name: "Bench", sets: 2, reps: 10, weight: 50.0)
        let exercise2 = Exercise(name: "Squat", sets: 2, reps: 5, weight: 100.0)
        
        // Mark all sets as completed so volume calculates
        for set in exercise1.setsList { set.isCompleted = true }
        for set in exercise2.setsList { set.isCompleted = true }
        exercise1.isCompleted = true
        exercise2.isCompleted = true

        let totalVolume = exercise1.exerciseVolume + exercise2.exerciseVolume
        
        #expect(totalVolume == (2 * 10 * 50.0) + (2 * 5 * 100.0))
        #expect(totalVolume == 2000.0)
    }
}
