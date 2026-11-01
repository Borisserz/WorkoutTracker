
import Foundation
import SwiftData

final class DataManager: Sendable {
    static let shared = DataManager()

    private init() {}

    struct ExportBundle: Codable {
        let exportedAt: Date
        let appVersion: String
        let workouts: [WorkoutDTO]
        let weightEntries: [WeightExportDTO]
        let goals: [GoalExportDTO]
        let bodyMeasurements: [BodyMeasurementExportDTO]
        let customPresets: [WorkoutPresetDTO]
        let exerciseNotes: [ExerciseNoteExportDTO]
        let aiChatSessions: [AIChatSessionExportDTO]
        let muscleColors: [String: String]
    }

    struct ExerciseNoteExportDTO: Codable {
        let exerciseName: String
        let text: String
    }

    struct AIChatSessionExportDTO: Codable {
        let id: UUID
        let title: String
        let date: Date
        let messages: [AIChatMessage]?
        let messageCount: Int
    }

    struct WeightExportDTO: Codable {
        let id: UUID
        let date: Date
        let weight: Double
    }

    struct GoalExportDTO: Codable {
        let id: UUID
        let type: String
        let targetValue: Double
        let startingValue: Double
        let targetDate: Date?
        let exerciseName: String?
        let targetReps: Int
        let isCompleted: Bool
        let createdAt: Date
    }

    struct BodyMeasurementExportDTO: Codable {
        let id: UUID
        let date: Date
        let bodyFat: Double?
        let neck: Double?
        let shoulders: Double?
        let chest: Double?
        let waist: Double?
        let hips: Double?
        let leftBicep: Double?
        let rightBicep: Double?
        let leftThigh: Double?
        let rightThigh: Double?
        let leftCalf: Double?
        let rightCalf: Double?
    }

    func exportAllDataAsJSON(
        workouts: [Workout],
        weightEntries: [WeightEntry] = [],
        goals: [UserGoal] = [],
        measurements: [BodyMeasurement] = [],
        customPresets: [WorkoutPreset] = [],
        exerciseNotes: [ExerciseNote] = [],
        aiChatSessions: [AIChatSession] = [],
        muscleColors: [String: String] = [:]
    ) -> URL? {
        let sessionExports: [AIChatSessionExportDTO] = aiChatSessions.map { session in
            let encodedMessages: [AIChatMessage]? = {
                let encoder = JSONEncoder()
                guard let data = try? encoder.encode(session.messages),
                      let decoded = try? JSONDecoder().decode([AIChatMessage].self, from: data) else {
                    return nil
                }
                return decoded
            }()
            return AIChatSessionExportDTO(
                id: session.id,
                title: session.title,
                date: session.date,
                messages: encodedMessages,
                messageCount: session.messages.count
            )
        }

        let bundle = ExportBundle(
            exportedAt: Date(),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0",
            workouts: workouts.map { $0.toDTO() },
            weightEntries: weightEntries.map { WeightExportDTO(id: $0.id, date: $0.date, weight: $0.weight) },
            goals: goals.map {
                GoalExportDTO(
                    id: $0.id,
                    type: String(describing: $0.type),
                    targetValue: $0.targetValue,
                    startingValue: $0.startingValue,
                    targetDate: Optional($0.targetDate),
                    exerciseName: $0.exerciseName,
                    targetReps: $0.targetReps,
                    isCompleted: $0.isCompleted,
                    createdAt: $0.createdAt
                )
            },
            bodyMeasurements: measurements.map {
                BodyMeasurementExportDTO(
                    id: $0.id,
                    date: $0.date,
                    bodyFat: $0.bodyFat,
                    neck: $0.neck,
                    shoulders: $0.shoulders,
                    chest: $0.chest,
                    waist: $0.waist,
                    hips: $0.hips,
                    leftBicep: $0.leftBicep,
                    rightBicep: $0.rightBicep,
                    leftThigh: $0.leftThigh,
                    rightThigh: $0.rightThigh,
                    leftCalf: $0.leftCalf,
                    rightCalf: $0.rightCalf
                )
            },
            customPresets: customPresets.map { $0.toDTO() },
            exerciseNotes: exerciseNotes.map {
                ExerciseNoteExportDTO(exerciseName: $0.exerciseName, text: $0.text)
            },
            aiChatSessions: sessionExports,
            muscleColors: muscleColors
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601

        do {
            let jsonData = try encoder.encode(bundle)
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

    func exportAllDataToCSV(
        workouts: [Workout],
        weightEntries: [WeightEntry] = [],
        goals: [UserGoal] = [],
        measurements: [BodyMeasurement] = []
    ) -> URL? {
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

        csvLines.append("## WEIGHT_ENTRIES\nID,Date,WeightKg")
        for entry in weightEntries {
            csvLines.append("\(entry.id.uuidString),\(dateFormatter.string(from: entry.date)),\(entry.weight)")
        }
        csvLines.append("")

        csvLines.append("## GOALS\nID,Type,Target,Starting,TargetDate,Exercise,TargetReps,Completed,CreatedAt")
        for goal in goals {
            csvLines.append("\(goal.id.uuidString),\(goal.type.rawValue),\(goal.targetValue),\(goal.startingValue),\(dateFormatter.string(from: goal.targetDate)),\"\(escapeCSV(goal.exerciseName ?? ""))\",\(goal.targetReps),\(goal.isCompleted),\(dateFormatter.string(from: goal.createdAt))")
        }
        csvLines.append("")

        csvLines.append("## BODY_MEASUREMENTS\nID,Date,BodyFat,Neck,Shoulders,Chest,Waist,Hips,LeftBicep,RightBicep,LeftThigh,RightThigh,LeftCalf,RightCalf")
        for m in measurements {
            func n(_ v: Double?) -> String { v.map { String($0) } ?? "" }
            csvLines.append("\(m.id.uuidString),\(dateFormatter.string(from: m.date)),\(n(m.bodyFat)),\(n(m.neck)),\(n(m.shoulders)),\(n(m.chest)),\(n(m.waist)),\(n(m.hips)),\(n(m.leftBicep)),\(n(m.rightBicep)),\(n(m.leftThigh)),\(n(m.rightThigh)),\(n(m.leftCalf)),\(n(m.rightCalf))")
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
