

import Foundation
import UserNotifications
import SwiftData

extension Notification.Name {
    static let workoutDataDidUpdate = Notification.Name("workoutDataDidUpdate")
    static let workoutCompletedEvent = Notification.Name("workoutCompletedEvent")
    static let restTimerAdd15s = Notification.Name("restTimerAdd15s")
}

@MainActor
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate, Sendable {

    static let shared = NotificationManager()

    private let restTimerCategoryId = "REST_TIMER_CATEGORY"
    private let retentionCategoryId = "RETENTION_CATEGORY"

    private let actionDone = "ACTION_DONE"
    private let actionAdd15s = "ACTION_ADD_15S"
    private let actionStartWorkout = "ACTION_START_WORKOUT"

    private let restTimerId = "rest_timer_done"
    private let recoveryId = "recovery_notification"
    private let streakRescueId = "streak_rescue_notification"
    private let dropOffBaseId = "dropoff_notification_"

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        setupNotificationCategories()
    }

    func requestPermission(completion: (@Sendable (Bool) -> Void)? = nil) {
        let options: UNAuthorizationOptions = [.alert, .badge, .sound, .timeSensitive]
        UNUserNotificationCenter.current().requestAuthorization(options: options) { granted, _ in
            completion?(granted)
        }
    }

    private func setupNotificationCategories() {

        let doneAction = UNNotificationAction(identifier: actionDone, title: String(localized: "Finish Set"), options: [.foreground])
        let add15sAction = UNNotificationAction(identifier: actionAdd15s, title: String(localized: "+15 Seconds"), options: [])
        let restCategory = UNNotificationCategory(identifier: restTimerCategoryId, actions: [doneAction, add15sAction], intentIdentifiers: [], options: [.customDismissAction])

        let startAction = UNNotificationAction(identifier: actionStartWorkout, title: String(localized: "Start Workout"), options: [.foreground])
        let retentionCategory = UNNotificationCategory(identifier: retentionCategoryId, actions: [startAction], intentIdentifiers: [], options: [])

        UNUserNotificationCenter.current().setNotificationCategories([restCategory, retentionCategory])
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let options: UNNotificationPresentationOptions = [.banner, .sound, .list, .badge]
        completionHandler(options)
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let action = response.actionIdentifier
        let identifier = response.notification.request.identifier

        Task { @MainActor in
            if identifier == restTimerId {
                if action == actionAdd15s {
                    NotificationCenter.default.post(name: .restTimerAdd15s, object: nil)
                } else if action == actionDone || action == UNNotificationDefaultActionIdentifier {
                    NotificationCenter.default.post(name: NSNotification.Name(Constants.NotificationIdentifiers.restTimerFinishedNotification.rawValue), object: nil)
                }
            } else if action == actionStartWorkout || action == UNNotificationDefaultActionIdentifier {

                NotificationCenter.default.post(name: Notification.Name("widgetActionTriggered"), object: "empty_workout")
            }
            completionHandler()
        }
    }

    func scheduleRestTimerNotification(seconds: Double) {
        cancelRestTimerNotification()

        let tone = UserDefaults.standard.string(forKey: Constants.UserDefaultsKeys.aiCoachTone.rawValue) ?? Constants.AIConstants.defaultTone
        let copy = AICopywriter.restTimerText(for: tone)

        let content = UNMutableNotificationContent()
        content.title = copy.title
        content.body = copy.body
        content.sound = .default
        content.categoryIdentifier = restTimerCategoryId
        content.interruptionLevel = .timeSensitive 

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        let request = UNNotificationRequest(identifier: restTimerId, content: content, trigger: trigger)

        Task { try? await UNUserNotificationCenter.current().add(request) }
    }

    func cancelRestTimerNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [restTimerId])
    }

    func scheduleSmartRetentions(workout: Workout, currentStreak: Int, forecast: ProgressForecast?, unitsManager: UnitsManager) {
        let center = UNUserNotificationCenter.current()

        center.removePendingNotificationRequests(withIdentifiers: [recoveryId, streakRescueId])
        for i in [3, 7, 14] { center.removePendingNotificationRequests(withIdentifiers: ["\(dropOffBaseId)\(i)"]) }

        let tone = UserDefaults.standard.string(forKey: Constants.UserDefaultsKeys.aiCoachTone.rawValue) ?? Constants.AIConstants.defaultTone
        let now = Date()

        let savedHours = UserDefaults.standard.double(forKey: Constants.UserDefaultsKeys.userRecoveryHours.rawValue)
        let recoveryHours = savedHours > 0 ? savedHours : 48.0
        let dominantMuscle = getDominantGroup(for: workout)

        let recoveryCopy = AICopywriter.recoveryText(for: tone, muscle: dominantMuscle)
        scheduleNotification(id: recoveryId, title: recoveryCopy.title, body: recoveryCopy.body, date: now.addingTimeInterval(recoveryHours * 3600), category: retentionCategoryId)

        if let forecast = forecast, forecast.confidence >= 70 {
            let weightStr = LocalizationHelper.shared.formatDecimal(unitsManager.convertFromKilograms(forecast.predictedMax))
            let prCopy = AICopywriter.prPredictionText(for: tone, exercise: forecast.exerciseName, weight: weightStr, unit: unitsManager.weightUnitString())

            let prDate = calendarDate(daysAhead: 2, hour: 17)
            scheduleNotification(id: "pr_prediction", title: prCopy.title, body: prCopy.body, date: prDate, category: retentionCategoryId)
        }

        let maxRestDays = UserDefaults.standard.integer(forKey: Constants.UserDefaultsKeys.streakRestDays.rawValue) > 0 ? UserDefaults.standard.integer(forKey: Constants.UserDefaultsKeys.streakRestDays.rawValue) : 2
        if currentStreak > 2 {
            let rescueCopy = AICopywriter.streakRescueText(for: tone, streak: currentStreak)

            let rescueHours = Double(maxRestDays * 24) - 12.0
            scheduleNotification(id: streakRescueId, title: rescueCopy.title, body: rescueCopy.body, date: now.addingTimeInterval(rescueHours * 3600), category: retentionCategoryId)
        }

        let dropOffDays = [3, 7, 14]
        for days in dropOffDays {
            let copy = AICopywriter.inactivityText(for: tone, daysOff: days)
            let date = now.addingTimeInterval(Double(days * 24 * 3600))
            scheduleNotification(id: "\(dropOffBaseId)\(days)", title: copy.title, body: copy.body, date: date, category: retentionCategoryId)
        }
    }

    private func scheduleNotification(id: String, title: String, body: String, date: Date, category: String? = nil) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        if let category = category { content.categoryIdentifier = category }

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        Task { try? await UNUserNotificationCenter.current().add(request) }
    }

    private func getDominantGroup(for workout: Workout) -> String {
        var counts: [String: Int] = [:]
        for exercise in workout.exercises {
            let targets = exercise.isSuperset ? exercise.subExercises : [exercise]
            for sub in targets { counts[sub.muscleGroup, default: 0] += 1 }
        }
        return counts.sorted { $0.value > $1.value }.first?.key ?? "Body"
    }

    private func calendarDate(daysAhead: Int, hour: Int) -> Date {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date().addingTimeInterval(Double(daysAhead * 24 * 3600)))
        comps.hour = hour; comps.minute = 0
        return Calendar.current.date(from: comps) ?? Date()
    }
}

