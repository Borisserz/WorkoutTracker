//
//  WorkoutViewModel.swift
//  WorkoutTracker
//

internal import SwiftUI
import SwiftData
import AudioToolbox
import WidgetKit
internal import UniformTypeIdentifiers
import Observation
import ActivityKit

// MARK: - Main ViewModel
@Observable
@MainActor
final class WorkoutViewModel {
    
    // (Nested Types остаются без изменений: BestResult, ChartDataPoint и т.д.)
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
    
    var activeWorkoutToResume: Workout?
    var currentError: AppError?
    
    // MARK: - Dependencies (DI)
    // Оставляем modelContainer только для тех операций, которые еще не переведены в Repository.
    // В идеале он тоже отсюда уйдет.
    private let modelContainer: ModelContainer
    private var context: ModelContext { modelContainer.mainContext }
    
    // Строгая абстракция слоя данных
    private let repository: any WorkoutRepositoryProtocol
    
    // Прямая связь с Dashboard (не нужно прокидывать через аргументы функций)
    private let dashboardViewModel: DashboardViewModel
    
    // MARK: - Init
    init(modelContainer: ModelContainer, repository: any WorkoutRepositoryProtocol, dashboardViewModel: DashboardViewModel) {
        self.modelContainer = modelContainer
        self.repository = repository
        self.dashboardViewModel = dashboardViewModel
        MuscleMapping.preload()
    }
    
    func showError(title: String, message: String) {
        self.currentError = AppError(title: title, message: message)
    }
    
