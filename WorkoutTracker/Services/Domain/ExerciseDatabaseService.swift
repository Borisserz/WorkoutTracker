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
    public let gifUrl: String?

    public var pattern: MovementPattern = .unsupported

    enum CodingKeys: String, CodingKey {
        case id, name, equipment, force, mechanic, primaryMuscles, secondaryMuscles, instructions, category, level, gifUrl
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
        
        let currentLang = Locale.current.language.languageCode?.identifier ?? "en"
        let langPrefix = String(currentLang.prefix(2))
        
        // Define supported localizations
        let supportedLocalizedLangs = ["ru", "de", "es", "fr", "it"]
        var targetLangFile: String? = nil
        
        if supportedLocalizedLangs.contains(langPrefix) {
            targetLangFile = "exercises_\(langPrefix).json"
        } else if currentLang == "pt-PT" || langPrefix == "pt" {
            targetLangFile = "exercises_pt-PT.json"
        }
        
        var enData: Data?
        var localizedData: Data?
        
        #if os(iOS)
        let storage = Storage.storage()
        let enRef = storage.reference(withPath: "exercises.json")
        var localizedRef: StorageReference?
        if let targetLangFile = targetLangFile {
            localizedRef = storage.reference(withPath: targetLangFile)
        }
        
        do {
            enData = try await enRef.data(maxSize: 5 * 1024 * 1024)
            if let localizedRef = localizedRef {
                localizedData = try await localizedRef.data(maxSize: 5 * 1024 * 1024)
            }
            print("☁️✅ The exercise catalog has been successfully uploaded from Firebase Storage!")
        } catch {
            print("☁️⚠️ Error downloading from Firebase: \(error.localizedDescription). We switch to local files.")
        }
        #endif
        
        // 2. Fallback для iPhone (и основной путь для Apple Watch)
        if enData == nil {
            if let localEnUrl = Bundle.main.url(forResource: "exercises", withExtension: "json") {
                enData = try? Data(contentsOf: localEnUrl)
                #if os(iOS)
                print("📱 The LOCAL English directory has been loaded.")
                #endif
            }
        }
        
        if targetLangFile != nil && localizedData == nil {
            let fileName = targetLangFile!.replacingOccurrences(of: ".json", with: "")
            if let localLocUrl = Bundle.main.url(forResource: fileName, withExtension: "json") {
                localizedData = try? Data(contentsOf: localLocUrl)
                #if os(iOS)
                print("📱 The LOCAL \(fileName) directory has been loaded.")
                #endif
            }
        }
        
        guard let finalEnData = enData else {
            print("❌ Error: Could not find the base exercise directory either in the cloud or locally.")
            return
        }

        do {
            let items = try JSONDecoder().decode([ExerciseDBItem].self, from: finalEnData)

            var locDict: [String: ExerciseDBItem] = [:]
            if targetLangFile != nil,
               let finalLocData = localizedData,
               let locItems = try? JSONDecoder().decode([ExerciseDBItem].self, from: finalLocData) {
                for item in locItems {
                    if let id = item.id { locDict[id] = item }
                }
            }

            var tempNamesLoc: [String: String] = [:]
            var tempInstLoc: [String: [String]] = [:]
            var dict: [String: ExerciseDBItem] = [:]
            var catalog: [String: Set<String>] = [:]

            for var item in items {
                item.pattern = PatternClassifier.classify(
                    name: item.name, force: item.force, mechanic: item.mechanic, primaryMuscles: item.primaryMuscles
                )
                let engKey = item.name.lowercased()
                dict[engKey] = item

                if let id = item.id, let locItem = locDict[id] {
                    tempNamesLoc[engKey] = locItem.name
                    if let inst = locItem.instructions { tempInstLoc[engKey] = inst }
                }

                let groupKey = item.primaryMuscles?.first?.capitalized ?? item.category?.capitalized ?? "Other"
                let mappedGroup = mapUIGroup(groupKey)
                catalog[mappedGroup, default: []].insert(item.name)
            }

            LocalizationHelper.shared.setTranslations(names: tempNamesLoc, instructions: tempInstLoc)
            self.exercisesDict = dict
            self.groupedCatalog = catalog.mapValues { Array($0).sorted() }
            self.isLoaded = true
            
        } catch {
            print("❌ JSON parsing error for exercises: \(error)")
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
    public func getPattern(for exerciseName: String) -> MovementPattern {
        if let pattern = exercisesDict[exerciseName.lowercased()]?.pattern {
            return pattern
        }
        return PatternClassifier.classify(name: exerciseName, force: nil, mechanic: nil, primaryMuscles: nil)
    }
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
