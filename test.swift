import Foundation

// Copying necessary structs
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

// Emulate Pushups JSON loading
let pushupsJSON = """
{
  "name": "Pushups",
  "force": "push",
  "mechanic": "compound",
  "primaryMuscles": ["chest"]
}
""".data(using: .utf8)!

struct MockItem: Codable {
    let name: String
    let force: String?
    let mechanic: String?
    let primaryMuscles: [String]?
}

let item = try! JSONDecoder().decode(MockItem.self, from: pushupsJSON)
let pattern = PatternClassifier.classify(name: item.name, force: item.force, mechanic: item.mechanic, primaryMuscles: item.primaryMuscles)
print("Pattern for Pushups is: \(pattern)")
