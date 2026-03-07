//
//  WorkoutViewModel.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 24.12.25.
//
//  Главная ViewModel приложения.
//  Является "мозгом", управляющим локальным стейтом и ошибками.
//  Вся работа со SwiftData переведена на фоновые потоки.
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
    
    // Кэш для дашборда
    @Published var dashboardMuscleData: [(muscle: String, count: Int)] = []
    @Published var dashboardTotalExercises: Int = 0
    @Published var dashboardTopExercises: [(name: String, count: Int)] = []
    
    // ОПТИМИЗАЦИЯ: Кэш для глобальной аналитики, чтобы не тормозить ProgressView
    @Published var streakCount: Int = 0
    @Published var bestWeekStats: PeriodStats = PeriodStats()
    @Published var bestMonthStats: PeriodStats = PeriodStats()
    @Published var weakPoints: [WeakPoint] = []
    @Published var recommendations: [Recommendation] = []
    
    // MARK: - Error Handling
    struct AppError: Identifiable { let id = UUID(); let title: String; let message: String }
    @Published var currentError: AppError?
    func showError(title: String, message: String) {
        DispatchQueue.main.async { self.currentError = AppError(title: title, message: message) }
    }
    
    init() {
        MuscleMapping.preload()
        loadCustomExercises()
        loadDeletedDefaultExercises()
    }
    
    // MARK: - File System Helpers
    private func getDocumentURL(for filename: String) -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent(filename)
    }
    
    // MARK: - BACKGROUND CACHE REFRESH
    
    func refreshAllCaches(container: ModelContainer) {
        Task.detached(priority: .userInitiated) {
            let context = ModelContext(container)
            
            let descriptor = FetchDescriptor<Workout>(
                predicate: #Predicate<Workout> { $0.endTime != nil },
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            
            guard let workouts = try? context.fetch(descriptor) else { return }
            
            var partialLastPerformances: [String: Exercise] = [:]
            var partialPRs: [String: Double] = [:]
            var stats: [String: Int] = [:]
            var exerciseCounts: [String: Int] = [:]
            
            for workout in workouts {
                for exercise in workout.exercises {
                    let targets = exercise.isSuperset ? exercise.safeSubExercises : [exercise]
                    
                    for ex in targets {
                        let name = ex.name
                        
                        if partialLastPerformances[name] == nil {
                            partialLastPerformances[name] = ex.duplicate()
                        }
                        
                        if ex.type == .strength {
                            let maxWeight = ex.safeSetsList
                                .filter { $0.isCompleted && $0.type != .warmup }
                                .compactMap { $0.weight }
                                .max() ?? 0
                                
                            let currentMax = partialPRs[name] ?? 0.0
                            if maxWeight > currentMax { partialPRs[name] = maxWeight }
                        }
                        
                        let isCardio = ex.type == .cardio || ex.type == .duration || ex.muscleGroup == "Cardio"
                        if !isCardio {
                            stats[ex.muscleGroup, default: 0] += 1
                        }
                        exerciseCounts[name, default: 0] += 1
                    }
                }
            }
            
            let recovery = RecoveryCalculator.calculate(hours: nil, workouts: workouts)
            let sortedMuscleData = stats.map { (muscle: $0.key, count: $0.value) }.filter { $0.count > 0 }.sorted { $0.count > $1.count }
            let totalExCount = sortedMuscleData.reduce(0) { $0 + $1.count }
            let topExercises = Array(exerciseCounts.sorted { $0.value > $1.value || ($0.value == $1.value && $0.key < $1.key) }.prefix(5)).map { (name: $0.key, count: $0.value) }
            
            // Расчет глобальной статистики один раз в фоне
            let streak = StatisticsManager.calculateWorkoutStreak(workouts: workouts)
            let bWeek = StatisticsManager.getBestStats(for: .week, workouts: workouts)
            let bMonth = StatisticsManager.getBestStats(for: .month, workouts: workouts)
            let weakPts = AnalyticsManager.getWeakPoints(recentWorkouts: workouts)
            let recs = AnalyticsManager.getRecommendations(workouts: workouts, recoveryStatus: recovery)
            
            await MainActor.run {
                self.lastPerformancesCache = partialLastPerformances
                self.personalRecordsCache = partialPRs
                self.recoveryStatus = recovery
                self.dashboardMuscleData = sortedMuscleData
                self.dashboardTotalExercises = totalExCount
                self.dashboardTopExercises = topExercises
                
                self.streakCount = streak
                self.bestWeekStats = bWeek
                self.bestMonthStats = bMonth
                self.weakPoints = weakPts
                self.recommendations = recs
            }
        }
    }
    
    func getLastPerformance(for exerciseName: String) -> Exercise? { lastPerformancesCache[exerciseName] }
    
    // MARK: - Default Initialization (SwiftData)
    
    @MainActor
    func checkAndGenerateDefaultPresets(context: ModelContext) {
        let descriptor = FetchDescriptor<WorkoutPreset>()
        let count = (try? context.fetchCount(descriptor)) ?? 0
        
        if count == 0 {
            let defaultPresets = Workout.examples.map { WorkoutPreset(id: UUID(), name: $0.title, icon: $0.icon, exercises: $0.exercises.map { $0.duplicate() }) }
            for preset in defaultPresets {
                context.insert(preset)
            }
            try? context.save()
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
    
    func updateWidgetData(container: ModelContainer) {
        Task.detached(priority: .background) {
            let context = ModelContext(container)
            let descriptor = FetchDescriptor<Workout>(
                predicate: #Predicate<Workout> { $0.endTime != nil },
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            
            guard let workouts = try? context.fetch(descriptor) else { return }
            
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
            
            WidgetDataManager.save(streak: currentStreak, weeklyStats: points)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
