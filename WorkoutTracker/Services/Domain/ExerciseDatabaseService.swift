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
    public let level: String? // Добавили level, так как удалили extension
    
    public var pattern: MovementPattern = .unsupported
    
    // Игнорируем 'pattern' при чтении JSON
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

// MARK: - 4. Database Service
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
            
            var dict: [String: ExerciseDBItem] = [:]
            var catalog: [String: Set<String>] = [:]
            
            for var item in items {
                item.pattern = PatternClassifier.classify(
                    name: item.name, force: item.force, mechanic: item.mechanic, primaryMuscles: item.primaryMuscles
                )
                dict[item.name.lowercased()] = item
                
                let groupKey = item.primaryMuscles?.first?.capitalized ?? item.category?.capitalized ?? "Other"
                let mappedGroup = mapUIGroup(groupKey)
                catalog[mappedGroup, default: []].insert(item.name)
            }
            
            self.exercisesDict = dict
            self.groupedCatalog = catalog.mapValues { Array($0).sorted() }
            self.isLoaded = true
        } catch { print("❌ Failed to parse: \(error)") }
    }
    
    public func getCatalog() -> [String: [String]] { return groupedCatalog }
    public func getAllExerciseItems() -> [ExerciseDBItem] { return Array(exercisesDict.values) }
    public func getInstructions(for exerciseName: String) -> [String]? { return exercisesDict[exerciseName.lowercased()]?.instructions }
    public func getPattern(for exerciseName: String) -> MovementPattern { return exercisesDict[exerciseName.lowercased()]?.pattern ?? .unsupported }
    public func getExerciseItem(for exerciseName: String) -> ExerciseDBItem? {
           return exercisesDict[exerciseName.lowercased()]
       }
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
