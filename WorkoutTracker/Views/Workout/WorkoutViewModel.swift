//
//  WorkoutViewModel.swift
//  WorkoutTracker
//
internal import SwiftUI
import SwiftData
import Combine
import AudioToolbox
import WidgetKit
internal import UniformTypeIdentifiers

// MARK: - Main ViewModel
@MainActor
class WorkoutViewModel: ObservableObject {
    
    struct BestResult: Identifiable, Sendable { let id = UUID(); let exerciseName: String; let value: String; let date: Date; let type: ExerciseType }
    struct ChartDataPoint: Identifiable, Sendable { let id = UUID(); let label: String; let value: Double }
    struct PersonalRecord: Identifiable, Hashable, Sendable { let id = UUID(); let exerciseName: String; let weight: Double; let date: Date }
    struct ExerciseTrend: Identifiable, Sendable { let id = UUID(); let exerciseName: String; let trend: TrendDirection; let changePercentage: Double; let currentValue: Double; let previousValue: Double; let period: String }
    enum TrendDirection: Sendable { case growing, declining, stable
        var icon: String { self == .growing ? "arrow.up.right" : self == .declining ? "arrow.down.right" : "arrow.right" }
        var color: Color { self == .growing ? .green : self == .declining ? .red : .orange }
    }
    struct ProgressForecast: Identifiable, Sendable { let id = UUID(); let exerciseName: String; let currentMax: Double; let predictedMax: Double; let confidence: Int; let timeframe: String }
    struct DetailedComparison: Sendable { let metric: String; let currentValue: Double; let previousValue: Double; let change: Double; let changePercentage: Double; let trend: TrendDirection }
    struct PeriodStats: Sendable { var workoutCount = 0; var totalReps = 0; var totalDuration = 0; var totalVolume = 0.0; var totalDistance = 0.0 }
    struct MuscleRecoveryStatus: Sendable { var muscleGroup: String; var recoveryPercentage: Int }
    struct WeakPoint: Identifiable, Sendable { let id = UUID(); let muscleGroup: String; let frequency: Int; let averageVolume: Double; let recommendation: String }
    struct Recommendation: Identifiable, Sendable { let id = UUID(); let type: RecommendationType; let title: String; let message: String; let priority: Int }
    enum RecommendationType: Sendable { case frequency, volume, balance, recovery, progression, positive
        var icon: String { self == .frequency ? "calendar" : self == .volume ? "scalemass" : self == .balance ? "scalemass.2" : self == .recovery ? "bed.double" : self == .progression ? "chart.line.uptrend.xyaxis" : "checkmark.circle.fill" }
        var color: Color { self == .frequency ? .blue : self == .volume ? .purple : self == .balance ? .orange : self == .recovery ? .green : self == .progression ? .pink : .green }
    }
    
    // MARK: - Published Properties
    @Published var lastPerformancesCache: [String: Exercise] = [:]
    @Published var personalRecordsCache: [String: Double] = [:]
    
    @Published var customExercises: [CustomExerciseDefinition] = []
    @Published var deletedDefaultExercises: Set<String> = []
    
    @Published var progressManager = ProgressManager()
    
    @Published var recoveryStatus: [MuscleRecoveryStatus] = []
    @Published var dashboardMuscleData: [MuscleCountDTO] = []
    @Published var dashboardTotalExercises: Int = 0
    @Published var dashboardTopExercises: [ExerciseCountDTO] = []
    
    @Published var streakCount: Int = 0
    @Published var bestWeekStats: PeriodStats = PeriodStats()
    @Published var bestMonthStats: PeriodStats = PeriodStats()
    @Published var weakPoints: [WeakPoint] = []
    @Published var recommendations: [Recommendation] = []
    
    @Published var activeWorkoutToResume: Workout?
    
    // MARK: - Data Layer
    var modelContainer: ModelContainer?
    
    // MARK: - Error Handling
    struct AppError: Identifiable { let id = UUID(); let title: String; let message: String }
    @Published var currentError: AppError?
    
    func showError(title: String, message: String) {
        self.currentError = AppError(title: title, message: message)
    }
    
    init() {
        MuscleMapping.preload()
    }
    
    // MARK: - MVVM Entity Manipulation (Delegated to Repository)
    
