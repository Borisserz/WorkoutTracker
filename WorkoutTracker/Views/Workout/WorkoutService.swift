//
//  WorkoutService.swift
//  WorkoutTracker
//

import Foundation
import SwiftData
import AudioToolbox
import WidgetKit

@Observable
@MainActor
final class WorkoutService {
    // ❌ УБРАНО: var currentError: AppError?
    
    public private(set) var aiLogicService: AILogicService
    
    private let workoutStore: WorkoutStoreProtocol
    private let analyticsService: AnalyticsService
    private let exerciseCatalogService: ExerciseCatalogService
    private let widgetSyncService: WidgetSyncService
    private let notificationManager: NotificationManager
    private let progressManager: ProgressManager
    
    // ✅ ДОБАВЛЕНО: Инъекция стейт-менеджера и Live Activity менеджера
    private let appState: AppStateManager
    private let liveActivityManager: LiveActivityManager

    init(workoutStore: WorkoutStoreProtocol,
         analyticsService: AnalyticsService,
         exerciseCatalogService: ExerciseCatalogService,
         widgetSyncService: WidgetSyncService,
         aiLogicService: AILogicService,
         notificationManager: NotificationManager,
         progressManager: ProgressManager,
         appState: AppStateManager,
         liveActivityManager: LiveActivityManager) {
        
        self.workoutStore = workoutStore
        self.analyticsService = analyticsService
        self.exerciseCatalogService = exerciseCatalogService
        self.widgetSyncService = widgetSyncService
        self.aiLogicService = aiLogicService
        self.notificationManager = notificationManager
        self.progressManager = progressManager
        self.appState = appState
        self.liveActivityManager = liveActivityManager
    }
    


    func fetchLatestWorkout() async -> Workout? {
        do {
            return try await workoutStore.fetchLatestWorkout()
        } catch {
            appState.showError(title: "Error", message: "Failed to fetch latest workout")
            return nil
        }
    }
    
    // MARK: - Workout Management
    func createWorkout(title: String, presetID: PersistentIdentifier?, isAIGenerated: Bool) async -> PersistentIdentifier? {
        do {
            let id = try await workoutStore.createWorkout(title: title, fromPresetID: presetID, isAIGenerated: isAIGenerated)
            
            return id
        } catch {
            appState.showError(title: String(localized: "Error"), message: error.localizedDescription)
            return nil
        }
    }
    
    func hasActiveWorkout() async -> Bool {
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
            _ = try await workoutStore.createWorkoutFromAI(generated: generated)
            
            
            // ✅ ИСПОЛЬЗУЕМ ВЫДЕЛЕННЫЙ СЕРВИС
            liveActivityManager.startWorkoutActivity(title: generated.title)
            
        } catch {
            appState.showError(title: "Save Failed", message: "Failed to save generated workout: \(error.localizedDescription)")
        }
    }
    


    
    // MARK: - Entity Manipulation
    func addSet(to exercise: Exercise, index: Int, weight: Double?, reps: Int?, distance: Double?, time: Int?, type: SetType, isCompleted: Bool) async {
        do {
            try await workoutStore.addSet(toExerciseID: exercise.persistentModelID, index: index, weight: weight, reps: reps, distance: distance, time: time, type: type, isCompleted: isCompleted)
        } catch {
            appState.showError(title: "Error", message: "Could not add set: \(error.localizedDescription)")
        }
    }
    
    func deleteSet(_ set: WorkoutSet, from exercise: Exercise) async {
        do {
            try await workoutStore.deleteSet(setID: set.persistentModelID, fromExerciseID: exercise.persistentModelID)
        } catch {
            appState.showError(title: "Error", message: "Could not delete set: \(error.localizedDescription)")
        }
    }
    func deleteSets(_ sets: [WorkoutSet], from exercise: Exercise) async {
          let ids = sets.map { $0.persistentModelID }
          do {
              try await workoutStore.deleteSets(setIDs: ids, fromExerciseID: exercise.persistentModelID)
          } catch {
              appState.showError(title: "Error", message: "Could not batch delete sets: \(error.localizedDescription)")
          }
      }
    func removeSubExercise(_ subExercise: Exercise, from superset: Exercise) async {
        do {
            try await workoutStore.removeSubExercise(subID: subExercise.persistentModelID, fromSupersetID: superset.persistentModelID)
        } catch {
            appState.showError(title: "Error", message: "Could not remove sub-exercise: \(error.localizedDescription)")
        }
    }
    
    func removeExercise(_ exercise: Exercise, from workout: Workout) async {
        do {
            try await workoutStore.removeExercise(exerciseID: exercise.persistentModelID, fromWorkoutID: workout.persistentModelID)
        } catch {
            appState.showError(title: "Error", message: "Could not remove exercise: \(error.localizedDescription)")
        }
    }
    
    func updateWorkoutFavoriteStatus(workout: Workout, isFavorite: Bool) async {
        do {
            try await workoutStore.updateWorkoutFavoriteStatus(workoutID: workout.persistentModelID, isFavorite: isFavorite)
        } catch {
            appState.showError(title: "Error", message: "Could not update workout favorite status: \(error.localizedDescription)")
        }
    }

    func updateExerciseEffort(exercise: Exercise, newEffort: Int) async {
        do {
            try await workoutStore.updateExercise(exerciseID: exercise.persistentModelID, newEffort: newEffort)
        } catch {
            appState.showError(title: "Error", message: "Could not update exercise effort: \(error.localizedDescription)")
        }
    }

    func updateWorkoutChatHistory(workout: Workout, history: [AIChatMessage]) async {
        do {
            try await workoutStore.updateWorkoutChatHistory(workoutID: workout.persistentModelID, history: history)
        } catch {
            appState.showError(title: "Error", message: "Could not update AI chat history: \(error.localizedDescription)")
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
        do {
            try await workoutStore.deleteWorkout(workoutID: workout.persistentModelID)
            
        } catch {
            appState.showError(title: "Delete Failed", message: "Could not delete workout: \(error.localizedDescription)")
        }
    }
    
    func processCompletedWorkout(_ workout: Workout) async {
        do {
            try await workoutStore.processCompletedWorkout(workoutID: workout.persistentModelID)
            
        } catch {
            appState.showError(title: "Process Failed", message: "Could not process completed workout: \(error.localizedDescription)")
        }
    }
    


    func applyAIAdjustment(_ adjustment: InWorkoutResponseDTO, to workout: Workout) async {
        do {
            try await workoutStore.applyAIAdjustment(adjustment, workoutID: workout.persistentModelID)
            
        } catch {
            appState.showError(title: "AI Update Failed", message: "Could not apply AI recommendations: \(error.localizedDescription)")
        }
    }
    

    
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
