//
//  NotificationManager.swift
//  WorkoutTracker
//

import Foundation
import UserNotifications
import SwiftData

extension Notification.Name {
    static let workoutDataDidUpdate = Notification.Name("workoutDataDidUpdate")
    static let workoutCompletedEvent = Notification.Name("workoutCompletedEvent")
}

class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    
    // MARK: - Singleton
    static let shared = NotificationManager()
    
    // MARK: - Constants
    private let restTimerId = Constants.NotificationIdentifiers.restTimerDone.rawValue
    private let restTimerCategoryId = Constants.NotificationIdentifiers.restTimerCategory.rawValue
    private let recoveryId = Constants.NotificationIdentifiers.recoveryNotification.rawValue
    private let inactivityId = Constants.NotificationIdentifiers.inactivityNotification.rawValue
    private let recoveryHoursKey = "userRecoveryHours"
    
    private var notificationTask: Task<Void, Never>?
    
    // MARK: - Init
    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        setupNotificationCategories()
        notificationTask = Task { await listenForWorkoutCompletion() }
    }
    
    deinit {
        notificationTask?.cancel()
    }
    
    private func listenForWorkoutCompletion() async {
        for await notification in NotificationCenter.default.notifications(named: .workoutCompletedEvent) {
            guard let workoutID = notification.object as? PersistentIdentifier,
                  let modelContainer = notification.userInfo?["modelContainer"] as? ModelContainer else { continue }
            
            let bgContext = ModelContext(modelContainer)
            if let workout = bgContext.model(for: workoutID) as? Workout {
                scheduleNotifications(after: workout)
            }
        }
    }
    
    // MARK: - Permissions & Setup
    
    func requestPermission() {
        let options: UNAuthorizationOptions = [.alert, .badge, .sound, .timeSensitive]
        UNUserNotificationCenter.current().requestAuthorization(options: options) { _, _ in }
    }
    
    func requestPermission(completion: @escaping (Bool) -> Void) {
        let options: UNAuthorizationOptions = [.alert, .badge, .sound, .timeSensitive]
        UNUserNotificationCenter.current().requestAuthorization(options: options) { granted, _ in
            completion(granted)
        }
    }
    
    private func setupNotificationCategories() {
        let doneAction = UNNotificationAction(identifier: Constants.NotificationIdentifiers.doneAction.rawValue, title: String(localized: "Done"), options: [.foreground])
        let restTimerCategory = UNNotificationCategory(identifier: restTimerCategoryId, actions: [doneAction], intentIdentifiers: [], options: [.customDismissAction])
        UNUserNotificationCenter.current().setNotificationCategories([restTimerCategory])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let options: UNNotificationPresentationOptions = notification.request.identifier == restTimerId ? [.banner, .sound, .list, .badge] : [.banner, .sound, .list]
        completionHandler(options)
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.actionIdentifier == Constants.NotificationIdentifiers.doneAction.rawValue || (response.notification.request.identifier == restTimerId && response.actionIdentifier == UNNotificationDefaultActionIdentifier) {
            NotificationCenter.default.post(name: NSNotification.Name(Constants.NotificationIdentifiers.restTimerFinishedNotification.rawValue), object: nil)
        }
        completionHandler()
    }
    
    // MARK: - Rest Timer Logic
    
    func scheduleRestTimerNotification(seconds: Double) {
        cancelRestTimerNotification()
        
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Timer Finished!")
        content.body = String(localized: "Rest time is over. Time to get back to your workout!")
        content.sound = .default
        content.categoryIdentifier = restTimerCategoryId
        content.badge = 1
        content.userInfo = ["type": "rest_timer"]
        content.threadIdentifier = "rest_timer"
        content.interruptionLevel = .timeSensitive
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        let request = UNNotificationRequest(identifier: restTimerId, content: content, trigger: trigger)
        
        Task { try? await UNUserNotificationCenter.current().add(request) }
    }
    
    func cancelRestTimerNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [restTimerId])
    }
    
    // MARK: - Workout Recovery Logic
    
     func scheduleNotifications(after workout: Workout) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [recoveryId, inactivityId])
        
        let savedHours = UserDefaults.standard.double(forKey: recoveryHoursKey)
        let recoveryHours = savedHours > 0 ? savedHours : 48.0
        let recoveryDate = Date().addingTimeInterval(recoveryHours * 3600)
        let dominantGroup = getDominantGroup(for: workout)
        let (title, body) = getMotivationalText(for: dominantGroup)
        
        scheduleNotification(id: recoveryId, title: title, body: body, date: recoveryDate)
        
        let inactivityDate = Date().addingTimeInterval(72 * 3600)
        scheduleNotification(id: inactivityId, title: "We miss you! 🥺", body: "It's been 3 days since your last workout. Don't lose your streak!", date: inactivityDate)
    }
    
    // MARK: - Private Helpers
    
    private func scheduleNotification(id: String, title: String, body: String, date: Date) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        
        // ИСПРАВЛЕНИЕ ЗДЕСЬ: Второй вызов тоже обернут в Task
        Task {
            try? await UNUserNotificationCenter.current().add(request)
        }
    }
    
    private func getDominantGroup(for workout: Workout) -> String {
        var counts: [String: Int] = [:]
        for exercise in workout.exercises {
            if exercise.isSuperset {
                for sub in exercise.subExercises { counts[sub.muscleGroup, default: 0] += 1 }
            } else {
                counts[exercise.muscleGroup, default: 0] += 1
            }
        }
        return counts.sorted { $0.value > $1.value }.first?.key ?? "General"
    }
    
    private func getMotivationalText(for group: String) -> (String, String) {
        switch group {
        case "Chest": return (String(localized: "Chest Fully Recovered!"), String(localized: "Yo, your chest is ready. Time to push some heavy iron!"))
        case "Back": return (String(localized: "Back is Ready!"), String(localized: "Your wings are recovered. Go do some pull-ups!"))
        case "Legs": return (String(localized: "Leg Day Awaits!"), String(localized: "Your legs are fully charged. Don't skip leg day!"))
        case "Arms": return (String(localized: "Guns are Reloaded!"), String(localized: "Biceps and Triceps are fresh. Time for a pump!"))
        case "Shoulders": return (String(localized: "Shoulders Ready!"), String(localized: "Delts are recovered. Go lift something overhead!"))
        default: return (String(localized: "Fully Recovered!"), String(localized: "Your body is ready for the next challenge. Let's go!"))
        }
    }
}
