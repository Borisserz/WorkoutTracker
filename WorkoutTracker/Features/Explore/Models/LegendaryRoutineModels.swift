//
//  LegendaryRoutineModels.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 12.04.26.
//

// ============================================================
// FILE: WorkoutTracker/Features/Explore/Models/LegendaryRoutineModels.swift
// ============================================================

import Foundation
internal import SwiftUI

// MARK: - Model
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

// MARK: - Mock Data Factory
@MainActor
public struct LegendaryCatalog {
    public static let shared = LegendaryCatalog()
    
    public var routines: [LegendaryRoutine] {
        [
            // 1. The Austrian Oak Classic (70s Volume/Pump)
            LegendaryRoutine(
                title: "The Austrian Oak Classic",
                eraTitle: "THE GOLDEN ERA",
                shortVibe: "High volume, chasing the ultimate pump.",
                loreDescription: "Inspired by the 1970s golden age of bodybuilding in Venice Beach. This routine focuses on agonizing high volume, supersets, and absolute chest/back dominance to build a massive, classic silhouette.",
                gradientColors: [Color(hex: "F5AF19"), Color(hex: "F12711")], // Golden/Orange
                difficulty: .advanced,
                estimatedMinutes: 75,
                benefits: ["Extreme Hypertrophy", "Chest Expansion", "Endurance"],
                exercises: [
                    ex("Barbell Bench Press - Medium Grip", group: "Chest", type: "Strength", sets: 5, reps: 10),
                    ex("Incline Dumbbell Press", group: "Chest", type: "Strength", sets: 4, reps: 12),
                    ex("Pullups", group: "Back", type: "Strength", sets: 5, reps: 10),
                    ex("Bent Over Barbell Row", group: "Back", type: "Strength", sets: 4, reps: 12),
                    ex("Barbell Curl", group: "Arms", type: "Strength", sets: 4, reps: 10)
                ]
            ),
            
            // 2. Mass Monster 5x5 (90s Raw Power)
            LegendaryRoutine(
                title: "Mass Monster 5x5",
                eraTitle: "THE HEAVYWEIGHT 90s",
                shortVibe: "Move heavy iron. Rest. Repeat.",
                loreDescription: "Welcome to the era of absolute mass. This routine strips away the fluff. You will focus solely on the 'Big Three' compound movements. 5 sets of 5 reps. Maximum weight, maximum central nervous system recruitment.",
                gradientColors: [Color(hex: "4B1248"), Color(hex: "F0C27B")], // Deep purple/gold
                difficulty: .intermediate,
                estimatedMinutes: 60,
                benefits: ["Raw Strength", "CNS Adaptation", "Bone Density"],
                exercises: [
                    ex("Barbell Squat", group: "Legs", type: "Strength", sets: 5, reps: 5),
                    ex("Barbell Bench Press - Medium Grip", group: "Chest", type: "Strength", sets: 5, reps: 5),
                    ex("Barbell Deadlift", group: "Back", type: "Strength", sets: 5, reps: 5)
                ]
            ),
            
            // 3. High Intensity Shadow (HIT - Dorian vibe)
            LegendaryRoutine(
                title: "High Intensity Shadow",
                eraTitle: "THE GRUNGE ERA",
                shortVibe: "One set to absolute failure.",
                loreDescription: "Quality over quantity. Inspired by the brutal 'Blood and Guts' methodology. You perform warmup sets, followed by exactly ONE working set taken beyond the point of muscular failure. Not for the faint of heart.",
                gradientColors: [Color(hex: "000000"), Color(hex: "434343"), Color.red.opacity(0.8)], // Dark/Red
                difficulty: .advanced,
                estimatedMinutes: 45,
                benefits: ["Time Efficiency", "Mental Toughness", "Muscle Density"],
                exercises: [
                    ex("Leg Press", group: "Legs", type: "Strength", sets: 1, reps: 8),
                    ex("Wide-Grip Lat Pulldown", group: "Back", type: "Strength", sets: 1, reps: 8),
                    ex("Seated Dumbbell Press", group: "Shoulders", type: "Strength", sets: 1, reps: 8),
                    ex("Triceps Pushdown", group: "Arms", type: "Strength", sets: 1, reps: 8)
                ]
            ),
            
            // 4. Classic Physique Champion (Modern Aesthetic)
            LegendaryRoutine(
                title: "Classic Aesthetic",
                eraTitle: "THE MODERN RENAISSANCE",
                shortVibe: "V-Taper, broad shoulders, vacuum posing.",
                loreDescription: "Aimed at the modern Classic Physique standard. This session heavily biases the lateral deltoids, upper chest, and lat width to create the illusion of a superhero V-Taper, while keeping the waist tight.",
                gradientColors: [Color(hex: "00C9FF"), Color(hex: "92FE9D")], // Cyan/Mint
                difficulty: .intermediate,
                estimatedMinutes: 65,
                benefits: ["V-Taper Aesthetics", "Shoulder Caps", "Symmetry"],
                exercises: [
                    ex("Side Lateral Raise", group: "Shoulders", type: "Strength", sets: 5, reps: 15),
                    ex("Barbell Incline Bench Press - Medium Grip", group: "Chest", type: "Strength", sets: 4, reps: 10),
                    ex("Wide-Grip Lat Pulldown", group: "Back", type: "Strength", sets: 4, reps: 12),
                    ex("Leg Extensions", group: "Legs", type: "Strength", sets: 4, reps: 15),
                    ex("Plank", group: "Core", type: "Duration", sets: 3, reps: 60) // 60 seconds
                ]
            ),
            
            // 5. German Volume Protocol (GVT)
            LegendaryRoutine(
                title: "German Volume Protocol",
                eraTitle: "THE IRON WALL",
                shortVibe: "10 Sets. 10 Reps. Pure agony.",
                loreDescription: "Originating in Germany for off-season weightlifters. You select one compound exercise and perform 10 sets of 10 reps. It forces extreme cellular hypertrophy. Expect severe DOMS.",
                gradientColors: [Color(hex: "114357"), Color(hex: "F29492")], // Dark Steel / Flesh
                difficulty: .advanced,
                estimatedMinutes: 50,
                benefits: ["Shock Hypertrophy", "Fat Loss", "Lactic Tolerance"],
                exercises: [
                    ex("Barbell Squat", group: "Legs", type: "Strength", sets: 10, reps: 10),
                    ex("Lying Leg Curls", group: "Legs", type: "Strength", sets: 10, reps: 10)
                ]
            )
        ]
    }
    
    // Вспомогательный билдер для DTO
    private func ex(_ name: String, group: String, type: String, sets: Int, reps: Int) -> GeneratedExerciseDTO {
        GeneratedExerciseDTO(
            name: name,
            muscleGroup: group,
            type: type,
            sets: sets,
            reps: reps,
            recommendedWeightKg: nil, // AI/App will auto-calculate or leave empty for user
            restSeconds: type == "Strength" ? 90 : 0
        )
    }
}
