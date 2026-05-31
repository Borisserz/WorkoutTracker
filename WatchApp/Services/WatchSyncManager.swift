import Foundation
import WatchConnectivity
import Observation
import SwiftData

@Observable
@MainActor
final class WatchSyncManager: NSObject, WCSessionDelegate {
    static let shared = WatchSyncManager()
    var isReachable: Bool = false

    var modelContext: ModelContext?

    private override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }

    func sendLiveAction(_ payload: LiveSyncPayload) {
        guard WCSession.default.isReachable else { return }
        if let data = try? JSONEncoder().encode(payload) {
            WCSession.default.sendMessage(["syncPayload": data], replyHandler: nil)
        }
    }

    func requestPresetsFromPhone() {
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(["request": "presets"], replyHandler: nil)
        }
    }

    func requestActiveStateFromPhone() {
        guard WCSession.default.isReachable else { return }
        let payload = LiveSyncPayload(action: .requestActiveState, workoutID: "")
        if let data = try? JSONEncoder().encode(payload) {
            WCSession.default.sendMessage(["syncPayload": data], replyHandler: nil)
        }
    }

    func transferGuaranteedPayload(_ payload: LiveSyncPayload) {
        if let data = try? JSONEncoder().encode(payload) {
            WCSession.default.transferUserInfo(["guaranteedSyncPayload": data])
        }
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        // Read Bool (Sendable) here; never capture the WCSession into the Task.
        let reachable = session.isReachable
        Task { @MainActor in self.isReachable = reachable }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor in self.isReachable = reachable }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        // Extract Data (Sendable) before the Task; never capture [String: Any].
        let syncData = message["syncPayload"] as? Data
        let presetsData = message["presetsBatch"] as? Data

        Task { @MainActor in
            if let data = syncData,
               let payload = try? JSONDecoder().decode(LiveSyncPayload.self, from: data) {

                if payload.action == .syncFullState {
                    NotificationCenter.default.post(name: NSNotification.Name("WatchStateRecoveryEvent"), object: nil, userInfo: ["payload": payload])
                } else {
                    NotificationCenter.default.post(name: NSNotification.Name("WatchLiveSyncEvent"), object: nil, userInfo: ["payload": payload])
                }
            }

            if let presetsData,
               let dtos = try? JSONDecoder().decode([WorkoutPresetDTO].self, from: presetsData) {
                await self.savePresetsLocally(dtos)
            }
        }
    }

    private func savePresetsLocally(_ dtos: [WorkoutPresetDTO]) async {
        guard let context = modelContext else { return }

        let fetchDescriptor = FetchDescriptor<WorkoutPreset>()
        if let existing = try? context.fetch(fetchDescriptor) {
            for p in existing { context.delete(p) }
        }

        for dto in dtos {
            let preset = WorkoutPreset(from: dto)
            context.insert(preset)
        }
        try? context.save()
    }

    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    #endif
}
