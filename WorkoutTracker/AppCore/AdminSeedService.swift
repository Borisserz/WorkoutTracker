//
//  AdminSeedService.swift
//  WorkoutTracker
//
//  Created by Admin Seed.
//

import Foundation
import FirebaseFirestore
internal import SwiftUI

@MainActor
final class AdminSeedService {
    static let shared = AdminSeedService()
    private let db = Firestore.firestore()
    
    private init() {}
    
    func seedFirestore() async {
        print("🚀 Starting Firestore Seed...")
        
        let legendaryRef = db.collection("legendary_routines")
        let exploreRef = db.collection("explore_programs")
        
        // --- 1. LEGENDARY ROUTINES ---
        let newLegendary = [
            FBLegendaryRoutine(
                id: nil,
                title: "Golden Chest",
                eraTitle: "Golden Era",
                shortVibe: "High Volume, Classic V-Taper focus",
                loreDescription: "The exact weekly protocol Arnold used to dominate the stage. Focused heavily on chest, back, and building the classic aesthetic proportion.",
                hexColors: ["FF4500", "FF8C00"], // Orange-Red gradient
                difficulty: "advanced",
                estimatedMinutes: 75,
                benefits: ["V-Taper", "Volume", "Mass"],
                exercises: [
                    FBGeneratedExerciseDTO(name: "Barbell Bench Press - Medium Grip", muscleGroup: "Chest", type: "Strength", sets: 5, reps: 10, recommendedWeightKg: nil, restSeconds: 90),
                    FBGeneratedExerciseDTO(name: "Incline Barbell Bench Press", muscleGroup: "Chest", type: "Strength", sets: 4, reps: 10, recommendedWeightKg: nil, restSeconds: 90),
                    FBGeneratedExerciseDTO(name: "Wide-Grip Lat Pulldown", muscleGroup: "Back", type: "Strength", sets: 4, reps: 10, recommendedWeightKg: nil, restSeconds: 90),
                    FBGeneratedExerciseDTO(name: "Bent-Over Barbell Row", muscleGroup: "Back", type: "Strength", sets: 4, reps: 10, recommendedWeightKg: nil, restSeconds: 90),
                    FBGeneratedExerciseDTO(name: "Dumbbell Bicep Curl", muscleGroup: "Arms", type: "Hypertrophy", sets: 3, reps: 12, recommendedWeightKg: nil, restSeconds: 60)
                ]
            ),
            FBLegendaryRoutine(
                id: nil,
                title: "Mental Toughness",
                eraTitle: "Endurance Era",
                shortVibe: "Stay Hard, Push Past Limits",
                loreDescription: "A brutally intense routine designed not just to build physical endurance, but to callous your mind. High reps, short rest, maximum suffering.",
                hexColors: ["1C1C1C", "434343"], // Dark grey gradient
                difficulty: "advanced",
                estimatedMinutes: 60,
                benefits: ["Endurance", "Mental Toughness", "Conditioning"],
                exercises: [
                    FBGeneratedExerciseDTO(name: "Pushups", muscleGroup: "Chest", type: "Bodyweight", sets: 10, reps: 20, recommendedWeightKg: nil, restSeconds: 30),
                    FBGeneratedExerciseDTO(name: "Pullups", muscleGroup: "Back", type: "Bodyweight", sets: 10, reps: 10, recommendedWeightKg: nil, restSeconds: 30),
                    FBGeneratedExerciseDTO(name: "Bodyweight Squat", muscleGroup: "Legs", type: "Bodyweight", sets: 10, reps: 30, recommendedWeightKg: nil, restSeconds: 30),
                    FBGeneratedExerciseDTO(name: "Burpees", muscleGroup: "Cardio", type: "Cardio", sets: 5, reps: 20, recommendedWeightKg: nil, restSeconds: 45)
                ]
            ),
            FBLegendaryRoutine(
                id: nil,
                title: "Blood & Guts",
                eraTitle: "Mass Monster Era",
                shortVibe: "Low Volume, Extreme Intensity",
                loreDescription: "Dorian Yates revolutionized bodybuilding by doing fewer sets but taking them beyond absolute failure. Forced reps, negatives, and total muscle annihilation.",
                hexColors: ["8B0000", "000000"], // Blood red to black
                difficulty: "advanced",
                estimatedMinutes: 45,
                benefits: ["Thickness", "Extreme Intensity", "Hypertrophy"],
                exercises: [
                    FBGeneratedExerciseDTO(name: "Barbell Deadlift", muscleGroup: "Back", type: "Strength", sets: 2, reps: 6, recommendedWeightKg: nil, restSeconds: 120),
                    FBGeneratedExerciseDTO(name: "Bent-Over Barbell Row", muscleGroup: "Back", type: "Strength", sets: 1, reps: 8, recommendedWeightKg: nil, restSeconds: 120),
                    FBGeneratedExerciseDTO(name: "Lat Pulldown (Reverse Grip)", muscleGroup: "Back", type: "Hypertrophy", sets: 1, reps: 8, recommendedWeightKg: nil, restSeconds: 120),
                    FBGeneratedExerciseDTO(name: "Seated Cable Row", muscleGroup: "Back", type: "Hypertrophy", sets: 1, reps: 8, recommendedWeightKg: nil, restSeconds: 120)
                ]
            )
        ]
        
        for routine in newLegendary {
            do {
                let docRef = legendaryRef.document()
                try docRef.setData(from: routine)
                print("✅ Seeded Legendary Routine: \(routine.title ?? "")")
            } catch {
                print("❌ Failed to seed Legendary Routine: \(error)")
            }
        }
        
        // --- 2. SOLO PROGRAMS (explore_programs with isSingleRoutine = true) ---
        let newSolo = [
            FBWorkoutProgram(
                id: nil,
                title: "Biceps & Triceps Blaster",
                descriptionText: "A high-intensity arm pump designed to tear down muscle fibers and force serious arm growth.",
                level: "intermediate",
                goal: "build_muscle",
                equipment: "full_gym",
                hexColors: ["FF007F", "8A2BE2"], // Pink to Purple
                isSingleRoutine: true,
                routines: [
                    FBWorkoutPresetDTO(
                        name: "Arm Blaster Day 1",
                        icon: "figure.flexibility",
                        folderName: nil,
                        exercises: [
                            FBExerciseDTO(name: "Barbell Curl", muscleGroup: "Arms", type: "Hypertrophy", category: "Other", effort: 8, isCompleted: false, setsList: nil, subExercises: nil, sets: 4, reps: 10, recommendedWeightKg: nil),
                            FBExerciseDTO(name: "Tricep Pushdown", muscleGroup: "Arms", type: "Hypertrophy", category: "Other", effort: 8, isCompleted: false, setsList: nil, subExercises: nil, sets: 4, reps: 12, recommendedWeightKg: nil),
                            FBExerciseDTO(name: "Dumbbell Hammer Curl", muscleGroup: "Arms", type: "Hypertrophy", category: "Other", effort: 8, isCompleted: false, setsList: nil, subExercises: nil, sets: 3, reps: 12, recommendedWeightKg: nil),
                            FBExerciseDTO(name: "Overhead Tricep Extension", muscleGroup: "Arms", type: "Hypertrophy", category: "Other", effort: 8, isCompleted: false, setsList: nil, subExercises: nil, sets: 3, reps: 12, recommendedWeightKg: nil)
                        ]
                    )
                ]
            ),
            FBWorkoutProgram(
                id: nil,
                title: "Core Crusher 15",
                descriptionText: "A brutal 15-minute abdominal routine to carve out your core and build foundational stability.",
                level: "intermediate",
                goal: "lose_weight",
                equipment: "bodyweight",
                hexColors: ["00FA9A", "2E8B57"], // Spring Green to Sea Green
                isSingleRoutine: true,
                routines: [
                    FBWorkoutPresetDTO(
                        name: "Core Circuit",
                        icon: "figure.core.cylinder",
                        folderName: nil,
                        exercises: [
                            FBExerciseDTO(name: "Crunches", muscleGroup: "Core", type: "Bodyweight", category: "Other", effort: 7, isCompleted: false, setsList: nil, subExercises: nil, sets: 3, reps: 20, recommendedWeightKg: nil),
                            FBExerciseDTO(name: "Hanging Leg Raise", muscleGroup: "Core", type: "Bodyweight", category: "Other", effort: 9, isCompleted: false, setsList: nil, subExercises: nil, sets: 3, reps: 15, recommendedWeightKg: nil),
                            FBExerciseDTO(name: "Russian Twist", muscleGroup: "Core", type: "Bodyweight", category: "Other", effort: 8, isCompleted: false, setsList: nil, subExercises: nil, sets: 3, reps: 30, recommendedWeightKg: nil),
                            FBExerciseDTO(name: "Plank", muscleGroup: "Core", type: "Duration", category: "Other", effort: 8, isCompleted: false, setsList: nil, subExercises: nil, sets: 3, reps: 60, recommendedWeightKg: nil)
                        ]
                    )
                ]
            ),
            FBWorkoutProgram(
                id: nil,
                title: "Leg Day Finisher",
                descriptionText: "A savage lower-body routine focusing on high-volume squats and lunges. Not for the faint of heart.",
                level: "advanced",
                goal: "build_muscle",
                equipment: "full_gym",
                hexColors: ["DC143C", "8B0000"], // Crimson to Dark Red
                isSingleRoutine: true,
                routines: [
                    FBWorkoutPresetDTO(
                        name: "Lower Body Annihilation",
                        icon: "figure.strengthtraining.traditional",
                        folderName: nil,
                        exercises: [
                            FBExerciseDTO(name: "Barbell Squat", muscleGroup: "Legs", type: "Strength", category: "Other", effort: 9, isCompleted: false, setsList: nil, subExercises: nil, sets: 5, reps: 8, recommendedWeightKg: nil),
                            FBExerciseDTO(name: "Leg Press", muscleGroup: "Legs", type: "Strength", category: "Other", effort: 8, isCompleted: false, setsList: nil, subExercises: nil, sets: 4, reps: 12, recommendedWeightKg: nil),
                            FBExerciseDTO(name: "Walking Lunges", muscleGroup: "Legs", type: "Hypertrophy", category: "Other", effort: 8, isCompleted: false, setsList: nil, subExercises: nil, sets: 3, reps: 20, recommendedWeightKg: nil),
                            FBExerciseDTO(name: "Leg Extension", muscleGroup: "Legs", type: "Hypertrophy", category: "Other", effort: 9, isCompleted: false, setsList: nil, subExercises: nil, sets: 3, reps: 15, recommendedWeightKg: nil)
                        ]
                    )
                ]
            ),
            FBWorkoutProgram(
                id: nil,
                title: "Shoulder Boulders",
                descriptionText: "A volume-heavy deltoid routine to build those 3D shoulders.",
                level: "intermediate",
                goal: "build_muscle",
                equipment: "dumbbells_only",
                hexColors: ["1E90FF", "000080"], // Dodger Blue to Navy
                isSingleRoutine: true,
                routines: [
                    FBWorkoutPresetDTO(
                        name: "Deltoid Domination",
                        icon: "figure.gymnastics",
                        folderName: nil,
                        exercises: [
                            FBExerciseDTO(name: "Overhead Dumbbell Press", muscleGroup: "Shoulders", type: "Strength", category: "Other", effort: 8, isCompleted: false, setsList: nil, subExercises: nil, sets: 4, reps: 10, recommendedWeightKg: nil),
                            FBExerciseDTO(name: "Dumbbell Lateral Raise", muscleGroup: "Shoulders", type: "Hypertrophy", category: "Other", effort: 9, isCompleted: false, setsList: nil, subExercises: nil, sets: 4, reps: 15, recommendedWeightKg: nil),
                            FBExerciseDTO(name: "Reverse Pec Deck Fly", muscleGroup: "Shoulders", type: "Hypertrophy", category: "Other", effort: 7, isCompleted: false, setsList: nil, subExercises: nil, sets: 3, reps: 15, recommendedWeightKg: nil),
                            FBExerciseDTO(name: "Dumbbell Front Raise", muscleGroup: "Shoulders", type: "Hypertrophy", category: "Other", effort: 8, isCompleted: false, setsList: nil, subExercises: nil, sets: 3, reps: 12, recommendedWeightKg: nil)
                        ]
                    )
                ]
            )
        ]
        
        for program in newSolo {
            do {
                let docRef = exploreRef.document()
                try docRef.setData(from: program)
                print("✅ Seeded Solo Program: \(program.title ?? "")")
            } catch {
                print("❌ Failed to seed Solo Program: \(error)")
            }
        }
        
        print("🎉 Firestore Seed Complete!")
    }
}
