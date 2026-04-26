

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
