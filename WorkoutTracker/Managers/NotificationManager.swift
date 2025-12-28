//
//  NotificationManager.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 27.12.25.
//

import Foundation
import UserNotifications

class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    
    
    // ... внутри class NotificationManager ...

        // 1. Запланировать уведомление о конце отдыха
        func scheduleRestTimerNotification(seconds: Double) {
            // Сначала удаляем старый таймер, если был
            cancelRestTimerNotification()
            
            let content = UNMutableNotificationContent()
            content.title = "Rest Finished! ⚡️"
            content.body = "Time to get back to work!"
            content.sound = UNNotificationSound.default
            // Можно добавить кастомный звук, если он есть в проекте
            // content.sound = UNNotificationSound(named: UNNotificationSoundName("ding.mp3"))

            // Триггер сработает ровно через seconds
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
            
            let request = UNNotificationRequest(identifier: "rest_timer_done", content: content, trigger: trigger)
            
            UNUserNotificationCenter.current().add(request)
        }
        
        // 2. Отменить уведомление (если пользователь нажал "Стоп" раньше времени)
        func cancelRestTimerNotification() {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["rest_timer_done"])
        }
    
    
    override init() {
        super.init()
        // Делегат нужен, чтобы обрабатывать пуши, даже если приложение открыто
        UNUserNotificationCenter.current().delegate = self
    }
    
    // 1. Запрос прав
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("✅ Notification permission granted.")
            } else if let error = error {
                print("❌ Notification permission error: \(error.localizedDescription)")
            }
        }
    }
    
    // 2. Настройка показа пуша, если приложение открыто (полезно для отладки)
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .list])
    }
    
    // 3. ГЛАВНАЯ ЛОГИКА
    func scheduleNotifications(after workout: Workout) {
        // Удаляем старые, чтобы не спамить
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        // --- ШАГ 1: ВОССТАНОВЛЕНИЕ (через 48 часов или как в настройках) ---
        let savedHours = UserDefaults.standard.double(forKey: "userRecoveryHours")
        let recoveryHours = savedHours > 0 ? savedHours : 48.0
        
        // Дата восстановления = Сейчас + часы * 3600 сек
        let recoveryDate = Date().addingTimeInterval(recoveryHours * 3600)
        
        let dominantGroup = getDominantGroup(for: workout)
        let (title, body) = getMotivationalText(for: dominantGroup)
        
        scheduleNotification(
            id: "recovery_notification",
            title: title,
            body: body,
            date: recoveryDate
        )
        
        // --- ШАГ 2: НАПОМИНАНИЕ (через 3 дня / 72 часа) ---
        let inactivityDate = Date().addingTimeInterval(72 * 3600)
        
        scheduleNotification(
            id: "inactivity_notification",
            title: "We miss you! 🥺",
            body: "It's been 3 days since your last workout. Don't lose your streak!",
            date: inactivityDate
        )
    }
    
    // Вспомогательная: Ставит уведомление по Календарю
    private func scheduleNotification(id: String, title: String, body: String, date: Date) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        // Создаем триггер по конкретной дате и времени
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Error scheduling: \(error.localizedDescription)")
            } else {
                print("✅ Scheduled '\(title)' for \(date.formatted())")
            }
        }
    }
    
    // Вспомогательная: Определяет главную группу мышц
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
    
    // Вспомогательная: Тексты
    private func getMotivationalText(for group: String) -> (String, String) {
        switch group {
        case "Chest":
            return ("Chest Fully Recovered! 🦍", "Yo, your chest is ready. Time to push some heavy iron!")
        case "Back":
            return ("Back is Ready! 🦅", "Your wings are recovered. Go do some pull-ups!")
        case "Legs":
            return ("Leg Day Awaits! 🦵", "Your legs are fully charged. Don't skip leg day!")
        case "Arms":
            return ("Guns are Reloaded! 💪", "Biceps and Triceps are fresh. Time for a pump!")
        case "Shoulders":
            return ("Shoulders Ready! 🥥", "Delts are recovered. Go lift something overhead!")
        default:
            return ("Fully Recovered! 🔋", "Your body is ready for the next challenge. Let's go!")
        }
    }
}
