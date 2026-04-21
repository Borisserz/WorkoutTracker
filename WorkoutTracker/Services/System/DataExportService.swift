

import Foundation

final class DataManager: Sendable {
    static let shared = DataManager()

    private init() {}

    func exportAllDataAsJSON(workouts: [Workout]) -> URL? {
        let dtos = workouts.map { $0.toDTO() }

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601

        do {
            let jsonData = try encoder.encode(dtos)

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
            let fileName = "WorkoutTracker_Export_\(dateFormatter.string(from: Date())).json"

            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            try jsonData.write(to: tempURL)

            return tempURL
        } catch {
            print("❌ Failed to encode JSON: \(error.localizedDescription)")
            return nil
        }
    }

    func exportAllDataToCSV(workouts: [Workout]) -> URL? {
        var csvLines: [String] = []
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"

        csvLines.append("# WorkoutTracker Export\n# Version: \(appVersion)\n# Export Date: \(dateFormatter.string(from: Date()))\n")

        csvLines.append("## WORKOUTS\nWorkout ID,Title,Date,End Time,Duration (min),Icon,Is Favorite,Exercise Count")
        for workout in workouts {
            let workoutDate = dateFormatter.string(from: workout.date)
            let endTimeStr = workout.endTime != nil ? dateFormatter.string(from: workout.endTime!) : ""
            csvLines.append("\(workout.id.uuidString),\"\(escapeCSV(workout.title))\",\(workoutDate),\(endTimeStr),\(workout.durationSeconds / 60),\(workout.icon),\(workout.isFavorite),\(workout.exercises.count)")
        }
        csvLines.append("")

        csvLines.append("## EXERCISES\nExercise ID,Workout ID,Workout Title,Exercise Name,Muscle Group,Type,Effort,Is Completed,Set Count")
        for workout in workouts {
            for exercise in workout.exercises {
                csvLines.append("\(exercise.id.uuidString),\(workout.id.uuidString),\"\(escapeCSV(workout.title))\",\"\(escapeCSV(exercise.name))\",\(exercise.muscleGroup),\(exercise.type.rawValue),\(exercise.effort),\(exercise.isCompleted),\(exercise.setsList.count)")
            }
        }
        csvLines.append("")

        csvLines.append("## SETS\nSet ID,Exercise ID,Exercise Name,Set Index,Weight,Reps,Distance (m),Time (sec),Is Completed,Set Type")
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
            print("❌ Failed to encode CSV: \(error.localizedDescription)")
            return nil
        }
    }

    private func escapeCSV(_ string: String) -> String {
        if string.contains(",") || string.contains("\"") || string.contains("\n") {
            return "\"\(string.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return string
    }
}
