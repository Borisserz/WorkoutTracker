internal import SwiftUI
import SwiftData
import Observation

@Observable @MainActor
final class UserStatsViewModel {
    private let userRepository: UserRepositoryProtocol // 🟢 Изменено
    var progressManager: ProgressManager
    
    init(userRepository: UserRepositoryProtocol, progressManager: ProgressManager) {
        self.userRepository = userRepository
        self.progressManager = progressManager
    }
    
    func addWeightEntry(weight: Double, date: Date = Date()) async {
        try? await userRepository.addWeightEntry(weight: weight, date: date)
        UserDefaults.standard.set(weight, forKey: Constants.UserDefaultsKeys.userBodyWeight.rawValue)
    }
    
    func deleteWeightEntry(_ entryID: PersistentIdentifier) async {
        try? await userRepository.deleteWeightEntry(entryID)
    }
    
    func addBodyMeasurement(neck: Double?, shoulders: Double?, chest: Double?, waist: Double?, pelvis: Double?, biceps: Double?, thigh: Double?, calves: Double?, date: Date = Date()) async {
        try? await userRepository.addBodyMeasurement(neck: neck, shoulders: shoulders, chest: chest, waist: waist, pelvis: pelvis, biceps: biceps, thigh: thigh, calves: calves, date: date)
    }
    
    func deleteBodyMeasurement(_ measurementID: PersistentIdentifier) async {
        try? await userRepository.deleteBodyMeasurement(measurementID)
    }
    
    func saveExerciseNote(exerciseName: String, text: String, existingNoteID: PersistentIdentifier?) async {
        _ = try? await userRepository.saveExerciseNote(exerciseName: exerciseName, text: text, existingNoteID: existingNoteID)
    }
}
