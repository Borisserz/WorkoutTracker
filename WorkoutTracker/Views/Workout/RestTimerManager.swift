//
//  RestTimerManager.swift
//  WorkoutTracker
//

internal import SwiftUI
import Combine
import AudioToolbox

@MainActor
class RestTimerManager: ObservableObject {
    
    // 🎼 МАЭСТРО: Убрали @Published, чтобы не вызывать глобальный рендер 10 раз в секунду.
    // Вместо этого используем CurrentValueSubject. Подписчики смогут слушать только изменения цифр.
    let timeRemainingSubject = CurrentValueSubject<Int, Never>(0)
    
    // Оставляем @Published только для флагов состояний интерфейса (меняются редко)
    @Published var isRestTimerActive: Bool = false
    @Published var restTimerFinished: Bool = false
    @Published var isHidden: Bool = false
    
    private var restEndTime: Date?
    private var restTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // Удобный геттер/сеттер для обновления сабджекта
    var restTimeRemaining: Int {
        get { timeRemainingSubject.value }
        set { timeRemainingSubject.send(newValue) }
    }
    
    private var defaultRestTime: Int {
        let saved = UserDefaults.standard.integer(forKey: Constants.UserDefaultsKeys.defaultRestTime.rawValue)
        return saved > 0 ? saved : 60
    }
    
    init() {
        restoreTimerState()
        
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                self?.checkTimerStateOnForeground()
            }
            .store(in: &cancellables)
        
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
            self.restEndTime = endTime
            self.restTimeRemaining = Int(ceil(timeRemaining))
            self.isRestTimerActive = true
            self.restTimerFinished = false
            startTicker()
        } else {
            clearTimerState()
        }
    }
    
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
        AudioServicesPlaySystemSound(1005)
        
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
