//
//  PhoneWatchManager.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 11.04.26.
//

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
    
    // Ссылка на базу данных iPhone
    var modelContainer: ModelContainer?

    private override init() {
        super.init()
    }
    
    // Запуск сессии
    func start(with container: ModelContainer) {
        self.modelContainer = container
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }
    
    // MARK: - WCSessionDelegate
    
    nonisolated func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        print("📱 PhoneWatchManager: WCSession activated with state: \(state.rawValue)")
    }
    
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) { }
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    
    // 🎧 СЛУШАЕМ ЗАПРОСЫ ОТ ЧАСОВ
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        Task { @MainActor in
            if let request = message["request"] as? String, request == "presets" {
                print("📱 PhoneWatchManager: Received request for presets from Watch")
                self.sendPresetsToWatch()
            }
        }
    }
    
    // 📤 ОТПРАВЛЯЕМ ТРЕНИРОВКИ НА ЧАСЫ
    private func sendPresetsToWatch() {
        guard let container = modelContainer else { return }
        let context = ModelContext(container)
        
        do {
            // Берем только пользовательские тренировки (не системные)
            let descriptor = FetchDescriptor<WorkoutPreset>(predicate: #Predicate { $0.isSystem == false })
            let presets = try context.fetch(descriptor)
            
            // Превращаем в DTO (Data Transfer Object)
            let dtos = presets.map { $0.toDTO() }
            
            // Кодируем в JSON и отправляем
            let data = try JSONEncoder().encode(dtos)
            
            if WCSession.default.isReachable {
                WCSession.default.sendMessage(["presetsBatch": data], replyHandler: nil)
                print("📱 PhoneWatchManager: Sent \(presets.count) presets to Watch")
            } else {
                print("📱 PhoneWatchManager: Watch is not reachable right now.")
            }
            
        } catch {
            print("📱 PhoneWatchManager: Failed to fetch or encode presets: \(error)")
        }
    }
}
