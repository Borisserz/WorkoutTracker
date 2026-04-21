

internal import SwiftUI
import Observation
import SwiftData

struct ActiveExerciseWrapper: Identifiable, Hashable, Sendable {
    var id: Int { index }
    let index: Int
}

@Observable
@MainActor
final class WatchActiveWorkoutViewModel: Hashable {
    let workoutID: UUID
    let workoutTitle: String
    var startDate: Date = Date()

    var isInitialized: Bool = false

    var exercises: [ExerciseDTO] = []
    var totalVolume: Double = 0.0
    var totalSets: Int = 0
    var totalDurationSeconds: Int = 0 

    var showRestTimer = false
    var showRPE = false
    var showSummary = false

    var activeExercise: ActiveExerciseWrapper? = nil
    var pendingNextExerciseIndex: Int? = nil
    var goBackToWorkoutView = false

    var restTimeRemaining: Int = 60
    var initialRestTime: Int = 60
    var nextSetInfo: String = ""
    var currentExerciseIndexForRPE: Int? = nil

    private var restTargetEndTime: Date?
    private var restTimerTask: Task<Void, Never>?
    private let store: WatchWorkoutStore

    init(workoutID: UUID, workoutTitle: String, presetDTO: WorkoutPresetDTO?, store: WatchWorkoutStore) {
        self.workoutID = workoutID
        self.workoutTitle = workoutTitle
        self.store = store
        if let dto = presetDTO { self.exercises = dto.exercises }
    }

    func cleanup() {
        restTimerTask?.cancel()
    }

    func initializeWorkout() async {
        guard !isInitialized else { return }
        isInitialized = true
        self.startDate = Date()

        let payload = LiveSyncPayload(
            action: .startWorkout,
            workoutID: workoutID.uuidString,
            workoutTitle: workoutTitle,
            exercises: self.exercises 
        )
        WatchSyncManager.shared.sendLiveAction(payload)
        _ = try? await store.startNewWorkout(title: workoutTitle, uuidString: workoutID.uuidString)
    }

    func addExercise(name: String) async {
        let newEx = ExerciseDTO(
            name: name, muscleGroup: "Mixed", type: .strength, category: .other, effort: 5,
            isCompleted: false, setsList: [], subExercises: [], sets: 3, reps: 10, recommendedWeightKg: 0.0
        )
        exercises.append(newEx)
        let payload = LiveSyncPayload(action: .addExercise, workoutID: workoutID.uuidString, exerciseName: name)
        WatchSyncManager.shared.sendLiveAction(payload)
    }
    func listenForRemoteUpdates() {
            NotificationCenter.default.addObserver(forName: NSNotification.Name("WatchLiveSyncEvent"), object: nil, queue: .main) { [weak self] notification in
                guard let self = self,
                      let payload = notification.userInfo?["payload"] as? LiveSyncPayload,
                      payload.workoutID == self.workoutID.uuidString else { return }
                self.applyRemoteDelta(payload)
            }
        }

        private func applyRemoteDelta(_ payload: LiveSyncPayload) {
            switch payload.action {
            case .syncFullState:
                            if let newExercises = payload.exercises {
                                self.exercises = newExercises
                                self.recalculateTotals()

                                if let activeEx = self.activeExercise, activeEx.index >= newExercises.count {
                                    self.goBackToWorkoutView = true
                                }
                            }
            case .addExercise:
                if let name = payload.exerciseName, !self.exercises.contains(where: { $0.name == name }) {
                    let newEx = ExerciseDTO(name: name, muscleGroup: "Mixed", type: .strength, category: .other, effort: 5, isCompleted: false, setsList: [], subExercises: [], sets: 3, reps: 10, recommendedWeightKg: 0.0)
                    self.exercises.append(newEx)
                }
            case .logSet:
                guard let exName = payload.exerciseName, let setIndex = payload.setIndex,
                      let exIdx = exercises.firstIndex(where: { $0.name == exName }) else { return }

                var currentEx = exercises[exIdx]
                var sets = currentEx.setsList ?? []

                let newSet = WorkoutSetDTO(index: setIndex, weight: payload.weight, reps: payload.reps, distance: nil, time: nil, isCompleted: payload.isCompleted ?? true, type: .normal)

                if let i = sets.firstIndex(where: { $0.index == setIndex }) { sets[i] = newSet }
                else { sets.append(newSet) }

                currentEx.setsList = sets
                exercises[exIdx] = currentEx
                recalculateTotals()

            case .finishWorkout:
                self.showSummary = true
            case .discardWorkout:
                self.goBackToWorkoutView = true
            default: break
            }
        }

