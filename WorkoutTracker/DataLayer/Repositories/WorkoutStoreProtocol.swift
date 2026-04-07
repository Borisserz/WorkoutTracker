// ============================================================
// FILE: WorkoutTracker/Views/Workout/WorkoutStoreProtocol.swift
// ============================================================

import Foundation
import SwiftData

/// Абстракция слоя доступа к данным SwiftData для Тренировок.
protocol WorkoutStoreProtocol: Sendable {
    func swapExercise(oldID: PersistentIdentifier, newExerciseDTO: ExerciseDTO, inWorkoutID: PersistentIdentifier) async throws
    func createWorkout(title: String, fromPresetID presetID: PersistentIdentifier?, isAIGenerated: Bool) async throws -> PersistentIdentifier
    func createWorkoutFromAI(generated: GeneratedWorkoutDTO) async throws -> PersistentIdentifier
    func addSet(toExerciseID: PersistentIdentifier, index: Int, weight: Double?, reps: Int?, distance: Double?, time: Int?, type: SetType, isCompleted: Bool) async throws
    func deleteSet(setID: PersistentIdentifier, fromExerciseID: PersistentIdentifier) async throws
    func deleteSets(setIDs: [PersistentIdentifier], fromExerciseID: PersistentIdentifier) async throws
    func removeSubExercise(subID: PersistentIdentifier, fromSupersetID: PersistentIdentifier) async throws
    func removeExercise(exerciseID: PersistentIdentifier, fromWorkoutID: PersistentIdentifier) async throws
    func deleteWorkout(workoutID: PersistentIdentifier) async throws
    func updateWorkoutFavoriteStatus(workoutID: PersistentIdentifier, isFavorite: Bool) async throws
    func updateExercise(exerciseID: PersistentIdentifier, newEffort: Int) async throws
    func updateWorkoutChatHistory(workoutID: PersistentIdentifier, history: [AIChatMessage]) async throws
    func applyAIAdjustment(_ adjustment: InWorkoutResponseDTO, workoutID: PersistentIdentifier) async throws
    func processCompletedWorkout(workoutID: PersistentIdentifier) async throws
    func findActiveWorkoutsAndCleanup() async throws -> [PersistentIdentifier]
    func fetchLatestWorkout() async throws -> Workout?
    func checkAndGenerateDefaultPresets() async throws

    // ✅ ДОБАВЛЕН НЕДОСТАЮЩИЙ МЕТОД
    func applySmartAction(proposal: SmartActionDTO, inWorkoutID: PersistentIdentifier) async throws
}
