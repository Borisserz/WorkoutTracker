//
//  RemoteConfigManager.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 26.04.26.
//

import Foundation
import FirebaseRemoteConfig

actor RemoteConfigManager: Sendable {
    static let shared = RemoteConfigManager()
    private let remoteConfig = RemoteConfig.remoteConfig()
    
   
    private var cachedPersonas: [AIPersona] = []

    private init() {
        let settings = RemoteConfigSettings()
        #if DEBUG
        settings.minimumFetchInterval = 0
        #else
        settings.minimumFetchInterval = 3600
        #endif
        remoteConfig.configSettings = settings
    }

    func fetchCloudValues() async {
        do {
            let status = try await remoteConfig.fetchAndActivate()
            if status == .successFetchedFromRemote {
                print("☁️✅ Remote Config: Свежие данные загружены из облака!")
            }
        
            let jsonString = remoteConfig.configValue(forKey: "ai_personas_config").stringValue ?? ""
            if let data = jsonString.data(using: .utf8),
               let config = try? JSONDecoder().decode(AIPersonasConfig.self, from: data) {
                self.cachedPersonas = config.personas
            }
            
        } catch {
            print("☁️❌ Ошибка Remote Config: \(error.localizedDescription)")
        }
    }

    func getString(forKey key: String) -> String {
        return remoteConfig.configValue(forKey: key).stringValue ?? ""
    }
    
    // Новые методы для получения персон
    func getAllPersonas() -> [AIPersona] {
        return cachedPersonas
    }
    
    func getPersona(id: String) -> AIPersona? {
        return cachedPersonas.first(where: { $0.id == id }) ?? cachedPersonas.first
    }
}
