//
//  RemoteConfigManager.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 26.04.26.
//

import Foundation
import OSLog
import FirebaseRemoteConfig

actor RemoteConfigManager: Sendable {
    static let shared = RemoteConfigManager()
    private let remoteConfig = RemoteConfig.remoteConfig()
    
   
    private var cachedPersonas: [AIPersona] = []

    private init() {
        let settings = RemoteConfigSettings()
        #if DEBUG
        // Allow frequent refresh in DEBUG without hammering Remote Config (I13).
        settings.minimumFetchInterval = 60
        #else
        settings.minimumFetchInterval = 3600
        #endif
        remoteConfig.configSettings = settings
    }

    func fetchCloudValues() async {
        do {
            let status = try await remoteConfig.fetchAndActivate()
            #if DEBUG
            if status == .successFetchedFromRemote {
                AppLog.remoteConfig.info("☁️✅ Remote Config: Fresh data downloaded from the cloud!")
            }
            #endif
            
            let showPromo = Self.isSisterAppsPromoEnabled(remoteConfig: remoteConfig, getString: getString(forKey:))
            if let sharedDefaults = UserDefaults(suiteName: "group.com.borisdev.WorkoutTracker") {
                sharedDefaults.set(showPromo, forKey: "show_foodtracker_promo_enabled")
            }
        
            let jsonString = remoteConfig.configValue(forKey: "ai_personas_config").stringValue
            if let data = jsonString.data(using: .utf8),
               let config = try? JSONDecoder().decode(AIPersonasConfig.self, from: data) {
                self.cachedPersonas = config.personas
            }
            
        } catch {
            AppLog.remoteConfig.error("☁️❌ Error Remote Config: \(error.localizedDescription)")
        }
    }

    func getString(forKey key: String) -> String {
        return remoteConfig.configValue(forKey: key).stringValue
    }
    
    var minimumAppVersion: String {
        return getString(forKey: "minimum_ios_version")
    }
    
    var recommendedAppVersion: String {
        return getString(forKey: "recommended_ios_version")
    }

    var showFoodTrackerPromo: Bool {
        showSisterAppsPromo
    }

    /// Legacy `show_foodtracker_promo` OR `show_sister_apps_promo`.
    var showSisterAppsPromo: Bool {
        Self.isSisterAppsPromoEnabled(remoteConfig: remoteConfig, getString: getString(forKey:))
    }

    private static func isSisterAppsPromoEnabled(
        remoteConfig: RemoteConfig,
        getString: (String) -> String
    ) -> Bool {
        let food = remoteConfig.configValue(forKey: "show_foodtracker_promo").boolValue ||
            getString("show_foodtracker_promo") == "1"
        let sister = remoteConfig.configValue(forKey: "show_sister_apps_promo").boolValue ||
            getString("show_sister_apps_promo") == "1"
        return food || sister
    }

    func getAllPersonas() -> [AIPersona] {
        return cachedPersonas
    }
    
    func getPersona(id: String) -> AIPersona? {
        return cachedPersonas.first(where: { $0.id == id }) ?? cachedPersonas.first
    }
}
