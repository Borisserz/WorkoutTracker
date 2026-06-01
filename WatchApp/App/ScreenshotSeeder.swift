
#if DEBUG
import Foundation
import SwiftData

@MainActor
enum ScreenshotSeeder {
    static func seedIfNeeded(_ context: ModelContext) {
        guard ProcessInfo.processInfo.arguments.contains("-screenshots") else { return }

        // не дублировать, если уже засеяли
        let fd = FetchDescriptor<WorkoutPreset>(predicate: #Predicate { $0.isSystem == false })
        if let existing = try? context.fetch(fd), !existing.isEmpty { return }

        let presets: [WorkoutPreset] = [
            WorkoutPreset(name: "Classic Foundation Six", icon: "🏋️", exercises: [
                Exercise(name: "Squat",          muscleGroup: "Legs",      sets: 4, reps: 8,  weight: 80),
                Exercise(name: "Bench Press",    muscleGroup: "Chest",     sets: 4, reps: 8,  weight: 60),
                Exercise(name: "Deadlift",       muscleGroup: "Back",      sets: 3, reps: 5,  weight: 100),
                Exercise(name: "Overhead Press", muscleGroup: "Shoulders", sets: 3, reps: 10, weight: 40),
                Exercise(name: "Barbell Row",    muscleGroup: "Back",      sets: 3, reps: 10, weight: 50),
                Exercise(name: "Barbell Curl",   muscleGroup: "Arms",      sets: 3, reps: 12, weight: 25),
            ]),
            WorkoutPreset(name: "Quick Home Shred", icon: "🔥", exercises: [
                Exercise(name: "Push-ups",      muscleGroup: "Chest",  sets: 4, reps: 15, weight: 0),
                Exercise(name: "Air Squat",     muscleGroup: "Legs",   sets: 4, reps: 20, weight: 0),
                Exercise(name: "Plank",         muscleGroup: "Core",   type: .duration, sets: 3, reps: 0, timeSeconds: 60),
                Exercise(name: "Jumping Jacks", muscleGroup: "Cardio", type: .cardio,   sets: 3, reps: 30),
                Exercise(name: "Crunches",      muscleGroup: "Core",   sets: 3, reps: 20, weight: 0),
            ]),
            WorkoutPreset(name: "PHUL Hypertrophy", icon: "💪", folderName: "Programs", exercises: [
                Exercise(name: "Incline Bench Press", muscleGroup: "Chest",     sets: 4, reps: 10, weight: 50),
                Exercise(name: "Leg Press",           muscleGroup: "Legs",      sets: 4, reps: 12, weight: 140),
                Exercise(name: "Lat Pulldown",        muscleGroup: "Back",      sets: 4, reps: 12, weight: 55),
                Exercise(name: "Lateral Raise",       muscleGroup: "Shoulders", sets: 3, reps: 15, weight: 10),
                Exercise(name: "Triceps Extension",   muscleGroup: "Arms",      sets: 3, reps: 12, weight: 20),
            ]),
        ]

        presets.forEach { context.insert($0) }
        try? context.save()
        print("⌚️ 🌱 seeded \(presets.count) screenshot presets")
    }
}
#endif