    func addSet(to exercise: Exercise, index: Int, weight: Double?, reps: Int?, distance: Double?, time: Int?, type: SetType, isCompleted: Bool) {
        guard let container = modelContainer else { return }
        let exerciseID = exercise.persistentModelID
        Task {
            let repository = WorkoutRepository(modelContainer: container)
            try? await repository.addSet(toExerciseID: exerciseID, index: index, weight: weight, reps: reps, distance: distance, time: time, type: type, isCompleted: isCompleted)
        }
    }
    
    func deleteSet(_ set: WorkoutSet, from exercise: Exercise) {
        guard let container = modelContainer else { return }
        let setID = set.persistentModelID
        let exerciseID = exercise.persistentModelID
        Task {
            let repository = WorkoutRepository(modelContainer: container)
            try? await repository.deleteSet(setID: setID, fromExerciseID: exerciseID)
        }
    }
    
    func removeSubExercise(_ subExercise: Exercise, from superset: Exercise) {
        guard let container = modelContainer else { return }
        let subID = subExercise.persistentModelID
        let supersetID = superset.persistentModelID
        Task {
            let repository = WorkoutRepository(modelContainer: container)
            try? await repository.removeSubExercise(subID: subID, fromSupersetID: supersetID)
        }
    }
    
    func removeExercise(_ exercise: Exercise, from workout: Workout) {
        guard let container = modelContainer else { return }
        let exerciseID = exercise.persistentModelID
        let workoutID = workout.persistentModelID
        Task {
            let repository = WorkoutRepository(modelContainer: container)
            try? await repository.removeExercise(exerciseID: exerciseID, fromWorkoutID: workoutID)
        }
    }
    
    // MARK: - ЗОМБИ-ТРЕНИРОВКИ И ВОССТАНОВЛЕНИЕ
    
    func cleanupAndFindActiveWorkouts() {
        guard let container = modelContainer else { return }
        Task {
            let repository = WorkoutRepository(modelContainer: container)
            if let _ = try? await repository.cleanupAndFindActiveWorkouts() { }
        }
    }
    
    func deleteWorkout(_ workout: Workout) {
        guard let container = modelContainer else { return }
        let workoutID = workout.persistentModelID
        Task {
            let repository = WorkoutRepository(modelContainer: container)
            try? await repository.deleteWorkout(workoutID: workoutID)
            await repository.rebuildAllStats()
            self.refreshAllCaches()
        }
    }
    
    func processCompletedWorkout(_ workout: Workout) {
        guard let container = modelContainer else { return }
        let workoutID = workout.persistentModelID
        Task {
            let repository = WorkoutRepository(modelContainer: container)
            try? await repository.processCompletedWorkout(workoutID: workoutID)
            self.refreshAllCaches()
        }
    }
    
    func finishWorkoutAndCalculateAchievements(_ workout: Workout, completion: @escaping ([Achievement], Int) -> Void) {
        guard let container = modelContainer else { return }
        let workoutID = workout.persistentModelID
        Task {
            let repository = WorkoutRepository(modelContainer: container)
            if let result = try? await repository.finishWorkoutAndCalculateAchievements(workoutID: workoutID) {
                await MainActor.run {
                    self.refreshAllCaches()
                    completion(result.newUnlocks, result.totalCount)
                }
            }
        }
    }
    
    // MARK: - BACKGROUND CACHE REFRESH
    