        private func recalculateTotals() {
            var vol = 0.0; var setsCount = 0
            for ex in exercises {
                for set in (ex.setsList ?? []) where set.isCompleted {
                    vol += (set.weight ?? 0) * Double(set.reps ?? 0)
                    setsCount += 1
                }
            }
            self.totalVolume = vol
            self.totalSets = setsCount
        }
    func logSpecificSet(exerciseIndex: Int, setIndex: Int, weight: Double, reps: Int) async {
        guard exercises.indices.contains(exerciseIndex) else { return }
        var currentEx = exercises[exerciseIndex]
        var currentSets = currentEx.setsList ?? []

        if let existingIndex = currentSets.firstIndex(where: { $0.index == setIndex }) {
            currentSets[existingIndex] = WorkoutSetDTO(index: setIndex, weight: weight, reps: reps, distance: nil, time: nil, isCompleted: true, type: .normal)
        } else {
            currentSets.append(WorkoutSetDTO(index: setIndex, weight: weight, reps: reps, distance: nil, time: nil, isCompleted: true, type: .normal))
        }

        currentEx.setsList = currentSets
        exercises[exerciseIndex] = currentEx

        WKInterfaceDevice.current().play(.success)
        let payload = LiveSyncPayload(action: .logSet, workoutID: workoutID.uuidString, exerciseName: currentEx.name, setIndex: setIndex, weight: weight, reps: reps, isCompleted: true)
        WatchSyncManager.shared.sendLiveAction(payload)

        _ = try? await store.logSet(workoutID: workoutID.uuidString, exerciseName: currentEx.name, weight: weight, reps: reps)

        totalSets += 1
        totalVolume += (weight * Double(reps))

        let completedCount = currentSets.filter { $0.isCompleted }.count
        let isLastSet = completedCount >= (currentEx.setsList?.count ?? 0)

        if isLastSet {
            nextSetInfo = "\(currentEx.name)\nSet \(completedCount)/\(currentEx.sets ?? 3)"
            currentExerciseIndexForRPE = exerciseIndex
            showRPE = true
        } else {
            let weightStr = String(format: "%.1f", weight)
            nextSetInfo = "Next set\n\(currentEx.name)\nSet \(completedCount + 1)/\(currentEx.sets ?? 3): \(weightStr)kg × \(reps)"

            let defaultRest = UserDefaults.standard.integer(forKey: "defaultRestTime")
            startTimer(duration: defaultRest > 0 ? defaultRest : 60)
        }
    }

    func saveRPE(_ rpe: Int) async {
        guard let exIndex = currentExerciseIndexForRPE else { return }
        let exName = exercises[exIndex].name
        _ = try? await store.updateExerciseEffort(workoutID: workoutID.uuidString, exerciseName: exName, effort: rpe)

        let payload = LiveSyncPayload(action: .updateEffort, workoutID: workoutID.uuidString, exerciseName: exName, effort: rpe)
        WatchSyncManager.shared.sendLiveAction(payload)

        exercises[exIndex].isCompleted = true
        showRPE = false
        currentExerciseIndexForRPE = nil

        if let nextIndex = exercises.firstIndex(where: { !$0.isCompleted }) {
            pendingNextExerciseIndex = nextIndex
            let nextExName = exercises[nextIndex].name
            nextSetInfo = "Next exercise\n\(nextExName)\nSet 1"
        } else {
            pendingNextExerciseIndex = nil
            nextSetInfo = "Workout Complete!\nRest up."
        }

        try? await Task.sleep(for: .milliseconds(400))
        let defaultRest = UserDefaults.standard.integer(forKey: "defaultRestTime")
        startTimer(duration: defaultRest > 0 ? defaultRest : 120)
        goBackToWorkoutView = true
    }

