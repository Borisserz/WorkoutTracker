import Foundation

/// RPE / effort is always 1…10 in UI (`EffortInputView`). Out-of-range values (e.g. legacy `50`) must clamp.
enum EffortScale {
    static let minimum = 1
    static let maximum = 10

    static func clamp(_ value: Int) -> Int {
        min(maximum, max(minimum, value))
    }
}

/// Prefer template rest → effort heuristic → caller default.
enum RestDurationPolicy {
    /// Auto-rest after completing a strength set. `nil` = don't invent a duration (non-strength).
    static func suggestedSeconds(
        templateRestSeconds: Int?,
        effort: Int,
        exerciseType: ExerciseType
    ) -> Int? {
        if let templateRestSeconds, templateRestSeconds > 0 {
            return templateRestSeconds
        }
        guard exerciseType == .strength else { return nil }
        let e = EffortScale.clamp(effort)
        if e >= 8 { return 180 }
        if e >= 6 { return 120 }
        return 90
    }

    /// 1-tap / manual start: template or effort heuristic, else user default (or 60).
    static func resolveSeconds(
        templateRestSeconds: Int?,
        effort: Int,
        exerciseType: ExerciseType,
        userDefaultRest: Int
    ) -> Int {
        if let suggested = suggestedSeconds(
            templateRestSeconds: templateRestSeconds,
            effort: effort,
            exerciseType: exerciseType
        ) {
            return suggested
        }
        return userDefaultRest > 0 ? userDefaultRest : 60
    }

    /// Label and tap on the session rest button. Both must use this so the printed time is the time that starts.
    /// No pending set → saved default, else 60 (same fallback as `resolveSeconds`).
    static func manualButtonSeconds(
        pendingTemplateRest: Int?,
        pendingEffort: Int?,
        pendingType: ExerciseType?,
        userDefaultRest: Int
    ) -> Int {
        if let pendingType {
            return resolveSeconds(
                templateRestSeconds: pendingTemplateRest,
                effort: pendingEffort ?? EffortScale.minimum,
                exerciseType: pendingType,
                userDefaultRest: userDefaultRest
            )
        }
        return userDefaultRest > 0 ? userDefaultRest : 60
    }
}
