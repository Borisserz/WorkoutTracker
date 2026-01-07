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
    /// - Parameters:
    ///   - workouts: Список тренировок для сохранения
    ///   - onError: Callback для обработки ошибок (опционально)
    func saveWorkouts(_ workouts: [Workout], onError: ((Error) -> Void)? = nil) {
        let url = workoutsFileURL
        
        do {
            let data = try JSONEncoder().encode(workouts)
            try data.write(to: url)
        } catch {
            onError?(error)
        }
    }
    
    /// Загружает массив тренировок из файла
    /// - Parameter onComplete: Callback с результатом загрузки (Result<[Workout], Error>)
    func loadWorkouts(onComplete: @escaping (Result<[Workout], Error>) -> Void) {
        let url = workoutsFileURL
        
        // Проверяем, существует ли файл
        guard FileManager.default.fileExists(atPath: url.path) else {
            // Файл не существует - это нормально при первом запуске
            onComplete(.success([]))
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            let workouts = try JSONDecoder().decode([Workout].self, from: data)
            onComplete(.success(workouts))
        } catch {
            // Ошибка декодирования - файл поврежден
            onComplete(.failure(error))
        }
    }
    
    // MARK: - Export
    
    /// Структура для экспорта всех данных приложения
    struct ExportData: Codable {
        let version: String
        let exportDate: Date
        let workouts: [Workout]
        let weightHistory: [WeightEntry]
        let customExercises: [CustomExerciseDefinition]
        let presets: [WorkoutPreset]
        let progress: ProgressData
        let exerciseNotes: [String: String]
        let deletedDefaultExercises: [String]
        
        struct ProgressData: Codable {
            let level: Int
            let totalXP: Int
        }
    }
    
    /// Экспортирует все данные приложения в JSON файл
    /// - Parameters:
    ///   - workouts: Список тренировок
    ///   - viewModel: ViewModel для доступа к другим данным
    /// - Returns: URL временного файла с экспортированными данными или nil в случае ошибки
    func exportAllData(workouts: [Workout], viewModel: WorkoutViewModel) -> URL? {
        // Собираем все данные
        let weightHistory = WeightTrackingManager.shared.weightHistory
        let customExercises = viewModel.customExercises
        let presets = viewModel.presets
        let progress = ExportData.ProgressData(
            level: viewModel.progressManager.level,
            totalXP: viewModel.progressManager.totalXP
        )
        let exerciseNotes = ExerciseNotesManager.shared.notes
        let deletedDefaultExercises = Array(viewModel.deletedDefaultExercises)
        
        // Версия приложения
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        
        // Создаем структуру экспорта
        let exportData = ExportData(
            version: appVersion,
            exportDate: Date(),
            workouts: workouts,
            weightHistory: weightHistory,
            customExercises: customExercises,
            presets: presets,
            progress: progress,
            exerciseNotes: exerciseNotes,
            deletedDefaultExercises: deletedDefaultExercises
        )
        
        // Кодируем в JSON
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let jsonData = try encoder.encode(exportData)
            
            // Создаем временный файл
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
            let fileName = "WorkoutTracker_Export_\(dateFormatter.string(from: Date())).json"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            
            try jsonData.write(to: tempURL)
            
            return tempURL
        } catch {
            print("Ошибка экспорта данных: \(error)")
            return nil
        }
    }
    
    /// Экспортирует все данные приложения в CSV файл
    /// - Parameters:
    ///   - workouts: Список тренировок
    ///   - viewModel: ViewModel для доступа к другим данным
    /// - Returns: URL временного файла с экспортированными данными или nil в случае ошибки
    func exportAllDataToCSV(workouts: [Workout], viewModel: WorkoutViewModel) -> URL? {
        var csvLines: [String] = []
        
        // Заголовок с метаданными
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        
        csvLines.append("# WorkoutTracker Export")
        csvLines.append("# Version: \(appVersion)")
        csvLines.append("# Export Date: \(dateFormatter.string(from: Date()))")
        csvLines.append("")
        
        // 1. Тренировки
        csvLines.append("## WORKOUTS")
        csvLines.append("Workout ID,Title,Date,End Time,Duration (min),Icon,Is Favorite,Exercise Count")
        
        for workout in workouts {
            let workoutDate = dateFormatter.string(from: workout.date)
            let endTimeStr = workout.endTime != nil ? dateFormatter.string(from: workout.endTime!) : ""
            let duration = workout.duration
            let exerciseCount = workout.exercises.count
            
            csvLines.append("\(workout.id.uuidString),\"\(escapeCSV(workout.title))\",\(workoutDate),\(endTimeStr),\(duration),\(workout.icon),\(workout.isFavorite),\(exerciseCount)")
        }
        csvLines.append("")
        
        // 2. Упражнения
        csvLines.append("## EXERCISES")
        csvLines.append("Exercise ID,Workout ID,Workout Title,Exercise Name,Muscle Group,Type,Effort,Is Completed,Set Count")
        
        for workout in workouts {
            for exercise in workout.exercises {
                csvLines.append("\(exercise.id.uuidString),\(workout.id.uuidString),\"\(escapeCSV(workout.title))\",\"\(escapeCSV(exercise.name))\",\(exercise.muscleGroup),\(exercise.type.rawValue),\(exercise.effort),\(exercise.isCompleted),\(exercise.setsList.count)")
            }
        }
        csvLines.append("")
        
        // 3. Сеты
        csvLines.append("## SETS")
        csvLines.append("Set ID,Exercise ID,Exercise Name,Set Index,Weight,Reps,Distance (km),Time (sec),Is Completed,Set Type")
        
        for workout in workouts {
            for exercise in workout.exercises {
                for set in exercise.setsList {
                    let weightStr = set.weight != nil ? String(set.weight!) : ""
                    let repsStr = set.reps != nil ? String(set.reps!) : ""
                    let distanceStr = set.distance != nil ? String(set.distance!) : ""
                    let timeStr = set.time != nil ? String(set.time!) : ""
                    
                    csvLines.append("\(set.id.uuidString),\(exercise.id.uuidString),\"\(escapeCSV(exercise.name))\",\(set.index),\(weightStr),\(repsStr),\(distanceStr),\(timeStr),\(set.isCompleted),\(set.type.rawValue)")
                }
            }
        }
        csvLines.append("")
        
        // 4. История веса
        csvLines.append("## WEIGHT HISTORY")
        csvLines.append("Entry ID,Date,Weight (kg)")
        
        let weightHistory = WeightTrackingManager.shared.weightHistory
        for entry in weightHistory {
            let entryDate = dateFormatter.string(from: entry.date)
            csvLines.append("\(entry.id.uuidString),\(entryDate),\(entry.weight)")
        }
        csvLines.append("")
        
        // 5. Пользовательские упражнения
        csvLines.append("## CUSTOM EXERCISES")
        csvLines.append("Exercise ID,Name,Category,Targeted Muscles,Type")
        
        let customExercises = viewModel.customExercises
        for exercise in customExercises {
            let muscles = exercise.targetedMuscles.joined(separator: ";")
            csvLines.append("\(exercise.id.uuidString),\"\(escapeCSV(exercise.name))\",\(exercise.category),\"\(escapeCSV(muscles))\",\(exercise.type.rawValue)")
        }
        csvLines.append("")
        
        // 6. Шаблоны тренировок
        csvLines.append("## PRESETS")
        csvLines.append("Preset ID,Name,Icon,Exercise Count")
        
        let presets = viewModel.presets
        for preset in presets {
            csvLines.append("\(preset.id.uuidString),\"\(escapeCSV(preset.name))\",\(preset.icon),\(preset.exercises.count)")
        }
        csvLines.append("")
        
        // 7. Прогресс
        csvLines.append("## PROGRESS")
        csvLines.append("Level,Total XP")
        
        csvLines.append("\(viewModel.progressManager.level),\(viewModel.progressManager.totalXP)")
        csvLines.append("")
        
        // 8. Заметки к упражнениям
        csvLines.append("## EXERCISE NOTES")
        csvLines.append("Exercise Name,Note")
        
        let exerciseNotes = ExerciseNotesManager.shared.notes
        for (exerciseName, note) in exerciseNotes {
            csvLines.append("\"\(escapeCSV(exerciseName))\",\"\(escapeCSV(note))\"")
        }
        
        // Создаем CSV файл
        do {
            let csvContent = csvLines.joined(separator: "\n")
            guard let csvData = csvContent.data(using: .utf8) else {
                return nil
            }
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
            let fileName = "WorkoutTracker_Export_\(dateFormatter.string(from: Date())).csv"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            
            try csvData.write(to: tempURL)
            
            return tempURL
        } catch {
            print("Ошибка экспорта данных в CSV: \(error)")
            return nil
        }
    }
    
    /// Экранирует специальные символы для CSV
    private func escapeCSV(_ string: String) -> String {
        // Если строка содержит запятую, кавычки или перенос строки, оборачиваем в кавычки
        if string.contains(",") || string.contains("\"") || string.contains("\n") {
            // Экранируем кавычки удвоением
            return string.replacingOccurrences(of: "\"", with: "\"\"")
        }
        return string
    }
}