    private func startTimer(duration: Int) {
        initialRestTime = duration
        restTimeRemaining = duration
        restTargetEndTime = Date().addingTimeInterval(TimeInterval(duration))
        showRestTimer = true

        restTimerTask?.cancel()
        restTimerTask = Task {
            while let target = restTargetEndTime, target > Date() {
                let diff = Int(round(target.timeIntervalSinceNow))
                if diff != restTimeRemaining {
                    await MainActor.run { restTimeRemaining = diff }
                }
                try? await Task.sleep(for: .milliseconds(200))
                if Task.isCancelled { return }
            }
            guard !Task.isCancelled else { return }
            await MainActor.run {
                WKInterfaceDevice.current().play(.success)
                showRestTimer = false
            }
        }
    }

    func skipTimer() {
        restTimerTask?.cancel()
        restTargetEndTime = nil
        showRestTimer = false
    }

    func adjustTimer(by seconds: Int) {
        guard let currentTarget = restTargetEndTime else { return }
        let newTarget = currentTarget.addingTimeInterval(TimeInterval(seconds))
        if newTarget <= Date() { skipTimer() }
        else {
            restTargetEndTime = newTarget
            restTimeRemaining = Int(newTarget.timeIntervalSinceNow)
        }
    }

    func addSetToExercise(at index: Int) {
        guard exercises.indices.contains(index) else { return }
        var currentEx = exercises[index]
        let currentCount = currentEx.setsList?.count ?? 0
        let newSetIndex = currentCount + 1

        let newSet = WorkoutSetDTO(index: newSetIndex, weight: nil, reps: nil, distance: nil, time: nil, isCompleted: false, type: .normal)

        if currentEx.setsList != nil {
            currentEx.setsList!.append(newSet)
        } else {
            currentEx.setsList = [newSet]
        }

        if currentEx.sets ?? 3 < newSetIndex {
            currentEx.sets = newSetIndex
        }

        exercises[index] = currentEx
    }

    func removeSet(exerciseIndex: Int, setIndex: Int) async {
        guard exercises.indices.contains(exerciseIndex) else { return }
        var currentEx = exercises[exerciseIndex]
        var currentSets = currentEx.setsList ?? []

        currentSets.removeAll { $0.index == setIndex }

        for i in 0..<currentSets.count {
            let old = currentSets[i]
            currentSets[i] = WorkoutSetDTO(index: i + 1, weight: old.weight, reps: old.reps, distance: old.distance, time: old.time, isCompleted: old.isCompleted, type: old.type)
        }
        currentEx.setsList = currentSets

        let targetSets = currentEx.sets ?? 3
        if targetSets > 1 { currentEx.sets = targetSets - 1 }
        exercises[exerciseIndex] = currentEx
    }

    func removeExercise(at index: Int) async {
        guard exercises.indices.contains(index) else { return }
        exercises.remove(at: index)
    }

    func finishWorkout(activeEnergy: Double) async {
           totalDurationSeconds = Int(Date().timeIntervalSince(startDate))

           _ = try? await store.finishWorkout(workoutID: workoutID.uuidString)

           let payload = LiveSyncPayload(
               action: .saveToHistory,
               workoutID: workoutID.uuidString,
               workoutTitle: workoutTitle,
               exercises: self.exercises,
               activeEnergy: activeEnergy,
               durationSeconds: totalDurationSeconds
           )
           WatchSyncManager.shared.transferGuaranteedPayload(payload)

           showSummary = true
       }

    func cancelWorkout() async {
        let payload = LiveSyncPayload(action: .discardWorkout, workoutID: workoutID.uuidString)
        WatchSyncManager.shared.sendLiveAction(payload)
    }

    nonisolated static func == (lhs: WatchActiveWorkoutViewModel, rhs: WatchActiveWorkoutViewModel) -> Bool {
        lhs.workoutID == rhs.workoutID
    }

    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(workoutID)
    }
}
