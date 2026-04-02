//
//  WorkoutService.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 2.04.26.
//


import Foundation
import SwiftData
import AudioToolbox
import WidgetKit // Для обновления виджетов
import ActivityKit // Для Live Activities

// MARK: - DTOs & Helper Enums (Moved from old WorkoutViewModel)
@Observable
@MainActor
final class WorkoutService {
    var currentError: AppError?
    
    // ИСПРАВЛЕНИЕ: Делаем сервис публичным, но только для чтения
    public private(set) var aiLogicService: AILogicService
    
    private let workoutStore: WorkoutStoreProtocol
    private let analyticsService: AnalyticsService
    private let exerciseCatalogService: ExerciseCatalogService
    private let widgetSyncService: WidgetSyncService
    private let notificationManager: NotificationManager
    private let progressManager: ProgressManager

    init(workoutStore: WorkoutStoreProtocol,
         analyticsService: AnalyticsService,
         exerciseCatalogService: ExerciseCatalogService,
         widgetSyncService: WidgetSyncService,
         aiLogicService: AILogicService,
         notificationManager: NotificationManager,
         progressManager: ProgressManager) {
        self.workoutStore = workoutStore
        self.analyticsService = analyticsService
        self.exerciseCatalogService = exerciseCatalogService
        self.widgetSyncService = widgetSyncService
        self.aiLogicService = aiLogicService
        self.notificationManager = notificationManager
        self.progressManager = progressManager
    }
    
    func showError(title: String, message: String) {
        self.currentError = AppError(title: title, message: message)
    }
    func saveAIChatSession(_ session: AIChatSession) async {
            do {
                try await workoutStore.saveAIChatSession(session)
            } catch {
                showError(title: "Error", message: "Could not save AI chat session: \(error.localizedDescription)")
            }
        }

        func fetchLatestWorkout() async -> Workout? {
            do {
                return try await workoutStore.fetchLatestWorkout()
            } catch {
                showError(title: "Error", message: "Failed to fetch latest workout")
                return nil
            }
        }
    // MARK: - Workout Management
    func createWorkout(title: String, presetID: PersistentIdentifier?, isAIGenerated: Bool) async -> PersistentIdentifier? {
        do {
            let id = try await workoutStore.createWorkout(title: title, fromPresetID: presetID, isAIGenerated: isAIGenerated)
            await WorkoutEventBus.shared.triggerUpdate()
            return id
        } catch {
            showError(title: String(localized: "Error"), message: error.localizedDescription)
            return nil
        }
    }
    
    func hasActiveWorkout() async -> Bool {
        // Мы используем findActiveWorkoutsAndCleanup для этого.
        // Если что-то вернулось, значит активная тренировка есть.
        do {
            let activeIDs = try await workoutStore.findActiveWorkoutsAndCleanup()
            return !activeIDs.isEmpty
        } catch {
            print("Error checking for active workouts: \(error)")
            return false
        }
    }
    
