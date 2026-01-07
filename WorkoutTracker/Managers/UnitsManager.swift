//
//  UnitsManager.swift
//  WorkoutTracker
//
//  Менеджер для управления единицами измерения веса (кг/фунты)
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

class UnitsManager: ObservableObject {
    static let shared = UnitsManager()
    
    @Published private(set) var weightUnit: WeightUnit {
        didSet {
            UserDefaults.standard.set(weightUnit.rawValue, forKey: "weightUnit")
        }
    }
    
    private init() {
        if let saved = UserDefaults.standard.string(forKey: "weightUnit"),
           let unit = WeightUnit(rawValue: saved) {
            self.weightUnit = unit
        } else {
            self.weightUnit = .kilograms
        }
    }
    
    func setWeightUnit(_ unit: WeightUnit) {
        weightUnit = unit
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
}

