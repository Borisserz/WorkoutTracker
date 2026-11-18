import Foundation
import HealthKit
import SwiftData
import Testing
@testable import WorkoutTracker

@Suite("Wave 3 HealthKit & FoodTracker Sync Tests")
struct Wave3HealthAndFoodSyncTests {

    @Test("HealthKit payload writes totalDistance when cardio sets have distance and omits when zero")
    func testHealthKitPayloadCardioDistance() {
        let withDist = HealthKitManager.buildWorkoutPayload(
            title: "Morning Run",
            calories: 320,
            distanceMeters: 4200
        )
        #expect(withDist.activityType == .running)
        #expect(withDist.distanceQuantity?.doubleValue(for: .meter()) == 4200)
        #expect(withDist.energyQuantity.doubleValue(for: .kilocalorie()) == 320)

        let zeroDist = HealthKitManager.buildWorkoutPayload(
            title: "Upper Body",
            calories: 210,
            distanceMeters: 0
        )
        #expect(zeroDist.activityType == .traditionalStrengthTraining)
        #expect(zeroDist.distanceQuantity == nil)

        // Workout helper computes completed cardio distance across exercises & supersets, ignoring uncompleted sets
        let workout = Workout(title: "Mixed", date: Date())
        let cardio = Exercise(name: "Treadmill", muscleGroup: "Cardio", type: .cardio, isCompleted: true)
        cardio.setsList = [
            WorkoutSet(index: 1, distance: 1500, time: 480, isCompleted: true),
            WorkoutSet(index: 2, distance: 900, time: 300, isCompleted: false)
        ]
        let subCardio = Exercise(name: "Rowing", muscleGroup: "Cardio", type: .cardio, isCompleted: true)
        subCardio.setsList = [
            WorkoutSet(index: 1, distance: 700, time: 180, isCompleted: true)
        ]
        let superset = Exercise(name: "Superset", muscleGroup: "Cardio", type: .strength, subExercises: [subCardio])
        workout.exercises = [cardio, superset]

        #expect(workout.computedCardioDistanceMeters == 2200)
    }

    @Test("WorkoutStore syncs daily FoodTracker calories on completion and subtracts cleanly on delete")
    func testWorkoutStoreSyncsAndSubtractsDailyCalories() async throws {
        let schema = Schema([
            Workout.self, WorkoutPreset.self, ExerciseNote.self, UserStats.self,
            ExerciseStat.self, MuscleStat.self, WeightEntry.self, MuscleColorPreference.self,
            AIChatSession.self, BodyMeasurement.self, ExerciseDictionaryItem.self, UserGoal.self
        ])
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        let suiteName = "wave3.foodtracker.sync.\(UUID().uuidString)"
        let sharedDefaults = try #require(UserDefaults(suiteName: suiteName))
        sharedDefaults.removePersistentDomain(forName: suiteName)
        defer { sharedDefaults.removePersistentDomain(forName: suiteName) }

        let now = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: Date()) ?? Date()
        let dayKey = WorkoutStore.sharedCalorieDateKey(for: now)

        let context = ModelContext(container)
        let w1 = Workout(title: "Push", date: now.addingTimeInterval(-3600))
        w1.endTime = now.addingTimeInterval(-1800)
        w1.durationSeconds = 1800
        let ex1 = Exercise(name: "Bench Press", muscleGroup: "Chest", type: .strength, isCompleted: true)
        ex1.setsList = [WorkoutSet(index: 1, weight: 80, reps: 8, isCompleted: true)]
        w1.exercises = [ex1]

        let w2 = Workout(title: "Run", date: now.addingTimeInterval(-900))
        w2.endTime = now
        w2.durationSeconds = 900
        let ex2 = Exercise(name: "Running", muscleGroup: "Cardio", type: .cardio, isCompleted: true)
        ex2.setsList = [WorkoutSet(index: 1, distance: 3000, time: 900, isCompleted: true)]
        w2.exercises = [ex2]

        context.insert(w1)
        context.insert(w2)
        try context.save()

        let store = WorkoutStore(modelContainer: container)
        let userWeightKg = 80.0
        let expected1 = CalorieCalculator.calculate(for: w1, userWeight: userWeightKg)
        let expected2 = CalorieCalculator.calculate(for: w2, userWeight: userWeightKg)
        #expect(expected1 > 0)
        #expect(expected2 > 0)

        await store.syncSharedDailyCalories(for: now, userWeightKg: userWeightKg, sharedDefaults: sharedDefaults)
        #expect(sharedDefaults.integer(forKey: dayKey) == expected1 + expected2)

        try await store.deleteWorkout(id: w1.id, userWeightKg: userWeightKg, sharedDefaults: sharedDefaults)
        #expect(sharedDefaults.integer(forKey: dayKey) == expected2)

        try await store.deleteWorkout(id: w2.id, userWeightKg: userWeightKg, sharedDefaults: sharedDefaults)
        #expect(sharedDefaults.integer(forKey: dayKey) == 0)
    }
}
