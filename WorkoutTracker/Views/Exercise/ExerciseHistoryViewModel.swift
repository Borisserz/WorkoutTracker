//
//  ExerciseHistoryViewModel.swift
//  WorkoutTracker
//

import Foundation
import SwiftData
internal import SwiftUI
import Observation
@Observable
@MainActor
final class ExerciseHistoryViewModel {
    
    enum Tab: String, CaseIterable {
        case summary = "Summary", technique = "Technique", history = "History"
        var localizedName: LocalizedStringKey { LocalizedStringKey(self.rawValue) }
    }
    
    enum GraphMetric: String, CaseIterable { case none = "None", max = "Max", average = "Average" }
    enum TimeRange: String, CaseIterable { case month = "1M", threeMonths = "3M", sixMonths = "6M", year = "1Y", all = "All" }
    
    var isDataLoaded: Bool = false
    var selectedTab: Tab = .summary
    var selectedTimeRange: TimeRange = .all
    var selectedMetric: GraphMetric = .none
    
    var exerciseType: ExerciseType = .strength
    var exerciseCategory: ExerciseCategory = .other
    var muscleGroup: String = "Unknown"
    
    var exerciseTrend: ExerciseTrend?
    var exerciseForecast: ProgressForecast?
    
    var displayedGraphData: [ExerciseHistoryDataPoint] = []
    
    // ВОТ ЭТА СТРОКА БЫЛА ПРОПУЩЕНА:
    var currentMetricValue: Double? = nil
    
    private var allDataPoints: [ExerciseHistoryDataPoint] = []
    
    let exerciseName: String
    private let analyticsService: AnalyticsService
    
    init(exerciseName: String, analyticsService: AnalyticsService) {
        self.exerciseName = exerciseName
        self.analyticsService = analyticsService
    }
    
    func loadData(unitsManager: UnitsManager) async {
        guard let payload = await analyticsService.fetchExerciseHistoryData(exerciseName: exerciseName) else {
            self.isDataLoaded = true
            return
        }
        
        self.exerciseType = payload.type
        self.exerciseCategory = payload.category
        self.muscleGroup = payload.muscleGroup
        self.exerciseTrend = payload.trend
        self.exerciseForecast = payload.forecast
        
        // Маппим данные, используя глобальный тип ExerciseHistoryDataPoint
        self.allDataPoints = payload.dataPoints.map { dp in
            var convertedValue = dp.value
            switch payload.type {
            case .strength: convertedValue = unitsManager.convertFromKilograms(dp.value)
            case .cardio: convertedValue = unitsManager.convertFromMeters(dp.value)
            case .duration: convertedValue = dp.value / 60.0
            }
            return ExerciseHistoryDataPoint(date: dp.date, value: convertedValue, rawWorkoutID: dp.rawWorkoutID)
        }
        
        self.updateGraphData()
        self.isDataLoaded = true
    }
    
    func updateGraphData() {
        let calendar = Calendar.current
        let filteredByDate: [ExerciseHistoryDataPoint]
        
        if selectedTimeRange == .all {
            filteredByDate = allDataPoints
        } else {
            let days: Int
            switch selectedTimeRange {
            case .month: days = 30; case .threeMonths: days = 90; case .sixMonths: days = 180; case .year: days = 365; case .all: days = 0
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
    
    var unitLabel: String { switch exerciseType { case .strength: return UnitsManager.shared.weightUnitString(); case .cardio: return UnitsManager.shared.distanceUnitString(); case .duration: return "min" } }
    var chartTitle: LocalizedStringKey { switch exerciseType { case .strength: return "Progress (Weight)"; case .cardio: return "Progress (Distance)"; case .duration: return "Progress (Time)" } }
    var chartColor: Color { switch exerciseType { case .strength: return .blue; case .cardio: return .orange; case .duration: return .purple } }
}
