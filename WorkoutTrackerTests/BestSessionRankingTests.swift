import Foundation
import Testing
@testable import WorkoutTracker

@Suite("Best Session PR Ranking Tests")
struct BestSessionRankingTests {

    private func makeSet(weight: Double? = nil, reps: Int? = nil, distance: Double? = nil, time: Int? = nil, type: SetType = .normal, completed: Bool = true) -> WorkoutSet {
        WorkoutSet(
            index: 1,
            weight: weight,
            reps: reps,
            distance: distance,
            time: time,
            isCompleted: completed,
            type: type
        )
    }

    private func makeExercise(name: String, type: ExerciseType = .strength, muscle: String = "Chest", sets: [WorkoutSet]) -> Exercise {
        Exercise(
            name: name,
            muscleGroup: muscle,
            type: type,
            effort: 8,
            setsList: sets,
            isCompleted: sets.contains(where: \.isCompleted)
        )
    }

    private func makeFinishedWorkout(title: String, daysAgo: Double, exercises: [Exercise]) -> Workout {
        let date = Date().addingTimeInterval(-daysAgo * 86_400)
        let workout = Workout(title: title, date: date)
        workout.endTime = date.addingTimeInterval(3_600)
        workout.exercises = exercises
        workout.totalStrengthVolume = exercises.reduce(0.0) { total, ex in
            total + ex.setsList
                .filter { $0.isCompleted && $0.type != .warmup }
                .reduce(0.0) { $0 + ($1.weight ?? 0.0) * Double($1.reps ?? 0) }
        }
        return workout
    }

    @Test("Zero-volume or uncompleted sessions never appear as Record sessions")
    func excludesEmptyAndUncompletedWorkouts() {
        let empty = makeFinishedWorkout(title: "Empty", daysAgo: 0, exercises: [])
        let zeroCompleted = makeFinishedWorkout(
            title: "Monday Workout",
            daysAgo: 1,
            exercises: [
                makeExercise(name: "3/4 Sit-Up", sets: [makeSet(weight: 0, reps: 0, completed: true)]),
                makeExercise(name: "Bench Press", sets: [makeSet(weight: 100, reps: 5, completed: false)])
            ]
        )
        let realPR = makeFinishedWorkout(
            title: "Push PR",
            daysAgo: 3,
            exercises: [
                makeExercise(name: "Bench Press", sets: [makeSet(weight: 90, reps: 5, completed: true)])
            ]
        )

        let ranked = HistoryBestSessionQuery.rankBestSessions(from: [empty, zeroCompleted, realPR])
        #expect(ranked.count == 1)
        #expect(ranked.first?.workout.title == "Push PR")
        #expect(ranked.first?.recordCount == 1)
    }

    @Test("Sessions with more current PRs rank first, ties favor most recent PR session")
    func ranksByRecordCountThenLatestDate() {
        // Older session sets 2 lasting exercise PRs (Squat 140, Deadlift 180)
        let twoPRs = makeFinishedWorkout(
            title: "Heavy Legs & Pull",
            daysAgo: 10,
            exercises: [
                makeExercise(name: "Squat", muscle: "Legs", sets: [makeSet(weight: 140, reps: 5)]),
                makeExercise(name: "Deadlift", muscle: "Back", sets: [makeSet(weight: 180, reps: 3)]),
                makeExercise(name: "Bench Press", sets: [makeSet(weight: 85, reps: 5)])
            ]
        )

        // Newer session beats Bench Press PR (100 kg), but doesn't beat Squat/Deadlift -> 1 PR
        let latestBenchPR = makeFinishedWorkout(
            title: "Chest Day PR",
            daysAgo: 1,
            exercises: [
                makeExercise(name: "Bench Press", sets: [makeSet(weight: 100, reps: 5)])
            ]
        )

        // Older session with higher raw volume than Chest Day PR, but all lifts beaten by other sessions -> 0 PRs
        let volumeOnlyNoPR = makeFinishedWorkout(
            title: "High Volume Filler",
            daysAgo: 5,
            exercises: [
                makeExercise(name: "Squat", muscle: "Legs", sets: [
                    makeSet(weight: 100, reps: 10),
                    makeSet(weight: 100, reps: 10),
                    makeSet(weight: 100, reps: 10)
                ])
            ]
        )

        // Tied 1 PR (Curl 45 kg), older than Chest Day PR -> should appear AFTER Chest Day PR
        let olderCurlPR = makeFinishedWorkout(
            title: "Arms Day",
            daysAgo: 7,
            exercises: [
                makeExercise(name: "Bicep Curl", muscle: "Arms", sets: [makeSet(weight: 45, reps: 8)])
            ]
        )

        let ranked = HistoryBestSessionQuery.rankBestSessions(from: [volumeOnlyNoPR, olderCurlPR, twoPRs, latestBenchPR])
        #expect(ranked.map(\.workout.title) == ["Heavy Legs & Pull", "Chest Day PR", "Arms Day"])
        #expect(ranked[0].recordCount == 2)
        #expect(ranked[1].recordCount == 1)
        #expect(ranked[2].recordCount == 1)
    }

    @Test("Tied exercise PR transfers to the latest session that matched or beat it")
    func latestSessionWinsOnMatchedPR() {
        let olderBench = makeFinishedWorkout(
            title: "Old Bench",
            daysAgo: 12,
            exercises: [makeExercise(name: "Bench Press", sets: [makeSet(weight: 100, reps: 5)])]
        )
        let latestBench = makeFinishedWorkout(
            title: "Latest Bench",
            daysAgo: 1,
            exercises: [makeExercise(name: "Bench Press", sets: [makeSet(weight: 100, reps: 5)])]
        )

        let ranked = HistoryBestSessionQuery.rankBestSessions(from: [olderBench, latestBench])
        #expect(ranked.count == 1)
        #expect(ranked.first?.workout.title == "Latest Bench")
        #expect(ranked.first?.recordCount == 1)
    }

    @Test("Warmup sets do not count toward PRs by default")
    func ignoresWarmupsByDefault() {
        let warmupOnly = makeFinishedWorkout(
            title: "Warmup Only",
            daysAgo: 1,
            exercises: [makeExercise(name: "Squat", muscle: "Legs", sets: [makeSet(weight: 120, reps: 5, type: .warmup)])]
        )

        #expect(HistoryBestSessionQuery.rankBestSessions(from: [warmupOnly], includeWarmups: false).isEmpty)
        #expect(HistoryBestSessionQuery.rankBestSessions(from: [warmupOnly], includeWarmups: true).count == 1)
    }
}
