//
//  WeightTrackingManager.swift
//  WorkoutTracker
//
//  Менеджер для отслеживания истории веса пользователя
//

import Foundation
import Combine

class WeightTrackingManager: ObservableObject {
    
    // MARK: - Singleton
    static let shared = WeightTrackingManager()
    
    // Закрытый инициализатор
    private init() {
        loadWeightHistory()
    }
    
    // MARK: - Published Properties
    
    @Published var weightHistory: [WeightEntry] = [] {
        didSet {
            saveWeightHistory()
        }
    }
    
    // MARK: - Constants
    
    private let fileName = "weight_history.json"
    
    // MARK: - Path Helpers
    
    /// Получает URL директории документов пользователя
    private func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
    
    /// Возвращает полный путь к файлу хранения истории веса
    private var weightHistoryFileURL: URL {
        return getDocumentsDirectory().appendingPathComponent(fileName)
    }
    
    // MARK: - Public Methods
    
    /// Добавляет новую запись веса
    /// - Parameters:
    ///   - weight: Вес в килограммах
    ///   - date: Дата записи (по умолчанию текущая дата)
    func addWeightEntry(weight: Double, date: Date = Date()) {
        // Удаляем запись за этот же день, если она существует
        let calendar = Calendar.current
        weightHistory.removeAll { entry in
            calendar.isDate(entry.date, inSameDayAs: date)
        }
        
        // Добавляем новую запись
        let entry = WeightEntry(date: date, weight: weight)
        weightHistory.append(entry)
        
        // Сортируем по дате (от старых к новым)
        weightHistory.sort { $0.date < $1.date }
        
        // ИСПРАВЛЕНИЕ: Синхронизируем вес в профиле (@AppStorage) с последним актуальным весом
        if let latestWeight = weightHistory.last?.weight {
            UserDefaults.standard.set(latestWeight, forKey: "userBodyWeight")
        }
    }
    
    /// Удаляет запись веса
    /// - Parameter entry: Запись для удаления
    func deleteWeightEntry(_ entry: WeightEntry) {
        weightHistory.removeAll { $0.id == entry.id }
        
        // ИСПРАВЛЕНИЕ: Обновляем вес в профиле после удаления записи
        if let latestWeight = weightHistory.last?.weight {
            UserDefaults.standard.set(latestWeight, forKey: "userBodyWeight")
        }
    }
    
    /// Получает последний записанный вес
    /// - Returns: Последний вес или nil, если записей нет
    func getLatestWeight() -> Double? {
        return weightHistory.last?.weight
    }
    
    /// Получает вес за определенный период
    /// - Parameters:
    ///   - days: Количество дней назад
    /// - Returns: Массив записей за период
    func getWeightHistory(days: Int) -> [WeightEntry] {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return weightHistory.filter { $0.date >= cutoffDate }
    }
    
    /// Получает статистику изменения веса
    /// - Returns: Кортеж (начальный вес, текущий вес, изменение)
    func getWeightStats() -> (startWeight: Double?, currentWeight: Double?, change: Double?) {
        guard !weightHistory.isEmpty else {
            return (nil, nil, nil)
        }
        
        let startWeight = weightHistory.first?.weight
        let currentWeight = weightHistory.last?.weight
        
        let change: Double?
        if let start = startWeight, let current = currentWeight {
            change = current - start
        } else {
            change = nil
        }
        
        return (startWeight, currentWeight, change)
    }
    
    /// Инициализирует первый вес из профиля, если истории веса еще нет
    /// - Parameter profileWeight: Вес из профиля пользователя (в килограммах)
    func initializeFirstWeightIfNeeded(from profileWeight: Double) {
        // Проверяем, есть ли уже записи в истории
        guard weightHistory.isEmpty else {
            return
        }
        
        // Проверяем, что вес в профиле валидный (больше 0)
        guard profileWeight > 0 else {
            return
        }
        
        // Добавляем первый вес с текущей датой как начальную точку отслеживания
        addWeightEntry(weight: profileWeight, date: Date())
    }
    
    // MARK: - Private Methods
    
    /// Сохраняет историю веса в файл
    private func saveWeightHistory() {
        let url = weightHistoryFileURL
        
        do {
            let data = try JSONEncoder().encode(weightHistory)
            try data.write(to: url)
        } catch {
            print("Ошибка сохранения истории веса: \(error)")
        }
    }
    
    /// Загружает историю веса из файла
    private func loadWeightHistory() {
        let url = weightHistoryFileURL
        
        // Проверяем, существует ли файл
        guard FileManager.default.fileExists(atPath: url.path) else {
            // Файл не существует - это нормально при первом запуске
            weightHistory = []
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            weightHistory = try JSONDecoder().decode([WeightEntry].self, from: data)
            
            // Сортируем по дате
            weightHistory.sort { $0.date < $1.date }
        } catch {
            print("Ошибка загрузки истории веса: \(error)")
            weightHistory = []
        }
    }
}

