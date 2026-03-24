//
//  RestTimerManager.swift
//  WorkoutTracker
//

internal import SwiftUI
import Combine
import AudioToolbox

@MainActor // Ensures UI updates always happen on the main thread
class RestTimerManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var restTimeRemaining: Int = 0
    @Published var isRestTimerActive: Bool = false
    @Published var restTimerFinished: Bool = false
    
    // MARK: - Private Properties
    private var restEndTime: Date?
    private var restTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    private var defaultRestTime: Int {
        let saved = UserDefaults.standard.integer(forKey: Constants.UserDefaultsKeys.defaultRestTime.rawValue)
        return saved > 0 ? saved : 60
    }
    
    // MARK: - Init / Deinit
    init() {
        // 1. Restore the timer state if the app was closed while the timer was running
        restoreTimerState()
        
        // 2. Safely subscribe to foreground notifications
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                self?.checkTimerStateOnForeground()
            }
            .store(in: &cancellables)
        
        // 3. Listen for "Done" interaction on the Local Notification (Posted by NotificationManager)
        NotificationCenter.default.publisher(for: NSNotification.Name(Constants.NotificationIdentifiers.restTimerFinishedNotification.rawValue))
            .sink { [weak self] _ in
                self?.stopRestTimer()
            }
            .store(in: &cancellables)
    }
    
    deinit {
        restTimer?.invalidate()
        restTimer = nil
    }
    
    // MARK: - Persistence Logic
    
    private func saveTimerState() {
        guard let endTime = restEndTime else { return }
        UserDefaults.standard.set(endTime.timeIntervalSince1970, forKey: Constants.UserDefaultsKeys.restEndTime.rawValue)
    }
    
    private func clearTimerState() {
        UserDefaults.standard.removeObject(forKey: Constants.UserDefaultsKeys.restEndTime.rawValue)
    }
    
    private func restoreTimerState() {
        let savedTime = UserDefaults.standard.double(forKey: Constants.UserDefaultsKeys.restEndTime.rawValue)
        guard savedTime > 0 else { return }
        
        let endTime = Date(timeIntervalSince1970: savedTime)
        let timeRemaining = endTime.timeIntervalSinceNow
        
        if timeRemaining > 0 {
            // Timer is still valid, resume it
            self.restEndTime = endTime
            self.restTimeRemaining = Int(ceil(timeRemaining))
            self.isRestTimerActive = true
            self.restTimerFinished = false
            startTicker()
        } else {
            // Timer expired while the app was closed
            clearTimerState()
        }
    }
    
    // MARK: - Timer Logic
    
    func startRestTimer(duration: Int? = nil) {
        let seconds = duration ?? defaultRestTime
        self.restEndTime = Date().addingTimeInterval(Double(seconds))
        self.restTimeRemaining = seconds
        self.isRestTimerActive = true
        self.restTimerFinished = false
        
        saveTimerState()
        
        NotificationManager.shared.scheduleRestTimerNotification(seconds: Double(seconds))
        startTicker()
    }
    
    private func startTicker() {
        restTimer?.invalidate()
        
        // Added to .common RunLoop to prevent pausing while scrolling
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let endTime = self.restEndTime else { return }
            let timeRemaining = endTime.timeIntervalSinceNow
            
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
            saveTimerState()
            
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
                saveTimerState()
                
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
        clearTimerState()
        
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
        AudioServicesPlaySystemSound(1005) // System notification sound
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self = self else { return }
            
            if self.restTimerFinished {
                withAnimation { self.stopRestTimer() }
            }
        }
    }
    
    func stopRestTimer() {
        isRestTimerActive = false
        restTimerFinished = false
        restEndTime = nil
        clearTimerState()
        
        restTimer?.invalidate()
        restTimer = nil
        NotificationManager.shared.cancelRestTimerNotification()
    }
}
