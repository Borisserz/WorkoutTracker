import Testing
@testable import WorkoutTracker

@Suite("Calorie Calculator Tests")
struct CalorieCalculatorTests {

    @Test("Calculate Calories for Strength Workout")
    @MainActor
    func testStrengthWorkoutCalories() async throws {
        let workout = Workout()
        workout.durationSeconds = 3600
        let exercise = Exercise(type: .strength, setsList: [
            WorkoutSet(index: 1, isCompleted: true),
            WorkoutSet(index: 2, isCompleted: true),
            WorkoutSet(index: 3, isCompleted: true)
        ])
        workout.exercises = [exercise]

        let cals = CalorieCalculator.calculate(for: workout, userWeight: 80.0)
        
        // 3 sets * 40s = 120s active strength
        // Resting = 3600 - 120 = 3480s
        // Strength Cals = (120/3600) * 6 * 80 = 16
        // Resting Cals = (3480/3600) * 2 * 80 = 154.66
        // Total = 170.66 -> 170
        
        #expect(cals >= 170)
        #expect(cals <= 171)
    }

    @Test("Calculate Calories for Cardio Workout")
    @MainActor
    func testCardioWorkoutCalories() async throws {
        let workout = Workout()
        workout.durationSeconds = 1800
        let exercise = Exercise(type: .cardio, setsList: [
            WorkoutSet(index: 1, time: 900, isCompleted: true),
            WorkoutSet(index: 2, time: 900, isCompleted: true)
        ])
        workout.exercises = [exercise]

        let cals = CalorieCalculator.calculate(for: workout, userWeight: 75.0)
        
        // 1800s active cardio
        // Resting = 0s
        // Cardio Cals = (1800/3600) * 8 * 75 = 300
        
        #expect(cals == 300)
    }
}
