import Foundation
import SwiftData

/// Best finished workout session entry ranked by active personal records held.
struct BestSessionEntry: Identifiable {
    let workout: Workout
    let recordCount: Int
    let recordExercises: [String]

    var id: UUID { workout.id }
}

/// Ranks finished sessions across the entire workout history by current exercise personal records.
enum HistoryBestSessionQuery {
    static let limit = 6

    /// Legacy volume-ordered descriptor kept for store-level window fetch checks.
    static func descriptor() -> FetchDescriptor<Workout> {
        var descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate<Workout> { $0.endTime != nil },
            sortBy: [SortDescriptor(\.totalStrengthVolume, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return descriptor
    }

    /// Fetches all finished sessions from SwiftData and returns top PR-holding sessions.
    @MainActor
    static func fetchBestSessions(
        in context: ModelContext,
        includeWarmups: Bool = false,
        limit: Int = HistoryBestSessionQuery.limit
    ) -> [BestSessionEntry] {
        let descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate<Workout> { $0.endTime != nil },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let allFinished = (try? context.fetch(descriptor)) ?? []
        return rankBestSessions(from: allFinished, includeWarmups: includeWarmups, limit: limit)
    }

    private struct ExerciseScore: Comparable {
        let tier: Int
        let primary: Double
        let secondary: Double

        static func < (lhs: ExerciseScore, rhs: ExerciseScore) -> Bool {
            if lhs.tier != rhs.tier { return lhs.tier < rhs.tier }
            if lhs.primary != rhs.primary { return lhs.primary < rhs.primary }
            return lhs.secondary < rhs.secondary
        }
    }

    private struct WinningRecord {
        let workout: Workout
        let exerciseName: String
        let score: ExerciseScore
    }

    /// Ranks finished sessions by how many current all-time exercise PRs each session holds.
    /// Ties on exercise score go to the most recent session; ties on PR count favor the latest PR session date.
    static func rankBestSessions(
        from workouts: [Workout],
        includeWarmups: Bool = false,
        limit: Int = HistoryBestSessionQuery.limit
    ) -> [BestSessionEntry] {
        let finished = workouts.filter { $0.endTime != nil }
        guard !finished.isEmpty, limit > 0 else { return [] }

        var currentBests: [String: WinningRecord] = [:]

        for workout in finished {
            var sessionBestPerExercise: [String: (displayName: String, score: ExerciseScore)] = [:]

            for exercise in workout.exercises {
                let targets = exercise.isSuperset ? exercise.subExercises : [exercise]
                for ex in targets {
                    let displayName = ex.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    let key = displayName.lowercased()
                    guard !key.isEmpty,
                          let score = bestScore(for: ex, includeWarmups: includeWarmups) else {
                        continue
                    }
                    if let existing = sessionBestPerExercise[key] {
                        if existing.score < score {
                            sessionBestPerExercise[key] = (displayName, score)
                        }
                    } else {
                        sessionBestPerExercise[key] = (displayName, score)
                    }
                }
            }

            for (key, candidate) in sessionBestPerExercise {
                if let incumbent = currentBests[key] {
                    if incumbent.score < candidate.score ||
                        (incumbent.score == candidate.score && workout.date > incumbent.workout.date) {
                        currentBests[key] = WinningRecord(
                            workout: workout,
                            exerciseName: candidate.displayName,
                            score: candidate.score
                        )
                    }
                } else {
                    currentBests[key] = WinningRecord(
                        workout: workout,
                        exerciseName: candidate.displayName,
                        score: candidate.score
                    )
                }
            }
        }

        var grouped: [UUID: (workout: Workout, exercises: [String])] = [:]
        for record in currentBests.values {
            var bucket = grouped[record.workout.id] ?? (record.workout, [])
            bucket.exercises.append(record.exerciseName)
            grouped[record.workout.id] = bucket
        }

        return grouped.values
            .map { bucket in
                BestSessionEntry(
                    workout: bucket.workout,
                    recordCount: bucket.exercises.count,
                    recordExercises: bucket.exercises.sorted()
                )
            }
            .sorted { lhs, rhs in
                if lhs.recordCount != rhs.recordCount {
                    return lhs.recordCount > rhs.recordCount
                }
                if lhs.workout.date != rhs.workout.date {
                    return lhs.workout.date > rhs.workout.date
                }
                return lhs.workout.totalStrengthVolume > rhs.workout.totalStrengthVolume
            }
            .prefix(limit)
            .map { $0 }
    }

    private static func bestScore(for exercise: Exercise, includeWarmups: Bool) -> ExerciseScore? {
        switch exercise.type {
        case .strength:
            let validSets = exercise.setsList.filter { set in
                set.isCompleted && (includeWarmups || set.type != .warmup)
            }
            guard !validSets.isEmpty else { return nil }

            let weightedSets = validSets.filter { ($0.weight ?? 0.0) > 0.0 }
            if let bestWeighted = weightedSets.max(by: { lhs, rhs in
                let lw = lhs.weight ?? 0.0
                let rw = rhs.weight ?? 0.0
                if lw == rw { return (lhs.reps ?? 0) < (rhs.reps ?? 0) }
                return lw < rw
            }) {
                let w = bestWeighted.weight ?? 0.0
                let r = bestWeighted.reps ?? 0
                return ExerciseScore(tier: 3, primary: w, secondary: Double(r))
            }

            let maxReps = validSets.compactMap(\.reps).max() ?? 0
            guard maxReps > 0 else { return nil }
            let totalReps = validSets.reduce(0) { $0 + ($1.reps ?? 0) }
            return ExerciseScore(tier: 2, primary: Double(maxReps), secondary: Double(totalReps))

        case .cardio:
            let totalDistance = exercise.setsList
                .filter(\.isCompleted)
                .compactMap(\.distance)
                .reduce(0.0, +)
            guard totalDistance > 0.0 else { return nil }
            return ExerciseScore(tier: 1, primary: totalDistance, secondary: 0.0)

        case .duration:
            let totalTime = exercise.setsList
                .filter(\.isCompleted)
                .compactMap(\.time)
                .reduce(0, +)
            guard totalTime > 0 else { return nil }
            return ExerciseScore(tier: 1, primary: Double(totalTime), secondary: 0.0)
        }
    }
}
