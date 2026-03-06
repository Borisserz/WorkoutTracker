//
//  RestTimerManager.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 2024.
//

internal import SwiftUI
import Combine
import AudioToolbox

class RestTimerManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var restTimeRemaining: Int = 0
    @Published var isRestTimerActive: Bool = false
    @Published var restTimerFinished: Bool = false
    
    // MARK: - Private Properties
    private var restEndTime: Date?
    private var restTimer: Timer?
    
    private var defaultRestTime: Int {
        let saved = UserDefaults.standard.integer(forKey: "defaultRestTime")
        return saved > 0 ? saved : 60
    }
    
    // MARK: - Init / Deinit
    init() {
        // Поддержка фона: при возвращении в приложение проверяем статус таймера, 
        // чтобы мгновенно обновить UI, если таймер истек в фоне.
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.checkTimerStateOnForeground()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        restTimer?.invalidate()
        restTimer = nil
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
        restTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let endTime = self.restEndTime else { return }
            let timeLeft = Int(endTime.timeIntervalSinceNow)
            
            if timeLeft >= 0 {
                if self.restTimeRemaining != timeLeft + 1 {
                    self.restTimeRemaining = timeLeft + 1
                }
            } else {
                self.finishTimer()
            }
        }
    }
    
    private func checkTimerStateOnForeground() {
        guard isRestTimerActive, let endTime = restEndTime else { return }
        let timeLeft = Int(endTime.timeIntervalSinceNow)
        
        if timeLeft <= 0 {
            finishTimer()
        } else {
            self.restTimeRemaining = timeLeft
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
        AudioServicesPlaySystemSound(1005)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation { self.stopRestTimer() }
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
