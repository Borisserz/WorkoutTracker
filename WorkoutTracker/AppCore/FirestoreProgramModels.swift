//
//  FirestoreProgramModels.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 26.04.26.
//

import Foundation
import FirebaseFirestore
internal import SwiftUI

struct FBGeneratedExerciseDTO: Codable {
    let name: String?
    let muscleGroup: String?
    let type: String?
    let sets: Int?
    let reps: Int?
    let recommendedWeightKg: Double?
    let restSeconds: Int?
    
    func toDTO() -> GeneratedExerciseDTO {
        GeneratedExerciseDTO(
            name: name ?? "Unknown",
            muscleGroup: muscleGroup ?? "Other",
            type: type ?? "Strength",
            sets: sets ?? 3,
            reps: reps ?? 10,
            recommendedWeightKg: recommendedWeightKg,
            restSeconds: restSeconds
        )
    }
}

struct FBLegendaryRoutine: Codable, Identifiable {
    @DocumentID var id: String?
    let title: String?
    let eraTitle: String?
    let shortVibe: String?
    let loreDescription: String?
    let hexColors: [String]?
    let difficulty: String?
    let estimatedMinutes: Int?
    let benefits: [String]?
    let exercises: [FBGeneratedExerciseDTO]?
}

struct FBWorkoutSetDTO: Codable {
    let index: Int?
    let weight: Double?
    let reps: Int?
    let distance: Double?
    let time: Int?
    let isCompleted: Bool?
    let type: String?
    
    func toDTO() -> WorkoutSetDTO {
        WorkoutSetDTO(
            index: index ?? 1,
            weight: weight,
            reps: reps,
            distance: distance,
            time: time,
            isCompleted: isCompleted ?? false,
            type: SetType(rawValue: type ?? "N") ?? .normal
        )
    }
}

struct FBExerciseDTO: Codable {
    let name: String?
    let muscleGroup: String?
    let type: String?
    let category: String?
    let effort: Int?
    let isCompleted: Bool?

    let setsList: [FBWorkoutSetDTO]?
    let subExercises: [FBExerciseDTO]?

    let sets: Int?
    let reps: Int?
    let recommendedWeightKg: Double?
    
    func toDTO() -> ExerciseDTO {
        ExerciseDTO(
            name: name ?? "Unknown",
            muscleGroup: muscleGroup ?? "Other",
            type: ExerciseType(rawValue: type ?? "Strength") ?? .strength,
            category: ExerciseCategory(rawValue: category ?? "Other") ?? .other,
            effort: effort ?? 5,
            isCompleted: isCompleted ?? false,
            setsList: setsList?.map { $0.toDTO() },
            subExercises: subExercises?.map { $0.toDTO() },
            sets: sets,
            reps: reps,
            recommendedWeightKg: recommendedWeightKg
        )
    }
}

struct FBWorkoutPresetDTO: Codable {
    let name: String?
    let icon: String?
    let folderName: String?
    let exercises: [FBExerciseDTO]?
    
    func toDTO() -> WorkoutPresetDTO {
        WorkoutPresetDTO(
            name: name ?? "Unknown",
            icon: icon ?? "figure.run",
            folderName: folderName,
            exercises: (exercises ?? []).map { $0.toDTO() }
        )
    }
}

struct FBWorkoutProgram: Codable, Identifiable {
    @DocumentID var id: String?
    let title: String?
    let descriptionText: String?
    let level: String?
    let goal: String?
    let equipment: String?
    let hexColors: [String]?
    let isSingleRoutine: Bool?
    let routines: [FBWorkoutPresetDTO]?
}
