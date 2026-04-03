//
//  RestTimerManager.swift
//  WorkoutTracker
//
internal import SwiftUI
import Observation
import AudioToolbox

@Observable
@MainActor
final class RestTimerManager {
    var restTimeRemaining: Int = 0
    var isRestTimerActive: Bool = false
    var restTimerFinished: Bool = false
    var isHidden: Bool = false
    
    private var restEndTime: Date?
    private var tickerTask: Task<Void, Never>? // ✅ ЗАМЕНИЛИ Timer на Task
    
    private var defaultRestTime: Int {
        let saved = UserDefaults.standard.integer(forKey: Constants.UserDefaultsKeys.defaultRestTime.rawValue)
        return saved > 0 ? saved : 60
    }
    
    init() {
        Task {
            for await notification in NotificationCenter.default.notifications(named: NSNotification.Name("ForceStartRestTimer")) {
                let duration = notification.userInfo?["duration"] as? Int
                self.startRestTimer(duration: duration)
            }
        }
        restoreTimerState()
        
        Task {
            for await _ in NotificationCenter.default.notifications(named: UIApplication.willEnterForegroundNotification) {
                checkTimerStateOnForeground()
            }
        }
        
        Task {
            let timerFinishedName = NSNotification.Name(Constants.NotificationIdentifiers.restTimerFinishedNotification.rawValue)
            for await _ in NotificationCenter.default.notifications(named: timerFinishedName) {
                stopRestTimer()
            }
        }
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
      
      // ✅ НОВЫЙ ЧИСТЫЙ TICKER НА БАЗЕ CONCURRENCY
      private func startTicker() {
          tickerTask?.cancel()
          
          tickerTask = Task {
              while !Task.isCancelled {
                  guard let endTime = self.restEndTime else { break }
                  let timeRemaining = endTime.timeIntervalSinceNow
                  
                  if timeRemaining > 0 {
                      let secondsLeft = Int(ceil(timeRemaining))
                      if self.restTimeRemaining != secondsLeft {
                          self.restTimeRemaining = secondsLeft
                      }
                      // Спим 100 миллисекунд (не блокируя Main Thread)
                      try? await Task.sleep(nanoseconds: 100_000_000)
                  } else {
                      self.restTimeRemaining = 0
                      self.finishTimer()
                      break
                  }
              }
          }
      }
    
    private func checkTimerStateOnForeground() {
        guard isRestTimerActive, let endTime = restEndTime else { return }
        let timeRemaining = endTime.timeIntervalSinceNow
        
        if timeRemaining <= 0 {
            self.restTimeRemaining = 0
            finishTimer(suppressAudio: true)
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
    
    func finishTimer(suppressAudio: Bool = false) {
          tickerTask?.cancel() // ✅
          tickerTask = nil
          restTimerFinished = true
          restEndTime = nil
          clearTimerState()
          
          if !suppressAudio {
              let generator = UINotificationFeedbackGenerator()
              generator.prepare()
              generator.notificationOccurred(.success)
              AudioServicesPlaySystemSound(1005)
          }
          
          Task {
              try? await Task.sleep(nanoseconds: 3_000_000_000)
              guard !Task.isCancelled else { return }
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
          
          tickerTask?.cancel() // ✅
          tickerTask = nil
          NotificationManager.shared.cancelRestTimerNotification()
      }
  }
