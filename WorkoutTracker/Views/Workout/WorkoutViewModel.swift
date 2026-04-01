internal import SwiftUI
import SwiftData
import AudioToolbox
import WidgetKit
internal import UniformTypeIdentifiers
import Observation

// MARK: - Main ViewModel
@Observable
@MainActor
final class WorkoutViewModel {
    
    // MARK: - Nested Types
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
    struct AppError: Identifiable { let id = UUID(); let title: String; let message: String }
    
    struct WorkoutAnalyticsData: Sendable {
        var intensity: [String: Int] = [:]
        var volume: Double = 0.0
        var chartExercises: [ExerciseChartDTO] = []
    }
    
    // MARK: - Published Properties (State)
    var lastPerformancesCache: [String: Exercise] = [:]
    var personalRecordsCache: [String: Double] = [:]
    var recoveryStatus: [MuscleRecoveryStatus] = []
    var dashboardMuscleData: [MuscleCountDTO] = []
    var dashboardTotalExercises: Int = 0
    var dashboardTopExercises: [ExerciseCountDTO] = []
    var streakCount: Int = 0
    var bestWeekStats: PeriodStats = PeriodStats()
    var bestMonthStats: PeriodStats = PeriodStats()
    var weakPoints: [WeakPoint] = []
    var recommendations: [Recommendation] = []
    var activeWorkoutToResume: Workout?
    var currentError: AppError?
    var workoutAnalytics = WorkoutAnalyticsData()
    
    // MARK: - Data Layer
    private let modelContainer: ModelContainer
    private var context: ModelContext { modelContainer.mainContext }
    
