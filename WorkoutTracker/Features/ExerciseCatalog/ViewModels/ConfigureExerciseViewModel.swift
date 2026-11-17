

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
        // Maestro deep flows: one set keeps E2E under a minute without changing product defaults.
        if UITestLaunchConfiguration.isUITestMode, exerciseType == .strength {
            form.sets = 1
            form.reps = 5
            form.weight = 40
        }
    }
    
    var previousPerformanceText: String? {
        guard let lastPerf = lastPerformanceInstance else { return nil }
        let lastSets = lastPerf.sortedSets.filter { $0.type != .warmup && $0.isCompleted }
        guard !lastSets.isEmpty else { return nil }

        let firstSet = lastSets.first
        let maxWeightKg = lastSets.compactMap { $0.weight }.max() ?? 0.0
        return Self.formatPreviousPerformance(
            exerciseType: exerciseType,
            setsCount: lastSets.count,
            reps: firstSet?.reps ?? 0,
            maxWeightKg: maxWeightKg,
            distanceMeters: firstSet?.distance ?? 0.0,
            durationSeconds: firstSet?.time ?? 0,
            weightUnit: UnitsManager.shared.weightUnit,
            distanceUnit: UnitsManager.shared.distanceUnit
        )
    }

    static func formatPreviousPerformance(
        exerciseType: ExerciseType,
        setsCount: Int,
        reps: Int,
        maxWeightKg: Double,
        distanceMeters: Double,
        durationSeconds: Int,
        weightUnit: WeightUnit,
        distanceUnit: DistanceUnit
    ) -> String {
        switch exerciseType {
        case .strength:
            let base = String(format: NSLocalizedString("Previous: %d sets × %d reps", comment: ""), setsCount, reps)
            if maxWeightKg > 0 {
                let converted = weightUnit == .kilograms ? maxWeightKg : maxWeightKg * 2.20462
                let formatted = LocalizationHelper.shared.formatFlexible(converted)
                return "\(base) @ \(formatted) \(weightUnit.shortName)"
            }
            return base

        case .cardio:
            let convertedDist = distanceUnit == .meters ? distanceMeters : distanceMeters * 0.000621371
            let distText = distanceUnit == .meters
                ? LocalizationHelper.shared.formatFlexible(convertedDist)
                : LocalizationHelper.shared.formatTwoDecimals(convertedDist)
            let mins = durationSeconds / 60
            let secs = durationSeconds % 60
            let base = String(format: NSLocalizedString("Previous: %d sets × %dm %ds", comment: ""), 1, mins, secs)
            return "\(distText) \(distanceUnit.shortName) · \(base)"

        case .duration:
            let mins = durationSeconds / 60
            let secs = durationSeconds % 60
            return String(format: NSLocalizedString("Previous: %d sets × %dm %ds", comment: ""), setsCount, mins, secs)
        }
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
