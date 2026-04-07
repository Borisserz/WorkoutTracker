// ============================================================
// FILE: WorkoutTracker/Features/Explore/Models/WorkoutProgramModels.swift
// ============================================================

import Foundation
internal import SwiftUI

enum ProgramLevel: String, CaseIterable, Identifiable, Sendable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"
    var id: String { rawValue }
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

// MARK: - Expanded Mock Catalog
@MainActor
struct MockProgramCatalog {
    static let shared = MockProgramCatalog()
    
    let programs: [WorkoutProgramDefinition] = [
        // MARK: - MULTI-DAY PROGRAMS
        
        WorkoutProgramDefinition(
            title: "Beginner PPL",
            description: "The ultimate Push/Pull/Legs split designed to build a solid foundation of muscle and strength.",
            level: .beginner,
            goal: .buildMuscle,
            equipment: .fullGym,
            gradientColors: [Color.blue, Color.cyan],
            isSingleRoutine: false,
            routines: [
                routine("Push: Chest, Shoulders, Triceps", icon: "img_chest", exercises: [
                    ex("Bench Press", "Chest", 3, 8),
                    ex("Incline Dumbbell Press", "Chest", 3, 10),
                    ex("Overhead Press", "Shoulders", 3, 8),
                    ex("Lateral Raises", "Shoulders", 3, 15),
                    ex("Triceps Extension", "Arms", 3, 12)
                ]),
                routine("Pull: Back & Biceps", icon: "img_back", exercises: [
                    ex("Deadlift", "Back", 3, 5),
                    ex("Pull-ups", "Back", 3, 8),
                    ex("Barbell Rows", "Back", 3, 10),
                    ex("Face Pulls", "Shoulders", 3, 15),
                    ex("Barbell Curl", "Arms", 3, 10)
                ]),
                routine("Legs & Core", icon: "img_legs", exercises: [
                    ex("Squat", "Legs", 3, 8),
                    ex("Leg Press", "Legs", 3, 12),
                    ex("Romanian Deadlift", "Legs", 3, 10),
                    ex("Calf Raises", "Legs", 4, 15),
                    ex("Plank", "Core", 3, 60)
                ])
            ]
        ),
        
        WorkoutProgramDefinition(
            title: "PHUL Hypertrophy",
            description: "Power Hypertrophy Upper Lower. A 4-day split maximizing both raw strength and muscle hypertrophy.",
            level: .intermediate,
            goal: .buildMuscle,
            equipment: .fullGym,
            gradientColors: [Color.purple, Color.indigo],
            isSingleRoutine: false,
            routines: [
                routine("Upper Power", icon: "img_default", exercises: [
                    ex("Bench Press", "Chest", 4, 5),
                    ex("Incline Dumbbell Press", "Chest", 3, 8),
                    ex("Barbell Rows", "Back", 4, 5),
                    ex("Lat Pulldown", "Back", 3, 8),
                    ex("Overhead Press", "Shoulders", 3, 8)
                ]),
                routine("Lower Power", icon: "img_legs2", exercises: [
                    ex("Squat", "Legs", 4, 5),
                    ex("Deadlift", "Back", 4, 5),
                    ex("Leg Press", "Legs", 3, 10),
                    ex("Calf Raises", "Legs", 4, 15)
                ]),
                routine("Upper Hypertrophy", icon: "img_arms", exercises: [
                    ex("Incline Bench Press", "Chest", 4, 12),
                    ex("Cable Crossover", "Chest", 3, 15),
                    ex("Seated Cable Row", "Back", 4, 12),
                    ex("Lateral Raises", "Shoulders", 4, 15),
                    ex("Triceps Pushdown", "Arms", 3, 12),
                    ex("Bicep Curls", "Arms", 3, 12)
                ]),
                routine("Lower Hypertrophy", icon: "img_legs", exercises: [
                    ex("Front Squat", "Legs", 4, 10),
                    ex("Bulgarian Split Squat", "Legs", 3, 12),
                    ex("Leg Curls", "Legs", 4, 15),
                    ex("Standing Calf Raise", "Legs", 4, 20)
                ])
            ]
        ),
        
        WorkoutProgramDefinition(
            title: "Advanced Bro Split",
            description: "The classic 5-day bodybuilding split. Destroy one muscle group per day with extreme volume.",
            level: .advanced,
            goal: .buildMuscle,
            equipment: .fullGym,
            gradientColors: [Color.red, Color(hex: "1a1a1a")],
            isSingleRoutine: false,
            routines: [
                routine("Chest Day", icon: "img_chest2", exercises: [ex("Bench Press", "Chest", 4, 8), ex("Incline Dumbbell Press", "Chest", 4, 10), ex("Dumbbell Flyes", "Chest", 4, 12), ex("Cable Crossover", "Chest", 4, 15)]),
                routine("Back Day", icon: "img_back2", exercises: [ex("Deadlift", "Back", 4, 5), ex("Pull-ups", "Back", 4, 8), ex("T-Bar Row", "Back", 4, 10), ex("Lat Pulldown", "Back", 4, 12)]),
                routine("Legs Day", icon: "img_legs", exercises: [ex("Squat", "Legs", 4, 8), ex("Leg Press", "Legs", 4, 12), ex("Leg Extensions", "Legs", 4, 15), ex("Leg Curls", "Legs", 4, 15)]),
                routine("Shoulder Day", icon: "img_shoulders", exercises: [ex("Overhead Press", "Shoulders", 4, 8), ex("Arnold Press", "Shoulders", 4, 10), ex("Lateral Raises", "Shoulders", 5, 15), ex("Face Pulls", "Shoulders", 4, 15)]),
                routine("Arms Day", icon: "img_arms", exercises: [ex("Barbell Curl", "Arms", 4, 10), ex("Triceps Extension", "Arms", 4, 10), ex("Hammer Curls", "Arms", 4, 12), ex("Skull Crushers", "Arms", 4, 12)])
            ]
        ),
        
        // MARK: - SINGLE ROUTINES
        
        WorkoutProgramDefinition(
            title: "Arnold's Golden Six",
            description: "A legendary full-body single routine. Arnold Schwarzenegger used this to build his early mass.",
            level: .intermediate,
            goal: .buildMuscle,
            equipment: .fullGym,
            gradientColors: [Color.yellow, Color.orange],
            isSingleRoutine: true,
            routines: [
                routine("Arnold's Golden Six", icon: "img_default", exercises: [
                    ex("Squat", "Legs", 4, 10),
                    ex("Bench Press", "Chest", 3, 10),
                    ex("Pull-ups", "Back", 3, 10),
                    ex("Overhead Press", "Shoulders", 4, 10),
                    ex("Barbell Curl", "Arms", 3, 10),
                    ex("Crunches", "Core", 3, 20)
                ])
            ]
        ),
        
        WorkoutProgramDefinition(
            title: "Madcow 5x5",
            description: "A single heavy session focused entirely on the big three compound lifts for maximum nervous system output.",
            level: .advanced,
            goal: .getStronger,
            equipment: .fullGym,
            gradientColors: [Color.gray, Color.black],
            isSingleRoutine: true,
            routines: [
                routine("Madcow 5x5", icon: "img_default", exercises: [
                    ex("Squat", "Legs", 5, 5),
                    ex("Bench Press", "Chest", 5, 5),
                    ex("Barbell Rows", "Back", 5, 5)
                ])
            ]
        ),
        
        WorkoutProgramDefinition(
            title: "Quick Home Shred",
            description: "High-intensity dumbbell and bodyweight circuit. Burn fat and keep muscle without stepping foot in a gym.",
            level: .beginner,
            goal: .loseWeight,
            equipment: .dumbbells,
            gradientColors: [Color.green, Color.teal],
            isSingleRoutine: true,
            routines: [
                routine("Quick Home Shred", icon: "img_arms", exercises: [
                    ex("Dumbbell Goblet Squat", "Legs", 4, 15),
                    ex("Push Ups", "Chest", 4, 15),
                    ex("Renegade Rows", "Back", 4, 12),
                    ex("Dumbbell Overhead Press", "Shoulders", 4, 12),
                    ex("Plank", "Core", 3, 60)
                ])
            ]
        ),
        
        WorkoutProgramDefinition(
            title: "1000-Ton Leg Day",
            description: "Warning: Extremely high volume leg day. Not for the faint of heart. Expect severe DOMS.",
            level: .advanced,
            goal: .buildMuscle,
            equipment: .fullGym,
            gradientColors: [Color.red, Color.pink],
            isSingleRoutine: true,
            routines: [
                routine("1000-Ton Leg Day", icon: "img_legs2", exercises: [
                    ex("Squat", "Legs", 5, 10),
                    ex("Leg Press", "Legs", 5, 15),
                    ex("Bulgarian Split Squat", "Legs", 4, 12),
                    ex("Romanian Deadlift", "Legs", 4, 12),
                    ex("Leg Extensions", "Legs", 4, 20),
                    ex("Seated Calf Raise", "Legs", 5, 20)
                ])
            ]
        )
    ]
    
    // MARK: - Builders
    private static func routine(_ name: String, icon: String, exercises: [ExerciseDTO]) -> WorkoutPresetDTO {
        WorkoutPresetDTO(name: name, icon: icon, folderName: nil, exercises: exercises)
    }
    
    private static func ex(_ name: String, _ group: String, _ sets: Int, _ reps: Int) -> ExerciseDTO {
        let setList = (1...sets).map { i in
            WorkoutSetDTO(index: i, weight: 0, reps: reps, distance: nil, time: nil, isCompleted: false, type: .normal)
        }
        return ExerciseDTO(name: name, muscleGroup: group, type: .strength, category: .other, effort: 5, isCompleted: false, setsList: setList, subExercises: [])
    }
}
