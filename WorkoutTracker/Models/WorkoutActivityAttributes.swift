//
//  WorkoutActivityAttributes.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 24.12.25.
//

// WorkoutActivityAttributes.swift
import Foundation
import ActivityKit

struct WorkoutActivityAttributes: ActivityAttributes {
    // ContentState - это та часть данных, которая будет меняться.
    public struct ContentState: Codable, Hashable {
        var startTime: Date
    }
    
    // Это статичные данные, которые не меняются в течение всей активности.
    var workoutTitle: String
}
