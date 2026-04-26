import Foundation
#if os(iOS)
import FirebaseStorage
#endif

public enum MovementPattern: String, Codable, Sendable {
    case squat, hinge, lunge
    case horizontalPress, verticalPress
    case horizontalPull, verticalPull
    case elbowFlexion, elbowExtension
    case coreFlexion, lateralRaise, calfRaise
    case unsupported
}

public struct ExerciseDBItem: Codable, Sendable {
    public let id: String?
    public let name: String
    public let equipment: String?
    public let force: String?
    public let mechanic: String?
    public let primaryMuscles: [String]?
    public let secondaryMuscles: [String]?
    public let instructions: [String]?
    public let category: String?
    public let level: String?

    public var pattern: MovementPattern = .unsupported

    enum CodingKeys: String, CodingKey {
        case id, name, equipment, force, mechanic, primaryMuscles, secondaryMuscles, instructions, category, level
    }
}

public struct MuscleActivation: Sendable {
    public let slug: String
    public let multiplier: Double
}

public struct PatternClassifier: Sendable {
    public static func classify(name: String, force: String?, mechanic: String?, primaryMuscles: [String]?) -> MovementPattern {
        let n = name.lowercased()
        let f = force?.lowercased()
        let m = mechanic?.lowercased()
        let primary = primaryMuscles?.first?.lowercased() ?? ""

        if n.contains("curl") && !n.contains("leg") { return .elbowFlexion }
        if n.contains("squat") || n.contains("thruster") || n.contains("wall sit") { return .squat }
        if n.contains("deadlift") || n.contains("good morning") || n.contains("hyperextension") { return .hinge }
        if n.contains("lunge") || n.contains("step-up") || n.contains("step up") { return .lunge }
        if n.contains("calf raise") || n.contains("calves") { return .calfRaise }
        if n.contains("lateral raise") || n.contains("front raise") || n.contains("fly") { return .lateralRaise }

        switch primary {
        case "chest", "pectorals":
            return (f == "push") ? .horizontalPress : .unsupported
        case "shoulders", "delts", "deltoids":
            return (f == "push") ? .verticalPress : .lateralRaise
        case "middle back", "lats", "upper back", "traps", "trapezius":
            if f == "pull" { return n.contains("row") ? .horizontalPull : .verticalPull }
            return .unsupported
        case "triceps": return .elbowExtension
        case "biceps": return .elbowFlexion
        case "quadriceps", "quads", "glutes", "gluteal":
            return (m == "compound") ? .squat : .unsupported
        case "hamstrings", "hamstring", "lower back", "lower-back": return .hinge
        case "abdominals", "abs", "core", "obliques": return .coreFlexion
        default: return .unsupported
        }
    }
}

