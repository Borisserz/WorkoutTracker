
internal import SwiftUI
import SwiftData
import Combine

@MainActor
class MuscleColorManager: ObservableObject {
    static let shared = MuscleColorManager()

    @Published var colors: [String: String] = [:]

    private var defaultColors: [String: Color] {
          let theme = ThemeManager.shared.current

          return [
              "Chest": theme.primaryAccent,           
              "Back": .green,                         
              "Legs": theme.secondaryMidTone,         
              "Shoulders": theme.deepPremiumAccent,   
              "Arms": .red,                           
              "Core": .yellow,                        
              "Cardio": theme.lightHighlight          
          ]
      }

    private var modelContainer: ModelContainer?

    private init() {}

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

        if let hex = colors[muscle] {
            return Color(hex: hex)
        }

        return defaultColors[muscle] ?? .gray
    }
}
