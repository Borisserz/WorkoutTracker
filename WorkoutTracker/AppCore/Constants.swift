//
//  Constants.swift
//  WorkoutTracker
//
import Foundation

public enum Constants {
    
    /// Keys used for standard UserDefaults storage
    public enum UserDefaultsKeys: String, CaseIterable {
        case streakRestDays
        case defaultRestTime
        case autoStartTimer
        case appearanceMode
        case userName
        case userBodyWeight
        case userGender
        case userRecoveryHours
        case hasSeenTutorial_Final_v8
        case hasMigratedToSwiftData_v2
        case widget_data
        case restEndTime
        case aiCoachTone
        case hasCompletedOnboarding
        case userAvatar
        case exerciseNotes = "ExerciseNotes"
        case muscleColors = "MuscleColors"
        case voiceCoachDucking
        case hasGeneratedDefaultPresets_v3
        case includeWarmupsInStats
        case preferred1RMFormula
    }
    
    /// Default values and keys for AI integrations
    public enum AIConstants {
        public static let defaultTone = "Мотивационный"
    }
    
    /// Identifiers for local notifications and notification center events
    public enum NotificationIdentifiers: String, CaseIterable {
        case restTimerDone = "rest_timer_done"
        case restTimerCategory = "REST_TIMER_CATEGORY"
        case recoveryNotification = "recovery_notification"
        case inactivityNotification = "inactivity_notification"
        case doneAction = "DONE_ACTION"
        case restTimerFinishedNotification = "RestTimerFinished"
    }
    
    /// Standardized Muscle Group names
    public enum MuscleName: String, CaseIterable {
        case chest = "Chest"
        case back = "Back"
        case legs = "Legs"
        case shoulders = "Shoulders"
        case arms = "Arms"
        case core = "Core"
        case upperBack = "Upper Back"
        case lats = "Lats"
        case traps = "Traps"
        case lowerBack = "Lower Back"
        case biceps = "Biceps"
        case triceps = "Triceps"
        case forearms = "Forearms"
        case abs = "Abs"
        case obliques = "Obliques"
        case glutes = "Glutes"
        case hamstrings = "Hamstrings"
        case quads = "Quads"
        case adductors = "Adductors"
        case abductors = "Abductors"
        case calves = "Calves"
        case neck = "Neck"
        case tibialis = "Tibialis"
        case hands = "Hands"
        case ankles = "Ankles"
        case feet = "Feet"
        case mixed = "Mixed"
        case cardio = "Cardio"
    }
    
    /// Standardized Exercise Categories
    public enum ExerciseCategoryName: String, CaseIterable {
        case squat = "Squat"
        case press = "Press"
        case deadlift = "Deadlift"
        case pull = "Pull"
        case curl = "Curl"
        case core = "Core"
        case cardio = "Cardio"
        case other = "Other"
    }
}
