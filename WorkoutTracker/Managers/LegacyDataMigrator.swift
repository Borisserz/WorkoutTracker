
import Foundation
import SwiftData

struct LegacyDataMigrator {
    
    @MainActor
    static func migrateAllIfNeeded(context: ModelContext) {
        let defaults = UserDefaults.standard
        let hasMigrated = defaults.bool(forKey: Constants.UserDefaultsKeys.hasMigratedToSwiftData_v2.rawValue)
        
        if !hasMigrated {
            migrateWeightHistory(context: context)
            migrateExerciseNotes(context: context)
            migrateMuscleColors(context: context)
            
            try? context.save()
            defaults.set(true, forKey: Constants.UserDefaultsKeys.hasMigratedToSwiftData_v2.rawValue)
            print("✅ Успешная миграция всех данных в SwiftData")
        }
    }
    
    private static func migrateWeightHistory(context: ModelContext) {
        let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("weight_history.json")
        struct OldWeightEntry: Codable { var id: UUID; var date: Date; var weight: Double }
        if let data = try? Data(contentsOf: fileURL), let oldEntries = try? JSONDecoder().decode([OldWeightEntry].self, from: data) {
            for oldEntry in oldEntries { context.insert(WeightEntry(id: oldEntry.id, date: oldEntry.date, weight: oldEntry.weight)) }
            try? FileManager.default.removeItem(at: fileURL)
        }
    }
    
    private static func migrateExerciseNotes(context: ModelContext) {
        let defaults = UserDefaults.standard
        if let oldNotes = defaults.dictionary(forKey: Constants.UserDefaultsKeys.exerciseNotes.rawValue) as? [String: String] {
            for (exerciseName, text) in oldNotes { context.insert(ExerciseNote(exerciseName: exerciseName, text: text)) }
            defaults.removeObject(forKey: Constants.UserDefaultsKeys.exerciseNotes.rawValue)
        }
    }
    
    private static func migrateMuscleColors(context: ModelContext) {
        let defaults = UserDefaults.standard
        if let oldColors = defaults.dictionary(forKey: Constants.UserDefaultsKeys.muscleColors.rawValue) as? [String: String] {
            for (muscle, hex) in oldColors { context.insert(MuscleColorPreference(muscleName: muscle, hexColor: hex)) }
            defaults.removeObject(forKey: Constants.UserDefaultsKeys.muscleColors.rawValue)
        }
    }
}
