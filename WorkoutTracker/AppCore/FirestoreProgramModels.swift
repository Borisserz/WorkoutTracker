//
//  FirestoreProgramModels.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 26.04.26.
//

import Foundation
import FirebaseFirestore
internal import SwiftUI

struct FBLegendaryRoutine: Codable, Identifiable {
    @DocumentID var id: String?
    let title: String
    let eraTitle: String
    let shortVibe: String
    let loreDescription: String
    let hexColors: [String]
    let difficulty: String
    let estimatedMinutes: Int
    let benefits: [String]
    let exercises: [GeneratedExerciseDTO]
}

struct FBWorkoutProgram: Codable, Identifiable {
    @DocumentID var id: String?
    let title: String
    let descriptionText: String
    let level: String
    let goal: String
    let equipment: String
    let hexColors: [String]
    let isSingleRoutine: Bool
    let routines: [WorkoutPresetDTO]
}
