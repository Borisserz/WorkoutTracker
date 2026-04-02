import Foundation
import SwiftData
internal import SwiftUI
import Observation

@Observable
@MainActor
final class ExerciseHistoryViewModel {
    
    // MARK: - Enums
    enum Tab: String, CaseIterable {
        case summary = "Summary"
        case technique = "Technique"
        case history = "History"
        var localizedName: LocalizedStringKey { LocalizedStringKey(self.rawValue) }
    }
    
    enum GraphMetric: String, CaseIterable {
        case none = "None"
        case max = "Max"
        case average = "Average"
    }
    
    enum TimeRange: String, CaseIterable {
        case month = "1M"
        case threeMonths = "3M"
        case sixMonths = "6M"
        case year = "1Y"
        case all = "All"
    }
    
    enum TrendPeriod: String, CaseIterable, Identifiable {
        case month = "Month"
        case threeMonths = "3 Months"
        case year = "Year"
        var id: Self { self }
        var displayName: String {
            switch self { case .month: return "1M"; case .threeMonths: return "3M"; case .year: return "1Y" }
        }
    }
    
    struct DataPoint: Identifiable, Sendable {
        let id = UUID()
        let date: Date
        let value: Double
        let rawWorkoutID: PersistentIdentifier // Чтобы открыть тренировку по тапу
    }
    
    // MARK: - UI State
    var isDataLoaded: Bool = false
    var selectedTab: Tab = .summary
    var selectedTimeRange: TimeRange = .all
    var selectedMetric: GraphMetric = .none
    var selectedTrendPeriod: TrendPeriod = .month
    
    // MARK: - Data State
    var exerciseType: ExerciseType = .strength
    var exerciseCategory: ExerciseCategory = .other
    var muscleGroup: String = "Unknown"
    
    var exerciseTrend: WorkoutViewModel.ExerciseTrend?
    var exerciseForecast: WorkoutViewModel.ProgressForecast?
    
    var displayedGraphData: [DataPoint] = []
    var currentMetricValue: Double? = nil
    
    private var allDataPoints: [DataPoint] = []
    let exerciseName: String
    
    init(exerciseName: String) {
        self.exerciseName = exerciseName
    }
    
    // MARK: - Loading
    func loadData(modelContainer: ModelContainer, unitsManager: UnitsManager) async {
        let repository = WorkoutRepository(modelContainer: modelContainer)
        guard let payload = await repository.fetchExerciseHistoryData(exerciseName: exerciseName) else {
            self.isDataLoaded = true
            return
        }
        
        self.exerciseType = payload.type
        self.exerciseCategory = payload.category
        self.muscleGroup = payload.muscleGroup
        self.exerciseTrend = payload.trend
        self.exerciseForecast = payload.forecast
        
        // Применяем конвертацию единиц (kg -> lbs, m -> mi) на MainActor
        self.allDataPoints = payload.dataPoints.map { dp in
            var convertedValue = dp.value
            switch payload.type {
            case .strength: convertedValue = unitsManager.convertFromKilograms(dp.value)
            case .cardio: convertedValue = unitsManager.convertFromMeters(dp.value)
            case .duration: convertedValue = dp.value / 60.0 // sec to min
            }
            return DataPoint(date: dp.date, value: convertedValue, rawWorkoutID: dp.rawWorkoutID)
        }
        
        self.updateGraphData()
        self.isDataLoaded = true
    }
    
    // MARK: - Logic
    func updateGraphData() {
        let calendar = Calendar.current
        let filteredByDate: [DataPoint]
        
        if selectedTimeRange == .all {
            filteredByDate = allDataPoints
        } else {
            let days: Int
            switch selectedTimeRange {
            case .month: days = 30
            case .threeMonths: days = 90
            case .sixMonths: days = 180
            case .year: days = 365
            case .all: days = 0
            }
            let cutoff = calendar.date(byAdding: .day, value: -days, to: Date()) ?? Date.distantPast
            filteredByDate = allDataPoints.filter { $0.date >= cutoff }
        }
        
        var newMetric: Double? = nil
        if selectedMetric != .none && !filteredByDate.isEmpty {
            let values = filteredByDate.map { $0.value }
            if selectedMetric == .max { newMetric = values.max() }
            else if selectedMetric == .average { newMetric = values.reduce(0, +) / Double(values.count) }
        }
        
        self.displayedGraphData = filteredByDate
        self.currentMetricValue = newMetric
    }
    
    // Helper accessors for View
    var unitLabel: String {
        switch exerciseType {
        case .strength: return UnitsManager.shared.weightUnitString()
        case .cardio: return UnitsManager.shared.distanceUnitString()
        case .duration: return "min"
        }
    }
    
    var chartTitle: LocalizedStringKey {
        switch exerciseType {
        case .strength: return "Progress (Weight)"
        case .cardio: return "Progress (Distance)"
        case .duration: return "Progress (Time)"
        }
    }
    
    var chartColor: Color {
        switch exerciseType {
        case .strength: return .blue
        case .cardio: return .orange
        case .duration: return .purple
        }
    }
}
