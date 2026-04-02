//
//  UserStatsViewModel.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 05.04.26.
//

internal import SwiftUI
import SwiftData
import Observation

@Observable
@MainActor
final class UserStatsViewModel {
    
    private let workoutStore: WorkoutStoreProtocol // Зависит строго от протокола хранилища
    
    // ProgressManager остается напрямую, так как это @Observable класс для UI-логики (не SwiftData)
    var progressManager: ProgressManager
    
    init(workoutStore: WorkoutStoreProtocol, progressManager: ProgressManager) {
        self.workoutStore = workoutStore
        self.progressManager = progressManager
    }
    
    // MARK: - Weight Tracking
    
    func addWeightEntry(weight: Double, date: Date = Date()) async {
        do {
            try await workoutStore.addWeightEntry(weight: weight, date: date)
            UserDefaults.standard.set(weight, forKey: Constants.UserDefaultsKeys.userBodyWeight.rawValue)
            await WorkoutEventBus.shared.triggerUpdate() // Уведомляем другие экраны об изменении (например, виджеты или графики)
        } catch {
            print("Error adding weight entry: \(error.localizedDescription)")
        }
    }
    
    func deleteWeightEntry(_ entryID: PersistentIdentifier) async {
        do {
            try await workoutStore.deleteWeightEntry(entryID)
            await WorkoutEventBus.shared.triggerUpdate()
        } catch {
            print("Error deleting weight entry: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Body Measurements
    
    func addBodyMeasurement(
        neck: Double?, shoulders: Double?, chest: Double?, waist: Double?,
        pelvis: Double?, biceps: Double?, thigh: Double?, calves: Double?,
        date: Date = Date()
    ) async {
        do {
            try await workoutStore.addBodyMeasurement(
                neck: neck, shoulders: shoulders, chest: chest,
                waist: waist, pelvis: pelvis, biceps: biceps,
                thigh: thigh, calves: calves, date: date
            )
            await WorkoutEventBus.shared.triggerUpdate()
        } catch {
            print("Error adding body measurement: \(error.localizedDescription)")
        }
    }
    
    func deleteBodyMeasurement(_ measurementID: PersistentIdentifier) async {
        do {
            try await workoutStore.deleteBodyMeasurement(measurementID)
            await WorkoutEventBus.shared.triggerUpdate()
        } catch {
            print("Error deleting body measurement: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Notes
    
    func saveExerciseNote(exerciseName: String, text: String, existingNoteID: PersistentIdentifier?) async {
        do {
            _ = try await workoutStore.saveExerciseNote(exerciseName: exerciseName, text: text, existingNoteID: existingNoteID)
        } catch {
            print("Error saving exercise note: \(error.localizedDescription)")
        }
    }
}
