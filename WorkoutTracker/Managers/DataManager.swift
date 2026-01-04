//
//  DataManager.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 24.12.25.
//
//  Менеджер данных.
//  Отвечает за персистентное хранение (сохранение и загрузку) истории тренировок
//  в файловую систему (JSON) в папке Documents.
//

import Foundation

class DataManager {
    
    // MARK: - Singleton
    static let shared = DataManager()
    
    // Закрытый инициализатор, чтобы нельзя было создать экземпляр извне
    private init() {}
    
    // MARK: - Constants
    private let fileName = "workouts.json"
    
    // MARK: - Path Helpers
    
    /// Получает URL директории документов пользователя
    private func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
    
    /// Возвращает полный путь к файлу хранения данных
    private var workoutsFileURL: URL {
        return getDocumentsDirectory().appendingPathComponent(fileName)
    }
    
    // MARK: - Public Methods
    
    /// Сохраняет массив тренировок в JSON файл
    /// - Parameter workouts: Список тренировок для сохранения
    func saveWorkouts(_ workouts: [Workout]) {
        let url = workoutsFileURL
        
        do {
            let data = try JSONEncoder().encode(workouts)
            try data.write(to: url)
            // print("✅ Workouts saved successfully.") // Можно раскомментировать для отладки
        } catch {
            print("❌ Error saving workouts: \(error.localizedDescription)")
        }
    }
    
    /// Загружает массив тренировок из файла
    /// - Returns: Массив `Workout` или пустой массив, если файл не найден/поврежден
    func loadWorkouts() -> [Workout] {
        let url = workoutsFileURL
        
        do {
            let data = try Data(contentsOf: url)
            let workouts = try JSONDecoder().decode([Workout].self, from: data)
            return workouts
        } catch {
            // Ошибка здесь нормальна при первом запуске (файла еще нет)
            // print("⚠️ Workouts load warning: \(error.localizedDescription)")
            return []
        }
    }
}
