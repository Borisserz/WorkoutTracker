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
    
    // MARK: - Caches
    
    private var cachedDateFormatters: [String: DateFormatter] = [:]
    private let cacheLock = NSLock()
    
    // MARK: - Init
    
    private init() {}
    
    // MARK: - Date Formatting
    
    /// Форматирует дату с названием дня недели и словом "Workout"
    /// Например: "Monday Workout" или "Понедельник Workout"
    func formatWorkoutDateName(_ date: Date = Date()) -> String {
        // Используем потокобезопасный и быстрый API FormatStyle
        let dayName = date.formatted(.dateTime.weekday(.wide))
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
        return value.formatted(.number.precision(.fractionLength(1)))
    }
    
    /// Форматирует число с двумя знаками после запятой (0.12)
    func formatTwoDecimals(_ value: Double) -> String {
        return value.formatted(.number.precision(.fractionLength(2)))
    }
    
    /// Форматирует число как целое (без дробной части)
    func formatInteger(_ value: Double) -> String {
        return value.formatted(.number.precision(.fractionLength(0)))
    }
    
    /// Форматирует число с указанным количеством знаков после запятой
    func formatNumber(_ value: Double, fractionDigits: Int) -> String {
        return value.formatted(.number.precision(.fractionLength(fractionDigits)))
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

