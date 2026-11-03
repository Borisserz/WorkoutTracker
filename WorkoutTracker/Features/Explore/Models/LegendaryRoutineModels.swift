

import Foundation
internal import SwiftUI

public struct LegendaryRoutine: Identifiable, Sendable {
    public let id = UUID()
    let title: String
    let eraTitle: String
    let shortVibe: String
    let loreDescription: String
    let gradientColors: [Color]
    let difficulty: ProgramLevel
    let estimatedMinutes: Int
    let benefits: [String]
    let exercises: [GeneratedExerciseDTO]
}

@MainActor
public struct LegendaryCatalog {
    public static let shared = LegendaryCatalog()

    private func ex(_ name: String, group: String, type: String, sets: Int, reps: Int) -> GeneratedExerciseDTO {
        GeneratedExerciseDTO(
            name: name,
            muscleGroup: group,
            type: type,
            sets: sets,
            reps: reps,
            recommendedWeightKg: nil, 
            restSeconds: type == "Strength" ? 90 : 0
        )
    }
}

/// Offline Hub fallback when Firestore Legendary is empty. Must match each card's equipment claim.
enum LegendaryFallbackCatalog {
    private static func ex(
        _ name: String,
        group: String,
        type: String = "Strength",
        sets: Int,
        reps: Int,
        rest: Int = 90
    ) -> GeneratedExerciseDTO {
        GeneratedExerciseDTO(
            name: name,
            muscleGroup: group,
            type: type,
            sets: sets,
            reps: reps,
            recommendedWeightKg: nil,
            restSeconds: rest
        )
    }

    static var routines: [LegendaryRoutine] {
        [
            LegendaryRoutine(
                title: "Bodyweight Definition Circuit",
                eraTitle: "No Equipment",
                shortVibe: "No equipment, maximum definition",
                loreDescription: "Bodyweight-focused sample inspired by minimal-equipment conditioning — a starter circuit, not a full published program.",
                gradientColors: [PastelTheme.pastelSlate, PastelTheme.pastelOat],
                difficulty: .intermediate,
                estimatedMinutes: 45,
                benefits: ["Definition", "Endurance", "Core"],
                exercises: [
                    ex("Push-ups", group: "Chest", type: "Bodyweight", sets: 4, reps: 15, rest: 60),
                    ex("Pull-ups", group: "Back", type: "Bodyweight", sets: 4, reps: 8, rest: 90),
                    ex("Bodyweight Squats", group: "Legs", type: "Bodyweight", sets: 3, reps: 20, rest: 60),
                    ex("Plank", group: "Core", type: "Duration", sets: 3, reps: 45, rest: 45)
                ]
            ),
            LegendaryRoutine(
                title: "Barbell Hypertrophy Primer",
                eraTitle: "Strength Block",
                shortVibe: "Elite hypertrophy and strength",
                loreDescription: "Short hypertrophy sample inspired by classic strength blocks — a starter split, not a full curriculum.",
                gradientColors: [PastelTheme.pastelAmber, PastelTheme.pastelPeach],
                difficulty: .advanced,
                estimatedMinutes: 60,
                benefits: ["Strength", "Mass", "V-Taper"],
                exercises: [
                    ex("Barbell Deadlift", group: "Back", sets: 3, reps: 6, rest: 120),
                    ex("Overhead Press", group: "Shoulders", sets: 3, reps: 8, rest: 90),
                    ex("Barbell Squat", group: "Legs", sets: 4, reps: 8, rest: 120)
                ]
            ),
            LegendaryRoutine(
                title: "Golden Era Volume Split",
                eraTitle: "Golden Era",
                shortVibe: "High volume, classic V-taper physique",
                loreDescription: "Golden Era–inspired push/pull sample for chest, back, and arms — a taste of classic volume training, not a full weekly split.",
                gradientColors: [PastelTheme.pastelAmber, PastelTheme.pastelOat],
                difficulty: .advanced,
                estimatedMinutes: 75,
                benefits: ["V-Taper", "Volume", "Mass"],
                exercises: [
                    ex("Barbell Bench Press - Medium Grip", group: "Chest", sets: 5, reps: 10),
                    ex("Incline Barbell Bench Press", group: "Chest", sets: 4, reps: 10),
                    ex("Wide-Grip Lat Pulldown", group: "Back", sets: 4, reps: 10),
                    ex("Bent-Over Barbell Row", group: "Back", sets: 4, reps: 10),
                    ex("Dumbbell Bicep Curl", group: "Arms", type: "Hypertrophy", sets: 3, reps: 12, rest: 60)
                ]
            ),
            LegendaryRoutine(
                title: "High Intensity Peak Sample",
                eraTitle: "High Intensity",
                shortVibe: "Peak intensity, failure sets",
                loreDescription: "HIT-inspired sample with low volume and hard sets — a taste of high-intensity training, not a full system.",
                gradientColors: [PastelTheme.pastelLavender, PastelTheme.pastelSlate],
                difficulty: .advanced,
                estimatedMinutes: 45,
                benefits: ["HIT", "Intensity", "Strength"],
                exercises: [
                    ex("Incline Dumbbell Press", group: "Chest", sets: 2, reps: 8, rest: 120),
                    ex("Dumbbell Flyes", group: "Chest", type: "Hypertrophy", sets: 1, reps: 10),
                    ex("Barbell Deadlift", group: "Back", sets: 2, reps: 6, rest: 120),
                    ex("Pullups", group: "Back", type: "Bodyweight", sets: 2, reps: 10)
                ]
            )
        ]
    }
}
