import Foundation
import OSLog
import ActivityKit

final class LiveActivityManager: Sendable {

    private static let maxWorkoutDuration: TimeInterval = 4 * 60 * 60

    func startWorkoutActivity(title: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = WorkoutActivityAttributes(workoutTitle: title)
        let state = WorkoutActivityAttributes.ContentState(startTime: Date())
        let staleDate = Date().addingTimeInterval(Self.maxWorkoutDuration)

        Task {
            // End orphan Island/activities left after crash / failed stop — then request fresh.
            for activity in Activity<WorkoutActivityAttributes>.activities {
                await activity.end(.init(state: state, staleDate: nil), dismissalPolicy: .immediate)
            }
            do {
                _ = try Activity<WorkoutActivityAttributes>.request(
                    attributes: attributes,
                    content: .init(state: state, staleDate: staleDate),
                    pushType: nil
                )
            } catch {
                AppLog.liveActivity.error("❌ LiveActivityManager: Failed to start activity: \(error.localizedDescription, privacy: .public)")
                TrackingManager.shared.recordError(error: error, additionalInfo: ["context": "LiveActivityManager_start"])
            }
        }
    }

    nonisolated static func resolvedStaleDate(existing: Date?, now: Date = Date()) -> Date {
        if let existing, existing > now {
            return existing
        }
        return now.addingTimeInterval(Self.maxWorkoutDuration)
    }

    func updateRestTimer(endTime: Date, currentExerciseName: String?, upcomingWeight: String?) {
        Task {
            for activity in Activity<WorkoutActivityAttributes>.activities {
                var newState = activity.content.state
                newState.restTimerEndTime = endTime
                newState.currentExerciseName = currentExerciseName
                newState.upcomingWeight = upcomingWeight

                let staleDate = Self.resolvedStaleDate(existing: activity.content.staleDate)
                await activity.update(
                    ActivityContent<WorkoutActivityAttributes.ContentState>(
                        state: newState,
                        staleDate: staleDate
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

                let staleDate = Self.resolvedStaleDate(existing: activity.content.staleDate)
                await activity.update(
                    ActivityContent<WorkoutActivityAttributes.ContentState>(
                        state: newState,
                        staleDate: staleDate
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
