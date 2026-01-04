//
//  NotificationManager.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 27.12.25.
//
//  Менеджер уведомлений.
//  Отвечает за:
//  1. Таймер отдыха (короткие уведомления).
//  2. Напоминания о восстановлении и пропуске тренировок (длинные уведомления).
//  3. Управление правами доступа к уведомлениям.
//

import Foundation
import UserNotifications

class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    
    // MARK: - Singleton
    static let shared = NotificationManager()
    
    // MARK: - Constants
    private let restTimerId = "rest_timer_done"
    private let recoveryId = "recovery_notification"
    private let inactivityId = "inactivity_notification"
    private let recoveryHoursKey = "userRecoveryHours"
    
    // MARK: - Init
    override init() {
        super.init()
        // Делегат нужен, чтобы обрабатывать пуши, даже если приложение открыто
        UNUserNotificationCenter.current().delegate = self
    }
    
    // MARK: - Permissions & Setup
    
    /// Запрос прав на отправку уведомлений
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("✅ Notification permission granted.")
            } else if let error = error {
                print("❌ Notification permission error: \(error.localizedDescription)")
            }
        }
    }
    
    /// Настройка показа пуша, если приложение открыто (показываем баннер и звук)
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .list])
    }
    
    // MARK: - Rest Timer Logic
    
    /// Запланировать уведомление о конце отдыха
    func scheduleRestTimerNotification(seconds: Double) {
        // Сначала удаляем старый таймер, если был
        cancelRestTimerNotification()
        
        let content = UNMutableNotificationContent()
        content.title = "Rest Finished! ⚡️"
        content.body = "Time to get back to work!"
        content.sound = UNNotificationSound.default
        
        // Триггер сработает ровно через seconds
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        let request = UNNotificationRequest(identifier: restTimerId, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
    
    /// Отменить уведомление таймера (если пользователь нажал "Стоп" раньше времени)
    func cancelRestTimerNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [restTimerId])
    }
    
    // MARK: - Workout Recovery Logic
    
    /// Планирует уведомления о восстановлении и напоминания после завершения тренировки
    func scheduleNotifications(after workout: Workout) {
        // Удаляем старые уведомления о восстановлении, чтобы не спамить
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        // --- ШАГ 1: ВОССТАНОВЛЕНИЕ (Recovery) ---
        let savedHours = UserDefaults.standard.double(forKey: recoveryHoursKey)
        let recoveryHours = savedHours > 0 ? savedHours : 48.0
        
        // Дата восстановления = Сейчас + часы * 3600 сек
        let recoveryDate = Date().addingTimeInterval(recoveryHours * 3600)
        
        let dominantGroup = getDominantGroup(for: workout)
        let (title, body) = getMotivationalText(for: dominantGroup)
        
        scheduleNotification(
            id: recoveryId,
            title: title,
            body: body,
            date: recoveryDate
        )
        
        // --- ШАГ 2: НАПОМИНАНИЕ (Inactivity) ---
        // Через 3 дня (72 часа)
        let inactivityDate = Date().addingTimeInterval(72 * 3600)
        
        scheduleNotification(
            id: inactivityId,
            title: "We miss you! 🥺",
            body: "It's been 3 days since your last workout. Don't lose your streak!",
            date: inactivityDate
        )
    }
    
    // MARK: - Private Helpers
    
    /// Вспомогательная функция для создания календарного уведомления
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
    
    /// Определяет главную группу мышц в тренировке (по количеству упражнений)
    private func getDominantGroup(for workout: Workout) -> String {
        var counts: [String: Int] = [:]
        
        for exercise in workout.exercises {
            if exercise.isSuperset {
                for sub in exercise.subExercises {
                    counts[sub.muscleGroup, default: 0] += 1
                }
            } else {
                counts[exercise.muscleGroup, default: 0] += 1
            }
        }
        
        return counts.sorted { $0.value > $1.value }.first?.key ?? "General"
    }
    
    /// Возвращает мотивационный текст в зависимости от группы мышц
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
