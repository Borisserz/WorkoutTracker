import Foundation
import FirebaseAnalytics
import FirebaseCrashlytics
import FirebasePerformance

/// Centralized manager for logging structured Firebase Analytics events.
public final class TrackingManager {
    public static let shared = TrackingManager()
    private init() {}

    public enum Event {
        // A. Onboarding & First Launch
        case onboardingStarted
        case onboardingStepCompleted(step: String)
        case onboardingCompleted(goal: String, daysPerWeek: Int, experienceLevel: String)
        case guestModeChosen

        // B. Main Workout Flow
        case workoutStarted(source: String, exerciseCount: Int, estimatedDuration: Int)
        case workoutCompleted(durationMinutes: Int, totalVolume: Double, exercisesCompleted: Int, setsCompleted: Int, avgEffort: Int, source: String)
        case workoutCancelled(durationMinutes: Int, exercisesDone: Int, reason: String)
        case exerciseAdded(exerciseName: String, source: String)
        case setLogged(exerciseName: String, weight: Double, reps: Int, setType: String)
        case restTimerUsed(durationSeconds: Int, skipped: Bool)
        case rpeGiven(rpeValue: Int, exerciseName: String)

        // C. AI Coach & Smart Builder
        case aiCoachOpened(source: String)
        case aiCoachMessageSent(context: String, messageLength: Int, hasAttachment: Bool)
        case aiCoachSuggestionAccepted(suggestionType: String)
        case smartBuilderUsed(muscleGroupsSelected: [String], goal: String)
        case aiProgramGenerated(programLengthWeeks: Int, difficulty: String)
        case proactiveWorkoutShown(reason: String)

        // E. Body Metrics & Progress
        case weightLogged(value: Double, unit: String, source: String)
        case bodyMeasurementUpdated(measurementType: String)
        case progressPhotoAdded
        case statsViewed(tab: String)
        case progressChartViewed(chartType: String, timeRange: String)

        // F. Templates & Explore
        case templateCreated(exerciseCount: Int)
        case templateStarted(templateName: String, source: String)
        case legendaryRoutineViewed(routineName: String)

        // G. WatchOS & Cross-device
        case watchWorkoutStarted
        case watchSyncCompleted(success: Bool, itemsSynced: Int)
        case heartRateConnected(source: String)

        // H. Additional
        case appOpened(source: String)
        case featureDiscovered(featureName: String)
        case errorOccurred(errorType: String, screen: String)

