//
//  StatsView.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 24.12.25.
//

internal import SwiftUI
import Charts

// ---------------------------------------------------
// ШАГ 1: "УМНАЯ" ВЬЮХА (ГЛАВНАЯ)
// Она будет считать данные и передавать их "глупой" вьюхе.
// ---------------------------------------------------
struct StatsView: View {
    @EnvironmentObject var viewModel: WorkoutViewModel
    
    @State private var selectedPeriod: Period = .week
    @State private var selectedMetric: GraphMetric = .count
    
    // Enum'ы теперь живут здесь
    enum Period: String, CaseIterable, Identifiable {
        case week = "Week"
        case month = "Month"
        case year = "Year"
        var id: Self { self }
    }
    
    enum GraphMetric: Identifiable {
        case count, volume, time
        var id: Self { self }
        
        var title: String {
            switch self {
            case .count: return "Activity"
            case .volume: return "Volume (kg)"
            case .time: return "Time (min)"
            }
        }
    }
    
    var body: some View {
        // --- СОЗДАЕМ ЛОКАЛЬНУЮ ССЫЛКУ НА VIEWMODEL ---
        let viewModel = self.viewModel

        // --- ВЫПОЛНЯЕМ ВСЕ РАСЧЕТЫ ЗДЕСЬ ---
        let currentInterval = calculateCurrentInterval()
        let previousInterval = calculatePreviousInterval()
        
        let currentStats = viewModel.getStats(for: currentInterval)
        let previousStats = viewModel.getStats(for: previousInterval)
        let chartData = viewModel.getChartData(for: selectedPeriod, metric: selectedMetric)
        let recentPRs = viewModel.getRecentPRs(in: currentInterval)
        let streakCount = viewModel.calculateWorkoutStreak()
        
        // --- ИСПОЛЬЗУЕМ ЯВНОЕ УКАЗАНИЕ ТИПА ENUM ---
        let bestWeek = viewModel.getBestStats(for: Period.week)
        let bestMonth = viewModel.getBestStats(for: Period.month)
        
        // --- ПЕРЕДАЕМ ГОТОВЫЕ ДАННЫЕ В "ГЛУПУЮ" ВЬЮХУ ---
        return StatsContentView(
            selectedPeriod: $selectedPeriod,
            selectedMetric: $selectedMetric,
            streakCount: streakCount,
            currentStats: currentStats,
            previousStats: previousStats,
            chartData: chartData,
            recentPRs: recentPRs,
            bestWeek: bestWeek,
            bestMonth: bestMonth
        )
    }
    
    // --- Вспомогательные функции, которые остались в "умной" вьюхе ---
    func calculateCurrentInterval() -> DateInterval {
        let now = Date()
        switch selectedPeriod {
        case .week: return Calendar.current.dateInterval(of: .weekOfYear, for: now)!
        case .month: return Calendar.current.dateInterval(of: .month, for: now)!
        case .year: return Calendar.current.dateInterval(of: .year, for: now)!
        }
    }
    
    func calculatePreviousInterval() -> DateInterval {
        let now = Date()
        switch selectedPeriod {
        case .week:
            let lastWeek = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: now)!
            return Calendar.current.dateInterval(of: .weekOfYear, for: lastWeek)!
        case .month:
            let lastMonth = Calendar.current.date(byAdding: .month, value: -1, to: now)!
            return Calendar.current.dateInterval(of: .month, for: lastMonth)!
        case .year:
            let lastYear = Calendar.current.date(byAdding: .year, value: -1, to: now)!
            return Calendar.current.dateInterval(of: .year, for: lastYear)!
        }
    }
}


// ---------------------------------------------------
// ШАГ 2: "ГЛУПАЯ" ВЬЮХА (ОТРИСОВКА)
// Она только показывает то, что ей дали. Ничего не считает сама.
// ---------------------------------------------------
struct StatsContentView: View {
    @Binding var selectedPeriod: StatsView.Period
    @Binding var selectedMetric: StatsView.GraphMetric
    
    let streakCount: Int
    let currentStats: WorkoutViewModel.PeriodStats
    let previousStats: WorkoutViewModel.PeriodStats
    let chartData: [WorkoutViewModel.ChartDataPoint]
    let recentPRs: [WorkoutViewModel.PersonalRecord]
    let bestWeek: WorkoutViewModel.PeriodStats
    let bestMonth: WorkoutViewModel.PeriodStats
    
