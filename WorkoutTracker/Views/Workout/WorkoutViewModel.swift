//
//  WorkoutViewModel.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 24.12.25.
//
//  Главная ViewModel приложения.
//  Является "мозгом", управляющим локальным стейтом и ошибками.
//  Вся работа со SwiftData (Workouts, Presets) перенесена во View через @Query.
//

internal import SwiftUI
import SwiftData
import Combine
import AudioToolbox
import WidgetKit
internal import UniformTypeIdentifiers

class WorkoutViewModel: ObservableObject {
    
    // MARK: - Nested Models
    struct BestResult: Identifiable { let id = UUID(); let exerciseName: String; let value: String; let date: Date; let type: ExerciseType }
    struct PeriodStats { var workoutCount = 0; var totalReps = 0; var totalDuration = 0; var totalVolume = 0.0; var totalDistance = 0.0 }
    struct ChartDataPoint: Identifiable { let id = UUID(); let label: String; let value: Double }
    struct PersonalRecord: Identifiable, Hashable { let id = UUID(); let exerciseName: String; let weight: Double; let date: Date }
    struct MuscleRecoveryStatus { var muscleGroup: String; var recoveryPercentage: Int }
    struct ExerciseTrend: Identifiable { let id = UUID(); let exerciseName: String; let trend: TrendDirection; let changePercentage: Double; let currentValue: Double; let previousValue: Double; let period: String }
    enum TrendDirection { case growing, declining, stable
        var icon: String { self == .growing ? "arrow.up.right" : self == .declining ? "arrow.down.right" : "arrow.right" }
        var color: Color { self == .growing ? .green : self == .declining ? .red : .orange }
    }
    struct ProgressForecast: Identifiable { let id = UUID(); let exerciseName: String; let currentMax: Double; let predictedMax: Double; let confidence: Int; let timeframe: String }
    struct WeakPoint: Identifiable { let id = UUID(); let muscleGroup: String; let frequency: Int; let averageVolume: Double; let recommendation: String }
    struct Recommendation: Identifiable { let id = UUID(); let type: RecommendationType; let title: String; let message: String; let priority: Int }
    enum RecommendationType { case frequency, volume, balance, recovery, progression, positive
        var icon: String { self == .frequency ? "calendar" : self == .volume ? "scalemass" : self == .balance ? "scalemass.2" : self == .recovery ? "bed.double" : self == .progression ? "chart.line.uptrend.xyaxis" : "checkmark.circle.fill" }
        var color: Color { self == .frequency ? .blue : self == .volume ? .purple : self == .balance ? .orange : self == .recovery ? .green : self == .progression ? .pink : .green }
    }
    struct DetailedComparison { let metric: String; let currentValue: Double; let previousValue: Double; let change: Double; let changePercentage: Double; let trend: TrendDirection }
    
    // MARK: - Published Properties
    @Published var lastPerformancesCache: [String: Exercise] = [:]
    @Published var personalRecordsCache: [String: Double] = [:]
    @Published var customExercises: [CustomExerciseDefinition] = [] { didSet { saveCustomExercises() } }
    @Published var recoveryStatus: [MuscleRecoveryStatus] = []
    @Published var progressManager = ProgressManager()
    @Published var deletedDefaultExercises: Set<String> = [] {
        didSet {
            let currentSet = deletedDefaultExercises
            let url = getDocumentURL(for: "DeletedDefaultExercises.json")
            Task.detached(priority: .background) {
                if let encoded = try? JSONEncoder().encode(currentSet) { 
                    try? encoded.write(to: url) 
                }
            }
        }
    }
    
    // MARK: - Error Handling
    struct AppError: Identifiable { let id = UUID(); let title: String; let message: String }
    @Published var currentError: AppError?
    func showError(title: String, message: String) {
        DispatchQueue.main.async { self.currentError = AppError(title: title, message: message) }
    }
    
    // MARK: - Private Properties
    private var recoveryCalculationTask: Task<Void, Never>?
    
    init() {
        MuscleMapping.preload()
        loadCustomExercises()
        loadDeletedDefaultExercises()
    }
    
    deinit { recoveryCalculationTask?.cancel() }
    
