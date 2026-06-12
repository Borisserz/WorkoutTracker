//
//  VersionManager.swift
//  WorkoutTracker
//

import Foundation
internal import SwiftUI
import Combine

@MainActor
@Observable
final class VersionManager {
    static let shared = VersionManager()
    
    var updateRequirement: UpdateRequirement = .noUpdate
    var hasDismissedSoftUpdate: Bool = false
    
    enum UpdateRequirement: Equatable {
        case hardUpdate
        case softUpdate
        case noUpdate
    }
    
    private init() {}
    
    func checkForUpdates() async {
        #if DEBUG || targetEnvironment(simulator)
        // Bypass force updates in developer / simulator environment
        self.updateRequirement = .noUpdate
        #else
        let minVersion = await RemoteConfigManager.shared.minimumAppVersion
        let recVersion = await RemoteConfigManager.shared.recommendedAppVersion
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        
        let newRequirement = evaluateRequirement(current: currentVersion, minimum: minVersion, recommended: recVersion)
        
        if newRequirement != self.updateRequirement {
            self.updateRequirement = newRequirement
        }
        #endif
    }
    
    private func evaluateRequirement(current: String, minimum: String, recommended: String) -> UpdateRequirement {
        if !minimum.isEmpty && isVersion(current, lessThan: minimum) {
            return .hardUpdate
        }
        
        if !recommended.isEmpty && isVersion(current, lessThan: recommended) {
            return .softUpdate
        }
        
        return .noUpdate
    }
    
    /// Compares two semantic version strings like "1.2.0" and "1.3". 
    /// Returns true if v1 is strictly less than v2.
    private func isVersion(_ v1: String, lessThan v2: String) -> Bool {
        let v1Components = v1.split(separator: ".").compactMap { Int($0) }
        let v2Components = v2.split(separator: ".").compactMap { Int($0) }
        
        let maxCount = max(v1Components.count, v2Components.count)
        
        for i in 0..<maxCount {
            let c1 = i < v1Components.count ? v1Components[i] : 0
            let c2 = i < v2Components.count ? v2Components[i] : 0
            
            if c1 < c2 { return true }
            if c1 > c2 { return false }
        }
        
        return false
    }
}
