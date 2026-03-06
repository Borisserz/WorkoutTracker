//
//  UnitsManager.swift
//  WorkoutTracker
//
//  Менеджер для управления единицами измерения веса (кг/фунты) и расстояния (км/мили)
//

import Foundation
import Combine

enum WeightUnit: String, Codable, CaseIterable {
    case kilograms = "kg"
    case pounds = "lbs"
    
    var displayName: String {
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
    case kilometers = "km"
    case miles = "mi"
    
    var displayName: String {
        switch self {
        case .kilometers: return "Kilometers (km)"
        case .miles: return "Miles (mi)"
        }
    }
    
    var shortName: String {
        return self.rawValue
    }
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
    
    private init() {
        if let saved = UserDefaults.standard.string(forKey: "weightUnit"),
           let unit = WeightUnit(rawValue: saved) {
            self.weightUnit = unit
        } else {
            self.weightUnit = .kilograms
        }
        
        if let savedDist = UserDefaults.standard.string(forKey: "distanceUnit"),
           let dUnit = DistanceUnit(rawValue: savedDist) {
            self.distanceUnit = dUnit
        } else {
            self.distanceUnit = .kilometers
        }
    }
    
    func setWeightUnit(_ unit: WeightUnit) {
        weightUnit = unit
    }
    
    func setDistanceUnit(_ unit: DistanceUnit) {
        distanceUnit = unit
    }
    
    // Конвертация из кг в выбранные единицы (для отображения)
    func convertFromKilograms(_ kg: Double) -> Double {
        switch weightUnit {
        case .kilograms:
            return kg
        case .pounds:
            return kg * 2.20462
        }
    }
    
    // Конвертация в кг из выбранных единиц (для сохранения)
    func convertToKilograms(_ value: Double) -> Double {
        switch weightUnit {
        case .kilograms:
            return value
        case .pounds:
            return value / 2.20462
        }
    }
    
    // Форматирование веса для отображения
    func formatWeight(_ kg: Double) -> String {
        let converted = convertFromKilograms(kg)
        return LocalizationHelper.shared.formatDecimal(converted)
    }
    
    // Получить единицу измерения для отображения
    func weightUnitString() -> String {
        return weightUnit.shortName
    }
    
    // Конвертация из км в выбранные единицы
    func convertFromKilometers(_ km: Double) -> Double {
        switch distanceUnit {
        case .kilometers:
            return km
        case .miles:
            return km * 0.621371
        }
    }
    
    // Конвертация в км из выбранных единиц
    func convertToKilometers(_ value: Double) -> Double {
        switch distanceUnit {
        case .kilometers:
            return value
        case .miles:
            return value / 0.621371
        }
    }
    
    // Форматирование расстояния
    func formatDistance(_ km: Double) -> String {
        let converted = convertFromKilometers(km)
        return LocalizationHelper.shared.formatDecimal(converted)
    }
    
    func distanceUnitString() -> String {
        return distanceUnit.shortName
    }
}