    func refreshAllCaches() {
        guard let container = modelContainer else { return }
        Task {
            let repository = WorkoutRepository(modelContainer: container)
            do {
                let cacheDTO = try await repository.fetchDashboardCache()
                let customExDTOs = (try? await repository.fetchCustomExercises()) ?? []
                let deletedDefs = (try? await repository.fetchDeletedDefaultExercises()) ?? []
                
                await MainActor.run {
                    self.personalRecordsCache = cacheDTO.personalRecords
                    self.dashboardTotalExercises = cacheDTO.dashboardTotalExercises
                    self.dashboardTopExercises = cacheDTO.dashboardTopExercises
                    self.dashboardMuscleData = cacheDTO.dashboardMuscleData
                    self.streakCount = cacheDTO.streakCount
                    
                    var newPerformancesCache: [String: Exercise] = [:]
                    for (name, data) in cacheDTO.lastPerformances {
                        if let dto = try? JSONDecoder().decode(ExerciseDTO.self, from: data) {
                            newPerformancesCache[name] = Exercise(from: dto)
                        }
                    }
                    self.lastPerformancesCache = newPerformancesCache
                    
                    self.recoveryStatus = cacheDTO.recoveryStatus.map { MuscleRecoveryStatus(muscleGroup: $0.muscleGroup, recoveryPercentage: $0.recoveryPercentage) }
                    self.bestWeekStats = PeriodStats(workoutCount: cacheDTO.bestWeekStats.workoutCount, totalReps: cacheDTO.bestWeekStats.totalReps, totalDuration: cacheDTO.bestWeekStats.totalDuration, totalVolume: cacheDTO.bestWeekStats.totalVolume, totalDistance: cacheDTO.bestWeekStats.totalDistance)
                    self.bestMonthStats = PeriodStats(workoutCount: cacheDTO.bestMonthStats.workoutCount, totalReps: cacheDTO.bestMonthStats.totalReps, totalDuration: cacheDTO.bestMonthStats.totalDuration, totalVolume: cacheDTO.bestMonthStats.totalVolume, totalDistance: cacheDTO.bestMonthStats.totalDistance)
                    self.weakPoints = cacheDTO.weakPoints.map { WeakPoint(muscleGroup: $0.muscleGroup, frequency: $0.frequency, averageVolume: $0.averageVolume, recommendation: $0.recommendation) }
                    
                    self.recommendations = cacheDTO.recommendations.compactMap { dto in
                        let type: RecommendationType
                        switch dto.typeRawValue {
                        case "frequency": type = .frequency
                        case "volume": type = .volume
                        case "balance": type = .balance
                        case "recovery": type = .recovery
                        case "progression": type = .progression
                        case "positive": type = .positive
                        default: return nil
                        }
                        return Recommendation(type: type, title: dto.title, message: dto.message, priority: dto.priority)
                    }
                    
                    self.customExercises = customExDTOs
                    self.deletedDefaultExercises = deletedDefs
                }
            } catch {
                print("Failed to refresh caches via Repository: \(error)")
            }
        }
    }
    
    func rebuildAllStats() {
        guard let container = modelContainer else { return }
        Task {
            let repository = WorkoutRepository(modelContainer: container)
            await repository.rebuildAllStats()
            self.refreshAllCaches()
        }
    }
    
    func getLastPerformance(for exerciseName: String) -> Exercise? { lastPerformancesCache[exerciseName] }
    
    // MARK: - Default Initialization
    
    func checkAndGenerateDefaultPresets() {
        guard let container = modelContainer else { return }
        Task {
            let repository = WorkoutRepository(modelContainer: container)
            try? await repository.checkAndGenerateDefaultPresets()
        }
    }
    
    // MARK: - Data Management (Dictionary / Custom Exercises)
    
    func loadDictionary() {
        guard let container = modelContainer else { return }
        Task {
            let repository = WorkoutRepository(modelContainer: container)
            let custom = (try? await repository.fetchCustomExercises()) ?? []
            let deleted = (try? await repository.fetchDeletedDefaultExercises()) ?? []
            
            await MainActor.run {
                self.customExercises = custom
                self.deletedDefaultExercises = deleted
            }
        }
    }
    
    var combinedCatalog: [String: [String]] {
        var catalog = Exercise.catalog
        for (category, exercises) in catalog {
            catalog[category] = exercises.filter { !deletedDefaultExercises.contains($0) }
        }
        for custom in customExercises {
            var list = catalog[custom.category] ?? []
            if !list.contains(custom.name) { list.append(custom.name) }
            catalog[custom.category] = list
        }
        return catalog
    }
    
    func isCustomExercise(name: String) -> Bool { customExercises.contains { $0.name == name } }
    
    func addCustomExercise(name: String, category: String, muscles: [String], type: ExerciseType = .strength) {
        guard let container = modelContainer else { return }
        Task {
            let repository = WorkoutRepository(modelContainer: container)
            try? await repository.addCustomExercise(name: name, category: category, muscles: muscles, type: type)
            await MainActor.run {
                MuscleMapping.updateCustomMapping(name: name, muscles: muscles)
                self.loadDictionary()
            }
        }
    }
    
