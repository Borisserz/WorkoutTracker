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
        let session = WCSession.default
        print("⌚️ requestPresets — state:\(session.activationState.rawValue) reachable:\(session.isReachable)")

        guard session.activationState == .activated else {
            print("⌚️ ❌ session not activated yet — aborting request")
            return
        }

        let message = ["request": "presets"]
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil) { error in
                print("⌚️ sendMessage failed → transferUserInfo fallback: \(error.localizedDescription)")
                session.transferUserInfo(message)   // guaranteed, queued
            }
        } else {
            print("⌚️ not reachable → transferUserInfo (guaranteed)")
            session.transferUserInfo(message)        // works on Simulator
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

    // MARK: - WCSessionDelegate (Watch)

    // REQUIRED on watchOS — this is what satisfies the protocol.
    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith activationState: WCSessionActivationState,
                             error: (any Error)?) {
        let reachable = session.isReachable
        let ctx = session.receivedApplicationContext        
        print("⌚️ activation: \(activationState.rawValue) reachable:\(reachable) ctxKeys:\(ctx.keys)")
        Task { @MainActor in self.isReachable = reachable }
        if !ctx.isEmpty { handleIncoming(ctx) }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor in self.isReachable = reachable }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        handleIncoming(message)
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        handleIncoming(userInfo)
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        handleIncoming(applicationContext)
    }

    nonisolated private func handleIncoming(_ dict: [String : Any]) {
        let syncData = dict["syncPayload"] as? Data
        let presetsData = dict["presetsBatch"] as? Data

        Task { @MainActor in
            if let data = syncData,
               let payload = try? JSONDecoder().decode(LiveSyncPayload.self, from: data) {
                let name = payload.action == .syncFullState ? "WatchStateRecoveryEvent" : "WatchLiveSyncEvent"
                NotificationCenter.default.post(name: .init(name), object: nil, userInfo: ["payload": payload])
            }

            if let presetsData {
                print("⌚️ got presetsBatch \(presetsData.count) bytes")
                if let dtos = try? JSONDecoder().decode([WorkoutPresetDTO].self, from: presetsData) {
                    print("⌚️ decoded \(dtos.count) presets → saving")
                    await self.savePresetsLocally(dtos)
                } else {
                    print("⌚️ ❌ failed to decode [WorkoutPresetDTO]")
                }
            }
        }
    }

    private func savePresetsLocally(_ dtos: [WorkoutPresetDTO]) async {
        guard let context = modelContext else { return }

        let fetchDescriptor = FetchDescriptor<WorkoutPreset>(predicate: #Predicate { $0.isSystem == false })
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
