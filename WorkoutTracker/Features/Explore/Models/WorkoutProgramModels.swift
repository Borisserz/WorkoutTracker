

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

    var programs: [WorkoutProgramDefinition] {
        [

            WorkoutProgramDefinition(
                title: "Beginner PPL",
                description: "The ultimate Push/Pull/Legs split designed to build a solid foundation of muscle and strength.",
                level: .beginner,
                goal: .buildMuscle,
                equipment: .fullGym,
                gradientColors: [theme.primaryAccent, theme.lightHighlight],
                isSingleRoutine: false,
                routines: [
                    routine("Push: Chest, Shoulders, Triceps", icon: "img_chest", exercises: [
                        ex("Barbell Bench Press - Medium Grip", "Chest", 3, 8),
                        ex("Incline Dumbbell Press", "Chest", 3, 10),
                        ex("Standing Military Press", "Shoulders", 3, 8),
                        ex("Side Lateral Raise", "Shoulders", 3, 15),
                        ex("Triceps Pushdown", "Arms", 3, 12)
                    ]),
                    routine("Pull: Back & Biceps", icon: "img_back", exercises: [
                        ex("Barbell Deadlift", "Back", 3, 5),
                        ex("Pullups", "Back", 3, 8),
                        ex("Bent Over Barbell Row", "Back", 3, 10),
                        ex("Face Pull", "Shoulders", 3, 15),
                        ex("Barbell Curl", "Arms", 3, 10)
                    ]),
                    routine("Legs & Core", icon: "img_legs", exercises: [
                        ex("Barbell Squat", "Legs", 3, 8),
                        ex("Leg Press", "Legs", 3, 12),
                        ex("Romanian Deadlift", "Legs", 3, 10),
                        ex("Standing Barbell Calf Raise", "Legs", 4, 15),
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
                gradientColors: [theme.deepPremiumAccent, theme.primaryAccent],
                isSingleRoutine: false,
                routines: [
                    routine("Upper Power", icon: "img_default", exercises: [
                        ex("Barbell Bench Press - Medium Grip", "Chest", 4, 5),
                        ex("Incline Dumbbell Press", "Chest", 3, 8),
                        ex("Bent Over Barbell Row", "Back", 4, 5),
                        ex("Wide-Grip Lat Pulldown", "Back", 3, 8),
                        ex("Standing Military Press", "Shoulders", 3, 8)
                    ]),
                    routine("Lower Power", icon: "img_legs2", exercises: [
                        ex("Barbell Squat", "Legs", 4, 5),
                        ex("Barbell Deadlift", "Back", 4, 5),
                        ex("Leg Press", "Legs", 3, 10),
                        ex("Standing Barbell Calf Raise", "Legs", 4, 15)
                    ]),
                    routine("Upper Hypertrophy", icon: "img_arms", exercises: [
                        ex("Barbell Incline Bench Press - Medium Grip", "Chest", 4, 12),
                        ex("Cable Crossover", "Chest", 3, 15),
                        ex("Seated Cable Rows", "Back", 4, 12),
                        ex("Side Lateral Raise", "Shoulders", 4, 15),
                        ex("Triceps Pushdown - Rope Attachment", "Arms", 3, 12),
                        ex("Dumbbell Bicep Curl", "Arms", 3, 12)
                    ]),
                    routine("Lower Hypertrophy", icon: "img_legs", exercises: [
                        ex("Front Barbell Squat", "Legs", 4, 10),
                        ex("Split Squat with Dumbbells", "Legs", 3, 12),
                        ex("Lying Leg Curls", "Legs", 4, 15),
                        ex("Seated Calf Raise", "Legs", 4, 20)
                    ])
                ]
            ),

            WorkoutProgramDefinition(
                title: "Advanced Bro Split",
                description: "The classic 5-day bodybuilding split. Destroy one muscle group per day with extreme volume.",
                level: .advanced,
                goal: .buildMuscle,
                equipment: .fullGym,
                gradientColors: [.red, theme.deepPremiumAccent],
                isSingleRoutine: false,
                routines: [
                    routine("Chest Day", icon: "img_chest2", exercises: [
                        ex("Barbell Bench Press - Medium Grip", "Chest", 4, 8),
                        ex("Incline Dumbbell Press", "Chest", 4, 10),
                        ex("Dumbbell Flyes", "Chest", 4, 12),
                        ex("Low Cable Crossover", "Chest", 4, 15)
                    ]),
                    routine("Back Day", icon: "img_back2", exercises: [
                        ex("Barbell Deadlift", "Back", 4, 5),
                        ex("Pullups", "Back", 4, 8),
                        ex("Lying T-Bar Row", "Back", 4, 10),
                        ex("Wide-Grip Lat Pulldown", "Back", 4, 12)
                    ]),
                    routine("Legs Day", icon: "img_legs", exercises: [
                        ex("Barbell Squat", "Legs", 4, 8),
                        ex("Leg Press", "Legs", 4, 12),
                        ex("Leg Extensions", "Legs", 4, 15),
                        ex("Lying Leg Curls", "Legs", 4, 15)
                    ]),
                    routine("Shoulder Day", icon: "img_shoulders", exercises: [
                        ex("Standing Military Press", "Shoulders", 4, 8),
                        ex("Arnold Dumbbell Press", "Shoulders", 4, 10),
                        ex("Side Lateral Raise", "Shoulders", 5, 15),
                        ex("Face Pull", "Shoulders", 4, 15)
                    ]),
                    routine("Arms Day", icon: "img_arms", exercises: [
                        ex("Barbell Curl", "Arms", 4, 10),
                        ex("Lying Triceps Press", "Arms", 4, 10),
                        ex("Hammer Curls", "Arms", 4, 12),
                        ex("EZ-Bar Skullcrusher", "Arms", 4, 12)
                    ])
                ]
            ),

            WorkoutProgramDefinition(
                title: "StrongLifts 5x5",
                description: "The ultimate beginner strength program. Focus on heavy compound movements 3 days a week to build a massive foundation.",
                level: .beginner,
                goal: .getStronger,
                equipment: .fullGym,
                gradientColors: [theme.secondaryMidTone, .red],
                isSingleRoutine: false,
                routines: [
                    routine("Workout A", icon: "img_default", exercises: [
                        ex("Barbell Squat", "Legs", 5, 5),
                        ex("Barbell Bench Press - Medium Grip", "Chest", 5, 5),
                        ex("Bent Over Barbell Row", "Back", 5, 5)
                    ]),
                    routine("Workout B", icon: "img_legs", exercises: [
                        ex("Barbell Squat", "Legs", 5, 5),
                        ex("Standing Military Press", "Shoulders", 5, 5),
                        ex("Barbell Deadlift", "Back", 1, 5)
                    ])
                ]
            ),

            WorkoutProgramDefinition(
                title: "Golden Era High Volume",
                description: "A high-volume, 6-day split favored by the Austrian Oak. Chest & Back, Shoulders & Arms, Legs. Repeat.",
                level: .advanced,
                goal: .buildMuscle,
                equipment: .fullGym,
                gradientColors: [Color(hex: "b8860b"), Color.black],
                isSingleRoutine: false,
                routines: [
                    routine("Chest & Back", icon: "img_chest", exercises: [
                        ex("Barbell Bench Press - Medium Grip", "Chest", 4, 10),
                        ex("Incline Dumbbell Press", "Chest", 4, 10),
                        ex("Pullups", "Back", 4, 10),
                        ex("Bent Over Barbell Row", "Back", 4, 10),
                        ex("Barbell Deadlift", "Back", 3, 8)
                    ]),
                    routine("Shoulders & Arms", icon: "img_arms", exercises: [
                        ex("Standing Military Press", "Shoulders", 4, 10),
                        ex("Side Lateral Raise", "Shoulders", 4, 12),
                        ex("Barbell Curl", "Arms", 4, 10),
                        ex("Hammer Curls", "Arms", 4, 10),
                        ex("Standing Overhead Barbell Triceps Extension", "Arms", 4, 12)
                    ]),
                    routine("Legs", icon: "img_legs2", exercises: [
                        ex("Barbell Squat", "Legs", 4, 8),
                        ex("Leg Press", "Legs", 4, 10),
                        ex("Romanian Deadlift", "Legs", 4, 10),
                        ex("Leg Extensions", "Legs", 4, 15),
                        ex("Standing Barbell Calf Raise", "Legs", 5, 15)
                    ])
                ]
            ),

            WorkoutProgramDefinition(
                title: "Glute Builder & Core",
                description: "Maximize lower body hypertrophy and core strength while keeping the upper body toned. Perfect for aesthetic goals.",
                level: .intermediate,
                goal: .buildMuscle,
                equipment: .fullGym,
                gradientColors: [theme.lightHighlight, theme.deepPremiumAccent],
                isSingleRoutine: false,
                routines: [
                    routine("Lower: Glutes & Quads", icon: "img_legs", exercises: [
                        ex("Barbell Squat", "Legs", 4, 10),
                        ex("Barbell Hip Thrust", "Legs", 4, 12),
                        ex("Dumbbell Lunges", "Legs", 3, 12),
                        ex("Leg Press", "Legs", 3, 15)
                    ]),
                    routine("Upper & Core", icon: "img_default", exercises: [
                        ex("Wide-Grip Lat Pulldown", "Back", 3, 12),
                        ex("Dumbbell Flyes", "Chest", 3, 12),
                        ex("Side Lateral Raise", "Shoulders", 3, 15),
                        ex("Plank", "Core", 3, 60),
                        ex("Cross-Body Crunch", "Core", 3, 20)
                    ]),
                    routine("Lower: Glutes & Hams", icon: "img_legs2", exercises: [
                        ex("Romanian Deadlift", "Legs", 4, 10),
                        ex("Split Squat with Dumbbells", "Legs", 3, 10),
                        ex("Lying Leg Curls", "Legs", 4, 15),
                        ex("Barbell Glute Bridge", "Legs", 3, 15)
                    ])
                ]
            ),

            WorkoutProgramDefinition(
                title: "Dumbbell Warrior",
                description: "No gym? No problem. A complete full-body hypertrophy program using only dumbbells. Great for home workouts.",
                level: .beginner,
                goal: .buildMuscle,
                equipment: .dumbbells,
                gradientColors: [theme.lightHighlight, theme.primaryAccent],
                isSingleRoutine: false,
                routines: [
                    routine("Full Body A", icon: "img_arms", exercises: [
                        ex("Goblet Squat", "Legs", 3, 12),
                        ex("Incline Dumbbell Press", "Chest", 3, 10),
                        ex("One-Arm Dumbbell Row", "Back", 3, 10),
                        ex("Arnold Dumbbell Press", "Shoulders", 3, 10),
                        ex("Crunches", "Core", 3, 15)
                    ]),
                    routine("Full Body B", icon: "img_shoulders", exercises: [
                        ex("Dumbbell Lunges", "Legs", 3, 12),
                        ex("Dumbbell Flyes", "Chest", 3, 12),
                        ex("Alternating Renegade Row", "Back", 3, 10),
                        ex("Dumbbell Bicep Curl", "Arms", 3, 12),
                        ex("Standing Dumbbell Triceps Extension", "Arms", 3, 12)
                    ])
                ]
            ),

            WorkoutProgramDefinition(
                title: "Classic 3-Day Mass Split",
                description: "A time-tested 3-day split (Back/Biceps, Legs/Shoulders, Chest/Triceps) perfect for building foundational mass and strength.",
                level: .beginner,
                goal: .buildMuscle,
                equipment: .fullGym,
                gradientColors: [theme.primaryAccent, theme.lightHighlight],
                isSingleRoutine: false,
                routines: [
                    routine("Monday: Back & Biceps", icon: "img_back", exercises: [
                        ex("Bent Over Barbell Row", "Back", 3, 8),
                        ex("Pullups", "Back", 3, 8),
                        ex("Straight-Arm Pulldown", "Back", 3, 8),
                        ex("Barbell Curl", "Arms", 3, 8),
                        ex("Hammer Curls", "Arms", 3, 10)
                    ]),
                    routine("Wednesday: Legs & Shoulders", icon: "img_legs", exercises: [
                        ex("Barbell Squat", "Legs", 3, 8),
                        ex("Leg Press", "Legs", 3, 8),
                        ex("Lying Leg Curls", "Legs", 3, 8),
                        ex("Smith Machine Overhead Shoulder Press", "Shoulders", 3, 8),
                        ex("Side Lateral Raise", "Shoulders", 3, 10),
                        ex("Seated Bent-Over Rear Delt Raise", "Shoulders", 3, 10)
                    ]),
                    routine("Friday: Chest & Triceps", icon: "img_chest", exercises: [
                        ex("Barbell Bench Press - Medium Grip", "Chest", 3, 8),
                        ex("Incline Dumbbell Flyes", "Chest", 3, 8),
                        ex("Cable Crossover", "Chest", 3, 10),
                        ex("Close-Grip Barbell Bench Press", "Arms", 3, 8),
                        ex("Triceps Pushdown", "Arms", 3, 10)
                    ])
                ]
            ),

            WorkoutProgramDefinition(
                title: "Power & Pump: Phase 1",
                description: "Advanced periodization. Heavy strength focus on Chest, Legs, and Shoulders. Hypertrophy pump for Back and Arms.",
                level: .intermediate,
                goal: .buildMuscle,
                equipment: .fullGym,
                gradientColors: [theme.deepPremiumAccent, theme.primaryAccent],
                isSingleRoutine: false,
                routines: [
                    routine("Day 1: Chest (Power) & Back (Pump)", icon: "img_chest2", exercises: [
                        ex("Barbell Incline Bench Press - Medium Grip", "Chest", 4, 8),
                        ex("Dumbbell Bench Press", "Chest", 3, 10),
                        ex("Low Cable Crossover", "Chest", 3, 12),
                        ex("Wide-Grip Pulldown Behind The Neck", "Back", 3, 12),
                        ex("Underhand Cable Pulldowns", "Back", 3, 15)
                    ]),
                    routine("Day 2: Legs (Power)", icon: "img_legs2", exercises: [
                        ex("Barbell Squat", "Legs", 3, 10),
                        ex("Narrow Stance Leg Press", "Legs", 3, 10),
                        ex("Stiff-Legged Barbell Deadlift", "Legs", 3, 10),
                        ex("Seated Leg Curl", "Legs", 3, 10),
                        ex("Standing Barbell Calf Raise", "Legs", 3, 10),
                        ex("Barbell Shrug", "Shoulders", 3, 10)
                    ]),
                    routine("Day 3: Shoulders (Power) & Arms (Pump)", icon: "img_shoulders", exercises: [
                        ex("Seated Dumbbell Press", "Shoulders", 3, 10),
                        ex("Seated Bent-Over Rear Delt Raise", "Shoulders", 4, 8),
                        ex("Dumbbell Incline Row", "Back", 4, 8),
                        ex("Triceps Pushdown - Rope Attachment", "Arms", 3, 12),
                        ex("Triceps Overhead Extension with Rope", "Arms", 3, 12),
                        ex("Cross Body Hammer Curl", "Arms", 3, 12),
                        ex("High Cable Curls", "Arms", 3, 12)
                    ])
                ]
            ),

            WorkoutProgramDefinition(
                title: "Power & Pump: Phase 2",
                description: "Advanced periodization. Heavy strength focus on Back and Arms. Hypertrophy pump for Chest, Legs, and Shoulders.",
                level: .advanced,
                goal: .buildMuscle,
                equipment: .fullGym,
                gradientColors: [theme.secondaryMidTone, .red],
                isSingleRoutine: false,
                routines: [
                    routine("Day 1: Back (Power) & Chest (Pump)", icon: "img_back2", exercises: [
                        ex("Bent Over Two-Dumbbell Row", "Back", 3, 10),
                        ex("Pullups", "Back", 4, 8),
                        ex("Reverse Grip Bent-Over Rows", "Back", 3, 10),
                        ex("Dumbbell Bench Press", "Chest", 3, 12),
                        ex("Incline Dumbbell Flyes", "Chest", 3, 15)
                    ]),
                    routine("Day 2: Legs (Pump)", icon: "img_legs", exercises: [
                        ex("Leg Press", "Legs", 3, 12),
                        ex("Leg Extensions", "Legs", 3, 12),
                        ex("Stiff-Legged Dumbbell Deadlift", "Legs", 3, 12),
                        ex("Lying Leg Curls", "Legs", 3, 12),
                        ex("Seated Calf Raise", "Legs", 3, 12),
                        ex("Dumbbell Shrug", "Shoulders", 3, 12)
                    ]),
                    routine("Day 3: Arms (Power) & Shoulders (Pump)", icon: "img_arms", exercises: [
                        ex("Close-Grip Barbell Bench Press", "Arms", 4, 8),
                        ex("EZ-Bar Skullcrusher", "Arms", 3, 10),
                        ex("Seated Triceps Press", "Arms", 3, 10),
                        ex("Barbell Curl", "Arms", 4, 8),
                        ex("Hammer Curls", "Arms", 3, 10),
                        ex("Machine Preacher Curls", "Arms", 3, 10),
                        ex("Side Lateral Raise", "Shoulders", 3, 15),
                        ex("Seated Bent-Over Rear Delt Raise", "Shoulders", 3, 15)
                    ])
                ]
            ),

            WorkoutProgramDefinition(
                title: "Classic Foundation Six",
                description: "A legendary full-body single routine. Arnold Schwarzenegger used this to build his early mass.",
                level: .intermediate,
                goal: .buildMuscle,
                equipment: .fullGym,
                gradientColors: [.yellow, theme.secondaryMidTone],
                isSingleRoutine: true,
                routines: [
                    routine("Arnold's Golden Six", icon: "img_default", exercises: [
                        ex("Barbell Squat", "Legs", 4, 10),
                        ex("Barbell Bench Press - Medium Grip", "Chest", 3, 10),
                        ex("Pullups", "Back", 3, 10),
                        ex("Standing Military Press", "Shoulders", 4, 10),
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
                gradientColors: [.gray, .black],
                isSingleRoutine: true,
                routines: [
                    routine("Madcow 5x5", icon: "img_default", exercises: [
                        ex("Barbell Squat", "Legs", 5, 5),
                        ex("Barbell Bench Press - Medium Grip", "Chest", 5, 5),
                        ex("Bent Over Barbell Row", "Back", 5, 5)
                    ])
                ]
            ),

            WorkoutProgramDefinition(
                title: "Quick Home Shred",
                description: "High-intensity dumbbell and bodyweight circuit. Burn fat and keep muscle without stepping foot in a gym.",
                level: .beginner,
                goal: .loseWeight,
                equipment: .dumbbells,
                gradientColors: [.green, theme.lightHighlight],
                isSingleRoutine: true,
                routines: [
                    routine("Quick Home Shred", icon: "img_arms", exercises: [
                        ex("Goblet Squat", "Legs", 4, 15),
                        ex("Pushups", "Chest", 4, 15),
                        ex("Alternating Renegade Row", "Back", 4, 12),
                        ex("Standing Dumbbell Press", "Shoulders", 4, 12),
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
                gradientColors: [.red, theme.deepPremiumAccent],
                isSingleRoutine: true,
                routines: [
                    routine("1000-Ton Leg Day", icon: "img_legs2", exercises: [
                        ex("Barbell Squat", "Legs", 5, 10),
                        ex("Leg Press", "Legs", 5, 15),
                        ex("Split Squat with Dumbbells", "Legs", 4, 12),
                        ex("Romanian Deadlift", "Legs", 4, 12),
                        ex("Leg Extensions", "Legs", 4, 20),
                        ex("Seated Calf Raise", "Legs", 5, 20)
                    ])
                ]
            )
        ]
    }

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
}
