import Foundation
import SwiftData

// Этого актора можно было бы удалить, если бы он не выполнял миграцию.
// Но так как он её выполняет, его лучше сохранить как изолированный актор.
@ModelActor
actor LegacyDataMigrator {
    
    func migrateAllIfNeeded() async { // Добавил async
        let defaults = UserDefaults.standard
        let hasMigrated = defaults.bool(forKey: Constants.UserDefaultsKeys.hasMigratedToSwiftData_v2.rawValue)
        
        guard !hasMigrated else { return }
        
        // Вся миграция должна происходить в фоновом потоке
        await migrateWeightHistory()
        await migrateExerciseNotes()
        await migrateMuscleColors()
        
        // Используем встроенный в актор modelContext
        try? modelContext.save()
        
        defaults.set(true, forKey: Constants.UserDefaultsKeys.hasMigratedToSwiftData_v2.rawValue)
        print("✅ Успешная фоновая миграция данных в SwiftData")
    }
    
    private func migrateWeightHistory() async { // Добавил async
        let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("weight_history.json")
        struct OldWeightEntry: Codable { var id: UUID; var date: Date; var weight: Double }
        
        if let data = try? Data(contentsOf: fileURL), let oldEntries = try? JSONDecoder().decode([OldWeightEntry].self, from: data) {
            for oldEntry in oldEntries {
                modelContext.insert(WeightEntry(id: oldEntry.id, date: oldEntry.date, weight: oldEntry.weight))
            }
            try? FileManager.default.removeItem(at: fileURL)
        }
    }
    
    private func migrateExerciseNotes() async { // Добавил async
        let defaults = UserDefaults.standard
        if let oldNotes = defaults.dictionary(forKey: Constants.UserDefaultsKeys.exerciseNotes.rawValue) as? [String: String] {
            for (exerciseName, text) in oldNotes {
                modelContext.insert(ExerciseNote(exerciseName: exerciseName, text: text))
            }
            defaults.removeObject(forKey: Constants.UserDefaultsKeys.exerciseNotes.rawValue)
        }
    }
    
    private func migrateMuscleColors() async { // Добавил async
        let defaults = UserDefaults.standard
        if let oldColors = defaults.dictionary(forKey: Constants.UserDefaultsKeys.muscleColors.rawValue) as? [String: String] {
            for (muscle, hex) in oldColors {
                modelContext.insert(MuscleColorPreference(muscleName: muscle, hexColor: hex))
            }
            defaults.removeObject(forKey: Constants.UserDefaultsKeys.muscleColors.rawValue)
        }
    }
}
