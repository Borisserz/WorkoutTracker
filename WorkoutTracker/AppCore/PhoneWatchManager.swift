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

    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith state: WCSessionActivationState,
                             error: Error?) {
        print("📱 activation: \(state.rawValue) reachable:\(session.isReachable) error:\(String(describing: error))")
        if let error = error {
            TrackingManager.shared.recordError(error: error, additionalInfo: ["context": "WCSessionActivation"])
        }
        if state == .activated {
            TrackingManager.shared.setUserProperty(name: "has_apple_watch", value: String(session.isWatchAppInstalled))
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) { session.activate() }

    // Только ОДНА копия этого метода!
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        Task { @MainActor in
            if let request = userInfo["request"] as? String, request == "presets" {
                print("📱 got queued presets request (transferUserInfo)")
                self.sendPresetsToWatch()
            }
            if let data = userInfo["guaranteedSyncPayload"] as? Data,
               let payload = try? JSONDecoder().decode(LiveSyncPayload.self, from: data),
               payload.action == .saveToHistory {
                NotificationCenter.default.post(name: .init("LiveWorkoutSyncEvent"), object: nil, userInfo: ["payload": payload])
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        if let data = message["syncPayload"] as? Data,
           let payload = try? JSONDecoder().decode(LiveSyncPayload.self, from: data) {
            Task { @MainActor in
                if payload.action == .updateHeartRate, let hr = payload.heartRate {
                    NotificationCenter.default.post(name: NSNotification.Name("LiveHeartRateUpdate"), object: hr)
                    return
                }

                if payload.action == .requestActiveState {
                    self.sendFullActiveStateToWatch()
                } else {
                    NotificationCenter.default.post(name: NSNotification.Name("LiveWorkoutSyncEvent"), object: nil, userInfo: ["payload": payload])
                }
            }
        } else if let request = message["request"] as? String, request == "presets" {
            print("📱 got presets request (sendMessage)")
            Task { @MainActor in
                self.sendPresetsToWatch()
            }
        }
    }

    // MARK: - Sending

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

    func sendFinishWorkoutToWatch(workoutID: String) {
        let payload = LiveSyncPayload(action: .finishWorkout, workoutID: workoutID)
        if let data = try? JSONEncoder().encode(payload), WCSession.default.isReachable {
            WCSession.default.sendMessage(["syncPayload": data], replyHandler: nil)
        }
    }

    private func sendPresetsToWatch() {
        let trace = TrackingManager.shared.startTrace(name: "watch_send_presets")
        guard let container = modelContainer else { 
            print("📱 ❌ no modelContainer")
            trace?.stop()
            return 
        }
        let context = ModelContext(container)
        do {
            let descriptor = FetchDescriptor<WorkoutPreset>(predicate: #Predicate { $0.isSystem == false })
            let presets = try context.fetch(descriptor)
            let dtos = presets.map { $0.toDTO() }
            let data = try JSONEncoder().encode(dtos)
            print("📱 sending \(presets.count) presets, \(data.count) bytes")

            // ГАРАНТИРОВАННАЯ доставка на симуляторе — не зависит от reachability.
            try WCSession.default.updateApplicationContext([
                "presetsBatch": data,
                "ts": Date().timeIntervalSince1970
            ])

            if WCSession.default.isReachable {
                WCSession.default.sendMessage(["presetsBatch": data], replyHandler: nil)
            }
            trace?.stop()
        } catch {
            print("📱 ❌ sendPresetsToWatch failed: \(error)")
            TrackingManager.shared.recordError(error: error, additionalInfo: ["context": "sendPresetsToWatch"])
            trace?.stop()
        }
    }
}
