// ============================================================
// FILE: WorkoutTracker/Features/ExerciseCatalog/ViewModels/ExerciseHistoryViewModel.swift
// ============================================================

import Foundation
import SwiftData
internal import SwiftUI
import Observation

@Observable
@MainActor
final class ExerciseHistoryViewModel {
    
    enum Tab: String, CaseIterable {
        case summary = "Summary", technique = "Technique", history = "History", oneRepMax = "1RM"
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
    var currentMetricValue: Double? = nil
    var personalRecords: ExerciseRecordsDTO? = nil
    private var allDataPoints: [ExerciseHistoryDataPoint] = []
    
    let exerciseName: String
    private let analyticsService: AnalyticsService
    
    // ✅ МЫШЦЫ ИЗ JSON
    var primaryMuscles: [String] = []
    var secondaryMuscles: [String] = []
    
    // MARK: - 1RM Calculator State
    
    var selectedFormula: RMFormula = .brzycki {
        didSet {
            UserDefaults.standard.set(selectedFormula.rawValue, forKey: Constants.UserDefaultsKeys.preferred1RMFormula.rawValue)
        }
    }
    
    var calcInputWeight: Double? = nil
    var calcInputReps: Int? = nil
    var manual1RMOverride: Double? = nil
    
    var effective1RM: Double {
        if let manual = manual1RMOverride { return manual }
        
        if let w = calcInputWeight, let r = calcInputReps, w > 0, r > 0 {
            return OneRepMaxCalculator.calculate1RM(weight: w, reps: r, formula: selectedFormula)
        }
        
        let maxHist = allDataPoints.map { $0.value }.max() ?? 0.0
        return UnitsManager.shared.convertToKilograms(maxHist)
    }
    
    // MARK: - Init
    
    init(exerciseName: String, analyticsService: AnalyticsService) {
        self.exerciseName = exerciseName
        self.analyticsService = analyticsService
        
        if let savedFormula = UserDefaults.standard.string(forKey: Constants.UserDefaultsKeys.preferred1RMFormula.rawValue),
           let formula = RMFormula(rawValue: savedFormula) {
            self.selectedFormula = formula
        }
    }
    
    // MARK: - Data Loading
    
    func loadData(unitsManager: UnitsManager) async {
        // 1. Сначала загружаем статику (мышцы) из БД, чтобы даже для пустых упражнений была информация
        let dbItem = await ExerciseDatabaseService.shared.getExerciseItem(for: exerciseName)
        self.primaryMuscles = dbItem?.primaryMuscles ?? []
        self.secondaryMuscles = dbItem?.secondaryMuscles ?? []
        
        // 2. Загружаем динамику (историю) из аналитики
        guard let payload = await analyticsService.fetchExerciseHistoryData(exerciseName: exerciseName) else {
            self.isDataLoaded = true
            return
        }
        
        self.exerciseType = payload.type
        self.exerciseCategory = payload.category
        self.muscleGroup = payload.muscleGroup
        self.exerciseTrend = payload.trend
        self.exerciseForecast = payload.forecast
        self.personalRecords = payload.records
        
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
    
    // MARK: - Graph Data
    
    func updateGraphData() {
        let calendar = Calendar.current
        let now = Date()
        
        let filteredByDate: [ExerciseHistoryDataPoint]
        if selectedTimeRange == .all {
            filteredByDate = allDataPoints
        } else {
            let days: Int
            switch selectedTimeRange {
            case .month: days = 30; case .threeMonths: days = 90; case .sixMonths: days = 180; case .year: days = 365; case .all: days = 0
            }
            let cutoff = calendar.date(byAdding: .day, value: -days, to: now) ?? .distantPast
            filteredByDate = allDataPoints.filter { $0.date >= cutoff }
        }
        
        guard !filteredByDate.isEmpty else {
            self.displayedGraphData = []
            self.currentMetricValue = nil
            return
        }
        
        var groupedDict: [Date: [Double]] = [:]
        
        for point in filteredByDate {
            let dateKey: Date
            switch selectedTimeRange {
            case .month, .threeMonths:
                dateKey = calendar.startOfDay(for: point.date)
            case .sixMonths, .year:
                let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: point.date)
                dateKey = calendar.date(from: comps) ?? calendar.startOfDay(for: point.date)
            case .all:
                if filteredByDate.count > 200 {
                    let comps = calendar.dateComponents([.year, .month], from: point.date)
                    dateKey = calendar.date(from: comps) ?? calendar.startOfDay(for: point.date)
                } else {
                    let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: point.date)
                    dateKey = calendar.date(from: comps) ?? calendar.startOfDay(for: point.date)
                }
            }
            groupedDict[dateKey, default: []].append(point.value)
        }
        
        var aggregatedPoints: [ExerciseHistoryDataPoint] = []
        for (date, values) in groupedDict {
            let aggregatedValue = values.max() ?? 0.0
            aggregatedPoints.append(ExerciseHistoryDataPoint(date: date, value: aggregatedValue, rawWorkoutID: filteredByDate.first!.rawWorkoutID))
        }
        
        let finalData = aggregatedPoints.sorted { $0.date < $1.date }
        
        var newMetric: Double? = nil
        if selectedMetric != .none {
            let values = finalData.map { $0.value }
            if selectedMetric == .max { newMetric = values.max() }
            else if selectedMetric == .average { newMetric = values.reduce(0, +) / Double(values.count) }
        }
        
        self.displayedGraphData = finalData
        self.currentMetricValue = newMetric
    }
    
    // MARK: - UI Helpers
    var unitLabel: String { switch exerciseType { case .strength: return UnitsManager.shared.weightUnitString(); case .cardio: return UnitsManager.shared.distanceUnitString(); case .duration: return "min" } }
    var chartTitle: LocalizedStringKey { switch exerciseType { case .strength: return "Progress (Weight)"; case .cardio: return "Progress (Distance)"; case .duration: return "Progress (Time)" } }
    
    // <--- ИЗМЕНЕНО: Динамические цвета для графиков в зависимости от темы
    var chartColor: Color {
        let theme = ThemeManager.shared.current
        switch exerciseType {
        case .strength: return theme.primaryAccent
        case .cardio: return theme.secondaryMidTone
        case .duration: return theme.deepPremiumAccent
        }
    }
}
