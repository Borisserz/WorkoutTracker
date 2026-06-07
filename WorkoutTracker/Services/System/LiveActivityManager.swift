import Foundation
import ActivityKit

final class LiveActivityManager: Sendable {

    private static let maxWorkoutDuration: TimeInterval = 4 * 60 * 60

    func startWorkoutActivity(title: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        guard Activity<WorkoutActivityAttributes>.activities.isEmpty else { return }

        let attributes = WorkoutActivityAttributes(workoutTitle: title)
        let state = WorkoutActivityAttributes.ContentState(startTime: Date())
        let staleDate = Date().addingTimeInterval(Self.maxWorkoutDuration)
        do {
            _ = try Activity<WorkoutActivityAttributes>.request(
                attributes: attributes,
                content: .init(state: state, staleDate: staleDate),
                pushType: nil
            )
        } catch {
            print("❌ LiveActivityManager: Failed to start activity: \(error)")
            TrackingManager.shared.recordError(error: error, additionalInfo: ["context": "LiveActivityManager_start"])
        }
    }

    func updateRestTimer(endTime: Date, currentExerciseName: String?, upcomingWeight: String?) {
        Task {
            for activity in Activity<WorkoutActivityAttributes>.activities {
                var newState = activity.content.state
                newState.restTimerEndTime = endTime
                newState.currentExerciseName = currentExerciseName
                newState.upcomingWeight = upcomingWeight
                
                await activity.update(
                    ActivityContent<WorkoutActivityAttributes.ContentState>(
                        state: newState,
                        staleDate: nil
                    )
                )
            }
        }
    }

    func clearRestTimer() {
        Task {
            for activity in Activity<WorkoutActivityAttributes>.activities {
                var newState = activity.content.state
                newState.restTimerEndTime = nil
                newState.currentExerciseName = nil
                newState.upcomingWeight = nil
                
                await activity.update(
                    ActivityContent<WorkoutActivityAttributes.ContentState>(
                        state: newState,
                        staleDate: nil
                    )
                )
            }
        }
    }

    func stopAllActivities() {
        Task {
            for activity in Activity<WorkoutActivityAttributes>.activities {
                let state = WorkoutActivityAttributes.ContentState(startTime: Date())
                await activity.end(.init(state: state, staleDate: nil), dismissalPolicy: .immediate)
            }
        }
    }
}
