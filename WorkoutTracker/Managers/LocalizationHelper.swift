//
//  LocalizationHelper.swift
//  WorkoutTracker
//
//  Helper для локализованного форматирования дат и чисел
//  Обеспечивает правильное форматирование с учетом текущей локали пользователя
//

import Foundation

class LocalizationHelper {
    
    // MARK: - Singleton
    static let shared = LocalizationHelper()
    
    // MARK: - Private Formatters
    
    private lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        return formatter
    }()
    
    private lazy var numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale.current
        formatter.numberStyle = .decimal
        return formatter
    }()
    
    private lazy var decimalFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale.current
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        return formatter
    }()
    
    private lazy var twoDecimalFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale.current
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()
    
    private lazy var integerFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale.current
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }()
    
    // MARK: - Caches
    
    private var cachedDateFormatters: [String: DateFormatter] = [:]
    private var cachedNumberFormatters: [Int: NumberFormatter] = [:]
    private let cacheLock = NSLock()
    
    // MARK: - Init
    
    private init() {}
    
    // MARK: - Date Formatting
    
    /// Форматирует дату с названием дня недели и словом "Workout"
    /// Например: "Monday Workout" или "Понедельник Workout"
    func formatWorkoutDateName(_ date: Date = Date()) -> String {
        dateFormatter.dateFormat = "EEEE"
        let dayName = dateFormatter.string(from: date)
        return "\(dayName) Workout"
    }
    
    /// Создает или возвращает закэшированный DateFormatter с указанным форматом и текущей локалью
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
    
    // MARK: - Number Formatting
    
    /// Форматирует число с одним знаком после запятой (0.1)
    func formatDecimal(_ value: Double) -> String {
        return decimalFormatter.string(from: NSNumber(value: value)) ?? String(format: "%.1f", value)
    }
    
    /// Форматирует число с двумя знаками после запятой (0.12)
    func formatTwoDecimals(_ value: Double) -> String {
        return twoDecimalFormatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }
    
    /// Форматирует число как целое (без дробной части)
    func formatInteger(_ value: Double) -> String {
        return integerFormatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    }
    
    /// Форматирует число с указанным количеством знаков после запятой, используя кэшированный NumberFormatter
    func formatNumber(_ value: Double, fractionDigits: Int) -> String {
        let formatter: NumberFormatter
        
        cacheLock.lock()
        if let cached = cachedNumberFormatters[fractionDigits] {
            formatter = cached
            cacheLock.unlock()
        } else {
            formatter = NumberFormatter()
            formatter.locale = Locale.current
            formatter.numberStyle = .decimal
            formatter.minimumFractionDigits = fractionDigits
            formatter.maximumFractionDigits = fractionDigits
            
            cachedNumberFormatters[fractionDigits] = formatter
            cacheLock.unlock()
        }
        
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.\(fractionDigits)f", value)
    }
    
    /// Форматирует число с автоматическим выбором формата в зависимости от значения
    /// Для значений >= 1000: 1 знак после запятой
    /// Для значений >= 1: целое число
    /// Для значений < 1: 2 знака после запятой
    func formatSmart(_ value: Double) -> String {
        if value >= 1000 {
            return formatDecimal(value)
        } else if value >= 1 {
            return formatInteger(value)
        } else {
            return formatTwoDecimals(value)
        }
    }
    
    /// Форматирует число с возможностью показать как целое, если дробная часть равна 0
    func formatFlexible(_ value: Double, fractionDigits: Int = 1) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return formatInteger(value)
        } else {
            return formatNumber(value, fractionDigits: fractionDigits)
        }
    }
}

