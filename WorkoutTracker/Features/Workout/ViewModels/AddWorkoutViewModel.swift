

internal import SwiftUI
import SwiftData 
import Observation

@Observable
@MainActor
final class AddWorkoutViewModel {
    var title: String = ""
    var selectedPreset: WorkoutPreset?
    var showActiveWorkoutAlert = false

    init() {
        setFormattedDateName()
    }

    func selectPreset(_ preset: WorkoutPreset?) {
        selectedPreset = preset
        if let p = preset {
            title = p.name
        } else {
            setFormattedDateName()
        }
    }

    func setFormattedDateName() {
        title = LocalizationHelper.shared.formatWorkoutDateName()
    }

    func checkAndStartWorkout(
        workoutService: WorkoutService,
        liveActivityManager: LiveActivityManager,
        onSuccess: @escaping () -> Void
    ) async {

        if await workoutService.hasActiveWorkout() {
            showActiveWorkoutAlert = true
            return
        }

        let finalTitle = title.isEmpty ? LocalizationHelper.shared.formatWorkoutDateName() : title
        let presetID = selectedPreset?.persistentModelID

        if let _ = await workoutService.createWorkout(title: finalTitle, presetID: presetID, isAIGenerated: false) {

            liveActivityManager.startWorkoutActivity(title: finalTitle)
            onSuccess()
        }
    }
}