    func startGeneratedWorkout(_ generated: GeneratedWorkoutDTO) async {
        do {
            // Теперь вся грязная работа со SwiftData происходит внутри Актора
            let _ = try await workoutStore.createWorkoutFromAI(generated: generated)
            
            await WorkoutEventBus.shared.triggerUpdate()
            
            // Запускаем Live Activity
            let attributes = WorkoutActivityAttributes(workoutTitle: generated.title)
            let state = WorkoutActivityAttributes.ContentState(startTime: Date())
            _ = try? Activity<WorkoutActivityAttributes>.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil),
                pushType: nil
            )
            
        } catch {
            showError(title: "Save Failed", message: "Failed to save generated workout: \(error.localizedDescription)")
        }
    }

    
    // MARK: - Presets Operations
    func savePreset(preset: WorkoutPreset?, name: String, icon: String, exercises: [Exercise]) async {
        do {
            if let existingPreset = preset {
                try await workoutStore.updatePreset(presetID: existingPreset.persistentModelID, name: name, icon: icon, exercises: exercises)
            } else {
                try await workoutStore.createPreset(name: name, icon: icon, exercises: exercises)
            }
            await WorkoutEventBus.shared.triggerUpdate()
        } catch {
            showError(title: "Save Failed", message: "Failed to save template: \(error.localizedDescription)")
        }
    }
    
    func deletePreset(_ preset: WorkoutPreset) async {
        do {
            try await workoutStore.deletePreset(presetID: preset.persistentModelID)
            await WorkoutEventBus.shared.triggerUpdate()
        } catch {
            showError(title: "Delete Failed", message: "Failed to delete template: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Entity Manipulation
    
    func addSet(to exercise: Exercise, index: Int, weight: Double?, reps: Int?, distance: Double?, time: Int?, type: SetType, isCompleted: Bool) async {
        let exerciseID = exercise.persistentModelID
        do {
            try await workoutStore.addSet(toExerciseID: exerciseID, index: index, weight: weight, reps: reps, distance: distance, time: time, type: type, isCompleted: isCompleted)
        } catch {
            showError(title: "Error", message: "Could not add set: \(error.localizedDescription)")
        }
    }
    
    func deleteSet(_ set: WorkoutSet, from exercise: Exercise) async {
        let setID = set.persistentModelID
        let exerciseID = exercise.persistentModelID
        do {
            try await workoutStore.deleteSet(setID: setID, fromExerciseID: exerciseID)
        } catch {
            showError(title: "Error", message: "Could not delete set: \(error.localizedDescription)")
        }
    }
    
    func removeSubExercise(_ subExercise: Exercise, from superset: Exercise) async {
        let subID = subExercise.persistentModelID
        let supersetID = superset.persistentModelID
        do {
            try await workoutStore.removeSubExercise(subID: subID, fromSupersetID: supersetID)
        } catch {
            showError(title: "Error", message: "Could not remove sub-exercise: \(error.localizedDescription)")
        }
    }
    
    func removeExercise(_ exercise: Exercise, from workout: Workout) async {
        let exerciseID = exercise.persistentModelID
        let workoutID = workout.persistentModelID
        do {
            try await workoutStore.removeExercise(exerciseID: exerciseID, fromWorkoutID: workoutID)
        } catch {
            showError(title: "Error", message: "Could not remove exercise: \(error.localizedDescription)")
        }
    }
    
    func updateWorkoutFavoriteStatus(workout: Workout, isFavorite: Bool) async {
        do {
            try await workoutStore.updateWorkoutFavoriteStatus(workoutID: workout.persistentModelID, isFavorite: isFavorite)
        } catch {
            showError(title: "Error", message: "Could not update workout favorite status: \(error.localizedDescription)")
        }
    }

    func updateExerciseEffort(exercise: Exercise, newEffort: Int) async {
        do {
            try await workoutStore.updateExercise(exerciseID: exercise.persistentModelID, newEffort: newEffort)
        } catch {
            showError(title: "Error", message: "Could not update exercise effort: \(error.localizedDescription)")
        }
    }

    func updateWorkoutChatHistory(workout: Workout, history: [AIChatMessage]) async {
        do {
            try await workoutStore.updateWorkoutChatHistory(workoutID: workout.persistentModelID, history: history)
        } catch {
            showError(title: "Error", message: "Could not update AI chat history: \(error.localizedDescription)")
        }
    }

    func cleanupAndFindActiveWorkouts() async {
        do {
            _ = try await workoutStore.findActiveWorkoutsAndCleanup()
        } catch {
            print("Cleanup failed: \(error.localizedDescription)")
        }
    }
    
    func deleteWorkout(_ workout: Workout) async {
        let workoutID = workout.persistentModelID
        do {
            try await workoutStore.deleteWorkout(workoutID: workoutID)
            // Rebuild stats will be triggered by DashboardViewModel listening to WorkoutEventBus
            await WorkoutEventBus.shared.triggerUpdate()
        } catch {
            showError(title: "Delete Failed", message: "Could not delete workout: \(error.localizedDescription)")
        }
    }
    
    func processCompletedWorkout(_ workout: Workout) async {
        let workoutID = workout.persistentModelID
        do {
            try await workoutStore.processCompletedWorkout(workoutID: workoutID)
            // Rebuild stats will be triggered by DashboardViewModel listening to WorkoutEventBus
            await WorkoutEventBus.shared.triggerUpdate()
        } catch {
            showError(title: "Process Failed", message: "Could not process completed workout: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Import/Export (Delegated to WorkoutExportService)
    func generateShareLink(for preset: WorkoutPreset) throws -> URL {
        return try WorkoutExportService.generateShareLink(for: preset.toDTO())
    }
    
    func exportPresetToFile(_ preset: WorkoutPreset) async throws -> URL {
        guard let fetchedPreset = try await workoutStore.fetchPreset(by: preset.persistentModelID) else {
            throw WorkoutRepositoryError.modelNotFound
        }
        return try WorkoutExportService.exportPresetToFile(fetchedPreset.toDTO())
    }

    func exportPresetToCSV(_ preset: WorkoutPreset) async throws -> URL {
        guard let fetchedPreset = try await workoutStore.fetchPreset(by: preset.persistentModelID) else {
            throw WorkoutRepositoryError.modelNotFound
        }
        return try WorkoutExportService.exportPresetToCSV(fetchedPreset.toDTO())
    }

    func applyAIAdjustment(_ adjustment: InWorkoutResponseDTO, to workout: Workout) async {
        do {
            try await workoutStore.applyAIAdjustment(adjustment, workoutID: workout.persistentModelID)
            await WorkoutEventBus.shared.triggerUpdate()
        } catch {
            showError(title: "AI Update Failed", message: "Could not apply AI recommendations: \(error.localizedDescription)")
        }
    }
    
    func importPreset(from url: URL) async -> Bool {
        do {
            let presetDTO = try WorkoutExportService.importPreset(from: url)
            // Создаем новый пресет из DTO и сохраняем его
            try await workoutStore.createPreset(name: presetDTO.name + " (Imported)", icon: presetDTO.icon, exercises: presetDTO.exercises.map { Exercise(from: $0) })
            await WorkoutEventBus.shared.triggerUpdate()
            return true
        } catch {
            showError(title: String(localized: "Import Failed"), message: error.localizedDescription)
            return false
        }
    }
    
    // MARK: - Utilities (Delegated to ExerciseCatalogService & WidgetSyncService)
    func checkAndGenerateDefaultPresets() async {
        do {
            try await exerciseCatalogService.checkAndGenerateDefaultPresets()
        } catch {
            print("Failed to generate default presets: \(error.localizedDescription)")
        }
    }
    
    func updateWidgetData() async {
        await widgetSyncService.updateWidgetData()
    }

}
