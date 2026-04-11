
internal import SwiftUI
import SwiftData
import Combine

@MainActor
class MuscleColorManager: ObservableObject {
    static let shared = MuscleColorManager()
    
    @Published var colors: [String: String] = [:]
    
    // ИСПРАВЛЕНИЕ: Дефолтные красивые цвета для диаграммы, если пользователь их не менял
    private var defaultColors: [String: Color] {
          let theme = ThemeManager.shared.current
          
          return [
              "Chest": theme.primaryAccent,           // Раньше: .blue
              "Back": .green,                         // Оставлено для контраста графика
              "Legs": theme.secondaryMidTone,         // Раньше: .orange
              "Shoulders": theme.deepPremiumAccent,   // Раньше: .purple
              "Arms": .red,                           // Оставлено для контраста графика
              "Core": .yellow,                        // Оставлено для контраста графика
              "Cardio": theme.lightHighlight          // Раньше: .teal
          ]
      }
    
    private var modelContainer: ModelContainer?
    
    private init() {}
    
    // Новая функция инициализации с ModelContainer
    func initialize(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        load(context: modelContainer.mainContext)
    }
    
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
