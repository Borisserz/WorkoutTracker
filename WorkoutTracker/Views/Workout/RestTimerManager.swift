//
//  RestTimerManager.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 2024.
//

internal import SwiftUI
import Combine
import AudioToolbox

@MainActor // Гарантирует, что обновления UI всегда происходят в главном потоке
class RestTimerManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var restTimeRemaining: Int = 0
    @Published var isRestTimerActive: Bool = false
    @Published var restTimerFinished: Bool = false
    
    // MARK: - Private Properties
    private var restEndTime: Date?
    private var restTimer: Timer?
    private var cancellables = Set<AnyCancellable>() // Хранилище подписок для Combine
    
    private var defaultRestTime: Int {
        let saved = UserDefaults.standard.integer(forKey: "defaultRestTime")
        return saved > 0 ? saved : 60
    }
    
    // MARK: - Init / Deinit
    init() {
        // Поддержка фона: безопасно подписываемся через Combine.
        // Это полностью решает проблему утечки памяти обсервера.
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                self?.checkTimerStateOnForeground()
            }
            .store(in: &cancellables)
    }
    
    deinit {
        restTimer?.invalidate()
        restTimer = nil
        // Отписка от нотификаций через Combine (cancellables) произойдет автоматически.
    }
    
    // MARK: - Timer Logic
    
    func startRestTimer(duration: Int? = nil) {
        let seconds = duration ?? defaultRestTime
        self.restEndTime = Date().addingTimeInterval(Double(seconds))
        self.restTimeRemaining = seconds
        self.isRestTimerActive = true
        self.restTimerFinished = false
        
        NotificationManager.shared.scheduleRestTimerNotification(seconds: Double(seconds))
        startTicker()
    }
    
    private func startTicker() {
        restTimer?.invalidate()
        
        // РЕШЕНИЕ: Создаем таймер через инициализатор (чтобы не дублировать в .default RunLoop)
        // и добавляем в .common RunLoop
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let endTime = self.restEndTime else { return }
            let timeRemaining = endTime.timeIntervalSinceNow
            
            // Используем ceil() для правильного округления до верхнего целого.
            // Это решает проблему зависания таймера на "1" и опоздания завершения.
            if timeRemaining > 0 {
                let secondsLeft = Int(ceil(timeRemaining))
                if self.restTimeRemaining != secondsLeft {
                    self.restTimeRemaining = secondsLeft
                }
            } else {
                self.restTimeRemaining = 0
                self.finishTimer()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        restTimer = timer
    }
    
    private func checkTimerStateOnForeground() {
        guard isRestTimerActive, let endTime = restEndTime else { return }
        let timeRemaining = endTime.timeIntervalSinceNow
        
        if timeRemaining <= 0 {
            self.restTimeRemaining = 0
            finishTimer()
        } else {
            self.restTimeRemaining = Int(ceil(timeRemaining))
            startTicker()
        }
    }
    
    func addRestTime(_ seconds: Int) {
        if isRestTimerActive, let currentEnd = restEndTime {
            let newEnd = currentEnd.addingTimeInterval(Double(seconds))
            self.restEndTime = newEnd
            NotificationManager.shared.scheduleRestTimerNotification(seconds: newEnd.timeIntervalSinceNow)
            self.restTimeRemaining += seconds
        }
    }
    
    func subtractRestTime(_ seconds: Int) {
        if isRestTimerActive, let currentEnd = restEndTime {
            let newEnd = currentEnd.addingTimeInterval(Double(-seconds))
            if newEnd.timeIntervalSinceNow <= 0 {
                self.restTimeRemaining = 0
                finishTimer()
            } else {
                self.restEndTime = newEnd
                NotificationManager.shared.scheduleRestTimerNotification(seconds: newEnd.timeIntervalSinceNow)
                self.restTimeRemaining = max(0, restTimeRemaining - seconds)
            }
        }
    }
    
    func finishTimer() {
        restTimer?.invalidate()
        restTimer = nil
        restTimerFinished = true
        restEndTime = nil
        
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
        AudioServicesPlaySystemSound(1005) // ID звукового оповещения системы
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self = self else { return }
            
            // Решаем Race condition: закрываем таймер только если за эти 3 секунды 
            // пользователь не запустил новый (если запустил, restTimerFinished будет равен false)
            if self.restTimerFinished {
                withAnimation { self.stopRestTimer() }
            }
        }
    }
    
    func stopRestTimer() {
        isRestTimerActive = false
        restTimerFinished = false
        restEndTime = nil
        restTimer?.invalidate()
        restTimer = nil
        NotificationManager.shared.cancelRestTimerNotification()
    }
}