    // MARK: - Active Workout Management
    func createWorkout(title: String, presetID: PersistentIdentifier?) async -> PersistentIdentifier? {
        do {
            let id = try await repository.createWorkout(title: title, fromPresetID: presetID)
            dashboardViewModel.refreshAllCaches()
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
    
    // MARK: - Presets Operations
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
        do {
            try context.save()
        } catch {
            showError(title: "Save Failed", message: "Failed to save template: \(error.localizedDescription)")
        }
    }
    
    func deletePreset(_ preset: WorkoutPreset) {
        context.delete(preset)
        do {
            try context.save()
        } catch {
            showError(title: "Delete Failed", message: "Failed to delete template: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Entity Manipulation (Delegated to Repository)
    
    func addSet(to exercise: Exercise, index: Int, weight: Double?, reps: Int?, distance: Double?, time: Int?, type: SetType, isCompleted: Bool) {
        let exerciseID = exercise.persistentModelID
        Task {
            do {
                try await repository.addSet(toExerciseID: exerciseID, index: index, weight: weight, reps: reps, distance: distance, time: time, type: type, isCompleted: isCompleted)
            } catch {
                showError(title: "Error", message: "Could not add set: \(error.localizedDescription)")
            }
        }
    }
    
    func deleteSet(_ set: WorkoutSet, from exercise: Exercise) {
        let setID = set.persistentModelID
        let exerciseID = exercise.persistentModelID
        Task {
            do {
                try await repository.deleteSet(setID: setID, fromExerciseID: exerciseID)
            } catch {
                showError(title: "Error", message: "Could not delete set: \(error.localizedDescription)")
            }
        }
    }
    
    func removeSubExercise(_ subExercise: Exercise, from superset: Exercise) {
        let subID = subExercise.persistentModelID
        let supersetID = superset.persistentModelID
        Task {
            do {
                try await repository.removeSubExercise(subID: subID, fromSupersetID: supersetID)
            } catch {
                showError(title: "Error", message: "Could not remove sub-exercise: \(error.localizedDescription)")
            }
        }
    }
    
    func removeExercise(_ exercise: Exercise, from workout: Workout) {
        let exerciseID = exercise.persistentModelID
        let workoutID = workout.persistentModelID
        Task {
            do {
                try await repository.removeExercise(exerciseID: exerciseID, fromWorkoutID: workoutID)
            } catch {
                showError(title: "Error", message: "Could not remove exercise: \(error.localizedDescription)")
            }
        }
    }
    
    func cleanupAndFindActiveWorkouts() {
        Task {
            do {
                _ = try await repository.cleanupAndFindActiveWorkouts()
            } catch {
                print("Cleanup failed: \(error.localizedDescription)")
            }
        }
    }
    
    func deleteWorkout(_ workout: Workout) {
        let workoutID = workout.persistentModelID
        Task {
            do {
                try await repository.deleteWorkout(workoutID: workoutID)
                await repository.rebuildAllStats()
                dashboardViewModel.refreshAllCaches()
            } catch {
                showError(title: "Delete Failed", message: "Could not delete workout: \(error.localizedDescription)")
            }
        }
    }
    
    func processCompletedWorkout(_ workout: Workout) {
        let workoutID = workout.persistentModelID
        Task {
            do {
                try await repository.processCompletedWorkout(workoutID: workoutID)
                dashboardViewModel.refreshAllCaches()
            } catch {
                showError(title: "Process Failed", message: "Could not process completed workout: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Import/Export (Delegated to Repo)
    func generateShareLink(for preset: WorkoutPreset) -> URL? {
        do {
            return try WorkoutExportService.generateShareLink(for: preset.toDTO())
        } catch {
            showError(title: String(localized: "Export Failed"), message: error.localizedDescription)
            return nil
        }
    }
    
    func exportPresetToFile(_ preset: WorkoutPreset) async -> URL? {
        let presetID = preset.persistentModelID
        do {
            return try await repository.exportPresetToFile(presetID: presetID)
        } catch {
            showError(title: String(localized: "Export Failed"), message: error.localizedDescription)
            return nil
        }
    }
    
    func exportPresetToCSV(_ preset: WorkoutPreset) async -> URL? {
        let presetID = preset.persistentModelID
        do {
            return try await repository.exportPresetToCSV(presetID: presetID)
        } catch {
            showError(title: String(localized: "Export Failed"), message: error.localizedDescription)
            return nil
        }
    }
    
    func importPreset(from url: URL) async -> Bool {
        do {
            try await repository.importPreset(from: url)
            dashboardViewModel.refreshAllCaches()
            return true
        } catch {
            showError(title: String(localized: "Import Failed"), message: error.localizedDescription)
            return false
        }
    }
    
    // MARK: - Utilities
    func checkAndGenerateDefaultPresets() {
        Task {
            do {
                try await repository.checkAndGenerateDefaultPresets()
            } catch {
                print("Failed to generate default presets: \(error.localizedDescription)")
            }
        }
    }
    
    func updateWidgetData() {
        Task {
            do {
                try await repository.updateWidgetData()
            } catch {
                print("Failed to update widget: \(error.localizedDescription)")
            }
        }
    }
    
    func applyAIAdjustment(_ adjustment: InWorkoutResponseDTO, to workout: Workout) {
        let workoutID = workout.persistentModelID
        Task {
            do {
                try await repository.applyAIAdjustment(adjustment, workoutID: workoutID)
            } catch {
                showError(title: "AI Update Failed", message: "Could not apply AI recommendations: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Workout Generation
        
        func startGeneratedWorkout(_ generated: GeneratedWorkout, dashboardViewModel: DashboardViewModel) {
            let newWorkout = Workout(
                title: generated.title,
                date: Date(),
                icon: "bolt.fill",
                exercises: generated.exercises
            )
            
            // Временно используем контекст ViewModel (позже это тоже уйдет в репозиторий)
            context.insert(newWorkout)
            
            do {
                    try context.save()
                    self.dashboardViewModel.refreshAllCaches() // Вызываем через self
                // Запускаем Live Activity
                let attributes = WorkoutActivityAttributes(workoutTitle: generated.title)
                let state = WorkoutActivityAttributes.ContentState(startTime: Date())
                _ = try? Activity<WorkoutActivityAttributes>.request(
                    attributes: attributes,
                    content: .init(state: state, staleDate: nil),
                    pushType: nil
                )
                
            } catch {
                showError(title: "Save Failed", message: "Failed to save generated workout: \(error.localizedDescription)")
            }
        }
}