        var name: String {
            switch self {
            case .onboardingStarted: return "onboarding_started"
            case .onboardingStepCompleted: return "onboarding_step_completed"
            case .onboardingCompleted: return "onboarding_completed"
            case .guestModeChosen: return "guest_mode_chosen"
            case .workoutStarted: return "workout_started"
            case .workoutCompleted: return "workout_completed"
            case .workoutCancelled: return "workout_cancelled"
            case .exerciseAdded: return "exercise_added"
            case .setLogged: return "set_logged"
            case .restTimerUsed: return "rest_timer_used"
            case .rpeGiven: return "rpe_given"
            case .aiCoachOpened: return "ai_coach_opened"
            case .aiCoachMessageSent: return "ai_coach_message_sent"
            case .aiCoachSuggestionAccepted: return "ai_coach_suggestion_accepted"
            case .smartBuilderUsed: return "smart_builder_used"
            case .aiProgramGenerated: return "ai_program_generated"
            case .proactiveWorkoutShown: return "proactive_workout_shown"
            case .weightLogged: return "weight_logged"
            case .bodyMeasurementUpdated: return "body_measurement_updated"
            case .progressPhotoAdded: return "progress_photo_added"
            case .statsViewed: return "stats_viewed"
            case .progressChartViewed: return "progress_chart_viewed"
            case .templateCreated: return "template_created"
            case .templateStarted: return "template_started"
            case .legendaryRoutineViewed: return "legendary_routine_viewed"
            case .watchWorkoutStarted: return "watch_workout_started"
            case .watchSyncCompleted: return "watch_sync_completed"
            case .heartRateConnected: return "heart_rate_connected"
            case .appOpened: return "app_opened"
            case .featureDiscovered: return "feature_discovered"
            case .errorOccurred: return "error_occurred"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .onboardingStepCompleted(let step):
                return ["step": step]
            case .onboardingCompleted(let goal, let daysPerWeek, let experienceLevel):
                return ["goal": goal, "days_per_week": daysPerWeek, "experience_level": experienceLevel]
            case .workoutStarted(let source, let count, let duration):
                return ["source": source, "exercise_count": count, "estimated_duration": duration]
            case .workoutCompleted(let duration, let vol, let exercises, let sets, let effort, let source):
                return [
                    "duration_minutes": duration, "total_volume": vol,
                    "exercises_completed": exercises, "sets_completed": sets,
                    "avg_effort": effort, "source": source
                ]
            case .workoutCancelled(let duration, let exercisesDone, let reason):
                return ["duration_minutes": duration, "exercises_done": exercisesDone, "reason": reason]
            case .exerciseAdded(let exerciseName, let source):
                return ["exercise_name": exerciseName, "source": source]
            case .setLogged(let exerciseName, let weight, let reps, let setType):
                return ["exercise_name": exerciseName, "weight": weight, "reps": reps, "set_type": setType]
            case .restTimerUsed(let duration, let skipped):
                return ["duration_seconds": duration, "skipped": skipped]
            case .rpeGiven(let rpeValue, let exerciseName):
                return ["rpe_value": rpeValue, "exercise_name": exerciseName]
            case .aiCoachOpened(let source):
                return ["source": source]
            case .aiCoachMessageSent(let context, let length, let hasAttachment):
                return ["context": context, "message_length": length, "has_attachment": hasAttachment]
            case .aiCoachSuggestionAccepted(let suggestionType):
                return ["suggestion_type": suggestionType]
            case .smartBuilderUsed(let muscles, let goal):
                return ["muscle_groups_selected": muscles.joined(separator: ","), "goal": goal]
            case .aiProgramGenerated(let weeks, let difficulty):
                return ["program_length_weeks": weeks, "difficulty": difficulty]
            case .proactiveWorkoutShown(let reason):
                return ["reason": reason]
            case .weightLogged(let value, let unit, let source):
                return ["value": value, "unit": unit, "source": source]
            case .bodyMeasurementUpdated(let type):
                return ["measurement_type": type]
            case .statsViewed(let tab):
                return ["tab": tab]
            case .progressChartViewed(let chartType, let timeRange):
                return ["chart_type": chartType, "time_range": timeRange]
            case .templateCreated(let exerciseCount):
                return ["exercise_count": exerciseCount]
            case .templateStarted(let name, let source):
                return ["template_name": name, "source": source]
            case .legendaryRoutineViewed(let name):
                return ["routine_name": name]
            case .watchSyncCompleted(let success, let items):
                return ["success": success, "items_synced": items]
            case .heartRateConnected(let source):
                return ["source": source]
            case .appOpened(let source):
                return ["source": source]
            case .featureDiscovered(let featureName):
                return ["feature_name": featureName]
            case .errorOccurred(let type, let screen):
                return ["error_type": type, "screen": screen]
            default:
                return nil
            }
        }
    }

    public func track(_ event: Event) {
        #if DEBUG
        print("📊 [Analytics] Logging event: \(event.name) with params: \(event.parameters ?? [:])")
        #endif
        Analytics.logEvent(event.name, parameters: event.parameters)
        Crashlytics.crashlytics().log(event.name)
        
        if case .onboardingCompleted(let goal, let daysPerWeek, let experienceLevel) = event {
            setUserProperty(name: "primary_goal", value: goal)
            setUserProperty(name: "training_frequency", value: String(daysPerWeek))
            setUserProperty(name: "experience_level", value: experienceLevel)
        }
    }

    public func setUserProperty(name: String, value: String?) {
        #if DEBUG
        print("📊 [Analytics] Setting user property: \(name) = \(value ?? "nil")")
        #endif
        Analytics.setUserProperty(value, forName: name)
        Crashlytics.crashlytics().setCustomValue(value ?? "nil", forKey: name)
    }

    public func recordError(error: Error, additionalInfo: [String: Any]? = nil) {
        #if DEBUG
        print("📊 [Crashlytics] Recording non-fatal error: \(error.localizedDescription)")
        #endif
        if let info = additionalInfo {
            let nsError = NSError(domain: "WorkoutTracker", code: 1, userInfo: [
                NSUnderlyingErrorKey: error,
                "additionalInfo": info
            ])
            Crashlytics.crashlytics().record(error: nsError)
        } else {
            Crashlytics.crashlytics().record(error: error)
        }
    }

    public func setUserID(id: String) {
        Analytics.setUserID(id)
        Crashlytics.crashlytics().setUserID(id)
    }

    public func startTrace(name: String) -> PerformanceTrace? {
        #if DEBUG
        print("⏱️ [Performance] Starting trace: \(name)")
        #endif
        if let trace = Performance.startTrace(name: name) {
            return FirebasePerformanceTrace(trace: trace)
        }
        return nil
    }
}

public protocol PerformanceTrace {
    func stop()
}

private struct FirebasePerformanceTrace: PerformanceTrace {
    let trace: Trace
    func stop() {
        trace.stop()
    }
}
