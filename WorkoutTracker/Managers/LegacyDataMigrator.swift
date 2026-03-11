import Foundation
import SwiftData

struct LegacyDataMigrator {
    
    @MainActor
    static func migrateAllIfNeeded(context: ModelContext) {
        let defaults = UserDefaults.standard
        let hasMigrated = defaults.bool(forKey: "hasMigratedToSwiftData_v2")
        
        if !hasMigrated {
            migrateWeightHistory(context: context)
            migrateExerciseNotes(context: context)
            migrateMuscleColors(context: context)
            
            try? context.save()
            defaults.set(true, forKey: "hasMigratedToSwiftData_v2")
            print("✅ Успешная миграция всех данных в SwiftData")
        }
    }
    
    // 1. Миграция Веса из JSON
    private static func migrateWeightHistory(context: ModelContext) {
        let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("weight_history.json")
        
        // Временная структура для декодирования старого JSON
        struct OldWeightEntry: Codable {
            var id: UUID
            var date: Date
            var weight: Double
        }
        
        if let data = try? Data(contentsOf: fileURL),
           let oldEntries = try? JSONDecoder().decode([OldWeightEntry].self, from: data) {
            
            for oldEntry in oldEntries {
                let newEntry = WeightEntry(id: oldEntry.id, date: oldEntry.date, weight: oldEntry.weight)
                context.insert(newEntry)
            }
            // Удаляем старый файл
            try? FileManager.default.removeItem(at: fileURL)
        }
    }
    
    // 2. Миграция Заметок из UserDefaults
    private static func migrateExerciseNotes(context: ModelContext) {
        let defaults = UserDefaults.standard
        if let oldNotes = defaults.dictionary(forKey: "ExerciseNotes") as? [String: String] {
            for (exerciseName, text) in oldNotes {
                let newNote = ExerciseNote(exerciseName: exerciseName, text: text)
                context.insert(newNote)
            }
            defaults.removeObject(forKey: "ExerciseNotes")
        }
    }
    
    // 3. Миграция Цветов из UserDefaults
    private static func migrateMuscleColors(context: ModelContext) {
        let defaults = UserDefaults.standard
        if let oldColors = defaults.dictionary(forKey: "MuscleColors") as? [String: String] {
            for (muscle, hex) in oldColors {
                let newColor = MuscleColorPreference(muscleName: muscle, hexColor: hex)
                context.insert(newColor)
            }
            defaults.removeObject(forKey: "MuscleColors")
        }
    }
}
