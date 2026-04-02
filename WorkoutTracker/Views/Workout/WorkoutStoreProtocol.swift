//
//  WorkoutStoreProtocol.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 2.04.26.
//

import Foundation
import SwiftData

/// Абстракция слоя доступа к данным SwiftData.
/// Всегда работает в изолированном акторе.
protocol WorkoutStoreProtocol: Sendable {
    func createWorkout(title: String, fromPresetID presetID: PersistentIdentifier?, isAIGenerated: Bool) async throws -> PersistentIdentifier
    func createWorkoutFromAI(generated: GeneratedWorkoutDTO) async throws -> PersistentIdentifier // Новый метод
    func addSet(toExerciseID: PersistentIdentifier, index: Int, weight: Double?, reps: Int?, distance: Double?, time: Int?, type: SetType, isCompleted: Bool) async throws
    func deleteSet(setID: PersistentIdentifier, fromExerciseID: PersistentIdentifier) async throws
    func removeSubExercise(subID: PersistentIdentifier, fromSupersetID: PersistentIdentifier) async throws
    func removeExercise(exerciseID: PersistentIdentifier, fromWorkoutID: PersistentIdentifier) async throws
    func deleteWorkout(workoutID: PersistentIdentifier) async throws
    func updateWorkoutFavoriteStatus(workoutID: PersistentIdentifier, isFavorite: Bool) async throws
    func updateExercise(exerciseID: PersistentIdentifier, newEffort: Int) async throws
    func updateWorkoutChatHistory(workoutID: PersistentIdentifier, history: [AIChatMessage]) async throws
    func applyAIAdjustment(_ adjustment: InWorkoutResponseDTO, workoutID: PersistentIdentifier) async throws // Добавлен в протокол
    func processCompletedWorkout(workoutID: PersistentIdentifier) async throws
    func findActiveWorkoutsAndCleanup() async throws -> [PersistentIdentifier]
    func createPreset(name: String, icon: String, exercises: [Exercise]) async throws
    func updatePreset(presetID: PersistentIdentifier, name: String, icon: String, exercises: [Exercise]) async throws
    func deletePreset(presetID: PersistentIdentifier) async throws
    func fetchPreset(by id: PersistentIdentifier) async throws -> WorkoutPreset?
    func addWeightEntry(weight: Double, date: Date) async throws
    func deleteWeightEntry(_ entryID: PersistentIdentifier) async throws
    func fetchLatestWorkout() async throws -> Workout?
    func addBodyMeasurement(neck: Double?, shoulders: Double?, chest: Double?, waist: Double?, pelvis: Double?, biceps: Double?, thigh: Double?, calves: Double?, date: Date) async throws
    func deleteBodyMeasurement(_ measurementID: PersistentIdentifier) async throws
    func saveExerciseNote(exerciseName: String, text: String, existingNoteID: PersistentIdentifier?) async throws -> PersistentIdentifier?
    func deleteAIChatSession(_ sessionID: PersistentIdentifier) async throws
    func addCustomExercise(name: String, category: String, targetedMuscles: [String], type: ExerciseType) async throws
    func deleteCustomExercise(name: String, category: String) async throws
    func hideDefaultExercise(name: String, category: String) async throws
    func fetchCustomExercises() async throws -> [CustomExerciseDefinition]
    func fetchDeletedDefaultExercises() async throws -> Set<String>
    func checkAndGenerateDefaultPresets() async throws
    func fetchExerciseNote(exerciseName: String) async throws -> ExerciseNote?
    func fetchAIChatSessions() async throws -> [AIChatSession]
    func saveAIChatSession(_ session: AIChatSession) async throws
}
