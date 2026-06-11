

internal import SwiftUI
import Observation

@Observable
@MainActor
final class ConfigureExerciseViewModel {
    enum FocusMode: String, CaseIterable, Identifiable, Sendable {
        case strength = "Strength"
        case hypertrophy = "Hypertrophy"
        case endurance = "Endurance"
        
        var id: String { self.rawValue }
        
        var localizedName: String {
            switch self {
            case .strength: return NSLocalizedString("Strength", comment: "")
            case .hypertrophy: return NSLocalizedString("Hypertrophy", comment: "")
            case .endurance: return NSLocalizedString("Endurance", comment: "")
            }
        }
    }

    var form = ExerciseFormState()

    var showValidationAlert = false
    var hasAutoFilled = false
    var showOverloadBanner = false
    var recommendedWeight: Double = 0.0
    var selectedFocusMode: FocusMode = .hypertrophy

    let exerciseName: String
    let muscleGroup: String
    let exerciseType: ExerciseType
    
    private var lastPerformanceInstance: Exercise? = nil

    init(exerciseName: String, muscleGroup: String, exerciseType: ExerciseType) {
        self.exerciseName = exerciseName
        self.muscleGroup = muscleGroup
        self.exerciseType = exerciseType
    }
    
    var previousPerformanceText: String? {
        guard let lastPerf = lastPerformanceInstance else { return nil }
        let lastSets = lastPerf.sortedSets.filter { $0.type != .warmup && $0.isCompleted }
        guard !lastSets.isEmpty else { return nil }
        
        switch exerciseType {
        case .strength:
            let setsCount = lastSets.count
            let reps = lastSets.first?.reps ?? 0
            let lastMax = lastSets.compactMap { $0.weight }.max() ?? 0.0
            if lastMax > 0 {
                return String(format: NSLocalizedString("Previous: %d sets × %d reps @ %.1f kg", comment: ""), setsCount, reps, lastMax)
            } else {
                return String(format: NSLocalizedString("Previous: %d sets × %d reps", comment: ""), setsCount, reps)
            }
        case .cardio:
            if let firstSet = lastSets.first {
                let dist = firstSet.distance ?? 0.0
                let t = firstSet.time ?? 0
                let mins = t / 60
                let secs = t % 60
                return String(format: NSLocalizedString("Previous: %.2f km in %dm %ds", comment: ""), dist, mins, secs)
            }
        case .duration:
            if let firstSet = lastSets.first {
                let setsCount = lastSets.count
                let t = firstSet.time ?? 0
                let mins = t / 60
                let secs = t % 60
                return String(format: NSLocalizedString("Previous: %d sets × %dm %ds", comment: ""), setsCount, mins, secs)
            }
        }
        return nil
    }

    func loadLastPerformance(from dashboardCache: [String: Exercise]) {
        guard !hasAutoFilled else { return }
        hasAutoFilled = true

        guard let lastPerf = dashboardCache[exerciseName] else { return }
        let lastSets = lastPerf.sortedSets.filter { $0.type != .warmup && $0.isCompleted }
        guard !lastSets.isEmpty else { return }
        
        self.lastPerformanceInstance = lastPerf

        switch exerciseType {
        case .strength:
            form.sets = lastSets.count > 0 ? lastSets.count : 3

            let previousReps = lastSets.first?.reps ?? 10
            form.reps = previousReps > 0 ? previousReps : 10

            // Infer focus mode from reps
            if form.reps <= 6 {
                selectedFocusMode = .strength
            } else if form.reps <= 12 {
                selectedFocusMode = .hypertrophy
            } else {
                selectedFocusMode = .endurance
            }

            let lastMax = lastSets.compactMap { $0.weight }.max() ?? 0.0
            form.weight = lastMax > 0 ? lastMax : nil

            if lastMax > 0 {
                self.recommendedWeight = lastMax + 2.5
                self.showOverloadBanner = true
            }

        case .cardio:
            if let firstSet = lastSets.first {
                form.distance = firstSet.distance
                let t = firstSet.time ?? 0
                form.minutes = t / 60
                form.seconds = t % 60
            }

        case .duration:
            if let firstSet = lastSets.first {
                form.sets = lastSets.count > 0 ? lastSets.count : 3
                let t = firstSet.time ?? 0
                form.minutes = t / 60
                form.seconds = t % 60
            }
        }
    }
    
    func selectFocusMode(_ mode: FocusMode) {
        selectedFocusMode = mode
        switch mode {
        case .strength:
            form.sets = 5
            form.reps = 5
        case .hypertrophy:
            form.sets = 4
            form.reps = 10
        case .endurance:
            form.sets = 3
            form.reps = 15
        }
    }

    func applyOverload() {
        form.weight = recommendedWeight
        showOverloadBanner = false
    }

    func generateExercise(unitsManager: UnitsManager) -> Exercise? {
        guard form.validate(for: exerciseType, unitsManager: unitsManager) else {
            showValidationAlert = true
            return nil
        }

        let setsCount = (exerciseType == .cardio) ? 1 : form.sets
        let totalSeconds = ((form.minutes ?? 0) * 60) + (form.seconds ?? 0)

        var generatedSets: [WorkoutSet] = []
        for i in 1...setsCount {
            generatedSets.append(WorkoutSet(
                index: i,
                weight: (exerciseType == .strength) ? form.weight : nil,
                reps: (exerciseType == .strength) ? form.reps : nil,
                distance: (exerciseType == .cardio) ? form.distance : nil,
                time: (totalSeconds > 0) ? totalSeconds : nil,
                isCompleted: false,
                type: .normal
            ))
        }

        return Exercise(
            name: exerciseName,
            muscleGroup: muscleGroup,
            type: exerciseType,
            sets: setsCount,
            reps: form.reps,
            weight: form.weight ?? 0.0,
            distance: form.distance,
            timeSeconds: totalSeconds > 0 ? totalSeconds : nil,
            effort: 5,
            setsList: generatedSets
        )
    }
}
