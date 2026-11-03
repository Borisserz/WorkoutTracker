import Foundation

enum StrengthGoalMatcher {
    /// A warm-up at the target load must not close a strength goal. Finish-workout uses the same rule.
    static func isMet(
        setType: SetType,
        isCompleted: Bool,
        weight: Double,
        reps: Int,
        targetWeight: Double,
        targetReps: Int
    ) -> Bool {
        isCompleted
            && setType != .warmup
            && weight >= targetWeight
            && reps >= targetReps
    }
}