struct AICopywriter {

    static func restTimerText(for tone: String) -> (title: String, body: String) {
        switch tone {
        case "Strict":
            return (String(localized: "Rest is over."), String(localized: "Pick up the weight. No excuses."))
        case "Friendly":
            return (String(localized: "Timer's up! ✌️"), String(localized: "Ready for the next set? You got this!"))
        case "Scientific":
            return (String(localized: "Timer Finished"), String(localized: "Optimal ATP resynthesis achieved. Commence next set."))
        default: 
            return (String(localized: "Time's up! 💥"), String(localized: "Let's crush this next set, champion!"))
        }
    }

    static func recoveryText(for tone: String, muscle: String) -> (title: String, body: String) {
        let locMuscle = String(localized: String.LocalizationValue(muscle))
        switch tone {
        case "Strict":
            return (String(localized: "\(locMuscle) at 100%."), String(localized: "Your \(locMuscle) is fully recovered. Get to the gym."))
        case "Friendly":
            return (String(localized: "Fresh Muscles! 🌟"), String(localized: "Looks like your \(locMuscle) is feeling fresh and ready to train!"))
        case "Scientific":
            return (String(localized: "Recovery Complete"), String(localized: "Myofibrillar repair complete in \(locMuscle). Ready for hypertrophy load."))
        default: 
            return (String(localized: "\(locMuscle) is Ready! 🔥"), String(localized: "Time to build! Let's hit \(locMuscle) today and grow."))
        }
    }

    static func streakRescueText(for tone: String, streak: Int) -> (title: String, body: String) {
        switch tone {
        case "Strict":
            return (String(localized: "Streak at risk."), String(localized: "You're about to lose your \(streak)-day streak. Train now."))
        case "Friendly":
            return (String(localized: "Hey there! 🏃"), String(localized: "Let's keep that \(streak)-day streak alive together! Just a quick session?"))
        case "Scientific":
            return (String(localized: "Consistency Alert"), String(localized: "Maintain your \(streak)-day streak to prevent neurological detraining."))
        default: 
            return (String(localized: "Save Your Streak! 🛡️"), String(localized: "Don't let your \(streak)-day streak die! 15 minutes is all it takes!"))
        }
    }

    static func prPredictionText(for tone: String, exercise: String, weight: String, unit: String) -> (title: String, body: String) {
        let locEx = String(localized: String.LocalizationValue(exercise))
        switch tone {
        case "Strict":
            return (String(localized: "PR Predicted."), String(localized: "Data shows you can lift \(weight)\(unit) on \(locEx). Prove it."))
        case "Friendly":
            return (String(localized: "New PR incoming? 🏆"), String(localized: "I believe you can hit a new \(locEx) PR of \(weight)\(unit) today!"))
        case "Scientific":
            return (String(localized: "Capacity Update"), String(localized: "Neuromuscular efficiency indicates a \(weight)\(unit) 1RM capacity for \(locEx)."))
        default: 
            return (String(localized: "Prime Condition! 🚀"), String(localized: "You're ready for a \(weight)\(unit) \(locEx) PR! Let's crush it!"))
        }
    }

    static func inactivityText(for tone: String, daysOff: Int) -> (title: String, body: String) {
        switch tone {
        case "Strict":
            return (String(localized: "Unacceptable."), String(localized: "\(daysOff) days of atrophy. Fix it before you lose your gains."))
        case "Friendly":
            return (String(localized: "We miss you! 🥺"), String(localized: "It's been \(daysOff) days! A quick 20-min session is better than nothing."))
        case "Scientific":
            return (String(localized: "System Recalibrating"), String(localized: "72+ hours post-workout: glycogen stores are full. Optimal time to train."))
        default: 
            return (String(localized: "Back on track! ⚡️"), String(localized: "Missed \(daysOff) days? It's never too late to restart your journey."))
        }
    }
}
