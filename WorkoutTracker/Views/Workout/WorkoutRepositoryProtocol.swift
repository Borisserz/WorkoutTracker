// WorkoutRepositoryProtocol.swift
import Foundation
import SwiftData

/// Абстракция слоя доступа к данным.
protocol WorkoutRepositoryProtocol: Sendable {
    func createWorkout(title: String, fromPresetID presetID: PersistentIdentifier?) async throws -> PersistentIdentifier
    func addSet(toExerciseID: PersistentIdentifier, index: Int, weight: Double?, reps: Int?, distance: Double?, time: Int?, type: SetType, isCompleted: Bool) async throws
    func deleteSet(setID: PersistentIdentifier, fromExerciseID: PersistentIdentifier) async throws
    func removeSubExercise(subID: PersistentIdentifier, fromSupersetID: PersistentIdentifier) async throws
    func removeExercise(exerciseID: PersistentIdentifier, fromWorkoutID: PersistentIdentifier) async throws
    func cleanupAndFindActiveWorkouts() async throws -> Bool
    func deleteWorkout(workoutID: PersistentIdentifier) async throws
    func processCompletedWorkout(workoutID: PersistentIdentifier) async throws
    func rebuildAllStats() async
    
    // Import / Export
    func exportPresetToFile(presetID: PersistentIdentifier) async throws -> URL
    func exportPresetToCSV(presetID: PersistentIdentifier) async throws -> URL
    func importPreset(from url: URL) async throws
    
    func updateWidgetData() async throws
    func applyAIAdjustment(_ adjustment: InWorkoutResponseDTO, workoutID: PersistentIdentifier) async throws
    
    // Fetchers
    func fetchDashboardCache() async throws -> DashboardCacheDTO
    func fetchWorkoutAnalytics(workoutID: PersistentIdentifier) async throws -> WorkoutAnalyticsData
    func fetchCustomExercises() async throws -> [CustomExerciseDefinition]
    func fetchDeletedDefaultExercises() async throws -> Set<String>
    func checkAndGenerateDefaultPresets() async throws
}
