//
//  UnitsManager.swift
//  WorkoutTracker
//
//  Менеджер для управления единицами измерения веса (кг/фунты) и расстояния (м/мили)
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
        
        if let savedDist = UserDefaults.standard.string(forKey: "distanceUnit") {
            // Миграция старых данных (если было km, ставим m)
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
    
    // Конвертация из метров в выбранные единицы
    func convertFromMeters(_ m: Double) -> Double {
        switch distanceUnit {
        case .meters:
            return m
        case .miles:
            return m * 0.000621371 // 1 метр = 0.000621371 мили
        }
    }
    
    // Конвертация в метры из выбранных единиц
    func convertToMeters(_ value: Double) -> Double {
        switch distanceUnit {
        case .meters:
            return value
        case .miles:
            return value / 0.000621371
        }
    }
    
    // Форматирование расстояния
    func formatDistance(_ m: Double) -> String {
        let converted = convertFromMeters(m)
        return LocalizationHelper.shared.formatDecimal(converted)
    }
    
    func distanceUnitString() -> String {
        return distanceUnit.shortName
    }
}

