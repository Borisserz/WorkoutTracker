//
//  WorkoutViewModel.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 24.12.25.
//
//  Главная ViewModel приложения.
//  Является "мозгом", связывающим данные (Workouts, Exercises) с UI.
//  Вся бизнес логика делегирована в StatisticsManager, AnalyticsManager, RecoveryCalculator и ImportExportService
//

internal import SwiftUI
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
    @Published var workouts: [Workout] = [] {
        didSet {
            saveWorkouts()
            calculateRecovery()
            updateWidgetData()
            updatePerformanceCaches()
        }
    }
    @Published var lastPerformancesCache: [String: Exercise] = [:]
    @Published var personalRecordsCache: [String: Double] = [:]
    @Published var presets: [WorkoutPreset] = []
    @Published var customExercises: [CustomExerciseDefinition] = [] { didSet { saveCustomExercises() } }
    @Published var recoveryStatus: [MuscleRecoveryStatus] = []
    @Published var progressManager = ProgressManager()
    @Published var deletedDefaultExercises: Set<String> = [] {
        didSet {
            let url = getDocumentURL(for: "DeletedDefaultExercises.json")
            if let encoded = try? JSONEncoder().encode(deletedDefaultExercises) { try? encoded.write(to: url) }
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
        loadWorkouts(); loadPresets(); loadCustomExercises(); loadDeletedDefaultExercises(); calculateRecovery()
    }
    deinit { recoveryCalculationTask?.cancel() }
    
    // MARK: - File System Helpers
    private func getDocumentURL(for filename: String) -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent(filename)
    }
    
    private func updatePerformanceCaches() {
        let workoutsCopy = self.workouts
        Task.detached(priority: .utility) {
            var newLastPerformances: [String: Exercise] = [:]
            var newPRs: [String: Double] = [:]
            
            for workout in workoutsCopy.sorted(by: { $0.date > $1.date }) {
                for exercise in workout.exercises {
                    for ex in (exercise.isSuperset ? exercise.subExercises : [exercise]) {
                        guard !workout.isActive else { continue }
                        if newLastPerformances[ex.name] == nil { newLastPerformances[ex.name] = ex }
                        if ex.type == .strength {
                            let maxWeight = ex.setsList.filter { $0.isCompleted && $0.type != .warmup }.compactMap { $0.weight }.max() ?? 0
                            if maxWeight > (newPRs[ex.name] ?? 0.0) { newPRs[ex.name] = maxWeight }
                        }
                    }
                }
            }
            await MainActor.run { self.lastPerformancesCache = newLastPerformances; self.personalRecordsCache = newPRs }
        }
    }
    
    // MARK: - 1. Statistics & Records Logic (Delegated)
    func getAllPersonalRecords() -> [BestResult] { StatisticsManager.getAllPersonalRecords(workouts: workouts) }
    func calculateWorkoutStreak() -> Int { StatisticsManager.calculateWorkoutStreak(workouts: workouts) }
    func getStats(for dateInterval: DateInterval) -> PeriodStats { StatisticsManager.getStats(for: dateInterval, workouts: workouts) }
    func getBestStats(for periodType: StatsView.Period) -> PeriodStats { StatisticsManager.getBestStats(for: periodType, workouts: workouts) }
    func getPersonalRecord(for exerciseName: String, onlyCompleted: Bool = false) -> Double {
        StatisticsManager.getPersonalRecord(for: exerciseName, onlyCompleted: onlyCompleted, cachedPR: personalRecordsCache[exerciseName] ?? 0.0, workouts: workouts)
    }
    func getRecentPRs(in interval: DateInterval) -> [PersonalRecord] { StatisticsManager.getRecentPRs(in: interval, workouts: workouts) }
    
    // MARK: - 2. Charts Data Logic (Delegated)
    func getChartData(for period: StatsView.Period, metric: StatsView.GraphMetric) -> [ChartDataPoint] { StatisticsManager.getChartData(for: period, metric: metric, workouts: workouts) }
    
    // MARK: - 3. Recovery Logic (Delegated)
    func calculateRecovery(hours: Double? = nil, debounce: Bool = false) {
        recoveryCalculationTask?.cancel()
        let workoutsCopy = self.workouts
        recoveryCalculationTask = Task {
            if debounce { try? await Task.sleep(nanoseconds: 150_000_000) }
            guard !Task.isCancelled else { return }
            let result = RecoveryCalculator.calculate(hours: hours, workouts: workoutsCopy)
            await MainActor.run { self.recoveryStatus = result }
        }
    }
    
    // MARK: - 4. Analysis & Recommendations (Delegated)
    func getImbalanceRecommendation() -> (title: String, message: String)? { AnalyticsManager.getImbalanceRecommendation(workouts: workouts) }
    func getExerciseTrends(period: StatsView.Period = .month) -> [ExerciseTrend] { AnalyticsManager.getExerciseTrends(workouts: workouts, period: period) }
    func getProgressForecast(daysAhead: Int = 30) -> [ProgressForecast] { AnalyticsManager.getProgressForecast(workouts: workouts, daysAhead: daysAhead) }
    func getWeakPoints() -> [WeakPoint] { AnalyticsManager.getWeakPoints(workouts: workouts) }
    func getRecommendations() -> [Recommendation] { AnalyticsManager.getRecommendations(workouts: workouts, recoveryStatus: recoveryStatus) }
    func getDetailedComparison(period: StatsView.Period) -> [DetailedComparison] { AnalyticsManager.getDetailedComparison(workouts: workouts, period: period) }
    
    // MARK: - 5. Data Management (Workouts)
    func addWorkout(_ workout: Workout) { workouts.insert(workout, at: 0) }
    private func loadWorkouts() {
        DataManager.shared.loadWorkouts { [weak self] result in
            if case .success(let w) = result { DispatchQueue.main.async { self?.workouts = w } }
        }
    }
    private func saveWorkouts() {
        let isExample = workouts.count == Workout.examples.count && workouts.map{$0.id} == Workout.examples.map{$0.id}
        if !isExample {
            DataManager.shared.saveWorkouts(workouts) { [weak self] error in self?.showError(title: "Save Failed", message: error.localizedDescription) }
            DispatchQueue.global(qos: .utility).async { [weak self] in
                guard let self = self else { return }
                if BackupManager.shared.shouldCreateBackup() { BackupManager.shared.createBackup(workouts: self.workouts, viewModel: self) }
            }
        }
    }
    func getLastPerformance(for exerciseName: String, currentWorkoutId: UUID) -> Exercise? { lastPerformancesCache[exerciseName] }
    
    // MARK: - 6. Data Management (Presets)
    func updatePreset(_ preset: WorkoutPreset) { if let idx = presets.firstIndex(where: { $0.id == preset.id }) { presets[idx] = preset } else { presets.append(preset) }; savePresets() }
    func deletePreset(_ preset: WorkoutPreset) { presets.removeAll(where: { $0.id == preset.id }); savePresets() }
    func deletePreset(at offsets: IndexSet) { presets.remove(atOffsets: offsets); savePresets() }
    private func savePresets() { if let e = try? JSONEncoder().encode(presets) { try? e.write(to: getDocumentURL(for: "SavedWorkoutPresets.json")) } }
    private func loadPresets() {
        if let data = try? Data(contentsOf: getDocumentURL(for: "SavedWorkoutPresets.json")), let dec = try? JSONDecoder().decode([WorkoutPreset].self, from: data) { self.presets = dec }
        if self.presets.isEmpty { self.presets = Workout.examples.map { WorkoutPreset(id: UUID(), name: $0.title, icon: $0.icon, exercises: $0.exercises) }; savePresets() }
    }
    
    // MARK: - 7. Data Management (Custom Exercises)
    private func loadDeletedDefaultExercises() { if let d = try? Data(contentsOf: getDocumentURL(for: "DeletedDefaultExercises.json")), let dec = try? JSONDecoder().decode(Set<String>.self, from: d) { deletedDefaultExercises = dec } }
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
    private func saveCustomExercises() { if let e = try? JSONEncoder().encode(customExercises) { try? e.write(to: getDocumentURL(for: "SavedCustomExercises.json")) } }
    private func loadCustomExercises() { if let d = try? Data(contentsOf: getDocumentURL(for: "SavedCustomExercises.json")), let dec = try? JSONDecoder().decode([CustomExerciseDefinition].self, from: d) { customExercises = dec } }
    
    // MARK: - 8. Import / Export (Delegated)
    func generateShareLink(for preset: WorkoutPreset) -> URL? {
        do { return try ImportExportService.generateShareLink(for: preset) } catch { showError(title: "Export Failed", message: error.localizedDescription); return nil }
    }
    func exportPresetToFile(_ preset: WorkoutPreset) -> URL? {
        do { return try ImportExportService.exportPresetToFile(preset) } catch { showError(title: "Export Failed", message: error.localizedDescription); return nil }
    }
    
    func exportPresetToCSV(_ preset: WorkoutPreset) -> URL? {
        do { return try ImportExportService.exportPresetToCSV(preset) } catch { showError(title: "Export Failed", message: error.localizedDescription); return nil }
    }
    
    func importPreset(from url: URL) -> Bool {
        do {
            let imported = try ImportExportService.importPreset(from: url)
            DispatchQueue.main.async { self.presets.insert(imported, at: 0); self.savePresets() }
            return true
        } catch { showError(title: "Import Failed", message: error.localizedDescription); return false }
    }
    
    // MARK: - 9. Widget
    func updateWidgetData() {
        let currentStreak = calculateWorkoutStreak()
        var points: [WidgetData.WeeklyPoint] = []
        let cal = Calendar.current
        for i in (0...5).reversed() {
            if let date = cal.date(byAdding: .weekOfYear, value: -i, to: Date()) {
                let interval = cal.dateInterval(of: .weekOfYear, for: date)!
                let count = workouts.filter { interval.contains($0.date) }.count
                let fmt = DateFormatter(); fmt.dateFormat = "M/d"
                points.append(WidgetData.WeeklyPoint(label: fmt.string(from: interval.start), count: count))
            }
        }
        WidgetDataManager.save(streak: currentStreak, weeklyStats: points)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
