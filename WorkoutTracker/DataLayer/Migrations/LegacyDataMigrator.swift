import Foundation
import OSLog
import SwiftData

@ModelActor
actor LegacyDataMigrator {

    func migrateAllIfNeeded() async {
        let defaults = UserDefaults.standard
        let hasMigrated = defaults.bool(forKey: Constants.UserDefaultsKeys.hasMigratedToSwiftData_v2.rawValue)
        guard !hasMigrated else { return }

        let weightURL = await migrateWeightHistory()
        let notesMigrated = await migrateExerciseNotes()
        let colorsMigrated = await migrateMuscleColors()

        do {
            try modelContext.save()
        } catch {
            AppLog.migration.error("❌ Legacy migration save failed — sources kept for retry: \(error.localizedDescription, privacy: .public)")
            return
        }

        // Only remove sources after a durable SwiftData save.
        if let weightURL {
            try? FileManager.default.removeItem(at: weightURL)
        }
        if notesMigrated {
            defaults.removeObject(forKey: Constants.UserDefaultsKeys.exerciseNotes.rawValue)
        }
        if colorsMigrated {
            defaults.removeObject(forKey: Constants.UserDefaultsKeys.muscleColors.rawValue)
        }

        defaults.set(true, forKey: Constants.UserDefaultsKeys.hasMigratedToSwiftData_v2.rawValue)
        AppLog.migration.info("✅ Successful background data migration in SwiftData")
    }

    private func migrateWeightHistory() async -> URL? {
        let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("weight_history.json")
        struct OldWeightEntry: Codable { var id: UUID; var date: Date; var weight: Double }

        guard let data = try? Data(contentsOf: fileURL),
              let oldEntries = try? JSONDecoder().decode([OldWeightEntry].self, from: data) else {
            return nil
        }
        for oldEntry in oldEntries {
            modelContext.insert(WeightEntry(id: oldEntry.id, date: oldEntry.date, weight: oldEntry.weight))
        }
        return fileURL
    }

    private func migrateExerciseNotes() async -> Bool {
        let defaults = UserDefaults.standard
        guard let oldNotes = defaults.dictionary(forKey: Constants.UserDefaultsKeys.exerciseNotes.rawValue) as? [String: String],
              !oldNotes.isEmpty else {
            return false
        }
        for (exerciseName, text) in oldNotes {
            modelContext.insert(ExerciseNote(exerciseName: exerciseName, text: text))
        }
        return true
    }

    private func migrateMuscleColors() async -> Bool {
        let defaults = UserDefaults.standard
        guard let oldColors = defaults.dictionary(forKey: Constants.UserDefaultsKeys.muscleColors.rawValue) as? [String: String],
              !oldColors.isEmpty else {
            return false
        }
        for (muscle, hex) in oldColors {
            modelContext.insert(MuscleColorPreference(muscleName: muscle, hexColor: hex))
        }
        return true
    }
}
