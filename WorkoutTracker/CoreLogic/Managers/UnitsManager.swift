

import Foundation
internal import SwiftUI
import Observation

enum WeightUnit: String, Codable, CaseIterable {
    case kilograms = "kg"
    case pounds = "lbs"
    var displayName: LocalizedStringKey { self == .kilograms ? "Kilograms (kg)" : "Pounds (lbs)" }
    var shortName: String { self.rawValue }
}

enum DistanceUnit: String, Codable, CaseIterable {
    case meters = "m"
    case miles = "mi"

    var displayName: LocalizedStringKey { self == .meters ? "Meters (m)" : "Miles (mi)" }
    var shortName: String { self.rawValue }
}

enum SizeUnit: String, Codable, CaseIterable {
    case centimeters = "cm"
    case inches = "in"

    var displayName: LocalizedStringKey { self == .centimeters ? "Centimeters (cm)" : "Inches (in)" }
    var shortName: String { self.rawValue }
}

@Observable
final class UnitsManager: @unchecked Sendable {
    nonisolated static let shared = UnitsManager()

    private(set) var weightUnit: WeightUnit {
        didSet { UserDefaults.standard.set(weightUnit.rawValue, forKey: "weightUnit") }
    }

    private(set) var distanceUnit: DistanceUnit {
        didSet { UserDefaults.standard.set(distanceUnit.rawValue, forKey: "distanceUnit") }
    }

    private(set) var sizeUnit: SizeUnit {
        didSet { UserDefaults.standard.set(sizeUnit.rawValue, forKey: "sizeUnit") }
    }

    private init() {
        if let saved = UserDefaults.standard.string(forKey: "weightUnit"), let unit = WeightUnit(rawValue: saved) {
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

        if let savedSize = UserDefaults.standard.string(forKey: "sizeUnit"), let sUnit = SizeUnit(rawValue: savedSize) {
            self.sizeUnit = sUnit
        } else {
            self.sizeUnit = .centimeters
        }
    }

    func setWeightUnit(_ unit: WeightUnit) { weightUnit = unit }
    func setDistanceUnit(_ unit: DistanceUnit) { distanceUnit = unit }
    func setSizeUnit(_ unit: SizeUnit) { sizeUnit = unit }

    nonisolated func convertFromKilograms(_ kg: Double) -> Double { weightUnit == .kilograms ? kg : kg * 2.20462 }
    nonisolated func convertToKilograms(_ value: Double) -> Double { weightUnit == .kilograms ? value : value / 2.20462 }
    nonisolated func formatWeight(_ kg: Double) -> String { LocalizationHelper.shared.formatDecimal(convertFromKilograms(kg)) }
    nonisolated func weightUnitString() -> String { weightUnit.shortName }

    nonisolated func convertFromMeters(_ m: Double) -> Double { distanceUnit == .meters ? m : m * 0.000621371 }
    nonisolated func convertToMeters(_ value: Double) -> Double { distanceUnit == .meters ? value : value / 0.000621371 }
    nonisolated func formatDistance(_ m: Double) -> String { LocalizationHelper.shared.formatDecimal(convertFromMeters(m)) }
    nonisolated func distanceUnitString() -> String { distanceUnit.shortName }

    nonisolated func convertFromCentimeters(_ cm: Double) -> Double { sizeUnit == .centimeters ? cm : cm / 2.54 }
    nonisolated func convertToCentimeters(_ value: Double) -> Double { sizeUnit == .centimeters ? value : value * 2.54 }
    nonisolated func formatSize(_ cm: Double) -> String { LocalizationHelper.shared.formatDecimal(convertFromCentimeters(cm)) }
    nonisolated func sizeUnitString() -> String { sizeUnit.shortName }

    nonisolated func displayWeightWithUnit(forKg kg: Double) -> String {
        "\(LocalizationHelper.shared.formatFlexible(convertFromKilograms(kg))) \(weightUnitString())"
    }

    nonisolated func displayDistanceWithUnit(forMeters m: Double) -> String {
        "\(LocalizationHelper.shared.formatTwoDecimals(convertFromMeters(m))) \(distanceUnitString())"
    }
}
