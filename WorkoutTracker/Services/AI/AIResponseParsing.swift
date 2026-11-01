import Foundation

/// Shared helpers for free-model / OpenRouter responses that often wrap JSON in
/// markdown fences or prose. Used by `AILogicService` before Codable decode.
enum AIResponseParsing: Sendable {

    /// Returns the most likely JSON object/array substring from a model reply.
    nonisolated static func extractJSONObject(from raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("```") {
            // ```json\n...\n``` or ```\n...\n```
            if let firstNL = text.firstIndex(of: "\n") {
                text = String(text[text.index(after: firstNL)...])
            }
            if let fence = text.range(of: "```", options: .backwards) {
                text = String(text[..<fence.lowerBound])
            }
            text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let data = text.data(using: .utf8),
           (try? JSONSerialization.jsonObject(with: data)) != nil {
            return text
        }

        // Prose + JSON: take outermost { ... } or [ ... ]
        if let start = text.firstIndex(of: "{"),
           let end = text.lastIndex(of: "}"),
           start < end {
            let slice = String(text[start...end])
            if let data = slice.data(using: .utf8),
               (try? JSONSerialization.jsonObject(with: data)) != nil {
                return slice
            }
        }
        if let start = text.firstIndex(of: "["),
           let end = text.lastIndex(of: "]"),
           start < end {
            let slice = String(text[start...end])
            if let data = slice.data(using: .utf8),
               (try? JSONSerialization.jsonObject(with: data)) != nil {
                return slice
            }
        }
        return text
    }
}

/// On-device intent routing so we don't burn an OpenRouter call (and rate limit)
/// just to decide chat vs workout-plan generation.
enum AIIntentClassifier: Sendable {

    nonisolated static func wantsWorkoutPlan(_ message: String) -> Bool {
        let text = message.lowercased()
        let positive = [
            "workout", "routine", "program", "split", "training plan",
            "build me", "create a", "generate a", "make me a", "plan a",
            "трениров", "программ", "сгенерир", "составь", "создай",
            "план на", "комплекс"
        ]
        let negativeOnlyChat = [
            "how ", "why ", "what is", "should i", "можно ли", "как ", "почему ",
            "что такое", "привет", "hello", "hi "
        ]
        let hitPositive = positive.contains { text.contains($0) }
        guard hitPositive else { return false }
        // "how to program progressive overload" is chat, not a plan request
        if text.contains("how to") || text.contains("как правильно") {
            return text.contains("workout") || text.contains("routine") || text.contains("трениров")
        }
        if negativeOnlyChat.contains(where: { text.hasPrefix($0.trimmingCharacters(in: .whitespaces)) })
            && !text.contains("workout") && !text.contains("routine") && !text.contains("трениров") {
            return false
        }
        return true
    }
}
