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
    
    // MARK: - Nested Models (Сделаны Sendable для безопасной передачи из ModelActor)
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
    
    // ВАЖНО: Восстановленные структуры для работы UI (не DTO)
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
    
    // MARK: - Error Handling
    struct AppError: Identifiable { let id = UUID(); let title: String; let message: String }
    @Published var currentError: AppError?
    
    func showError(title: String, message: String) {
        self.currentError = AppError(title: title, message: message)
    }
    
    init() {
        MuscleMapping.preload()
    }
    
    // MARK: - MVVM Entity Manipulation
    
    func addSet(to exercise: Exercise, index: Int, weight: Double?, reps: Int?, distance: Double?, time: Int?, type: SetType, isCompleted: Bool, container: ModelContainer) {
        // 🎼 Все делаем строго на MainActor
        let newSet = WorkoutSet(index: index, weight: weight, reps: reps, distance: distance, time: time, isCompleted: isCompleted, type: type)
        
        exercise.modelContext?.insert(newSet)
        exercise.setsList.append(newSet)
        exercise.updateAggregates()
        
        try? exercise.modelContext?.save()
    }
    
    func deleteSet(_ set: WorkoutSet, from exercise: Exercise, container: ModelContainer) {
        if let index = exercise.setsList.firstIndex(where: { $0.id == set.id }) {
            exercise.setsList.remove(at: index)
        }
        
        exercise.modelContext?.delete(set)
        
        let remainingSets = exercise.sortedSets
        for (i, remainingSet) in remainingSets.enumerated() { remainingSet.index = i + 1 }
        exercise.updateAggregates()
        
        try? exercise.modelContext?.save()
    }
    
    func removeSubExercise(_ subExercise: Exercise, from superset: Exercise, container: ModelContainer) {
        if let index = superset.subExercises.firstIndex(where: { $0.id == subExercise.id }) {
            superset.subExercises.remove(at: index)
        }
        
        superset.modelContext?.delete(subExercise)
        superset.updateAggregates()
        
        try? superset.modelContext?.save()
    }
    
    func removeExercise(_ exercise: Exercise, from workout: Workout, container: ModelContainer) {
        if let index = workout.exercises.firstIndex(where: { $0.id == exercise.id }) {
            workout.exercises.remove(at: index)
        }
        
        workout.modelContext?.delete(exercise)
        
        try? workout.modelContext?.save()
    }
    
    // MARK: - ЗОМБИ-ТРЕНИРОВКИ И ВОССТАНОВЛЕНИЕ
    
    func cleanupAndFindActiveWorkouts(container: ModelContainer) {
        Task {
            let repository = WorkoutRepository(modelContainer: container)
            if let _ = try? await repository.cleanupAndFindActiveWorkouts() { }
        }
    }
    
    func deleteWorkout(_ workout: Workout, container: ModelContainer) {
        let workoutID = workout.persistentModelID
        Task {
            let repository = WorkoutRepository(modelContainer: container)
            try? await repository.deleteWorkout(workoutID: workoutID)
            await repository.rebuildAllStats()
            self.refreshAllCaches(container: container)
        }
    }
    
    func processCompletedWorkout(_ workout: Workout, container: ModelContainer) {
        let workoutID = workout.persistentModelID
        Task {
            let repository = WorkoutRepository(modelContainer: container)
            try? await repository.processCompletedWorkout(workoutID: workoutID)
            self.refreshAllCaches(container: container)
        }
    }
    
    // MARK: - BACKGROUND CACHE REFRESH
    
    func refreshAllCaches(container: ModelContainer) {
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
                    
                    // Маппинг DTO обратно в удобные структуры UI
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
    
    func rebuildAllStats(container: ModelContainer) {
        Task {
            let repository = WorkoutRepository(modelContainer: container)
            await repository.rebuildAllStats()
            self.refreshAllCaches(container: container)
        }
    }
    
    func getLastPerformance(for exerciseName: String) -> Exercise? { lastPerformancesCache[exerciseName] }
    
    // MARK: - Default Initialization
    
    func checkAndGenerateDefaultPresets(container: ModelContainer) {
        Task {
            let repository = WorkoutRepository(modelContainer: container)
            try? await repository.checkAndGenerateDefaultPresets()
        }
    }
    
    // MARK: - Data Management (Dictionary / Custom Exercises)
    
    func loadDictionary(container: ModelContainer) {
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
    
    func addCustomExercise(name: String, category: String, muscles: [String], type: ExerciseType = .strength, container: ModelContainer) {
        Task {
            let repository = WorkoutRepository(modelContainer: container)
            try? await repository.addCustomExercise(name: name, category: category, muscles: muscles, type: type)
            await MainActor.run {
                MuscleMapping.updateCustomMapping(name: name, muscles: muscles)
                self.loadDictionary(container: container)
            }
        }
    }
    
    func deleteCustomExercise(name: String, category: String, container: ModelContainer) {
        Task {
            let repository = WorkoutRepository(modelContainer: container)
            try? await repository.deleteCustomExercise(name: name, category: category)
            await MainActor.run {
                MuscleMapping.updateCustomMapping(name: name, muscles: nil)
                self.loadDictionary(container: container)
            }
        }
    }
    
    func deleteExercise(name: String, category: String, container: ModelContainer) {
        if isCustomExercise(name: name) {
            deleteCustomExercise(name: name, category: category, container: container)
        } else {
            Task {
                let repository = WorkoutRepository(modelContainer: container)
                try? await repository.hideDefaultExercise(name: name, category: category)
                await MainActor.run { self.loadDictionary(container: container) }
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
    
    func importPreset(from url: URL, container: ModelContainer) -> Bool {
        do {
            let preset = try ImportExportService.importPreset(from: url)
            Task {
                let repository = WorkoutRepository(modelContainer: container)
                try? await repository.importPreset(dto: preset.toDTO())
                self.refreshAllCaches(container: container)
            }
            return true
        } catch {
            showError(title: String(localized: "Import Failed"), message: error.localizedDescription)
            return false
        }
    }
    
    // MARK: - Widget
    
    func updateWidgetData(container: ModelContainer) {
        Task {
            let repository = WorkoutRepository(modelContainer: container)
            try? await repository.updateWidgetData()
        }
    }
    
    
    // MARK: - AI Adjustments
    func applyAIAdjustment(_ adjustment: InWorkoutResponseDTO, to workout: Workout, context: ModelContext) {
        guard workout.isActive else { return }
        
        switch adjustment.actionType {
        case "reduceRemainingLoad":
            let percentage = adjustment.valuePercentage ?? 10.0
            let multiplier = 1.0 - (percentage / 100.0)
            for ex in workout.exercises where !ex.isCompleted {
                for set in ex.setsList where !set.isCompleted {
                    if let currentW = set.weight, currentW > 0 {
                        let newWeight = currentW * multiplier
                        set.weight = round(newWeight / 2.5) * 2.5
                    }
                }
                ex.updateAggregates()
            }
            
        case "skipExercise":
            guard let targetName = adjustment.targetExerciseName,
                  let targetEx = workout.exercises.first(where: { $0.name.lowercased() == targetName.lowercased() && !$0.isCompleted }) else { break }
            
            let hasCompletedSets = targetEx.setsList.contains(where: { $0.isCompleted })
            
            if hasCompletedSets {
                for set in targetEx.setsList where !set.isCompleted { context.delete(set) }
                targetEx.setsList.removeAll(where: { !$0.isCompleted })
                targetEx.isCompleted = true
            } else {
                if let idx = workout.exercises.firstIndex(of: targetEx) {
                    workout.exercises.remove(at: idx)
                    context.delete(targetEx)
                }
            }
            
        case "dropWeight":
            guard let targetName = adjustment.targetExerciseName,
                  let targetExercise = workout.exercises.first(where: { $0.name.lowercased() == targetName.lowercased() }) else { break }
            
            if let nextSet = targetExercise.setsList.sorted(by: { $0.index < $1.index }).first(where: { !$0.isCompleted }) {
                if let currentWeight = nextSet.weight, let percentage = adjustment.valuePercentage {
                    let newWeight = currentWeight * (1.0 - (percentage / 100.0))
                    nextSet.weight = round(newWeight / 2.5) * 2.5
                }
            }
            targetExercise.updateAggregates()
            
        case "addSet":
            guard let targetName = adjustment.targetExerciseName,
                  let targetExercise = workout.exercises.first(where: { $0.name.lowercased() == targetName.lowercased() }) else { break }
            
            let newIndex = (targetExercise.setsList.map { $0.index }.max() ?? 0) + 1
            let newSet = WorkoutSet(
                index: newIndex,
                weight: adjustment.valueWeightKg ?? targetExercise.firstSetWeight,
                reps: adjustment.valueReps ?? targetExercise.firstSetReps,
                isCompleted: false,
                type: .failure
            )
            context.insert(newSet)
            targetExercise.setsList.append(newSet)
            targetExercise.updateAggregates()
            
        case "replaceExercise":
            guard let targetName = adjustment.targetExerciseName,
                  let targetExercise = workout.exercises.first(where: { $0.name.lowercased() == targetName.lowercased() }),
                  let newName = adjustment.replacementExerciseName else { break }
            
            let completedSetsCount = targetExercise.setsList.filter({ $0.isCompleted }).count
            let totalSetsCount = targetExercise.setsList.count
            let remainingSets = totalSetsCount - completedSetsCount
            
            let newExWeight = adjustment.valueWeightKg ?? targetExercise.firstSetWeight
            let newExReps = adjustment.valueReps ?? targetExercise.firstSetReps
            let newExSets = remainingSets > 0 ? remainingSets : 3
            
            let newExercise = Exercise(name: newName, muscleGroup: targetExercise.muscleGroup, type: targetExercise.type, sets: newExSets, reps: newExReps, weight: newExWeight)
            context.insert(newExercise)
            
            if completedSetsCount == 0 {
                if let idx = workout.exercises.firstIndex(of: targetExercise) {
                    workout.exercises[idx] = newExercise
                    context.delete(targetExercise)
                }
            } else {
                for set in targetExercise.setsList where !set.isCompleted { context.delete(set) }
                targetExercise.setsList.removeAll(where: { !$0.isCompleted })
                targetExercise.isCompleted = true
                targetExercise.updateAggregates()
                
                if let idx = workout.exercises.firstIndex(of: targetExercise) {
                    workout.exercises.insert(newExercise, at: idx + 1)
                }
            }
            
        default:
            break
        }
        
        try? context.save()
    }

}
