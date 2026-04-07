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
    
    // ✅ ИСПРАВЛЕНО: Добавлена вкладка oneRepMax
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
    
    private var allDataPoints: [ExerciseHistoryDataPoint] = []
    
    let exerciseName: String
    private let analyticsService: AnalyticsService
    
    // MARK: - 1RM Calculator State
    
    var selectedFormula: RMFormula = .brzycki {
        didSet {
            UserDefaults.standard.set(selectedFormula.rawValue, forKey: Constants.UserDefaultsKeys.preferred1RMFormula.rawValue)
        }
    }
    
    var calcInputWeight: Double? = nil
    var calcInputReps: Int? = nil
    var manual1RMOverride: Double? = nil
    
    /// Возвращает базовый 1RM (в КГ). Приоритет: Ручной ввод -> Ввод из калькулятора -> Лучший сет в истории -> 0
    var effective1RM: Double {
        if let manual = manual1RMOverride { return manual }
        
        if let w = calcInputWeight, let r = calcInputReps, w > 0, r > 0 {
            return OneRepMaxCalculator.calculate1RM(weight: w, reps: r, formula: selectedFormula)
        }
        
        let maxHist = allDataPoints.map { $0.value }.max() ?? 0.0
        return UnitsManager.shared.convertToKilograms(maxHist) // Возвращаем чистые КГ для математики
    }
    
    // MARK: - Init
    
    init(exerciseName: String, analyticsService: AnalyticsService) {
        self.exerciseName = exerciseName
        self.analyticsService = analyticsService
        
        // Загрузка сохраненной формулы 1RM
        if let savedFormula = UserDefaults.standard.string(forKey: Constants.UserDefaultsKeys.preferred1RMFormula.rawValue),
           let formula = RMFormula(rawValue: savedFormula) {
            self.selectedFormula = formula
        }
    }

    
    func loadData(unitsManager: UnitsManager) async {
        guard let payload = await analyticsService.fetchExerciseHistoryData(exerciseName: exerciseName) else {
            self.isDataLoaded = true
            return
        }
        var effective1RM: Double {
               if let manual = manual1RMOverride { return manual }
               
               // Если ручного ввода нет, но есть введенные данные сета - считаем от них
               if let w = calcInputWeight, let r = calcInputReps, w > 0, r > 0 {
                   return OneRepMaxCalculator.calculate1RM(weight: w, reps: r, formula: selectedFormula)
               }
               
               // Фоллбэк на исторический максимум (берем максимальный вес)
               let maxHist = allDataPoints.map { $0.value }.max() ?? 0.0
               // В allDataPoints у нас уже сконвертированные значения. Нам нужны КГ для формулы.
               return UnitsManager.shared.convertToKilograms(maxHist)
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