    func deleteCustomExercise(name: String, category: String) {
        guard let container = modelContainer else { return }
        Task {
            let repository = WorkoutRepository(modelContainer: container)
            try? await repository.deleteCustomExercise(name: name, category: category)
            await MainActor.run {
                MuscleMapping.updateCustomMapping(name: name, muscles: nil)
                self.loadDictionary()
            }
        }
    }
    
    func deleteExercise(name: String, category: String) {
        guard let container = modelContainer else { return }
        if isCustomExercise(name: name) {
            deleteCustomExercise(name: name, category: category)
        } else {
            Task {
                let repository = WorkoutRepository(modelContainer: container)
                try? await repository.hideDefaultExercise(name: name, category: category)
                await MainActor.run { self.loadDictionary() }
            }
        }
    }
    
    // MARK: - Import / Export
    
    func generateShareLink(for preset: WorkoutPreset) -> URL? {
        do { return try ImportExportService.generateShareLink(for: preset) } catch { showError(title: String(localized: "Export Failed"), message: error.localizedDescription); return nil }
    }
    
    func exportPresetToFile(_ preset: WorkoutPreset) -> URL? {
        do { return try ImportExportService.exportPresetToFile(preset) } catch { showError(title: String(localized: "Export Failed"), message: error.localizedDescription); return nil }
    }
    
    func exportPresetToCSV(_ preset: WorkoutPreset) -> URL? {
        do { return try ImportExportService.exportPresetToCSV(preset) } catch { showError(title: String(localized: "Export Failed"), message: error.localizedDescription); return nil }
    }
    
    func importPreset(from url: URL) -> Bool {
        guard let container = modelContainer else { return false }
        do {
            let preset = try ImportExportService.importPreset(from: url)
            Task {
                let repository = WorkoutRepository(modelContainer: container)
                try? await repository.importPreset(dto: preset.toDTO())
                self.refreshAllCaches()
            }
            return true
        } catch {
            showError(title: String(localized: "Import Failed"), message: error.localizedDescription)
            return false
        }
    }
    
    // MARK: - Widget
    
    func updateWidgetData() {
        guard let container = modelContainer else { return }
        Task {
            let repository = WorkoutRepository(modelContainer: container)
            try? await repository.updateWidgetData()
        }
    }
    
    // MARK: - AI Adjustments
    func applyAIAdjustment(_ adjustment: InWorkoutResponseDTO, to workout: Workout) {
        guard let container = modelContainer else { return }
        let workoutID = workout.persistentModelID
        Task {
            let repository = WorkoutRepository(modelContainer: container)
            try? await repository.applyAIAdjustment(adjustment, workoutID: workoutID)
        }
    }
    
    // MARK: - Import Export Service
    struct ImportExportService {
        enum ExportError: LocalizedError {
            case noInternet, invalidData, encodingFailed
            var errorDescription: String? { self == .noInternet ? String(localized: "Internet connection required.") : String(localized: "Data processing failed.") }
        }
        
        private static func escapeCSV(_ string: String) -> String {
            return string.contains(",") || string.contains("\"") || string.contains("\n") ? string.replacingOccurrences(of: "\"", with: "\"\"") : string
        }
        
        static func generateShareLink(for preset: WorkoutPreset) throws -> URL {
            let dto = preset.toDTO()
            let jsonData = try JSONEncoder().encode(dto)
            let compressedData = try (jsonData as NSData).compressed(using: .zlib) as Data
            var comp = URLComponents(string: "https://borisserz.github.io/workout-share/")!
            comp.queryItems = [URLQueryItem(name: "data", value: compressedData.base64EncodedString())]
            return comp.url!
        }
        
        static func exportPresetToFile(_ preset: WorkoutPreset) throws -> URL {
            let dto = preset.toDTO()
            let jsonData = try JSONEncoder().encode(dto)
            let name = preset.name.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(name).workouttemplate")
            try jsonData.write(to: tempURL)
            return tempURL
        }
        
