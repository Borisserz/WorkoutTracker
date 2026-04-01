import Foundation

// 🎼 Убран @MainActor. Класс сделан final и Sendable, так как не имеет изменяемого состояния.
// Теперь сложные операции экспорта честно отрабатывают в фоновых потоках.
final class DataManager: Sendable {
    static let shared = DataManager()
    
    private init() {}
    
    // Заглушки, чтобы не ломать старые вызовы
    func saveWorkouts(_ workouts: [Workout], onError: ((Error) -> Void)? = nil) { }
    func loadWorkouts(onComplete: @escaping (Result<[Workout], Error>) -> Void) {
        onComplete(.success([]))
    }
    
    // MARK: - Export to JSON (Manual mapping for @Model objects)
    func exportAllDataAsJSON(workouts: [Workout]) -> URL? {
        // Поскольку объекты @Model не поддерживают Codable автоматически,
        // маппим их в обычные словари (DTO - Data Transfer Objects).
        let workoutsDictArray = workouts.map { workout -> [String: Any] in
            return [
                "id": workout.id.uuidString,
                "title": workout.title,
                "date": workout.date.timeIntervalSince1970,
                "endTime": workout.endTime?.timeIntervalSince1970 ?? NSNull(),
                "icon": workout.icon,
                "isFavorite": workout.isFavorite,
                "exercises": workout.exercises.map { exercise in
                    return [
                        "id": exercise.id.uuidString,
                        "name": exercise.name,
                        "muscleGroup": exercise.muscleGroup,
                        "type": exercise.type.rawValue,
                        "effort": exercise.effort,
                        "isCompleted": exercise.isCompleted,
                        "sets": exercise.setsList.map { set in
                            return [
                                "id": set.id.uuidString,
                                "index": set.index,
                                "weight": set.weight ?? NSNull(),
                                "reps": set.reps ?? NSNull(),
                                "distance": set.distance ?? NSNull(),
                                "time": set.time ?? NSNull(),
                                "isCompleted": set.isCompleted,
                                "type": set.type.rawValue
                            ]
                        }
                    ]
                }
            ]
        }
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: workoutsDictArray, options: .prettyPrinted)
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
            let fileName = "WorkoutTracker_Export_\(dateFormatter.string(from: Date())).json"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            try jsonData.write(to: tempURL)
            return tempURL
        } catch {
            print("Failed to encode JSON: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Export to CSV
    func exportAllDataToCSV(workouts: [Workout]) -> URL? {
        var csvLines: [String] = []
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        
        csvLines.append("# WorkoutTracker Export\n# Version: \(appVersion)\n# Export Date: \(dateFormatter.string(from: Date()))\n")
        
        // 1. Тренировки
        csvLines.append("## WORKOUTS\nWorkout ID,Title,Date,End Time,Duration (min),Icon,Is Favorite,Exercise Count")
        for workout in workouts {
            let workoutDate = dateFormatter.string(from: workout.date)
            let endTimeStr = workout.endTime != nil ? dateFormatter.string(from: workout.endTime!) : ""
            csvLines.append("\(workout.id.uuidString),\"\(escapeCSV(workout.title))\",\(workoutDate),\(endTimeStr),\(workout.durationSeconds / 60),\(workout.icon),\(workout.isFavorite),\(workout.exercises.count)")
        }
        csvLines.append("")
        
        // 2. Упражнения
        csvLines.append("## EXERCISES\nExercise ID,Workout ID,Workout Title,Exercise Name,Muscle Group,Type,Effort,Is Completed,Set Count")
        for workout in workouts {
            for exercise in workout.exercises {
                csvLines.append("\(exercise.id.uuidString),\(workout.id.uuidString),\"\(escapeCSV(workout.title))\",\"\(escapeCSV(exercise.name))\",\(exercise.muscleGroup),\(exercise.type.rawValue),\(exercise.effort),\(exercise.isCompleted),\(exercise.setsList.count)")
            }
        }
        csvLines.append("")
        
        // 3. Сеты
        csvLines.append("## SETS\nSet ID,Exercise ID,Exercise Name,Set Index,Weight,Reps,Distance (km),Time (sec),Is Completed,Set Type")
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
        
        do {
            let csvContent = csvLines.joined(separator: "\n")
            guard let csvData = csvContent.data(using: .utf8) else { return nil }
            let fileName = "WorkoutTracker_Export_\(dateFormatter.string(from: Date())).csv"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            try csvData.write(to: tempURL)
            return tempURL
        } catch {
            return nil
        }
    }
    
    private func escapeCSV(_ string: String) -> String {
        if string.contains(",") || string.contains("\"") || string.contains("\n") {
            return string.replacingOccurrences(of: "\"", with: "\"\"")
        }
        return string
    }
}
