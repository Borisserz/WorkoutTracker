//
//  LiveActivityManager.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 3.04.26.
//

//
//  LiveActivityManager.swift
//  WorkoutTracker
//

import Foundation
import ActivityKit

/// Изолированный сервис для управления системными Live Activities
final class LiveActivityManager: Sendable {
    
    func startWorkoutActivity(title: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        
        let attributes = WorkoutActivityAttributes(workoutTitle: title)
        let state = WorkoutActivityAttributes.ContentState(startTime: Date())
        
        do {
            _ = try Activity<WorkoutActivityAttributes>.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil),
                pushType: nil
            )
        } catch {
            print("❌ LiveActivityManager: Failed to start activity: \(error)")
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
