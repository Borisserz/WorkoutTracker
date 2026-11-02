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
        guard let data = try? JSONEncoder().encode(payload) else { return }
        let session = WCSession.default
        if session.isReachable {
            session.sendMessage(["syncPayload": data], replyHandler: nil) { _ in
                // Fall back to guaranteed delivery if live message fails.
                session.transferUserInfo(["guaranteedSyncPayload": data])
            }
        } else {
            session.transferUserInfo(["guaranteedSyncPayload": data])
        }
    }

    func requestPresetsFromPhone() {
        let session = WCSession.default
        #if DEBUG
        print("⌚️ requestPresets — state:\(session.activationState.rawValue) reachable:\(session.isReachable)")
        #endif

        guard session.activationState == .activated else {
            #if DEBUG
            print("⌚️ ❌ session not activated yet — aborting request")
            #endif
            return
        }

        let message = ["request": "presets"]
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil) { error in
                #if DEBUG
                print("⌚️ sendMessage failed → transferUserInfo fallback: \(error.localizedDescription)")
                #endif
                session.transferUserInfo(message)   // guaranteed, queued
            }
        } else {
            #if DEBUG
            print("⌚️ not reachable → transferUserInfo (guaranteed)")
            #endif
            session.transferUserInfo(message)        // works on Simulator
        }
    }

    func requestActiveStateFromPhone() {
        let payload = LiveSyncPayload(action: .requestActiveState, workoutID: "")
        guard let data = try? JSONEncoder().encode(payload) else { return }
        let message = ["syncPayload": data]
        let session = WCSession.default
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil) { error in
                #if DEBUG
                print("⌚️ active-state sendMessage failed → transferUserInfo: \(error.localizedDescription)")
                #endif
                session.transferUserInfo(message)
            }
        } else {
            session.transferUserInfo(message)
        }
    }

    /// Ask iPhone whether a new Watch session is allowed.
    /// Companion installed but unreachable → refuse (avoids dual active sessions).
    /// No companion → allow Watch-only standalone.
    func phoneAllowsNewWorkout() async -> Bool {
        let session = WCSession.default
        guard session.activationState == .activated else { return false }
        #if os(watchOS)
        let hasCompanion = session.isCompanionAppInstalled
        #else
        let hasCompanion = true
        #endif
        if !session.isReachable {
            return !hasCompanion
        }
        return await withCheckedContinuation { continuation in
            session.sendMessage(["request": "canStartWorkout"], replyHandler: { reply in
                continuation.resume(returning: (reply["allowed"] as? Bool) ?? false)
            }, errorHandler: { _ in
                // Transport failed with companion present — fail closed.
                continuation.resume(returning: !hasCompanion)
            })
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
        #if DEBUG
        print("⌚️ activation: \(activationState.rawValue) reachable:\(reachable) ctxKeys:\(ctx.keys)")
        #endif
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
                #if DEBUG
                print("⌚️ got presetsBatch \(presetsData.count) bytes")
                #endif
                if let dtos = try? JSONDecoder().decode([WorkoutPresetDTO].self, from: presetsData) {
                    #if DEBUG
                    print("⌚️ decoded \(dtos.count) presets → saving")
                    #endif
                    await self.savePresetsLocally(dtos)
                } else {
                    #if DEBUG
                    print("⌚️ ❌ failed to decode [WorkoutPresetDTO]")
                    #endif
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
        do {
            try context.save()
        } catch {
            #if DEBUG
            print("⌚️ ❌ failed to save presets locally: \(error.localizedDescription)")
            #endif
        }
    }

    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    #endif
}
