//
//  WorkoutViewModel.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 24.12.25.
//
//  Главная ViewModel приложения.
//  Является "мозгом", управляющим локальным стейтом и ошибками.
//  Вся работа со SwiftData переведена на фоновые потоки или инкапсулирована по MVVM.
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
    
    // Кэш для UI (обновляется из SwiftData)
    @Published var customExercises: [CustomExerciseDefinition] = []
    @Published var deletedDefaultExercises: Set<String> = []
    
    @Published var recoveryStatus: [MuscleRecoveryStatus] = []
    @Published var progressManager = ProgressManager()
    
    // Кэш для дашборда
    @Published var dashboardMuscleData: [(muscle: String, count: Int)] = []
    @Published var dashboardTotalExercises: Int = 0
    @Published var dashboardTopExercises: [(name: String, count: Int)] = []
    
    // ОПТИМИЗАЦИЯ: Кэш для глобальной аналитики
    @Published var streakCount: Int = 0
    @Published var bestWeekStats: PeriodStats = PeriodStats()
    @Published var bestMonthStats: PeriodStats = PeriodStats()
    @Published var weakPoints: [WeakPoint] = []
    @Published var recommendations: [Recommendation] = []
    
    // ИСПРАВЛЕНИЕ: Хранение активной тренировки для защиты от OOM
    @Published var activeWorkoutToResume: Workout?
    func removeExercise(_ exercise: Exercise, from workout: Workout, context: ModelContext) {
            if let index = workout.exercises.firstIndex(where: { $0.id == exercise.id }) {
                workout.exercises.remove(at: index)
            }
            context.delete(exercise)
            try? context.save()
        }
        
    
    // MARK: - Error Handling
    struct AppError: Identifiable { let id = UUID(); let title: String; let message: String }
    @Published var currentError: AppError?
    
    func showError(title: String, message: String) {
        self.currentError = AppError(title: title, message: message)
    }
    
    init() {
        MuscleMapping.preload()
    }
    
    // MARK: - MVVM Entity Manipulation (Sets & Exercises)
    
    func addSet(_ set: WorkoutSet, to exercise: Exercise, context: ModelContext) {
        context.insert(set)
        exercise.setsList.append(set)
        exercise.updateAggregates()
        try? context.save()
    }
    
    func deleteSet(_ set: WorkoutSet, from exercise: Exercise, context: ModelContext) {
        if let index = exercise.setsList.firstIndex(where: { $0.id == set.id }) {
            exercise.setsList.remove(at: index)
        }
        context.delete(set)
        
        // Re-index remaining sets to maintain sequence
        let remainingSets = exercise.sortedSets
        for (i, remainingSet) in remainingSets.enumerated() {
            remainingSet.index = i + 1
        }
        
        exercise.updateAggregates()
        try? context.save()
    }
    

        
        // 👇 ДОБАВЬ ВОТ ЭТОТ МЕТОД:
        func removeSubExercise(_ subExercise: Exercise, from superset: Exercise, context: ModelContext) {
            if let index = superset.subExercises.firstIndex(where: { $0.id == subExercise.id }) {
                superset.subExercises.remove(at: index)
            }
            context.delete(subExercise)
            superset.updateAggregates()
            try? context.save()
        }
        // 👆 КОНЕЦ ВСТАВКИ
    
    // MARK: - ЗОМБИ-ТРЕНИРОВКИ И ВОССТАНОВЛЕНИЕ (Защита от OOM)
    
    /// Находит тренировки без endTime. Вызывайте при старте приложения.
    func cleanupAndFindActiveWorkouts(context: ModelContext) {
        let descriptor = FetchDescriptor<Workout>(predicate: #Predicate<Workout> { $0.endTime == nil })
        guard let activeWorkouts = try? context.fetch(descriptor) else { return }
        
        for workout in activeWorkouts {
            let hoursSinceStart = Date().timeIntervalSince(workout.date) / 3600
            if hoursSinceStart > 12 {
                // Тренировка-зомби (зависла более 12 часов назад). Закрываем принудительно.
                workout.endTime = workout.date.addingTimeInterval(3600) // Фиктивный час
                processCompletedWorkout(workout, context: context)
            } else {
                // Свежая незавершенная тренировка. Предлагаем восстановить.
                self.activeWorkoutToResume = workout
            }
        }
        try? context.save()
    }
    
    // MARK: - ИНКАПСУЛЯЦИЯ УДАЛЕНИЯ ДЛЯ ЗАЩИТЫ СТАТИСТИКИ
    
    /// Единая точка удаления тренировки. Гарантирует, что статистика не рассинхронизируется.
    func deleteWorkout(_ workout: Workout, context: ModelContext) {
        let container = context.container
        context.delete(workout)
        try? context.save()
        
        // Полностью перестраиваем статистику, чтобы гарантировать консистентность
        Task {
            await rebuildAllStats(container: container)
        }
    }
    
    // MARK: - INCREMENTAL WORKOUT COMPLETION (Защита от N+1)
    
    /// Эту функцию ВАЖНО вызывать ровно один раз при нажатии кнопки "Завершить тренировку".
    func processCompletedWorkout(_ workout: Workout, context: ModelContext) {
        
        // 1. ОБНОВЛЯЕМ АГРЕГАТЫ НА УРОВНЕ САМОЙ ТРЕНИРОВКИ
        if let endTime = workout.endTime {
            workout.durationSeconds = Int(endTime.timeIntervalSince(workout.date))
        } else {
            workout.durationSeconds = 0
        }
        
        var totalEffort = 0
        var exercisesWithCompletedSets = 0
        var strengthVol = 0.0
        var cardioDist = 0.0
        
        for exercise in workout.exercises {
            // Убеждаемся, что агрегаты самого упражнения актуальны
            exercise.updateAggregates()
            
            let targets = exercise.isSuperset ? exercise.subExercises : [exercise]
            var hasCompletedSet = false
            
            for sub in targets {
                sub.updateAggregates()
                
                if sub.setsList.contains(where: { $0.isCompleted }) {
                    hasCompletedSet = true
                }
                
                if sub.type == .strength {
                    strengthVol += sub.exerciseVolume
                } else if sub.type == .cardio {
                    cardioDist += sub.setsList.filter { $0.isCompleted }.compactMap { $0.distance }.reduce(0.0, +)
                }
            }
            
            if hasCompletedSet {
                totalEffort += exercise.effort
                exercisesWithCompletedSets += 1
            }
        }
        
        // Effort slider returns 1-10, we want a percentage 10-100
        let avgEffort = exercisesWithCompletedSets > 0 ? Double(totalEffort) / Double(exercisesWithCompletedSets) : 0.0
        workout.effortPercentage = Int(avgEffort * 10)
        workout.totalStrengthVolume = strengthVol
        workout.totalCardioDistance = cardioDist
        
        // 2. ОБНОВЛЯЕМ ГЛОБАЛЬНУЮ СТАТИСТИКУ
        let uStatsDesc = FetchDescriptor<UserStats>()
        let uStats = (try? context.fetch(uStatsDesc))?.first ?? UserStats()
        if uStats.modelContext == nil { context.insert(uStats) }
        
        uStats.totalWorkouts += 1
        uStats.totalVolume += workout.totalStrengthVolume     // O(1) complexity now
        uStats.totalDistance += workout.totalCardioDistance   // O(1) complexity now
        
        let hour = Calendar.current.component(.hour, from: workout.date)
        if hour < 9 { uStats.earlyWorkouts += 1 }
        if hour >= 20 { uStats.nightWorkouts += 1 }
        
        // Быстрый Dictionary-загрузчик (избегает N+1 внутри цикла)
        let allExStats = (try? context.fetch(FetchDescriptor<ExerciseStat>())) ?? []
        let allMStats = (try? context.fetch(FetchDescriptor<MuscleStat>())) ?? []
        var exStatsDict = Dictionary(uniqueKeysWithValues: allExStats.map { ($0.exerciseName, $0) })
        var mStatsDict = Dictionary(uniqueKeysWithValues: allMStats.map { ($0.muscleName, $0) })
        
        for exercise in workout.exercises {
            let targets = exercise.isSuperset ? exercise.subExercises : [exercise]
            for ex in targets {
                let name = ex.name
                
                let exStat = exStatsDict[name] ?? {
                    let newStat = ExerciseStat(exerciseName: name)
                    context.insert(newStat)
                    exStatsDict[name] = newStat
                    return newStat
                }()
                
                exStat.totalCount += 1
                if let encoded = try? JSONEncoder().encode(ex.toDTO()) {
                    exStat.lastPerformanceDTO = encoded
                }
                
                if ex.type == .strength {
                    let maxWeight = ex.setsList.filter { $0.isCompleted && $0.type != .warmup }.compactMap { $0.weight }.max() ?? 0
                    if maxWeight > exStat.maxWeight { exStat.maxWeight = maxWeight }
                }
                
                let isCardio = ex.type == .cardio || ex.type == .duration || ex.muscleGroup == "Cardio"
                if !isCardio {
                    let mName = ex.muscleGroup
                    let mStat = mStatsDict[mName] ?? {
                        let newMStat = MuscleStat(muscleName: mName)
                        context.insert(newMStat)
                        mStatsDict[mName] = newMStat
                        return newMStat
                    }()
                    mStat.totalCount += 1
                }
            }
        }
        
        try? context.save()
        refreshAllCaches(container: context.container)
    }
    
    // MARK: - BACKGROUND CACHE REFRESH (Оптимизировано, без OOM)
    
    func refreshAllCaches(container: ModelContainer) {
        Task.detached(priority: .userInitiated) {
            let context = ModelContext(container)
            
            // 1. Проверяем, нужна ли миграция или пересчет
            let exStatsCount = (try? context.fetchCount(FetchDescriptor<ExerciseStat>())) ?? 0
            let totalWorkoutsDesc = FetchDescriptor<Workout>(predicate: #Predicate<Workout> { $0.endTime != nil })
            let totalWorkoutsCount = (try? context.fetchCount(totalWorkoutsDesc)) ?? 0
            
            if exStatsCount == 0 && totalWorkoutsCount > 0 {
                await self.rebuildAllStats(container: container)
                return // Пересчет сам перезапустит этот метод
            }
            
            // 2. Читаем готовые агрегированные модели O(1)
            let exStats = (try? context.fetch(FetchDescriptor<ExerciseStat>())) ?? []
            let mStats = (try? context.fetch(FetchDescriptor<MuscleStat>())) ?? []
            
            var partialLastPerformancesDTO: [String: ExerciseDTO] = [:]
            var partialPRs: [String: Double] = [:]
            var exerciseCounts: [String: Int] = [:]
            var stats: [String: Int] = [:]
            
            for ex in exStats {
                partialPRs[ex.exerciseName] = ex.maxWeight
                exerciseCounts[ex.exerciseName] = ex.totalCount
                if let data = ex.lastPerformanceDTO, let dto = try? JSONDecoder().decode(ExerciseDTO.self, from: data) {
                    partialLastPerformancesDTO[ex.exerciseName] = dto
                }
            }
            
            for m in mStats {
                stats[m.muscleName] = m.totalCount
            }
            
            // 3. Достаем "сырые" тренировки только за последние 90 дней для Recovery и Аналитики
            let calendar = Calendar.current
            let threeMonthsAgo = calendar.date(byAdding: .month, value: -3, to: Date())!
            
            var recentDesc = FetchDescriptor<Workout>(
                predicate: #Predicate<Workout> { $0.endTime != nil && $0.date >= threeMonthsAgo },
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            recentDesc.fetchLimit = 150 // Гарантированная защита от OOM
            let recentWorkouts = (try? context.fetch(recentDesc)) ?? []
            
            let recovery = RecoveryCalculator.calculate(hours: nil, workouts: recentWorkouts)
            let sortedMuscleData = stats.map { (muscle: $0.key, count: $0.value) }.filter { $0.count > 0 }.sorted { $0.count > $1.count }
            let totalExCount = sortedMuscleData.reduce(0) { $0 + $1.count }
            let topExercises = Array(exerciseCounts.sorted { $0.value > $1.value || ($0.value == $1.value && $0.key < $1.key) }.prefix(5)).map { (name: $0.key, count: $0.value) }
            
            let streak = StatisticsManager.calculateWorkoutStreak(workouts: recentWorkouts)
            let bWeek = StatisticsManager.getBestStats(for: .week, workouts: recentWorkouts)
            let bMonth = StatisticsManager.getBestStats(for: .month, workouts: recentWorkouts)
            let weakPts = AnalyticsManager.getWeakPoints(recentWorkouts: recentWorkouts)
            let recs = AnalyticsManager.getRecommendations(workouts: recentWorkouts, recoveryStatus: recovery)
            
            await MainActor.run {
                self.loadDictionary(context: ModelContext(container))
                
                var newPerformancesCache: [String: Exercise] = [:]
                for (name, dto) in partialLastPerformancesDTO {
                    newPerformancesCache[name] = Exercise(from: dto)
                }
                
                self.lastPerformancesCache = newPerformancesCache
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
    
    // ИСПРАВЛЕНИЕ: Универсальный инструмент пересчета статистики, решающий проблему рассинхронизации.
    func rebuildAllStats(container: ModelContainer) async {
        Task.detached(priority: .background) {
            let context = ModelContext(container)
            
            // Полная очистка старых агрегатов для чистого пересчета
            try? context.delete(model: UserStats.self)
            try? context.delete(model: ExerciseStat.self)
            try? context.delete(model: MuscleStat.self)
            
            let allDesc = FetchDescriptor<Workout>(predicate: #Predicate<Workout> { $0.endTime != nil })
            guard let allWorkouts = try? context.fetch(allDesc) else { return }
            
            let uStats = UserStats()
            context.insert(uStats)
            
            var exStatsDict: [String: ExerciseStat] = [:]
            var mStatsDict: [String: MuscleStat] = [:]
            
            for workout in allWorkouts {
                
                // BACKWARD COMPATIBILITY: Force generate aggregates for old workouts
                if let endTime = workout.endTime, workout.durationSeconds == 0 {
                    workout.durationSeconds = Int(endTime.timeIntervalSince(workout.date))
                }
                
                var strVol = 0.0
                var carDist = 0.0
                var totEff = 0
                var exComp = 0
                
                for exercise in workout.exercises {
                    exercise.updateAggregates()
                    
                    let targets = exercise.isSuperset ? exercise.subExercises : [exercise]
                    var hasComp = false
                    
                    for sub in targets {
                        sub.updateAggregates()
                        if sub.setsList.contains(where: { $0.isCompleted }) {
                            hasComp = true
                        }
                        
                        if sub.type == .strength {
                            strVol += sub.exerciseVolume
                        } else if sub.type == .cardio {
                            carDist += sub.setsList.filter { $0.isCompleted }.compactMap { $0.distance }.reduce(0, +)
                        }
                        
                        let name = sub.name
                        let exStat = exStatsDict[name] ?? {
                            let stat = ExerciseStat(exerciseName: name)
                            context.insert(stat)
                            exStatsDict[name] = stat
                            return stat
                        }()
                        
                        exStat.totalCount += 1
                        if let encoded = try? JSONEncoder().encode(sub.toDTO()) {
                            exStat.lastPerformanceDTO = encoded
                        }
                        if sub.type == .strength {
                            let maxWeight = sub.setsList.filter { $0.isCompleted && $0.type != .warmup }.compactMap { $0.weight }.max() ?? 0
                            if maxWeight > exStat.maxWeight { exStat.maxWeight = maxWeight }
                        }
                        
                        let isCardio = sub.type == .cardio || sub.type == .duration || sub.muscleGroup == "Cardio"
                        if !isCardio {
                            let mName = sub.muscleGroup
                            let mStat = mStatsDict[mName] ?? {
                                let stat = MuscleStat(muscleName: mName)
                                context.insert(stat)
                                mStatsDict[mName] = stat
                                return stat
                            }()
                            mStat.totalCount += 1
                        }
                    }
                    
                    if hasComp {
                        totEff += exercise.effort
                        exComp += 1
                    }
                }
                
                // Set workout level aggregates
                workout.totalStrengthVolume = strVol
                workout.totalCardioDistance = carDist
                if exComp > 0 {
                    workout.effortPercentage = Int((Double(totEff) / Double(exComp)) * 10)
                }
                
                // Add to global User Stats
                uStats.totalWorkouts += 1
                uStats.totalVolume += workout.totalStrengthVolume
                uStats.totalDistance += workout.totalCardioDistance
                
                let hour = Calendar.current.component(.hour, from: workout.date)
                if hour < 9 { uStats.earlyWorkouts += 1 }
                if hour >= 20 { uStats.nightWorkouts += 1 }
            }
            
            try? context.save()
            
            // После завершения пересчета запускаем нормальное обновление кэшей
            await self.refreshAllCaches(container: container)
        }
    }
    
    func getLastPerformance(for exerciseName: String) -> Exercise? { lastPerformancesCache[exerciseName] }
    
    // MARK: - Default Initialization (SwiftData)
    
    func checkAndGenerateDefaultPresets(context: ModelContext) {
        let descriptor = FetchDescriptor<WorkoutPreset>()
        let count = (try? context.fetchCount(descriptor)) ?? 0
        
        if count == 0 {
            for example in Workout.examples {
                let preset = WorkoutPreset(id: UUID(), name: example.title, icon: example.icon, exercises: [])
                context.insert(preset)
                
                for exercise in example.exercises {
                    let duplicatedExercise = exercise.duplicate()
                    context.insert(duplicatedExercise)
                    preset.exercises.append(duplicatedExercise)
                    
                    for set in duplicatedExercise.setsList {
                        context.insert(set)
                    }
                    
                    for sub in duplicatedExercise.subExercises {
                        context.insert(sub)
                        for subSet in sub.setsList {
                            context.insert(subSet)
                        }
                    }
                }
            }
            try? context.save()
        }
    }
    
    // MARK: - Data Management (Dictionary / Custom Exercises)
    
    func loadDictionary(context: ModelContext) {
            let descriptor = FetchDescriptor<ExerciseDictionaryItem>()
            let count = (try? context.fetchCount(descriptor)) ?? 0
            
            // Автоматическая миграция из старых JSON
            if count == 0 {
                migrateJSONToSwiftData(context: context)
            }
            
            if let items = try? context.fetch(descriptor) {
                // ИСПРАВЛЕНИЕ: Исключаем скрытые кастомные упражнения из UI каталога (!$0.isHidden)
                self.customExercises = items.filter { $0.isCustom && !$0.isHidden }.map {
                    CustomExerciseDefinition(id: UUID(), name: $0.name, category: $0.category, targetedMuscles: $0.targetedMuscles, type: $0.type)
                }
                self.deletedDefaultExercises = Set(items.filter { $0.isHidden && !$0.isCustom }.map { $0.name })
            }
        }
    
    
    private func migrateJSONToSwiftData(context: ModelContext) {
        let fm = FileManager.default
        let customUrl = URL.documentsDirectory.appendingPathComponent("SavedCustomExercises.json")
        let deletedUrl = URL.documentsDirectory.appendingPathComponent("DeletedDefaultExercises.json")
        
        var didMigrate = false
        
        if let data = try? Data(contentsOf: customUrl),
           let customEx = try? JSONDecoder().decode([CustomExerciseDefinition].self, from: data) {
            for ex in customEx {
                let item = ExerciseDictionaryItem(name: ex.name, category: ex.category, targetedMuscles: ex.targetedMuscles, type: ex.type, isCustom: true, isHidden: false)
                context.insert(item)
            }
            try? fm.removeItem(at: customUrl)
            didMigrate = true
        }
        
        if let data = try? Data(contentsOf: deletedUrl),
           let deletedEx = try? JSONDecoder().decode(Set<String>.self, from: data) {
            for exName in deletedEx {
                let category = Exercise.catalog.first(where: { $0.value.contains(exName) })?.key ?? "Other"
                let item = ExerciseDictionaryItem(name: exName, category: category, targetedMuscles: [], type: .strength, isCustom: false, isHidden: true)
                context.insert(item)
            }
            try? fm.removeItem(at: deletedUrl)
            didMigrate = true
        }
        
        if didMigrate {
            try? context.save()
        }
    }
    
    var combinedCatalog: [String: [String]] {
        var catalog = Exercise.catalog
        for (category, exercises) in catalog { catalog[category] = exercises.filter { !deletedDefaultExercises.contains($0) } }
        for custom in customExercises { var list = catalog[custom.category] ?? []; if !list.contains(custom.name) { list.append(custom.name) }; catalog[custom.category] = list }
        return catalog
    }
    
    func isCustomExercise(name: String) -> Bool { customExercises.contains { $0.name == name } }
    
    func addCustomExercise(name: String, category: String, muscles: [String], type: ExerciseType = .strength, context: ModelContext) {
        let item = ExerciseDictionaryItem(name: name, category: category, targetedMuscles: muscles, type: type, isCustom: true, isHidden: false)
        context.insert(item)
        try? context.save()
        
        loadDictionary(context: context)
        MuscleMapping.updateCustomMapping(name: name, muscles: muscles)
    }
    
    private func deleteCustomExercise(name: String, category: String, context: ModelContext) {
            let descriptor = FetchDescriptor<ExerciseDictionaryItem>(predicate: #Predicate { $0.name == name && $0.isCustom })
            if let items = try? context.fetch(descriptor), let item = items.first {
                // ИСПРАВЛЕНИЕ: Soft Delete (скрываем упражнение из каталога, но оставляем для истории)
                item.isHidden = true
                try? context.save()
            }
            
            loadDictionary(context: context)
            MuscleMapping.updateCustomMapping(name: name, muscles: nil)
        }
    func deleteExercise(name: String, category: String, context: ModelContext) {
        if isCustomExercise(name: name) {
            deleteCustomExercise(name: name, category: category, context: context)
        } else {
            let item = ExerciseDictionaryItem(name: name, category: category, targetedMuscles: [], type: .strength, isCustom: false, isHidden: true)
            context.insert(item)
            try? context.save()
            loadDictionary(context: context)
        }
    }
    
    // MARK: - Import / Export
    
    func generateShareLink(for preset: WorkoutPreset) -> URL? {
        do {
            return try ImportExportService.generateShareLink(for: preset)
        } catch {
            showError(title: String(localized: "Export Failed"), message: error.localizedDescription)
            return nil
        }
    }
    
    func exportPresetToFile(_ preset: WorkoutPreset) -> URL? {
        do {
            return try ImportExportService.exportPresetToFile(preset)
        } catch {
            showError(title: String(localized: "Export Failed"), message: error.localizedDescription)
            return nil
        }
    }
    
    func exportPresetToCSV(_ preset: WorkoutPreset) -> URL? {
        do { return try ImportExportService.exportPresetToCSV(preset) } catch { showError(title: String(localized: "Export Failed"), message: error.localizedDescription); return nil }
    }
    
    func importPreset(from url: URL, context: ModelContext) -> Bool {
        do {
            let preset = try ImportExportService.importPreset(from: url)
            
            let baseName = preset.name
            var finalName = baseName
            var suffixCounter = 1
            
            while true {
                let nameToCheck = finalName
                let descriptor = FetchDescriptor<WorkoutPreset>(predicate: #Predicate { $0.name == nameToCheck })
                let existingCount = (try? context.fetchCount(descriptor)) ?? 0
                
                if existingCount == 0 {
                    break
                }
                
                finalName = "\(baseName) (\(suffixCounter))"
                suffixCounter += 1
            }
            
            preset.name = finalName
            context.insert(preset)
            try? context.save()
            
            return true
            
        } catch {
            showError(title: String(localized: "Import Failed"), message: error.localizedDescription)
            return false
        }
    }
    
    // MARK: - Widget
    
    func updateWidgetData(container: ModelContainer) {
        Task.detached(priority: .background) {
            let context = ModelContext(container)
            let sixWeeksAgo = Calendar.current.date(byAdding: .weekOfYear, value: -6, to: Date())!
            var descriptor = FetchDescriptor<Workout>(
                predicate: #Predicate<Workout> { $0.endTime != nil && $0.date >= sixWeeksAgo },
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            descriptor.fetchLimit = 100
            
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