    var body: some View {
        NavigationStack {
            List {
                // 1. СЕКЦИЯ "СТРИК"
                Section {
                    HStack(spacing: 15) {
                        Image(systemName: "flame.fill")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        
                        VStack(alignment: .leading) {
                            Text("\(streakCount) Day Streak")
                                .font(.headline)
                            Text(streakCount > 0 ? "Keep the fire burning!" : "Start your streak today!")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .listRowBackground(Color.orange.opacity(0.1))
                .listRowSeparator(.hidden)
                
                // 2. ПЕРЕКЛЮЧАТЕЛЬ ПЕРИОДА
                Picker("Period", selection: $selectedPeriod) {
                    ForEach(StatsView.Period.allCases) { Text($0.rawValue) }
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
                
                // 3. СЕКЦИЯ "ХАЙЛАЙТЫ"
                Section(header: Text("Highlights for this \(selectedPeriod.rawValue)")) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            Button { withAnimation { selectedMetric = .count } } label: {
                                HighlightCard(title: "Workouts", value: "\(currentStats.workoutCount)", icon: "figure.run", isSelected: selectedMetric == .count,
                                              change: calculateChange(current: currentStats.workoutCount, previous: previousStats.workoutCount))
                            }.buttonStyle(PlainButtonStyle())
                            
                            Button { withAnimation { selectedMetric = .volume } } label: {
                                HighlightCard(title: "Volume (kg)", value: "\(Int(currentStats.totalVolume))", icon: "scalemass.fill", isSelected: selectedMetric == .volume,
                                              change: calculateChange(current: Int(currentStats.totalVolume), previous: Int(previousStats.totalVolume)))
                            }.buttonStyle(PlainButtonStyle())
                            
                            Button { withAnimation { selectedMetric = .time } } label: {
                                HighlightCard(title: "Time (min)", value: "\(currentStats.totalDuration)", icon: "stopwatch.fill", isSelected: selectedMetric == .time,
                                              change: calculateChange(current: currentStats.totalDuration, previous: previousStats.totalDuration))
                            }.buttonStyle(PlainButtonStyle())
                        }
                        .padding(.vertical, 5)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                }
                
                // 4. СЕКЦИЯ "ГРАФИК"
                Section(header: Text(selectedMetric.title)) {
                    if chartData.isEmpty || chartData.reduce(0, { $0 + $1.value }) == 0 {
                        Text("No data for this period")
                            .foregroundColor(.secondary)
                            .frame(height: 180, alignment: .center)
                    } else {
                        Chart(chartData) { dataPoint in
                            BarMark(
                                x: .value("Label", dataPoint.label),
                                y: .value("Value", dataPoint.value)
                            )
                            .foregroundStyle(Color.blue.gradient)
                            .cornerRadius(6)
                        }
                        .frame(height: 180)
                    }
                }
                
                // 5. СЕКЦИЯ "ЛИЧНЫЕ РЕКОРДЫ"
                if !recentPRs.isEmpty {
                    Section(header: Text("New Personal Records")) {
                        ForEach(recentPRs) { pr in
                            HStack {
                                Image(systemName: "trophy.fill").foregroundColor(.orange)
                                VStack(alignment: .leading) {
                                    Text(pr.exerciseName).fontWeight(.bold)
                                    Text(pr.date.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundColor(.secondary)
                                }
                                Spacer()
                                Text("\(Int(pr.weight)) kg").font(.headline).foregroundColor(.blue)
                            }
                        }
                    }
                }
                
                // 6. СЕКЦИЯ "ЛУЧШИЕ РЕЗУЛЬТАТЫ ЗА ВСЕ ВРЕМЯ"
                Section(header: Text("All-Time Bests")) {
                    HStack {
                        Image(systemName: "calendar.badge.exclamationmark").foregroundColor(.green)
                        Text("Best Week:")
                        Spacer()
                        Text("\(bestWeek.workoutCount) workouts, \(Int(bestWeek.totalVolume)) kg").bold()
                    }
                    
                    HStack {
                        Image(systemName: "calendar").foregroundColor(.green)
                        Text("Best Month:")
                        Spacer()
                        Text("\(bestMonth.workoutCount) workouts, \(Int(bestMonth.totalVolume)) kg").bold()
                    }
                }
            }
            .navigationTitle("Progress")
        }
    }
    
    // Вспомогательная функция для расчета % (можно оставить здесь)
    func calculateChange(current: Int, previous: Int) -> Double {
        if previous == 0 { return current > 0 ? 100.0 : 0.0 }
        return (Double(current - previous) / Double(previous)) * 100.0
    }
}


// --- КОМПОНЕНТ ДЛЯ ХАЙЛАЙТОВ (без изменений) ---
struct HighlightCard: View {
    let title: String
    let value: String
    let icon: String
    let isSelected: Bool
    let change: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
            
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("\(change, specifier: "%.0f")%")
                    .font(.caption.bold())
                    .foregroundColor(change >= 0 ? .green : .red)
            }
        }
        .padding()
        .frame(minWidth: 140)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2.5)
        )
    }
}


#Preview {
    StatsView()
        .environmentObject(WorkoutViewModel())
}
