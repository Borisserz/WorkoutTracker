// ============================================================
// FILE: WorkoutTracker/Features/Profile/UserStatsViewModel.swift
// ============================================================

internal import SwiftUI
import SwiftData
import Observation

@Observable @MainActor
final class UserStatsViewModel {
    private let userRepository: UserRepositoryProtocol
    var progressManager: ProgressManager
    
    // Inject HealthKit implicitly or via DI. Using the global actor singleton for simplicity here.
    
    init(userRepository: UserRepositoryProtocol, progressManager: ProgressManager) {
        self.userRepository = userRepository
        self.progressManager = progressManager
    }
    
    /// Syncs weight from Apple Health on app launch or profile view appear
    func syncWeightFromHealthKit() async {
        do {
            try await HealthKitManager.shared.requestAuthorization()
            let hkWeight = try await HealthKitManager.shared.fetchLatestWeight()
            
            let currentLocalWeight = UserDefaults.standard.double(forKey: Constants.UserDefaultsKeys.userBodyWeight.rawValue)
            
            // If HealthKit weight differs (e.g. user stepped on smart scale), update our local DB
            if abs(hkWeight - currentLocalWeight) > 0.1 {
                UserDefaults.standard.set(hkWeight, forKey: Constants.UserDefaultsKeys.userBodyWeight.rawValue)
                try? await userRepository.addWeightEntry(weight: hkWeight, date: Date())
            }
        } catch {
            print("HealthKit sync skipped: \(error.localizedDescription)")
        }
    }
    
    /// Adds weight to local DB and pushes to Apple Health
    func addWeightEntry(weight: Double, date: Date = Date()) async {
        try? await userRepository.addWeightEntry(weight: weight, date: date)
        UserDefaults.standard.set(weight, forKey: Constants.UserDefaultsKeys.userBodyWeight.rawValue)
        
        // ✅ БЕЗОПАСНАЯ ПРОВЕРКА ЦЕЛИ ЧЕРЕЗ РЕПОЗИТОРИЙ (Без прямого доступа к ModelContext)
        if let goalAchieved = try? await userRepository.checkBodyweightGoal(currentWeight: weight), goalAchieved {
            // Если цель по весу достигнута, можно запустить триггер для UI (например, через NotificationCenter)
            // или обновить локальный стейт, чтобы на экране прогресса появилась ачивка.
            print("🎯 Bodyweight Goal Achieved!")
            NotificationCenter.default.post(name: NSNotification.Name("BodyweightGoalAchieved"), object: nil)
        }
        
        // Push to HealthKit
        Task.detached {
            try? await HealthKitManager.shared.saveWeight(weight, date: date)
        }
    }
    
    func deleteWeightEntry(_ entryID: PersistentIdentifier) async {
        try? await userRepository.deleteWeightEntry(entryID)
    }
    
    // ✅ ИСПРАВЛЕНИЕ: Новый элегантный метод для сохранения всей модели замеров сразу
    func saveBodyMeasurement(_ measurement: BodyMeasurement) async {
        try? await userRepository.saveBodyMeasurement(measurement)
    }
    
    func deleteBodyMeasurement(_ measurementID: PersistentIdentifier) async {
        try? await userRepository.deleteBodyMeasurement(measurementID)
    }
    
    func saveExerciseNote(exerciseName: String, text: String, existingNoteID: PersistentIdentifier?) async {
        _ = try? await userRepository.saveExerciseNote(exerciseName: exerciseName, text: text, existingNoteID: existingNoteID)
    }
}
