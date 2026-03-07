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
    @Published var workouts: [Workout] = [] {
        didSet {
            let oldWorkouts = oldValue
            // SwiftData автоматически отслеживает внутренние изменения в @Model.
            // При изменении массива мы просто обновляем кэши виджетов и рекавери.
            calculateRecovery()
            updateWidgetData()
            updatePerformanceCaches(oldWorkouts: oldWorkouts)
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
            let currentSet = deletedDefaultExercises
            let url = getDocumentURL(for: "DeletedDefaultExercises.json")
            Task.detached(priority: .background) {
                if let encoded = try? JSONEncoder().encode(currentSet) { 
                    try? encoded.write(to: url) 
                }
            }
        }
    }
    
    // MARK: - SwiftData Integration
    private var modelContext: ModelContext?
    
    func setContext(_ context: ModelContext) {
        guard self.modelContext == nil else { return }
        self.modelContext = context
        fetchData()
    }
    
    func fetchData() {
        guard let context = modelContext else { return }
        
        // Достаем тренировки
        let workoutDescriptor = FetchDescriptor<Workout>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        self.workouts = (try? context.fetch(workoutDescriptor)) ?? []
        
        // Достаем пресеты
        let presetDescriptor = FetchDescriptor<WorkoutPreset>()
        self.presets = (try? context.fetch(presetDescriptor)) ?? []
        
        // Генерируем дефолтные пресеты при первом запуске
        if self.presets.isEmpty {
            let defaultPresets = Workout.examples.map { WorkoutPreset(id: UUID(), name: $0.title, icon: $0.icon, exercises: $0.exercises.map { $0.duplicate() }) }
            for preset in defaultPresets {
                context.insert(preset)
            }
            // Автосохранение SwiftData сработает само
            self.presets = defaultPresets
        }
    }
    
    func saveChanges() {
        // ИСПРАВЛЕНИЕ: Форсируем сохранение в БД перед тем, как делать fetch
        try? modelContext?.save()
        
        // Освежаем массивы для UI, так как приложение всё ещё опирается на @Published массивы.
        if let context = modelContext {
            let workoutDescriptor = FetchDescriptor<Workout>(sortBy: [SortDescriptor(\.date, order: .reverse)])
            self.workouts = (try? context.fetch(workoutDescriptor)) ?? []
            
            let presetDescriptor = FetchDescriptor<WorkoutPreset>()
            self.presets = (try? context.fetch(presetDescriptor)) ?? []
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
        // Вызов fetchData произойдет позже, когда View передаст ModelContext
        loadCustomExercises()
        loadDeletedDefaultExercises()
        calculateRecovery()
    }
    deinit { recoveryCalculationTask?.cancel() }
    
    // MARK: - File System Helpers
    private func getDocumentURL(for filename: String) -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent(filename)
    }
    
    private func updatePerformanceCaches(oldWorkouts: [Workout]? = nil) {
        // Все вычисления с @Model моделями выполняем на главном потоке для безопасности
        Task { @MainActor in
            var exercisesToUpdate: Set<String>? = nil
            
            // 1. Вычисляем только изменившиеся упражнения
            if let oldWorkouts = oldWorkouts {
                var changedNames = Set<String>()
                let newWorkoutsDict = Dictionary(uniqueKeysWithValues: self.workouts.map { ($0.id, $0) })
                let oldWorkoutsDict = Dictionary(uniqueKeysWithValues: oldWorkouts.map { ($0.id, $0) })
                
                var needsFullRebuild = false
                
                // Проходимся по новым (в поиске измененных или добавленных)
                for workout in self.workouts {
                    if let oldWorkout = oldWorkoutsDict[workout.id] {
                        if oldWorkout !== workout { // Используем проверку на ссылочное равенство
                            Self.extractExerciseNames(from: workout, into: &changedNames)
                            // Если объект не удален, можно безопасно читать его свойства
                            if !oldWorkout.isDeleted {
                                Self.extractExerciseNames(from: oldWorkout, into: &changedNames)
                            }
                        }
                    } else {
                        // Совершенно новая тренировка
                        Self.extractExerciseNames(from: workout, into: &changedNames)
                    }
                }
                
                // Ищем удаленные тренировки
                for oldWorkout in oldWorkouts {
                    if newWorkoutsDict[oldWorkout.id] == nil {
                        // Обращение к связям удаленного объекта вызывает краш SwiftData,
                        // поэтому мы просто делаем полный пересчет кэша
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
            
            // 2. Ищем данные только для измененных упражнений
            for workout in self.workouts.sorted(by: { $0.date > $1.date }) {
                guard !workout.isActive else { continue }
                for exercise in workout.exercises {
                    for ex in (exercise.isSuperset ? exercise.subExercises : [exercise]) {
                        let name = ex.name
                        
                        if let targets = exercisesToUpdate, !targets.contains(name) {
                            continue
                        }
                        
                        if partialLastPerformances[name] == nil { 
                            partialLastPerformances[name] = ex 
                        }
                        
                        if ex.type == .strength {
                            let maxWeight = ex.setsList.filter { $0.isCompleted && $0.type != .warmup }.compactMap { $0.weight }.max() ?? 0
                            let currentMax = partialPRs[name] ?? 0.0
                            if maxWeight > currentMax { 
                                partialPRs[name] = maxWeight 
                            }
                        }
                    }
                }
            }
            
            // 3. Сохраняем и патчим основной кэш
            if let targets = exercisesToUpdate {
                for name in targets {
                    if let pr = partialPRs[name] {
                        self.personalRecordsCache[name] = pr
                    } else {
                        self.personalRecordsCache.removeValue(forKey: name)
                    }
                    
                    if let lp = partialLastPerformances[name] {
                        self.lastPerformancesCache[name] = lp
                    } else {
                        self.lastPerformancesCache.removeValue(forKey: name)
                    }
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
        
        // Обращаемся к моделям безопасно в MainActor
        recoveryCalculationTask = Task { @MainActor in
            if debounce { try? await Task.sleep(nanoseconds: 150_000_000) }
            guard !Task.isCancelled else { return }
            let result = RecoveryCalculator.calculate(hours: hours, workouts: self.workouts)
            self.recoveryStatus = result
        }
    }
    
    // MARK: - 4. Analysis & Recommendations (Delegated)
    func getImbalanceRecommendation() -> (title: String, message: String)? { AnalyticsManager.getImbalanceRecommendation(recentWorkouts: workouts) }
    func getExerciseTrends(period: StatsView.Period = .month) -> [ExerciseTrend] { AnalyticsManager.getExerciseTrends(workouts: workouts, period: period) }
    func getProgressForecast(daysAhead: Int = 30) -> [ProgressForecast] { AnalyticsManager.getProgressForecast(workouts: workouts, daysAhead: daysAhead) }
    func getWeakPoints() -> [WeakPoint] { AnalyticsManager.getWeakPoints(recentWorkouts: workouts) }
    func getRecommendations() -> [Recommendation] { AnalyticsManager.getRecommendations(workouts: workouts, recoveryStatus: recoveryStatus) }
    func getDetailedComparison(period: StatsView.Period) -> [DetailedComparison] { AnalyticsManager.getDetailedComparison(workouts: workouts, period: period) }
    
    // MARK: - 5. Data Management (Workouts)
    func addWorkout(_ workout: Workout) {
        modelContext?.insert(workout)
        saveChanges()
    }
    
    func deleteWorkout(_ workout: Workout) {
        modelContext?.delete(workout)
        saveChanges()
    }
    
    // ИСПРАВЛЕНИЕ: Массовое удаление, чтобы не вызывать saveChanges() много раз в цикле UI
    func deleteWorkouts(_ workoutsToDelete: [Workout]) {
        for workout in workoutsToDelete {
            modelContext?.delete(workout)
        }
        saveChanges()
    }
    
    func getLastPerformance(for exerciseName: String, currentWorkoutId: UUID) -> Exercise? { lastPerformancesCache[exerciseName] }
    
    // MARK: - 6. Data Management (Presets)
    func updatePreset(_ preset: WorkoutPreset) { 
        saveChanges()
    }
    
    func deletePreset(_ preset: WorkoutPreset) { 
        modelContext?.delete(preset)
        saveChanges()
    }
    
    func deletePreset(at offsets: IndexSet) { 
        for index in offsets {
            let preset = presets[index]
            modelContext?.delete(preset)
        }
        saveChanges()
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
    
    private func saveCustomExercises() { 
        let currentExercises = customExercises
        let url = getDocumentURL(for: "SavedCustomExercises.json")
        // Здесь это безопасно, так как currentExercises не являются @Model
        Task.detached(priority: .background) {
            if let e = try? JSONEncoder().encode(currentExercises) { 
                try? e.write(to: url) 
            }
        }
    }
    
    private func loadCustomExercises() { if let d = try? Data(contentsOf: getDocumentURL(for: "SavedCustomExercises.json")), let dec = try? JSONDecoder().decode([CustomExerciseDefinition].self, from: d) { customExercises = dec } }
    
    // MARK: - 8. Import / Export
    
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
    
    func importPreset(from url: URL) -> Bool {
        do {
            let preset = try ImportExportService.importPreset(from: url)
            modelContext?.insert(preset)
            saveChanges()
            return true
        } catch {
            showError(title: "Import Failed", message: error.localizedDescription)
            return false
        }
    }
    
    // MARK: - 9. Widget
    func updateWidgetData() {
        // Мы собираем данные на главном потоке (так как обращаемся к @Model)
        Task { @MainActor in
            let currentStreak = self.calculateWorkoutStreak()
            var points: [WidgetData.WeeklyPoint] = []
            let cal = Calendar.current
            
            for i in (0...5).reversed() {
                if let date = cal.date(byAdding: .weekOfYear, value: -i, to: Date()) {
                    let interval = cal.dateInterval(of: .weekOfYear, for: date)!
                    let count = self.workouts.filter { interval.contains($0.date) }.count
                    let fmt = DateFormatter()
                    fmt.dateFormat = "M/d"
                    points.append(WidgetData.WeeklyPoint(label: fmt.string(from: interval.start), count: count))
                }
            }
            
            // Запись на диск передаем в фон, потому что данные теперь thread-safe (Value Types)
            Task.detached(priority: .background) {
                WidgetDataManager.save(streak: currentStreak, weeklyStats: points)
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }
}
