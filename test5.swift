import Foundation

struct PatternClassifier {
    static func classify(name: String) -> String {
        let n = name.lowercased()
        if n.contains("squat") { return "squat" }
        return "unsupported"
    }
}
print(PatternClassifier.classify(name: "Squats"))
