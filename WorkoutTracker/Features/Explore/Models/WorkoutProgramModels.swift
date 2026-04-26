

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
