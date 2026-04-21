

import Foundation
internal import SwiftUI
import Observation

enum AIBuilderState {
    case idle
    case loading
    case success(GeneratedProgramDTO)
    case error(String)
}

enum MuscleTargetState: Int, Sendable {
    case neutral, grow, exclude

    mutating func toggle() {
        switch self {
        case .neutral: self = .grow
        case .grow: self = .exclude
        case .exclude: self = .neutral
        }
    }
}

@Observable
@MainActor
final class AIProgramBuilderViewModel {

    private let aiLogicService: AILogicService

    var goal: ProgramGoal = .buildMuscle
    var level: ProgramLevel = .intermediate
    var equipment: ProgramEquipment = .fullGym
    var daysPerWeek: Int = 4

    let availableMuscles = ["Chest", "Back", "Legs", "Shoulders", "Arms", "Core", "Cardio"]
    var muscleStates: [String: MuscleTargetState] = [:]

    var state: AIBuilderState = .idle
    var isSaving: Bool = false

    init(aiLogicService: AILogicService) {
        self.aiLogicService = aiLogicService
        for muscle in availableMuscles { muscleStates[muscle] = .neutral }
    }

    func generateProgram() async {
            self.state = .loading
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()

            let growList = muscleStates.filter { $0.value == .grow }.map { $0.key }
            let excludeList = muscleStates.filter { $0.value == .exclude }.map { $0.key }
            let isRussian = Locale.current.language.languageCode?.identifier == "ru" ? "Russian" : "English"

            let relevantCatalogArray = await ExerciseDatabaseService.shared.getRelevantExercisesContext(
                for: "full body program \(growList.joined(separator: " "))",
                equipmentPref: equipment.rawValue,
                limit: 100 
            )
            let safeCatalogContext = relevantCatalogArray.joined(separator: ", ")

            do {
                let dto = try await aiLogicService.generateMultiDayProgram(
                    goal: goal.rawValue,
                    level: level.rawValue,
                    days: daysPerWeek,
                    equipment: equipment.rawValue,
                    musclesToGrow: growList,
                    musclesToExclude: excludeList,
                    language: isRussian,
                    catalogContext: safeCatalogContext 
                )

                try await Task.sleep(for: .seconds(1.5))
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                self.state = .success(dto)
            } catch {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                self.state = .error(error.localizedDescription)
            }
        }

    func saveProgram(presetService: PresetService, dto: GeneratedProgramDTO) async {
        guard !isSaving else { return }
        isSaving = true

        let folderName = dto.title

        for routine in dto.schedule {
            let exercises: [Exercise] = routine.exercises.map { exDTO in
                let exerciseType = ExerciseType(rawValue: exDTO.type) ?? .strength
                let category = ExerciseCategory.determine(from: exDTO.name)

                let exercise = Exercise(
                    name: exDTO.name,
                    muscleGroup: exDTO.muscleGroup,
                    type: exerciseType,
                    category: category,
                    sets: exDTO.sets,
                    reps: exDTO.reps,
                    weight: exDTO.recommendedWeightKg ?? 0.0
                )

                if let rest = exDTO.restSeconds {
                    for set in exercise.setsList { set.time = rest }
                }
                return exercise
            }

            await presetService.savePreset(
                preset: nil,
                name: routine.dayName + ": " + routine.focus,
                icon: "brain.head.profile",
                folderName: folderName,
                exercises: exercises
            )
        }

        isSaving = false
    }
}
