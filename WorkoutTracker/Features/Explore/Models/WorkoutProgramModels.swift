

import Foundation
internal import SwiftUI

enum ProgramLevel: String, CaseIterable, Identifiable, Sendable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"
    var id: String { rawValue }
    var localizedName: String {
            String(localized: String.LocalizationValue(self.rawValue))
        }
}

enum ProgramGoal: String, CaseIterable, Identifiable, Sendable {
    case buildMuscle = "Build Muscle"
    case getStronger = "Get Stronger"
    case loseWeight = "Lose Weight"
    var id: String { rawValue }
}

enum ProgramEquipment: String, CaseIterable, Identifiable, Sendable {
    case fullGym = "Full Gym"
    case dumbbells = "Dumbbells Only"
    case bodyweight = "Bodyweight"
    var id: String { rawValue }

    var icon: String {
        switch self {
        case .fullGym: return "dumbbell.fill"
        case .dumbbells: return "scalemass.fill"
        case .bodyweight: return "figure.mixed.cardio"
        }
    }
}

enum CatalogFilter: String, CaseIterable, Hashable, Sendable {
    case all = "All"
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"
    case buildMuscle = "Build Muscle"
    case getStronger = "Get Stronger"
    case loseWeight = "Lose Weight"
    case fullGym = "Full Gym"
    case dumbbells = "Dumbbells Only"
    case bodyweight = "Bodyweight"
}

struct WorkoutProgramDefinition: Identifiable, Sendable {
    let id = UUID()
    let title: String
    let description: String
    let level: ProgramLevel
    let goal: ProgramGoal
    let equipment: ProgramEquipment
    let gradientColors: [Color]
    let isSingleRoutine: Bool
    let routines: [WorkoutPresetDTO]
}

@MainActor
struct MockProgramCatalog {
    static let shared = MockProgramCatalog()
    private var theme: AppTheme { ThemeManager.shared.current }

   
    private func routine(_ name: String, icon: String, exercises: [ExerciseDTO]) -> WorkoutPresetDTO {
        WorkoutPresetDTO(name: name, icon: icon, folderName: nil, exercises: exercises)
    }

    private func ex(_ name: String, _ group: String, _ sets: Int, _ reps: Int) -> ExerciseDTO {
        let setList = (1...sets).map { i in
            if reps >= 60 {
                return WorkoutSetDTO(index: i, weight: nil, reps: nil, distance: nil, time: reps, isCompleted: false, type: .normal)
            } else {
                return WorkoutSetDTO(index: i, weight: 0, reps: reps, distance: nil, time: nil, isCompleted: false, type: .normal)
            }
        }

        let type: ExerciseType = reps >= 60 ? .duration : .strength
        return ExerciseDTO(
            name: name,
            muscleGroup: group,
            type: type,
            category: .other,
            effort: 5,
            isCompleted: false,
            setsList: setList,
            subExercises: []
        )
    }
    var featuredPrograms: [WorkoutProgramDefinition] {
        [
            WorkoutProgramDefinition(
                title: "Arnold's Golden 6",
                description: "The classic full-body routine that built the Austrian Oak. Simple, effective, and brutal. Focus on progressive overload and ample rest.",
                level: .intermediate, goal: .buildMuscle, equipment: .fullGym,
                gradientColors: [.orange, .red], isSingleRoutine: true,
                routines: [
                    routine("Full Body Day", icon: "figure.strengthtraining.traditional", exercises: [
                        ex("Barbell Squat", "Legs", 4, 10),
                        ex("Barbell Bench Press", "Chest", 3, 10),
                        ex("Pull-ups", "Back", 3, 10),
                        ex("Overhead Press", "Shoulders", 4, 10),
                        ex("Barbell Curl", "Arms", 3, 10),
                        ex("Crunches", "Core", 3, 20)
                    ])
                ]
            ),
            WorkoutProgramDefinition(
                title: "Push Pull Legs (PPL)",
                description: "The ultimate 3-day split for maximizing muscle growth and recovery. Hits every muscle group optimally.",
                level: .advanced, goal: .buildMuscle, equipment: .fullGym,
                gradientColors: [.purple, .blue], isSingleRoutine: false,
                routines: [
                    routine("Push Day", icon: "arrow.up.right", exercises: [
                        ex("Barbell Bench Press", "Chest", 4, 8),
                        ex("Incline Dumbbell Press", "Chest", 3, 10),
                        ex("Overhead Press", "Shoulders", 4, 8),
                        ex("Lateral Raises", "Shoulders", 3, 15),
                        ex("Tricep Extensions", "Arms", 3, 12)
                    ]),
                    routine("Pull Day", icon: "arrow.down.left", exercises: [
                        ex("Deadlift", "Back", 3, 5),
                        ex("Pull-ups", "Back", 4, 8),
                        ex("Barbell Row", "Back", 3, 10),
                        ex("Face Pulls", "Shoulders", 3, 15),
                        ex("Bicep Curls", "Arms", 3, 12)
                    ]),
                    routine("Legs Day", icon: "figure.run", exercises: [
                        ex("Barbell Squat", "Legs", 4, 8),
                        ex("Leg Press", "Legs", 3, 12),
                        ex("Romanian Deadlift", "Legs", 3, 10),
                        ex("Leg Extensions", "Legs", 3, 15),
                        ex("Calf Raises", "Legs", 4, 15)
                    ])
                ]
            ),
            WorkoutProgramDefinition(
                title: "Home HIIT Shred",
                description: "No equipment? No problem. High-intensity intervals to burn fat fast and build cardiovascular endurance.",
                level: .beginner, goal: .loseWeight, equipment: .bodyweight,
                gradientColors: [.cyan, .green], isSingleRoutine: false,
                routines: [
                    routine("Core Crusher", icon: "flame.fill", exercises: [
                        ex("Plank", "Core", 3, 60),
                        ex("Crunches", "Core", 3, 20),
                        ex("Russian Twists", "Core", 3, 20),
                        ex("Leg Raises", "Core", 3, 15)
                    ]),
                    routine("Full Body Sweat", icon: "drop.fill", exercises: [
                        ex("Jumping Jacks", "Cardio", 4, 60),
                        ex("Push Ups", "Chest", 4, 15),
                        ex("Squat Jumps", "Legs", 4, 15),
                        ex("Burpees", "Cardio", 4, 10)
                    ])
                ]
            ),
            WorkoutProgramDefinition(
                title: "Powerlifting Basics",
                description: "Focus on the big three: Squat, Bench, and Deadlift to build raw, uncompromising strength.",
                level: .intermediate, goal: .getStronger, equipment: .fullGym,
                gradientColors: [.gray, .black], isSingleRoutine: false,
                routines: [
                    routine("Squat Day", icon: "arrow.up.circle.fill", exercises: [
                        ex("Barbell Squat", "Legs", 5, 5),
                        ex("Leg Press", "Legs", 3, 8),
                        ex("Plank", "Core", 3, 60)
                    ]),
                    routine("Bench Day", icon: "arrow.right.circle.fill", exercises: [
                        ex("Barbell Bench Press", "Chest", 5, 5),
                        ex("Close Grip Bench Press", "Triceps", 3, 8),
                        ex("Tricep Extensions", "Arms", 3, 10)
                    ]),
                    routine("Deadlift Day", icon: "arrow.up.down.circle.fill", exercises: [
                        ex("Deadlift", "Back", 5, 5),
                        ex("Barbell Row", "Back", 3, 8),
                        ex("Hamstring Curls", "Legs", 3, 10)
                    ])
                ]
            )
        ]
    }
}