public actor ExerciseDatabaseService {
    public static let shared = ExerciseDatabaseService()

    private var exercisesDict: [String: ExerciseDBItem] = [:]
    private var groupedCatalog: [String: [String]] = [:]
    private var isLoaded: Bool = false

    private init() {}

    public func loadDatabase() async {
        guard !isLoaded else { return }
        
        var enData: Data?
        var ruData: Data?
        
        #if os(iOS)
        // 1. Пытаемся загрузить из Firebase (только для iPhone)
        let storage = Storage.storage()
        let enRef = storage.reference(withPath: "exercises.json")
        let ruRef = storage.reference(withPath: "exercises_ru.json")
        
        do {
            enData = try await enRef.data(maxSize: 5 * 1024 * 1024)
            ruData = try await ruRef.data(maxSize: 5 * 1024 * 1024)
            print("☁️✅ Каталог упражнений успешно загружен из Firebase Storage!")
        } catch {
            print("☁️⚠️ Ошибка загрузки из Firebase: \(error.localizedDescription). Переходим на локальные файлы.")
        }
        #endif
        
        // 2. Fallback для iPhone (и основной путь для Apple Watch)
        if enData == nil {
            if let localEnUrl = Bundle.main.url(forResource: "exercises", withExtension: "json") {
                enData = try? Data(contentsOf: localEnUrl)
                #if os(iOS)
                print("📱 Загружен ЛОКАЛЬНЫЙ английский каталог.")
                #endif
            }
        }
        
        if ruData == nil {
            if let localRuUrl = Bundle.main.url(forResource: "exercises_ru", withExtension: "json") {
                ruData = try? Data(contentsOf: localRuUrl)
                #if os(iOS)
                print("📱 Загружен ЛОКАЛЬНЫЙ русский каталог.")
                #endif
            }
        }
        
        guard let finalEnData = enData else {
            print("❌ Ошибка: не удалось найти базовый каталог упражнений ни в облаке, ни локально.")
            return
        }

        do {
            let items = try JSONDecoder().decode([ExerciseDBItem].self, from: finalEnData)

            var ruDict: [String: ExerciseDBItem] = [:]
            if Locale.current.language.languageCode?.identifier == "ru",
               let finalRuData = ruData,
               let ruItems = try? JSONDecoder().decode([ExerciseDBItem].self, from: finalRuData) {
                for item in ruItems {
                    if let id = item.id { ruDict[id] = item }
                }
            }

            var tempNamesRU: [String: String] = [:]
            var tempInstRU: [String: [String]] = [:]
            var dict: [String: ExerciseDBItem] = [:]
            var catalog: [String: Set<String>] = [:]

            for var item in items {
                item.pattern = PatternClassifier.classify(
                    name: item.name, force: item.force, mechanic: item.mechanic, primaryMuscles: item.primaryMuscles
                )
                let engKey = item.name.lowercased()
                dict[engKey] = item

                if let id = item.id, let ruItem = ruDict[id] {
                    tempNamesRU[engKey] = ruItem.name
                    if let inst = ruItem.instructions { tempInstRU[engKey] = inst }
                }

                let groupKey = item.primaryMuscles?.first?.capitalized ?? item.category?.capitalized ?? "Other"
                let mappedGroup = mapUIGroup(groupKey)
                catalog[mappedGroup, default: []].insert(item.name)
            }

            LocalizationHelper.shared.setTranslations(names: tempNamesRU, instructions: tempInstRU)
            self.exercisesDict = dict
            self.groupedCatalog = catalog.mapValues { Array($0).sorted() }
            self.isLoaded = true
            
        } catch {
            print("❌ Ошибка парсинга JSON упражнений: \(error)")
        }
    }

    public func getRelevantExercisesContext(for prompt: String, equipmentPref: String = "any", limit: Int = 20) -> [String] {
        let query = prompt.lowercased()
        var scoredItems: [(name: String, score: Int)] = []

        for item in exercisesDict.values {
            var score = 0
            let itemName = item.name.lowercased()
            let itemCategory = item.category?.lowercased() ?? ""
            let itemPrimary = item.primaryMuscles?.first?.lowercased() ?? ""
            let itemEquipment = item.equipment?.lowercased() ?? "bodyweight"

            if query.contains(itemPrimary) || query.contains(itemCategory) { score += 10 }
            if (query.contains("chest") || query.contains("pecs")) && itemPrimary == "chest" { score += 10 }
            if (query.contains("back") || query.contains("lats")) && itemPrimary == "lats" { score += 10 }
            if (query.contains("legs") || query.contains("quads") || query.contains("glutes")) && (itemCategory == "legs" || itemPrimary == "quadriceps") { score += 10 }
            if (query.contains("arm") || query.contains("bicep") || query.contains("tricep")) && (itemPrimary == "biceps" || itemPrimary == "triceps") { score += 10 }
            if (query.contains("shoulder") || query.contains("delt")) && itemPrimary == "deltoids" { score += 10 }

            let pref = equipmentPref.lowercased()
            if pref != "any" && pref != "full gym" {
                if pref.contains("dumbbell") && itemEquipment.contains("dumbbell") { score += 15 }
                if pref.contains("bodyweight") && (itemEquipment.contains("body") || itemEquipment == "none") { score += 15 }

                if pref.contains("bodyweight") && (itemEquipment.contains("barbell") || itemEquipment.contains("machine") || itemEquipment.contains("cable")) {
                    score -= 20
                }
                if pref.contains("dumbbell") && (itemEquipment.contains("barbell") || itemEquipment.contains("machine")) {
                    score -= 10
                }
            }

            if query.contains(itemName) { score += 50 }

            if score > 0 {
                scoredItems.append((item.name, score))
            }
        }

        let topItems = scoredItems
            .sorted { $0.score > $1.score }
            .prefix(limit)
            .map { $0.name }

        if topItems.isEmpty {
            return ["Bench Press", "Squat", "Deadlift", "Pull-ups", "Dumbbell Curls", "Shoulder Press", "Lunges", "Plank"]
        }

        return Array(topItems)
    }

    public func getCatalog() -> [String: [String]] { return groupedCatalog }
    public func getAllExerciseItems() -> [ExerciseDBItem] { return Array(exercisesDict.values) }
    public func getPattern(for exerciseName: String) -> MovementPattern { return exercisesDict[exerciseName.lowercased()]?.pattern ?? .unsupported }
    public func getExerciseItem(for exerciseName: String) -> ExerciseDBItem? { return exercisesDict[exerciseName.lowercased()] }

    public func getMuscleActivations(for exerciseName: String, fallbackGroup: String) -> [MuscleActivation] {
        guard let item = exercisesDict[exerciseName.lowercased()] else {
            return [MuscleActivation(slug: mapToSlug(fallbackGroup), multiplier: 1.0)]
        }
        var activations: [MuscleActivation] = []
        for muscle in item.primaryMuscles ?? [] { activations.append(MuscleActivation(slug: mapToSlug(muscle), multiplier: 1.0)) }
        if let secondary = item.secondaryMuscles {
            for muscle in secondary { activations.append(MuscleActivation(slug: mapToSlug(muscle), multiplier: 0.4)) }
        }
        return activations
    }

    private func mapToSlug(_ rawName: String) -> String {
        let lowercased = rawName.lowercased()
        switch lowercased {
        case "lower back", "lower-back": return "lower-back"
        case "middle back", "lats", "upper back", "traps", "trapezius": return "upper-back"
        case "forearms", "forearm": return "forearm"
        case "glutes", "gluteal": return "gluteal"
        case "hamstrings", "hamstring": return "hamstring"
        case "quadriceps", "quads": return "quadriceps"
        case "calves", "calf": return "calves"
        case "shoulders", "delts", "deltoids": return "deltoids"
        case "chest", "pectorals": return "chest"
        case "biceps": return "biceps"
        case "triceps": return "triceps"
        case "abdominals", "abs", "core": return "abs"
        case "obliques": return "obliques"
        case "adductors", "abductors": return "adductors"
        default: return lowercased.replacingOccurrences(of: " ", with: "-")
        }
    }

    private func mapUIGroup(_ rawName: String) -> String {
        let lower = rawName.lowercased()
        if lower.contains("chest") { return "Chest" }
        if lower.contains("back") || lower.contains("lats") { return "Back" }
        if lower.contains("leg") || lower.contains("quad") || lower.contains("ham") { return "Legs" }
        if lower.contains("shoulder") || lower.contains("delt") { return "Shoulders" }
        if lower.contains("bicep") || lower.contains("tricep") || lower.contains("arm") { return "Arms" }
        if lower.contains("ab") || lower.contains("core") { return "Core" }
        if lower.contains("cardio") { return "Cardio" }
        return rawName.capitalized
    }
}
