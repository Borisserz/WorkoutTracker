// ============================================================
// FILE: WatchApp/Services/WatchSyncManager.swift
// ============================================================
import Foundation
import WatchConnectivity
import Observation
import SwiftData

@Observable
@MainActor
final class WatchSyncManager: NSObject, WCSessionDelegate, Sendable {
    static let shared = WatchSyncManager()
    var isReachable: Bool = false
    
    // Ссылка на контекст для сохранения пришедших данных
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
    
    // Запрос пресетов у телефона
    func requestPresetsFromPhone() {
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(["request": "presets"], replyHandler: nil)
        }
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        Task { @MainActor in self.isReachable = session.isReachable }
    }
    
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in self.isReachable = session.isReachable }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        Task { @MainActor in
            // 1. Обработка живых событий (сеты, старт)
            if let data = message["syncPayload"] as? Data,
               let payload = try? JSONDecoder().decode(LiveSyncPayload.self, from: data) {
                NotificationCenter.default.post(name: NSNotification.Name("LiveWorkoutSyncEvent"), object: nil, userInfo: ["payload": payload])
            }
            
            // 2. Получение пресетов от телефона
            if let presetsData = message["presetsBatch"] as? Data,
               let dtos = try? JSONDecoder().decode([WorkoutPresetDTO].self, from: presetsData) {
                await self.savePresetsLocally(dtos)
            }
        }
    }

    private func savePresetsLocally(_ dtos: [WorkoutPresetDTO]) async {
        guard let context = modelContext else { return }
        
        // Удаляем старые, чтобы не дублировать (простой способ синхронизации без iCloud)
        let fetchDescriptor = FetchDescriptor<WorkoutPreset>()
        if let existing = try? context.fetch(fetchDescriptor) {
            for p in existing { context.delete(p) }
        }
        
        // Вставляем новые
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
