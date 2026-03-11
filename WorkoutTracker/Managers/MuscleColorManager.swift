internal import SwiftUI
import SwiftData
import Combine

@MainActor
class MuscleColorManager: ObservableObject {
    static let shared = MuscleColorManager()
    
    @Published var colors: [String: String] = [:]
    
    // ИСПРАВЛЕНИЕ: Дефолтные красивые цвета для диаграммы, если пользователь их не менял
    private let defaultColors: [String: Color] = [
        "Chest": .blue,
        "Back": .green,
        "Legs": .orange,
        "Shoulders": .purple,
        "Arms": .red,
        "Core": .yellow,
        "Cardio": .teal
    ]
    
    private init() {}
    
    func load(context: ModelContext) {
        let descriptor = FetchDescriptor<MuscleColorPreference>()
        if let prefs = try? context.fetch(descriptor), !prefs.isEmpty {
            for pref in prefs {
                colors[pref.muscleName] = pref.hexColor
            }
        }
    }
    
    func save(muscle: String, hex: String, context: ModelContext) {
        colors[muscle] = hex
        
        let descriptor = FetchDescriptor<MuscleColorPreference>(predicate: #Predicate { $0.muscleName == muscle })
        
        if let existing = try? context.fetch(descriptor).first {
            existing.hexColor = hex
        } else {
            let newPref = MuscleColorPreference(muscleName: muscle, hexColor: hex)
            context.insert(newPref)
        }
        
        try? context.save()
    }
    
    func getColor(for muscle: String) -> Color {
        // Если пользователь задал свой цвет, возвращаем его
        if let hex = colors[muscle] {
            return Color(hex: hex)
        }
        // Иначе возвращаем дефолтный цвет для этой группы
        return defaultColors[muscle] ?? .gray
    }
}