        static func exportPresetToCSV(_ preset: WorkoutPreset) throws -> URL {
            var csvLines: [String] = []
            csvLines.append("# Workout Template Export")
            csvLines.append("# Preset Name: \(preset.name)")
            csvLines.append("# Icon: \(preset.icon)")
            csvLines.append("# Exercise Count: \(preset.exercises.count)")
            csvLines.append("")
            csvLines.append("## PRESET INFO")
            csvLines.append("Preset ID,Name,Icon,Exercise Count")
            csvLines.append("\(preset.id.uuidString),\"\(escapeCSV(preset.name))\",\(preset.icon),\(preset.exercises.count)")
            csvLines.append("")
            csvLines.append("## EXERCISES")
            csvLines.append("Exercise ID,Name,Muscle Group,Type,Effort,Is Completed,Set Count")
            for exercise in preset.exercises {
                csvLines.append("\(exercise.id.uuidString),\"\(escapeCSV(exercise.name))\",\(exercise.muscleGroup),\(exercise.type.rawValue),\(exercise.effort),\(exercise.isCompleted),\(exercise.setsList.count)")
            }
            csvLines.append("")
            csvLines.append("## SETS")
            csvLines.append("Set ID,Exercise ID,Exercise Name,Set Index,Weight,Reps,Distance (m),Time (sec),Is Completed,Set Type")
            for exercise in preset.exercises {
                for set in exercise.setsList {
                    let weightStr = set.weight != nil ? String(set.weight!) : ""
                    let repsStr = set.reps != nil ? String(set.reps!) : ""
                    let distanceStr = set.distance != nil ? String(set.distance!) : ""
                    let timeStr = set.time != nil ? String(set.time!) : ""
                    csvLines.append("\(set.id.uuidString),\(exercise.id.uuidString),\"\(escapeCSV(exercise.name))\",\(set.index),\(weightStr),\(repsStr),\(distanceStr),\(timeStr),\(set.isCompleted),\(set.type.rawValue)")
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
        
        static func processImportedData(_ jsonData: Data) throws -> WorkoutPreset {
            let dto = try JSONDecoder().decode(WorkoutPresetDTO.self, from: jsonData)
            let preset = WorkoutPreset(from: dto)
            preset.name += " (Imported)"
            return preset
        }
        
        static func importPreset(from url: URL) throws -> WorkoutPreset {
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
    // Добавляем структуру для хранения результатов аналитики
    struct WorkoutAnalyticsData: Sendable {
        var intensity: [String: Int] = [:]
        var volume: Double = 0.0
        var chartExercises: [Exercise] = []
    }
    
    @Published var workoutAnalytics = WorkoutAnalyticsData()
    
    func updateWorkoutAnalytics(for workout: Workout) {
        let workoutID = workout.persistentModelID
        guard let container = modelContainer else { return }
        
        Task.detached(priority: .userInitiated) {
            let bgContext = ModelContext(container)
            guard let bgWorkout = bgContext.model(for: workoutID) as? Workout else { return }
            
            var counts = [String: Int]()
            var volume = 0.0
            
            // 1. Считаем интенсивность и объем
            for exercise in bgWorkout.exercises {
                let targets = exercise.isSuperset ? exercise.subExercises : [exercise]
                for sub in targets {
                    if sub.type != .cardio && sub.setsList.contains(where: { $0.isCompleted }) {
                        let muscles = MuscleMapping.getMuscles(for: sub.name, group: sub.muscleGroup)
                        for muscleSlug in muscles {
                            counts[muscleSlug, default: 0] += 1
                        }
                    }
                }
                volume += exercise.exerciseVolume
            }
            
            // 2. Готовим список упражнений для графика (только силовые с выполненными сетами и весом)
            let flattened = bgWorkout.exercises.flatMap { $0.isSuperset ? $0.subExercises : [$0] }
            let forChart = flattened.filter { ex in
                ex.type == .strength && ex.setsList.contains(where: { $0.isCompleted && ($0.weight ?? 0) > 0 })
            }
            
            // Захватываем данные для передачи в MainActor
            let finalCounts = counts
            let finalVolume = volume
            let finalChart = forChart
            
            await MainActor.run {
                self.workoutAnalytics = WorkoutAnalyticsData(
                    intensity: finalCounts,
                    volume: finalVolume,
                    chartExercises: finalChart
                )
            }
        }
    }
}
