// ============================================================
// FILE: WorkoutTracker/Services/System/PhoneWatchManager.swift
// ============================================================
import Foundation
import WatchConnectivity
import SwiftData
internal import SwiftUI

@MainActor
final class PhoneWatchManager: NSObject, WCSessionDelegate {
    static let shared = PhoneWatchManager()
    
    var modelContainer: ModelContainer?

    private override init() {
        super.init()
    }
    
    func start(with container: ModelContainer) {
        self.modelContainer = container
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }
    
    // MARK: - WCSessionDelegate
    
    nonisolated func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) { }
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) { }
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        Task { @MainActor in
            if let data = message["syncPayload"] as? Data, let payload = try? JSONDecoder().decode(LiveSyncPayload.self, from: data) {
                if payload.action == .requestActiveState {
                    self.sendFullActiveStateToWatch()
                } else {
                    NotificationCenter.default.post(name: NSNotification.Name("LiveWorkoutSyncEvent"), object: nil, userInfo: ["payload": payload])
                }
            }
            else if let request = message["request"] as? String, request == "presets" {
                self.sendPresetsToWatch()
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        Task { @MainActor in
            if let data = userInfo["guaranteedSyncPayload"] as? Data,
               let payload = try? JSONDecoder().decode(LiveSyncPayload.self, from: data),
               payload.action == .saveToHistory {
                NotificationCenter.default.post(name: NSNotification.Name("LiveWorkoutSyncEvent"), object: nil, userInfo: ["payload": payload])
            }
        }
    }

    func sendFullActiveStateToWatch() {
           guard let container = modelContainer else { return }
           let context = ModelContext(container)
           
           let desc = FetchDescriptor<Workout>(predicate: #Predicate { $0.endTime == nil })
           if let activeWorkout = try? context.fetch(desc).first {
               let dtos = activeWorkout.exercises.map { $0.toDTO() }
               let payload = LiveSyncPayload(
                   action: .syncFullState,
                   workoutID: activeWorkout.id.uuidString,
                   workoutTitle: activeWorkout.title,
                   exercises: dtos
               )
               if let data = try? JSONEncoder().encode(payload), WCSession.default.isReachable {
                   WCSession.default.sendMessage(["syncPayload": data], replyHandler: nil)
               }
           }
       }
       
       // 2. ДОБАВИЛИ метод для завершения тренировки с телефона
       func sendFinishWorkoutToWatch(workoutID: String) {
           let payload = LiveSyncPayload(action: .finishWorkout, workoutID: workoutID)
           if let data = try? JSONEncoder().encode(payload), WCSession.default.isReachable {
               WCSession.default.sendMessage(["syncPayload": data], replyHandler: nil)
           }
       }
    
    private func sendPresetsToWatch() {
        guard let container = modelContainer else { return }
        let context = ModelContext(container)
        
        do {
            let descriptor = FetchDescriptor<WorkoutPreset>(predicate: #Predicate { $0.isSystem == false })
            let presets = try context.fetch(descriptor)
            let dtos = presets.map { $0.toDTO() }
            let data = try JSONEncoder().encode(dtos)
            
            if WCSession.default.isReachable {
                WCSession.default.sendMessage(["presetsBatch": data], replyHandler: nil)
            }
        } catch {
            print("📱 PhoneWatchManager: Failed to fetch or encode presets: \(error)")
        }
    }
}
