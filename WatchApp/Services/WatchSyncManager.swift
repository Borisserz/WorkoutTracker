import Foundation
import OSLog
import WatchConnectivity
import Observation
import SwiftData


#if os(watchOS)
private enum SyncLog {
    static let logger = WatchAppLog.sync
}
#else
private enum SyncLog {
    static let logger = AppLog.watch
}
#endif

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
        let envelope = WatchSyncEnvelope.userInfo(carrying: data)
        let session = WCSession.default
        if session.isReachable {
            session.sendMessage(envelope, replyHandler: nil) { _ in
                // Fall back to guaranteed delivery if live message fails.
                session.transferUserInfo(envelope)
            }
        } else {
            session.transferUserInfo(envelope)
        }
    }

    func requestPresetsFromPhone() {
        let session = WCSession.default
        SyncLog.logger.debug("⌚️ requestPresets — state:\(session.activationState.rawValue) reachable:\(session.isReachable)")

        guard session.activationState == .activated else {
            SyncLog.logger.error("⌚️ ❌ session not activated yet — aborting request")
            return
        }

        let message = ["request": "presets"]
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil) { error in
                SyncLog.logger.error("⌚️ sendMessage failed → transferUserInfo fallback: \(error.localizedDescription)")
                session.transferUserInfo(message)   // guaranteed, queued
            }
        } else {
            SyncLog.logger.debug("⌚️ not reachable → transferUserInfo (guaranteed)")
            session.transferUserInfo(message)        // works on Simulator
        }
    }

    func requestActiveStateFromPhone() {
        let payload = LiveSyncPayload(action: .requestActiveState, workoutID: "")
        guard let data = try? JSONEncoder().encode(payload) else { return }
        let envelope = WatchSyncEnvelope.userInfo(carrying: data)
        let session = WCSession.default
        if session.isReachable {
            session.sendMessage(envelope, replyHandler: nil) { error in
                SyncLog.logger.error("⌚️ active-state sendMessage failed → transferUserInfo: \(error.localizedDescription)")
                session.transferUserInfo(envelope)
            }
        } else {
            session.transferUserInfo(envelope)
        }
    }

    /// Ask iPhone whether a new Watch session is allowed.
    /// Companion installed but unreachable → refuse (avoids dual active sessions).
    /// No companion → allow Watch-only standalone.
    func phoneAllowsNewWorkout() async -> Bool {
        let session = WCSession.default
        #if os(watchOS)
        let hasCompanion = session.isCompanionAppInstalled
        #else
        let hasCompanion = true
        #endif
        switch WatchSessionPolicy.watchMayAttemptStart(
            sessionActivated: session.activationState == .activated,
            isReachable: session.isReachable,
            hasCompanionApp: hasCompanion
        ) {
        case .refuse:
            return false
        case .allowStandalone:
            return true
        case .askPhone:
            return await withCheckedContinuation { continuation in
                session.sendMessage(["request": "canStartWorkout"], replyHandler: { reply in
                    continuation.resume(
                        returning: WatchSessionPolicy.watchMayStartAfterPhoneHandshake(
                            phoneAllowed: reply["allowed"] as? Bool,
                            transportFailed: false,
                            hasCompanionApp: hasCompanion
                        )
                    )
                }, errorHandler: { _ in
                    continuation.resume(
                        returning: WatchSessionPolicy.watchMayStartAfterPhoneHandshake(
                            phoneAllowed: nil,
                            transportFailed: true,
                            hasCompanionApp: hasCompanion
                        )
                    )
                })
            }
        }
    }

    func transferGuaranteedPayload(_ payload: LiveSyncPayload) {
        if let data = try? JSONEncoder().encode(payload) {
            WCSession.default.transferUserInfo(WatchSyncEnvelope.userInfo(carrying: data))
        }
    }

    // MARK: - WCSessionDelegate (Watch)

    // REQUIRED on watchOS — this is what satisfies the protocol.
    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith activationState: WCSessionActivationState,
                             error: (any Error)?) {
        let reachable = session.isReachable
        let ctx = session.receivedApplicationContext        
        SyncLog.logger.debug("⌚️ activation: \(activationState.rawValue) reachable:\(reachable) ctxKeys:\(ctx.keys)")
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
        let syncData = WatchSyncEnvelope.liveSyncData(from: dict)
        let presetsData = dict["presetsBatch"] as? Data

        Task { @MainActor in
            if let data = syncData,
               let payload = try? JSONDecoder().decode(LiveSyncPayload.self, from: data) {
                let name = payload.action == .syncFullState ? "WatchStateRecoveryEvent" : "WatchLiveSyncEvent"
                NotificationCenter.default.post(name: .init(name), object: nil, userInfo: ["payload": payload])
            }

            if let presetsData {
                SyncLog.logger.debug("⌚️ got presetsBatch \(presetsData.count) bytes")
                if let dtos = try? JSONDecoder().decode([WorkoutPresetDTO].self, from: presetsData) {
                    SyncLog.logger.debug("⌚️ decoded \(dtos.count) presets → saving")
                    await self.savePresetsLocally(dtos)
                } else {
                    SyncLog.logger.error("⌚️ ❌ failed to decode [WorkoutPresetDTO]")
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
            SyncLog.logger.error("⌚️ ❌ failed to save presets locally: \(error.localizedDescription)")
        }
    }

    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    #endif
}
