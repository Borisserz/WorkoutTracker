import Foundation

/// Canonical body metrics live in UserDefaults (kg and cm). A missing key is unset, not a default body.
enum BodyMetricStore {
    static let heightKey = "userHeight"

    static func weightKilograms(in defaults: UserDefaults = .standard) -> Double? {
        guard defaults.object(forKey: Constants.UserDefaultsKeys.userBodyWeight.rawValue) != nil else { return nil }
        let value = defaults.double(forKey: Constants.UserDefaultsKeys.userBodyWeight.rawValue)
        return value > 10 ? value : nil
    }

    static func heightCentimeters(in defaults: UserDefaults = .standard) -> Double? {
        guard let object = defaults.object(forKey: heightKey) else { return nil }
        let value: Double
        if let number = object as? NSNumber {
            value = number.doubleValue
        } else {
            return nil
        }
        return value > 0 ? value : nil
    }
}

enum ProfileMetricsFormatter {
    static let unset = "—"

    static func weight(storedKg: Double?, unit: WeightUnit) -> (value: String, unit: String) {
        guard let storedKg else { return (unset, "") }
        let shown = unit == .kilograms ? storedKg : storedKg * 2.20462
        return (String(format: "%.1f", shown), unit.shortName)
    }

    static func height(storedCm: Double?, unit: SizeUnit) -> (value: String, unit: String) {
        guard let storedCm else { return (unset, "") }
        let shown = unit == .centimeters ? storedCm : storedCm / 2.54
        let rounded = shown.rounded()
        return (String(format: "%.0f", rounded), unit.shortName)
    }
}

/// Cardio fields are minutes on screen and seconds in storage. Duration fields are seconds both ways.
enum SetTimeField {
    case minutes
    case seconds
}

enum SetTimeCodec {
    static func storedSeconds(fromDisplay value: Double, field: SetTimeField) -> Int {
        let raw = field == .minutes ? Int((value * 60).rounded()) : Int(value.rounded())
        return InputValidator.validateTime(raw).clampedValue
    }

    static func displayValue(fromStoredSeconds seconds: Int, field: SetTimeField) -> Double {
        field == .minutes ? Double(seconds) / 60.0 : Double(seconds)
    }
}