    // MARK: - Init
    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        MuscleMapping.preload()
    }
    
    func showError(title: String, message: String) {
        self.currentError = AppError(title: title, message: message)
    }
    
    // MARK: - Active Workout Management
    
    func createWorkout(title: String, presetID: PersistentIdentifier?) async -> PersistentIdentifier? {
        let repository = WorkoutRepository(modelContainer: modelContainer)
        do {
            let id = try await repository.createWorkout(title: title, fromPresetID: presetID)
            self.refreshAllCaches()
            return id
        } catch {
            showError(title: String(localized: "Error"), message: error.localizedDescription)
            return nil
        }
    }
    
    func hasActiveWorkout() -> Bool {
        let descriptor = FetchDescriptor<Workout>(predicate: #Predicate<Workout> { $0.endTime == nil })
        let count = (try? context.fetchCount(descriptor)) ?? 0
        return count > 0
    }
    
    // MARK: - Presets & Drafts Operations (MainActor)
    
    func savePreset(preset: WorkoutPreset?, name: String, icon: String, exercises: [Exercise]) {
        if let existingPreset = preset {
            existingPreset.name = name
            existingPreset.icon = icon
            existingPreset.exercises.removeAll()
            
            for ex in exercises {
                if ex.modelContext == nil { context.insert(ex) }
                ex.preset = existingPreset
                existingPreset.exercises.append(ex)
            }
        } else {
            let newPreset = WorkoutPreset(id: UUID(), name: name, icon: icon, exercises: [])
            context.insert(newPreset)
            
            for ex in exercises {
                if ex.modelContext == nil { context.insert(ex) }
                ex.preset = newPreset
                newPreset.exercises.append(ex)
            }
        }
        try? context.save()
    }
    
    func deletePreset(_ preset: WorkoutPreset) {
        context.delete(preset)
        try? context.save()
    }
    
    func updateExerciseSets(exercise: Exercise, newSets: [WorkoutSet]) {
        for set in exercise.setsList {
            if set.modelContext != nil { context.delete(set) }
        }
        for set in newSets {
            if set.modelContext == nil { context.insert(set) }
        }
        exercise.setsList = newSets
        exercise.updateAggregates()
        try? context.save()
    }
    
    func addSetToDraftExercise(_ exercise: Exercise, set: WorkoutSet) {
        if exercise.modelContext != nil && set.modelContext == nil {
            context.insert(set)
        }
        exercise.setsList.append(set)
        try? context.save()
    }
    
    func removeSetFromDraftExercise(_ exercise: Exercise, set: WorkoutSet) {
        if let idx = exercise.setsList.firstIndex(where: { $0.id == set.id }) {
            exercise.setsList.remove(at: idx)
            if set.modelContext != nil {
                context.delete(set)
            }
            try? context.save()
        }
    }
    
    // MARK: - MVVM Entity Manipulation (Delegated to Repository)
    
    func addSet(to exercise: Exercise, index: Int, weight: Double?, reps: Int?, distance: Double?, time: Int?, type: SetType, isCompleted: Bool) {
        let exerciseID = exercise.persistentModelID
        Task {
            let repository = WorkoutRepository(modelContainer: modelContainer)
            try? await repository.addSet(toExerciseID: exerciseID, index: index, weight: weight, reps: reps, distance: distance, time: time, type: type, isCompleted: isCompleted)
        }
    }
    
    func deleteSet(_ set: WorkoutSet, from exercise: Exercise) {
        let setID = set.persistentModelID
        let exerciseID = exercise.persistentModelID
        Task {
            let repository = WorkoutRepository(modelContainer: modelContainer)
            try? await repository.deleteSet(setID: setID, fromExerciseID: exerciseID)
        }
    }
    
    func removeSubExercise(_ subExercise: Exercise, from superset: Exercise) {
        let subID = subExercise.persistentModelID
        let supersetID = superset.persistentModelID
        Task {
            let repository = WorkoutRepository(modelContainer: modelContainer)
            try? await repository.removeSubExercise(subID: subID, fromSupersetID: supersetID)
        }
    }
    
    func removeExercise(_ exercise: Exercise, from workout: Workout) {
        let exerciseID = exercise.persistentModelID
        let workoutID = workout.persistentModelID
        Task {
            let repository = WorkoutRepository(modelContainer: modelContainer)
            try? await repository.removeExercise(exerciseID: exerciseID, fromWorkoutID: workoutID)
        }
    }
    
    func cleanupAndFindActiveWorkouts() {
        Task {
            let repository = WorkoutRepository(modelContainer: modelContainer)
            if let _ = try? await repository.cleanupAndFindActiveWorkouts() { }
        }
    }
    
    func deleteWorkout(_ workout: Workout) {
        let workoutID = workout.persistentModelID
        Task {
            let repository = WorkoutRepository(modelContainer: modelContainer)
            try? await repository.deleteWorkout(workoutID: workoutID)
            await repository.rebuildAllStats()
            self.refreshAllCaches()
        }
    }
    
    func processCompletedWorkout(_ workout: Workout) {
        let workoutID = workout.persistentModelID
        Task {
            let repository = WorkoutRepository(modelContainer: modelContainer)
            try? await repository.processCompletedWorkout(workoutID: workoutID)
            self.refreshAllCaches()
        }
    }
    
    func finishWorkoutAndCalculateAchievements(_ workout: Workout, completion: @escaping ([Achievement], Int) -> Void) {
        let workoutID = workout.persistentModelID
        Task {
            let repository = WorkoutRepository(modelContainer: modelContainer)
            if let result = try? await repository.finishWorkoutAndCalculateAchievements(workoutID: workoutID) {
                await MainActor.run {
                    self.refreshAllCaches()
                    completion(result.newUnlocks, result.totalCount)
                }
            }
        }
    }
    
    // MARK: - Background Cache Refresh
    
    func refreshAllCaches() {
        Task {
            let repository = WorkoutRepository(modelContainer: modelContainer)
            do {
                let cacheDTO = try await repository.fetchDashboardCache()
                
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
                    case "frequency": type = .frequency; case "volume": type = .volume; case "balance": type = .balance
                    case "recovery": type = .recovery; case "progression": type = .progression; case "positive": type = .positive
                    default: return nil
                    }
                    return Recommendation(type: type, title: dto.title, message: dto.message, priority: dto.priority)
                }
            } catch {
                print("Failed to refresh caches via Repository: \(error)")
            }
        }
    }
    
    func rebuildAllStats() {
        Task {
            let repository = WorkoutRepository(modelContainer: modelContainer)
            await repository.rebuildAllStats()
            self.refreshAllCaches()
        }
    }
    
    func getLastPerformance(for exerciseName: String) -> Exercise? { lastPerformancesCache[exerciseName] }
    
    // MARK: - Import/Export (Delegated to Repo)
    
    func generateShareLink(for preset: WorkoutPreset) -> URL? {
        // Выполняется на MainActor, так как DTO сериализуется быстро, а ShareLink требует синхронного URL
        do {
            return try WorkoutExportService.generateShareLink(for: preset.toDTO())
        } catch {
            showError(title: String(localized: "Export Failed"), message: error.localizedDescription)
            return nil
        }
    }
    
    func exportPresetToFile(_ preset: WorkoutPreset) async -> URL? {
        let presetID = preset.persistentModelID
        let repository = WorkoutRepository(modelContainer: modelContainer)
        do {
            return try await repository.exportPresetToFile(presetID: presetID)
        } catch {
            showError(title: String(localized: "Export Failed"), message: error.localizedDescription)
            return nil
        }
    }
    
    func exportPresetToCSV(_ preset: WorkoutPreset) async -> URL? {
        let presetID = preset.persistentModelID
        let repository = WorkoutRepository(modelContainer: modelContainer)
        do {
            return try await repository.exportPresetToCSV(presetID: presetID)
        } catch {
            showError(title: String(localized: "Export Failed"), message: error.localizedDescription)
            return nil
        }
    }
    
    func importPreset(from url: URL) async -> Bool {
        let repository = WorkoutRepository(modelContainer: modelContainer)
        do {
            try await repository.importPreset(from: url)
            self.refreshAllCaches()
            return true
        } catch {
            showError(title: String(localized: "Import Failed"), message: error.localizedDescription)
            return false
        }
    }
    
    // MARK: - Utilities
    
    func checkAndGenerateDefaultPresets() {
        Task {
            let repository = WorkoutRepository(modelContainer: modelContainer)
            try? await repository.checkAndGenerateDefaultPresets()
        }
    }
    
    func updateWidgetData() {
        Task {
            let repository = WorkoutRepository(modelContainer: modelContainer)
            try? await repository.updateWidgetData()
        }
    }
    
    func applyAIAdjustment(_ adjustment: InWorkoutResponseDTO, to workout: Workout) {
        let workoutID = workout.persistentModelID
        Task {
            let repository = WorkoutRepository(modelContainer: modelContainer)
            try? await repository.applyAIAdjustment(adjustment, workoutID: workoutID)
        }
    }
    
    func updateWorkoutAnalytics(for workout: Workout) {
        let workoutID = workout.persistentModelID
        Task {
            let repository = WorkoutRepository(modelContainer: modelContainer)
            if let analytics = try? await repository.fetchWorkoutAnalytics(workoutID: workoutID) {
                self.workoutAnalytics = analytics
            }
        }
    }
}
