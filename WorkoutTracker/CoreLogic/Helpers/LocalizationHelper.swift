

import Foundation

class LocalizationHelper {

     private var exerciseNamesRU: [String: String] = [:]
     private var exerciseInstructionsRU: [String: [String]] = [:]

     func setTranslations(names: [String: String], instructions: [String: [String]]) {
         cacheLock.lock()
         defer { cacheLock.unlock() }
         self.exerciseNamesRU = names
         self.exerciseInstructionsRU = instructions
     }

     func translateName(_ englishName: String) -> String {
         guard Locale.current.language.languageCode?.identifier == "ru" else { return englishName }
         cacheLock.lock()
         defer { cacheLock.unlock() }
         return exerciseNamesRU[englishName.lowercased()] ?? englishName
     }

     func translateInstructions(for englishName: String) -> [String]? {
         guard Locale.current.language.languageCode?.identifier == "ru" else { return nil }
         cacheLock.lock()
         defer { cacheLock.unlock() }
         return exerciseInstructionsRU[englishName.lowercased()]
     }

    static let shared = LocalizationHelper()

    private var cachedDateFormatters: [String: DateFormatter] = [:]
    private let cacheLock = NSLock()

    private init() {}

    func formatWorkoutDateName(_ date: Date = Date()) -> String {

        let dayName = date.formatted(.dateTime.weekday(.wide))
        return "\(dayName) Workout"
    }

    func createDateFormatter(format: String) -> DateFormatter {
        cacheLock.lock()
        defer { cacheLock.unlock() }

        if let formatter = cachedDateFormatters[format] {
            return formatter
        }

        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = format

        cachedDateFormatters[format] = formatter
        return formatter
    }

    func formatDecimal(_ value: Double) -> String {
        return value.formatted(.number.precision(.fractionLength(1)))
    }

    func formatTwoDecimals(_ value: Double) -> String {
        return value.formatted(.number.precision(.fractionLength(2)))
    }

    func formatInteger(_ value: Double) -> String {
        return value.formatted(.number.precision(.fractionLength(0)))
    }

    func formatNumber(_ value: Double, fractionDigits: Int) -> String {
        return value.formatted(.number.precision(.fractionLength(fractionDigits)))
    }

    func formatSmart(_ value: Double) -> String {
        if value >= 1000 {
            return formatDecimal(value)
        } else if value >= 1 {
            return formatInteger(value)
        } else {
            return formatTwoDecimals(value)
        }
    }

    func formatFlexible(_ value: Double, fractionDigits: Int = 1) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return formatInteger(value)
        } else {
            return formatNumber(value, fractionDigits: fractionDigits)
        }
    }
}

