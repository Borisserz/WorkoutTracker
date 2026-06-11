import Foundation

public enum MovementPattern: String, Codable {
    case squat, hinge, lunge, horizontalPress, verticalPress, horizontalPull, verticalPull, elbowFlexion, elbowExtension, coreFlexion, lateralRaise, calfRaise, unsupported
}

public struct PatternClassifier {
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
        case "chest", "pectorals": return (f == "push") ? .horizontalPress : .unsupported
        case "shoulders", "delts", "deltoids": return (f == "push") ? .verticalPress : .lateralRaise
        case "middle back", "lats", "upper back", "traps", "trapezius":
            if f == "pull" { return n.contains("row") ? .horizontalPull : .verticalPull }
            return .unsupported
        case "triceps": return .elbowExtension
        case "biceps": return .elbowFlexion
        case "quadriceps", "quads", "glutes", "gluteal": return (m == "compound") ? .squat : .unsupported
        case "hamstrings", "hamstring", "lower back", "lower-back": return .hinge
        case "abdominals", "abs", "core", "obliques": return .coreFlexion
        default: return .unsupported
        }
    }
}

public struct ExerciseDBItem: Codable {
    public let id: String?
    public let name: String
    public let force: String?
    public let mechanic: String?
    public let equipment: String?
    public let primaryMuscles: [String]?
    public let secondaryMuscles: [String]?
    public let instructions: [String]?
    public let category: String?
    
    public var pattern: MovementPattern = .unsupported

    enum CodingKeys: String, CodingKey {
        case id, name, force, mechanic, equipment, primaryMuscles, secondaryMuscles, instructions, category
    }
}

let url = URL(fileURLWithPath: "./WorkoutTracker/DataLayer/LocalDB/exercises.json")
let data = try! Data(contentsOf: url)
let items = try! JSONDecoder().decode([ExerciseDBItem].self, from: data)

var dict: [String: ExerciseDBItem] = [:]
for var item in items {
    item.pattern = PatternClassifier.classify(
        name: item.name, force: item.force, mechanic: item.mechanic, primaryMuscles: item.primaryMuscles
    )
    let engKey = item.name.lowercased()
    dict[engKey] = item
}

let keys = dict.keys.filter { $0.contains("squat") }
print("Squat variants: \(keys)")

if let item = dict["squats"] {
    print("Found 'squats'! Pattern: \(item.pattern)")
} else {
    print("'squats' NOT FOUND in dict!")
}

if let item = dict["squat"] {
    print("Found 'squat'! Pattern: \(item.pattern)")
} else {
    print("'squat' NOT FOUND in dict!")
}

