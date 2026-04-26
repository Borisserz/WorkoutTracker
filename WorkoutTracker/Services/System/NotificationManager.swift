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

    nonisolated func userNotificationcenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
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

    // ИЗМЕНЕНИЕ 1: Добавляем async
    func scheduleRestTimerNotification(seconds: Double) async {
        cancelRestTimerNotification()

        let tone = UserDefaults.standard.string(forKey: Constants.UserDefaultsKeys.aiCoachTone.rawValue) ?? "motivational"
        // ИЗМЕНЕНИЕ 2: Добавляем await
        let copy = await AICopywriter.restTimerText(for: tone)

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
    
    // ИЗМЕНЕНИЕ 3: Добавляем async
    func scheduleSmartRetentions(workout: Workout, currentStreak: Int, forecast: ProgressForecast?, unitsManager: UnitsManager) async {
        let center = UNUserNotificationCenter.current()

        center.removePendingNotificationRequests(withIdentifiers: [recoveryId, streakRescueId])
        for i in [3, 7, 14] { center.removePendingNotificationRequests(withIdentifiers: ["\(dropOffBaseId)\(i)"]) }

        let tone = UserDefaults.standard.string(forKey: Constants.UserDefaultsKeys.aiCoachTone.rawValue) ?? "motivational"
        let now = Date()

        let savedHours = UserDefaults.standard.double(forKey: Constants.UserDefaultsKeys.userRecoveryHours.rawValue)
        let recoveryHours = savedHours > 0 ? savedHours : 48.0
        let dominantMuscle = getDominantGroup(for: workout)

        // ИЗМЕНЕНИЕ 4: Добавляем await повсюду
        let recoveryCopy = await AICopywriter.recoveryText(for: tone, muscle: dominantMuscle)
        scheduleNotification(id: recoveryId, title: recoveryCopy.title, body: recoveryCopy.body, date: now.addingTimeInterval(recoveryHours * 3600), category: retentionCategoryId)

        if let forecast = forecast, forecast.confidence >= 70 {
            let weightStr = LocalizationHelper.shared.formatDecimal(unitsManager.convertFromKilograms(forecast.predictedMax))
            let prCopy = await AICopywriter.prPredictionText(for: tone, exercise: forecast.exerciseName, weight: weightStr, unit: unitsManager.weightUnitString())

            let prDate = calendarDate(daysAhead: 2, hour: 17)
            scheduleNotification(id: "pr_prediction", title: prCopy.title, body: prCopy.body, date: prDate, category: retentionCategoryId)
        }

        let maxRestDays = UserDefaults.standard.integer(forKey: Constants.UserDefaultsKeys.streakRestDays.rawValue) > 0 ? UserDefaults.standard.integer(forKey: Constants.UserDefaultsKeys.streakRestDays.rawValue) : 2
        if currentStreak > 2 {
            let rescueCopy = await AICopywriter.streakRescueText(for: tone, streak: currentStreak)

            let rescueHours = Double(maxRestDays * 24) - 12.0
            scheduleNotification(id: streakRescueId, title: rescueCopy.title, body: rescueCopy.body, date: now.addingTimeInterval(rescueHours * 3600), category: retentionCategoryId)
        }

        let dropOffDays = [3, 7, 14]
        for days in dropOffDays {
            let copy = await AICopywriter.inactivityText(for: tone, daysOff: days)
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
    static func restTimerText(for toneId: String) async -> (title: String, body: String) {
        let persona = await RemoteConfigManager.shared.getPersona(id: toneId)
        return (persona?.notifications.restTimer.title ?? "Time's up!",
                persona?.notifications.restTimer.body ?? "Let's crush the next set!")
    }

    static func recoveryText(for toneId: String, muscle: String) async -> (title: String, body: String) {
        let persona = await RemoteConfigManager.shared.getPersona(id: toneId)
        let title = persona?.notifications.recovery.title ?? "Muscle Recovered!"
        let body = persona?.notifications.recovery.body ?? "Time to train."
        return (title.replacingOccurrences(of: "{muscle}", with: muscle),
                body.replacingOccurrences(of: "{muscle}", with: muscle))
    }

    static func streakRescueText(for toneId: String, streak: Int) async -> (title: String, body: String) {
        let persona = await RemoteConfigManager.shared.getPersona(id: toneId)
        return (persona?.notifications.streak.title ?? "Save Your Streak!",
                (persona?.notifications.streak.body ?? "Don't let your {streak}-day streak die!").replacingOccurrences(of: "{streak}", with: "\(streak)"))
    }

    static func prPredictionText(for toneId: String, exercise: String, weight: String, unit: String) async -> (title: String, body: String) {
        let persona = await RemoteConfigManager.shared.getPersona(id: toneId)
        return (persona?.notifications.pr.title ?? "PR Predicted!",
                (persona?.notifications.pr.body ?? "Data shows you can lift {weight}{unit} on {exercise}.").replacingOccurrences(of: "{exercise}", with: exercise).replacingOccurrences(of: "{weight}", with: weight).replacingOccurrences(of: "{unit}", with: unit))
    }

    static func inactivityText(for toneId: String, daysOff: Int) async -> (title: String, body: String) {
        let persona = await RemoteConfigManager.shared.getPersona(id: toneId)
        return (persona?.notifications.inactivity.title ?? "Back on track!",
                (persona?.notifications.inactivity.body ?? "Missed {daysOff} days? Time to restart.").replacingOccurrences(of: "{daysOff}", with: "\(daysOff)"))
    }
}
