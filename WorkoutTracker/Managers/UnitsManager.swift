//
//  UnitsManager.swift
//  WorkoutTracker
//

import Foundation
import Combine
internal import SwiftUI

enum WeightUnit: String, Codable, CaseIterable {
    case kilograms = "kg"
    case pounds = "lbs"
    
    var displayName: LocalizedStringKey {
        switch self {
        case .kilograms: return "Kilograms (kg)"
        case .pounds: return "Pounds (lbs)"
        }
    }
    
    var shortName: String {
        return self.rawValue
    }
}

enum DistanceUnit: String, Codable, CaseIterable {
    case meters = "m"
    case miles = "mi"
    
    var displayName: String {
        switch self {
        case .meters: return "Meters (m)"
        case .miles: return "Miles (mi)"
        }
    }
    
    var shortName: String {
        return self.rawValue
    }
}

// ДОБАВЛЕНО: Enum для размеров тела
enum SizeUnit: String, Codable, CaseIterable {
    case centimeters = "cm"
    case inches = "in"
    
    var displayName: String {
        switch self {
        case .centimeters: return "Centimeters (cm)"
        case .inches: return "Inches (in)"
        }
    }
    
    var shortName: String { return self.rawValue }
}

class UnitsManager: ObservableObject {
    static let shared = UnitsManager()
    
    @Published private(set) var weightUnit: WeightUnit {
        didSet {
            UserDefaults.standard.set(weightUnit.rawValue, forKey: "weightUnit")
        }
    }
    
    @Published private(set) var distanceUnit: DistanceUnit {
        didSet {
            UserDefaults.standard.set(distanceUnit.rawValue, forKey: "distanceUnit")
        }
    }
    
    // ДОБАВЛЕНО: Состояние для размеров тела
    @Published private(set) var sizeUnit: SizeUnit {
        didSet {
            UserDefaults.standard.set(sizeUnit.rawValue, forKey: "sizeUnit")
        }
    }
    
    private init() {
        if let saved = UserDefaults.standard.string(forKey: "weightUnit"),
           let unit = WeightUnit(rawValue: saved) {
            self.weightUnit = unit
        } else {
            self.weightUnit = .kilograms
        }
        
        if let savedDist = UserDefaults.standard.string(forKey: "distanceUnit") {
            if savedDist == "km" {
                self.distanceUnit = .meters
                UserDefaults.standard.set("m", forKey: "distanceUnit")
            } else if let dUnit = DistanceUnit(rawValue: savedDist) {
                self.distanceUnit = dUnit
            } else {
                self.distanceUnit = .meters
            }
        } else {
            self.distanceUnit = .meters
        }
        
        if let savedSize = UserDefaults.standard.string(forKey: "sizeUnit"),
           let sUnit = SizeUnit(rawValue: savedSize) {
            self.sizeUnit = sUnit
        } else {
            self.sizeUnit = .centimeters
        }
    }
    
    func setWeightUnit(_ unit: WeightUnit) { weightUnit = unit }
    func setDistanceUnit(_ unit: DistanceUnit) { distanceUnit = unit }
    func setSizeUnit(_ unit: SizeUnit) { sizeUnit = unit }
    
    // Weight logic
    func convertFromKilograms(_ kg: Double) -> Double {
        switch weightUnit {
        case .kilograms: return kg
        case .pounds: return kg * 2.20462
        }
    }
    
    func convertToKilograms(_ value: Double) -> Double {
        switch weightUnit {
        case .kilograms: return value
        case .pounds: return value / 2.20462
        }
    }
    
    func formatWeight(_ kg: Double) -> String {
        let converted = convertFromKilograms(kg)
        return LocalizationHelper.shared.formatDecimal(converted)
    }
    
    func weightUnitString() -> String { return weightUnit.shortName }
    
    // Distance logic
    func convertFromMeters(_ m: Double) -> Double {
        switch distanceUnit {
        case .meters: return m
        case .miles: return m * 0.000621371
        }
    }
    
    func convertToMeters(_ value: Double) -> Double {
        switch distanceUnit {
        case .meters: return value
        case .miles: return value / 0.000621371
        }
    }
    
    func formatDistance(_ m: Double) -> String {
        let converted = convertFromMeters(m)
        return LocalizationHelper.shared.formatDecimal(converted)
    }
    
    func distanceUnitString() -> String { return distanceUnit.shortName }
    
    // ДОБАВЛЕНО: Size logic
    func convertFromCentimeters(_ cm: Double) -> Double {
        switch sizeUnit {
        case .centimeters: return cm
        case .inches: return cm / 2.54
        }
    }
    
    func convertToCentimeters(_ value: Double) -> Double {
        switch sizeUnit {
        case .centimeters: return value
        case .inches: return value * 2.54
        }
    }
    
    func formatSize(_ cm: Double) -> String {
        let converted = convertFromCentimeters(cm)
        return LocalizationHelper.shared.formatDecimal(converted)
    }
    
    func sizeUnitString() -> String { return sizeUnit.shortName }
}
