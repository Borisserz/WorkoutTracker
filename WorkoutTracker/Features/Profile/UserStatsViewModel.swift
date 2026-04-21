

internal import SwiftUI
import SwiftData
import Observation

@Observable @MainActor
final class UserStatsViewModel {
    private let userRepository: UserRepositoryProtocol
    var progressManager: ProgressManager

    init(userRepository: UserRepositoryProtocol, progressManager: ProgressManager) {
        self.userRepository = userRepository
        self.progressManager = progressManager
    }
    func syncWeightFromHealthKit() async {
        do {
            try await HealthKitManager.shared.requestAuthorization()
            let hkWeight = try await HealthKitManager.shared.fetchLatestWeight()

            let currentLocalWeight = UserDefaults.standard.double(forKey: Constants.UserDefaultsKeys.userBodyWeight.rawValue)

            if abs(hkWeight - currentLocalWeight) > 0.1 {
                UserDefaults.standard.set(hkWeight, forKey: Constants.UserDefaultsKeys.userBodyWeight.rawValue)
                try? await userRepository.addWeightEntry(weight: hkWeight, date: Date(), imageFileNames: [])
            }
        } catch {
            print("HealthKit sync skipped: \(error.localizedDescription)")
        }
    }

    func addWeightEntry(weight: Double, date: Date = Date(), images: [UIImage] = []) async {
        var savedFileNames: [String] = []

        if !images.isEmpty {
            do {
                savedFileNames = try await LocalImageStore.shared.saveImages(images)
            } catch {
                print("❌ Failed to save progress photos: \(error.localizedDescription)")
            }
        }

        try? await userRepository.addWeightEntry(weight: weight, date: date, imageFileNames: savedFileNames)
        UserDefaults.standard.set(weight, forKey: Constants.UserDefaultsKeys.userBodyWeight.rawValue)

        if let goalAchieved = try? await userRepository.checkBodyweightGoal(currentWeight: weight), goalAchieved {
            NotificationCenter.default.post(name: NSNotification.Name("BodyweightGoalAchieved"), object: nil)
        }

        Task.detached {
            try? await HealthKitManager.shared.saveWeight(weight, date: date)
        }
    }
    func deleteWeightEntry(_ entryID: PersistentIdentifier) async {
        try? await userRepository.deleteWeightEntry(entryID)
    }

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