    // MARK: - File System Helpers
    private func getDocumentURL(for filename: String) -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent(filename)
    }
    
    // MARK: - App State Updaters
    
    /// Этот метод должен вызываться из корневой View приложения через `.onChange(of: workouts)`
    func updatePerformanceCaches(workouts: [Workout], oldWorkouts: [Workout]? = nil) {
        Task { @MainActor in
            var exercisesToUpdate: Set<String>? = nil
            
            if let oldWorkouts = oldWorkouts {
                var changedNames = Set<String>()
                let newWorkoutsDict = Dictionary(uniqueKeysWithValues: workouts.map { ($0.id, $0) })
                let oldWorkoutsDict = Dictionary(uniqueKeysWithValues: oldWorkouts.map { ($0.id, $0) })
                
                var needsFullRebuild = false
                
                for workout in workouts {
                    if let oldWorkout = oldWorkoutsDict[workout.id] {
                        if oldWorkout !== workout {
                            Self.extractExerciseNames(from: workout, into: &changedNames)
                            if !oldWorkout.isDeleted {
                                Self.extractExerciseNames(from: oldWorkout, into: &changedNames)
                            }
                        }
                    } else {
                        Self.extractExerciseNames(from: workout, into: &changedNames)
                    }
                }
                
                for oldWorkout in oldWorkouts {
                    if newWorkoutsDict[oldWorkout.id] == nil {
                        needsFullRebuild = true
                        break
                    }
                }
                
                if needsFullRebuild {
                    exercisesToUpdate = nil
                } else {
                    if changedNames.isEmpty { return }
                    exercisesToUpdate = changedNames
                }
            }
            
            var partialLastPerformances: [String: Exercise] = [:]
            var partialPRs: [String: Double] = [:]
            
            for workout in workouts.sorted(by: { $0.date > $1.date }) {
                guard !workout.isActive else { continue }
                for exercise in workout.exercises {
                    for ex in (exercise.isSuperset ? exercise.subExercises : [exercise]) {
                        let name = ex.name
                        
                        if let targets = exercisesToUpdate, !targets.contains(name) { continue }
                        
                        if partialLastPerformances[name] == nil { partialLastPerformances[name] = ex }
                        
                        if ex.type == .strength {
                            let maxWeight = ex.setsList.filter { $0.isCompleted && $0.type != .warmup }.compactMap { $0.weight }.max() ?? 0
                            let currentMax = partialPRs[name] ?? 0.0
                            if maxWeight > currentMax { partialPRs[name] = maxWeight }
                        }
                    }
                }
            }
            
            if let targets = exercisesToUpdate {
                for name in targets {
                    if let pr = partialPRs[name] { self.personalRecordsCache[name] = pr }
                    else { self.personalRecordsCache.removeValue(forKey: name) }
                    
                    if let lp = partialLastPerformances[name] { self.lastPerformancesCache[name] = lp }
                    else { self.lastPerformancesCache.removeValue(forKey: name) }
                }
            } else {
                self.lastPerformancesCache = partialLastPerformances
                self.personalRecordsCache = partialPRs
            }
        }
    }
    
    private static func extractExerciseNames(from workout: Workout, into set: inout Set<String>) {
        for exercise in workout.exercises {
            for ex in (exercise.isSuperset ? exercise.subExercises : [exercise]) {
                set.insert(ex.name)
            }
        }
    }
    
    func getLastPerformance(for exerciseName: String) -> Exercise? { lastPerformancesCache[exerciseName] }
    
    // MARK: - Recovery Logic
    
    func calculateRecovery(workouts: [Workout], hours: Double? = nil, debounce: Bool = false) {
        recoveryCalculationTask?.cancel()
        recoveryCalculationTask = Task { @MainActor in
            if debounce { try? await Task.sleep(nanoseconds: 150_000_000) }
            guard !Task.isCancelled else { return }
            self.recoveryStatus = RecoveryCalculator.calculate(hours: hours, workouts: workouts)
        }
    }
    
    // MARK: - Default Initialization (SwiftData)
    
    func checkAndGenerateDefaultPresets(context: ModelContext) {
        let descriptor = FetchDescriptor<WorkoutPreset>()
        let count = (try? context.fetchCount(descriptor)) ?? 0
        
        if count == 0 {
            let defaultPresets = Workout.examples.map { WorkoutPreset(id: UUID(), name: $0.title, icon: $0.icon, exercises: $0.exercises.map { $0.duplicate() }) }
            for preset in defaultPresets {
                context.insert(preset)
            }
        }
    }
    
    // MARK: - Data Management (Custom Exercises)
    
    private func loadDeletedDefaultExercises() {
        let url = getDocumentURL(for: "DeletedDefaultExercises.json")
        Task.detached(priority: .background) { [weak self] in
            if let d = try? Data(contentsOf: url),
               let dec = try? JSONDecoder().decode(Set<String>.self, from: d) {
                await MainActor.run {
                    self?.deletedDefaultExercises = dec
                }
            }
        }
    }
    
    var combinedCatalog: [String: [String]] {
        var catalog = Exercise.catalog
        for (category, exercises) in catalog { catalog[category] = exercises.filter { !deletedDefaultExercises.contains($0) } }
        for custom in customExercises { var list = catalog[custom.category] ?? []; if !list.contains(custom.name) { list.append(custom.name) }; catalog[custom.category] = list }
        return catalog
    }
    
    func addCustomExercise(name: String, category: String, muscles: [String], type: ExerciseType = .strength) { customExercises.append(.init(name: name, category: category, targetedMuscles: muscles, type: type)); MuscleMapping.updateCustomMapping(name: name, muscles: muscles) }
    
    func deleteCustomExercise(name: String, category: String) { customExercises.removeAll { $0.name == name }; MuscleMapping.updateCustomMapping(name: name, muscles: nil) }
    
    func deleteExercise(name: String, category: String) {
        if isCustomExercise(name: name) {
            deleteCustomExercise(name: name, category: category)
        } else {
            deletedDefaultExercises.insert(name)
        }
    }
    
    func isCustomExercise(name: String) -> Bool { customExercises.contains { $0.name == name } }
    
    private func saveCustomExercises() { 
        let currentExercises = customExercises
        let url = getDocumentURL(for: "SavedCustomExercises.json")
        Task.detached(priority: .background) {
            if let e = try? JSONEncoder().encode(currentExercises) { 
                try? e.write(to: url) 
            }
        }
    }
    
    private func loadCustomExercises() {
        let url = getDocumentURL(for: "SavedCustomExercises.json")
        Task.detached(priority: .background) { [weak self] in
            if let d = try? Data(contentsOf: url),
               let dec = try? JSONDecoder().decode([CustomExerciseDefinition].self, from: d) {
                await MainActor.run {
                    self?.customExercises = dec
                }
            }
        }
    }
    
    // MARK: - Import / Export
    
    func generateShareLink(for preset: WorkoutPreset) -> URL? {
        do {
            return try ImportExportService.generateShareLink(for: preset)
        } catch {
            showError(title: "Export Failed", message: error.localizedDescription)
            return nil
        }
    }
    
    func exportPresetToFile(_ preset: WorkoutPreset) -> URL? {
        do {
            return try ImportExportService.exportPresetToFile(preset)
        } catch {
            showError(title: "Export Failed", message: error.localizedDescription)
            return nil
        }
    }
    
    func exportPresetToCSV(_ preset: WorkoutPreset) -> URL? {
        do { return try ImportExportService.exportPresetToCSV(preset) } catch { showError(title: "Export Failed", message: error.localizedDescription); return nil }
    }
    
    func importPreset(from url: URL, context: ModelContext) -> Bool {
        do {
            let preset = try ImportExportService.importPreset(from: url)
            context.insert(preset)
            return true
        } catch {
            showError(title: "Import Failed", message: error.localizedDescription)
            return false
        }
    }
    
    // MARK: - Widget
    
    func updateWidgetData(workouts: [Workout]) {
        Task { @MainActor in
            let currentStreak = StatisticsManager.calculateWorkoutStreak(workouts: workouts)
            var points: [WidgetData.WeeklyPoint] = []
            let cal = Calendar.current
            
            for i in (0...5).reversed() {
                if let date = cal.date(byAdding: .weekOfYear, value: -i, to: Date()) {
                    let interval = cal.dateInterval(of: .weekOfYear, for: date)!
                    let count = workouts.filter { interval.contains($0.date) }.count
                    let fmt = DateFormatter()
                    fmt.dateFormat = "M/d"
                    points.append(WidgetData.WeeklyPoint(label: fmt.string(from: interval.start), count: count))
                }
            }
            
            Task.detached(priority: .background) {
                WidgetDataManager.save(streak: currentStreak, weeklyStats: points)
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }
}
