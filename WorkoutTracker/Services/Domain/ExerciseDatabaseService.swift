// ============================================================
// FILE: WorkoutTracker/Services/Domain/ExerciseDatabaseService.swift
// ============================================================

import Foundation

// MARK: - 1. Movement Patterns
public enum MovementPattern: String, Codable, Sendable {
    case squat, hinge, lunge
    case horizontalPress, verticalPress
    case horizontalPull, verticalPull
    case elbowFlexion, elbowExtension
    case coreFlexion, lateralRaise, calfRaise
    case unsupported
}

// MARK: - 2. Data Models
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

// MARK: - 3. Pattern Classifier
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

// MARK: - 4. Database Service (with RAG Engine)
public actor ExerciseDatabaseService {
    public static let shared = ExerciseDatabaseService()
    
    private var exercisesDict: [String: ExerciseDBItem] = [:]
    private var groupedCatalog: [String: [String]] = [:]
    private var isLoaded: Bool = false
    
    private init() {}
    
    public func loadDatabase() {
        guard !isLoaded else { return }
        guard let url = Bundle.main.url(forResource: "exercises", withExtension: "json") else { return }
        
        do {
            let data = try Data(contentsOf: url)
            let items = try JSONDecoder().decode([ExerciseDBItem].self, from: data)
            
            var ruDict: [String: ExerciseDBItem] = [:]
            if Locale.current.language.languageCode?.identifier == "ru",
               let ruUrl = Bundle.main.url(forResource: "exercises_ru", withExtension: "json"),
               let ruData = try? Data(contentsOf: ruUrl),
               let ruItems = try? JSONDecoder().decode([ExerciseDBItem].self, from: ruData) {
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
        } catch { print("❌ Failed to parse: \(error)") }
    }
    
    // MARK: - RAG Engine (Smart Filtering)
    /// Локальный векторный-like поиск для формирования микро-контекста ИИ
    public func getRelevantExercisesContext(for prompt: String, equipmentPref: String = "any", limit: Int = 20) -> [String] {
        let query = prompt.lowercased()
        var scoredItems: [(name: String, score: Int)] = []
        
        for item in exercisesDict.values {
            var score = 0
            let itemName = item.name.lowercased()
            let itemCategory = item.category?.lowercased() ?? ""
            let itemPrimary = item.primaryMuscles?.first?.lowercased() ?? ""
            let itemEquipment = item.equipment?.lowercased() ?? "bodyweight"
            
            // 1. Поиск по мышечным группам (Высокий приоритет)
            if query.contains(itemPrimary) || query.contains(itemCategory) { score += 10 }
            if (query.contains("chest") || query.contains("pecs")) && itemPrimary == "chest" { score += 10 }
            if (query.contains("back") || query.contains("lats")) && itemPrimary == "lats" { score += 10 }
            if (query.contains("legs") || query.contains("quads") || query.contains("glutes")) && (itemCategory == "legs" || itemPrimary == "quadriceps") { score += 10 }
            if (query.contains("arm") || query.contains("bicep") || query.contains("tricep")) && (itemPrimary == "biceps" || itemPrimary == "triceps") { score += 10 }
            if (query.contains("shoulder") || query.contains("delt")) && itemPrimary == "deltoids" { score += 10 }
            
            // 2. Инвентарь (Положительные и отрицательные веса)
            let pref = equipmentPref.lowercased()
            if pref != "any" && pref != "full gym" {
                if pref.contains("dumbbell") && itemEquipment.contains("dumbbell") { score += 15 }
                if pref.contains("bodyweight") && (itemEquipment.contains("body") || itemEquipment == "none") { score += 15 }
                
                // Пенальти за несовпадение инвентаря
                if pref.contains("bodyweight") && (itemEquipment.contains("barbell") || itemEquipment.contains("machine") || itemEquipment.contains("cable")) {
                    score -= 20
                }
                if pref.contains("dumbbell") && (itemEquipment.contains("barbell") || itemEquipment.contains("machine")) {
                    score -= 10
                }
            }
            
            // 3. Прямое упоминание названия (Точное попадание)
            if query.contains(itemName) { score += 50 }
            
            if score > 0 {
                scoredItems.append((item.name, score))
            }
        }
        
        let topItems = scoredItems
            .sorted { $0.score > $1.score }
            .prefix(limit)
            .map { $0.name }
        
        // Фоллбэк: если запрос вообще не относится к фитнесу (пользователь просто написал "привет")
        if topItems.isEmpty {
            return ["Bench Press", "Squat", "Deadlift", "Pull-ups", "Dumbbell Curls", "Shoulder Press", "Lunges", "Plank"]
        }
        
        return Array(topItems)
    }
    
    // Вспомогательные геттеры
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
