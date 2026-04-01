//
//  WorkoutExportService.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 1.04.26.
//


import Foundation

/// ОПТИМИЗАЦИЯ: Независимый сервис для импорта/экспорта тренировок (Separation of Concerns).
/// Работает с DTO, чтобы не тащить SwiftData модели в фоновые потоки.
struct WorkoutExportService: Sendable {
    
    enum ExportError: LocalizedError {
        case noInternet, invalidData, encodingFailed
        var errorDescription: String? {
            self == .noInternet ? String(localized: "Internet connection required.") : String(localized: "Data processing failed.")
        }
    }
    
    private static func escapeCSV(_ string: String) -> String {
        return string.contains(",") || string.contains("\"") || string.contains("\n") ? string.replacingOccurrences(of: "\"", with: "\"\"") : string
    }
    
    static func generateShareLink(for preset: WorkoutPresetDTO) throws -> URL {
        let jsonData = try JSONEncoder().encode(preset)
        let compressedData = try (jsonData as NSData).compressed(using: .zlib) as Data
        var comp = URLComponents(string: "https://borisserz.github.io/workout-share/")!
        comp.queryItems = [URLQueryItem(name: "data", value: compressedData.base64EncodedString())]
        return comp.url!
    }
    
    static func exportPresetToFile(_ preset: WorkoutPresetDTO) throws -> URL {
        let jsonData = try JSONEncoder().encode(preset)
        let name = preset.name.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(name).workouttemplate")
        try jsonData.write(to: tempURL)
        return tempURL
    }
    
    static func exportPresetToCSV(_ preset: WorkoutPresetDTO) throws -> URL {
        var csvLines: [String] = []
        csvLines.append("# Workout Template Export")
        csvLines.append("# Preset Name: \(preset.name)")
        csvLines.append("# Icon: \(preset.icon)")
        csvLines.append("# Exercise Count: \(preset.exercises.count)")
        csvLines.append("")
        csvLines.append("## PRESET INFO")
        csvLines.append("Name,Icon,Exercise Count")
        csvLines.append("\"\(escapeCSV(preset.name))\",\(preset.icon),\(preset.exercises.count)")
        csvLines.append("")
        csvLines.append("## EXERCISES")
        csvLines.append("Name,Muscle Group,Type,Effort,Is Completed,Set Count")
        for exercise in preset.exercises {
            csvLines.append("\"\(escapeCSV(exercise.name))\",\(exercise.muscleGroup),\(exercise.type.rawValue),\(exercise.effort),\(exercise.isCompleted),\(exercise.setsList.count)")
        }
        csvLines.append("")
        csvLines.append("## SETS")
        csvLines.append("Exercise Name,Set Index,Weight,Reps,Distance (m),Time (sec),Is Completed,Set Type")
        for exercise in preset.exercises {
            for set in exercise.setsList {
                let weightStr = set.weight != nil ? String(set.weight!) : ""
                let repsStr = set.reps != nil ? String(set.reps!) : ""
                let distanceStr = set.distance != nil ? String(set.distance!) : ""
                let timeStr = set.time != nil ? String(set.time!) : ""
                csvLines.append("\"\(escapeCSV(exercise.name))\",\(set.index),\(weightStr),\(repsStr),\(distanceStr),\(timeStr),\(set.isCompleted),\(set.type.rawValue)")
            }
        }
        
        let csvContent = csvLines.joined(separator: "\n")
        guard let csvData = csvContent.data(using: .utf8) else {
            throw ExportError.encodingFailed
        }
        
        let sanitizedName = preset.name.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: "\\", with: "-").replacingOccurrences(of: ":", with: "-")
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(sanitizedName).csv")
        try csvData.write(to: tempURL)
        return tempURL
    }
    
    static func processImportedData(_ jsonData: Data) throws -> WorkoutPresetDTO {
        let dto = try JSONDecoder().decode(WorkoutPresetDTO.self, from: jsonData)
        // В реальной модели мы добавим "(Imported)", но тут просто возвращаем DTO
        return dto
    }
    
    static func importPreset(from url: URL) throws -> WorkoutPresetDTO {
        if url.isFileURL {
            return try processImportedData(try Data(contentsOf: url))
        } else {
            guard let comp = URLComponents(url: url, resolvingAgainstBaseURL: true),
                  let b64 = comp.queryItems?.first(where: { $0.name == "data" })?.value?.replacingOccurrences(of: " ", with: "+"),
                  let raw = Data(base64Encoded: b64, options: .ignoreUnknownCharacters) else { throw ExportError.invalidData }
            return try processImportedData((try? (raw as NSData).decompressed(using: .zlib) as Data) ?? raw)
        }
    }
}
