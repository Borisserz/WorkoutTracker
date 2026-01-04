//
//  StatsView.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 24.12.25.
//
//  Экран "Прогресс" (Статистика).
//  Реализован по паттерну Container/View:
//  1. StatsView (Container) — отвечает за вычисление дат, интервалов и подготовку данных.
//  2. StatsContentView (View) — отвечает только за верстку и отображение.
//

internal import SwiftUI
import Charts

// MARK: - 1. Smart Container View

struct StatsView: View {
    
    // MARK: - Nested Types
    
    enum Period: String, CaseIterable, Identifiable {
        case week = "Week"
        case month = "Month"
        case year = "Year"
        var id: Self { self }
    }
    
    enum GraphMetric: Identifiable {
        case count, volume, time, distance
        
        var id: Self { self }
        
        var title: String {
            switch self {
            case .count: return "Activity"
            case .volume: return "Volume (kg)"
            case .time: return "Time (min)"
            case .distance: return "Distance (km)"
            }
        }
    }
    
    // MARK: - Environment & State
    
    @EnvironmentObject var viewModel: WorkoutViewModel
    
    @State private var selectedPeriod: Period = .week
    @State private var selectedMetric: GraphMetric = .count
    
    // MARK: - Body
    
    var body: some View {
        // 1. Вычисляем интервалы времени
        let currentInterval = calculateCurrentInterval()
        let previousInterval = calculatePreviousInterval()
        
        // 2. Запрашиваем данные у ViewModel
        let currentStats = viewModel.getStats(for: currentInterval)
        let previousStats = viewModel.getStats(for: previousInterval)
        let chartData = viewModel.getChartData(for: selectedPeriod, metric: selectedMetric)
        let recentPRs = viewModel.getRecentPRs(in: currentInterval)
        let streakCount = viewModel.calculateWorkoutStreak()
        
        let bestWeek = viewModel.getBestStats(for: Period.week)
        let bestMonth = viewModel.getBestStats(for: Period.month)
        
        // 3. Передаем готовые данные в View
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
    
    // MARK: - Date Logic
    
    private func calculateCurrentInterval() -> DateInterval {
        let now = Date()
        let calendar = Calendar.current
        switch selectedPeriod {
        case .week: return calendar.dateInterval(of: .weekOfYear, for: now)!
        case .month: return calendar.dateInterval(of: .month, for: now)!
        case .year: return calendar.dateInterval(of: .year, for: now)!
        }
    }
    
    private func calculatePreviousInterval() -> DateInterval {
        let now = Date()
        let calendar = Calendar.current
        switch selectedPeriod {
        case .week:
            let lastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: now)!
            return calendar.dateInterval(of: .weekOfYear, for: lastWeek)!
        case .month:
            let lastMonth = calendar.date(byAdding: .month, value: -1, to: now)!
            return calendar.dateInterval(of: .month, for: lastMonth)!
        case .year:
            let lastYear = calendar.date(byAdding: .year, value: -1, to: now)!
            return calendar.dateInterval(of: .year, for: lastYear)!
        }
    }
}

// MARK: - 2. Dumb Content View

struct StatsContentView: View {
    
    // MARK: - Environment & Bindings
    
    @EnvironmentObject var viewModel: WorkoutViewModel
    @Binding var selectedPeriod: StatsView.Period
    @Binding var selectedMetric: StatsView.GraphMetric
    
    // MARK: - Data Properties
    
    let streakCount: Int
    let currentStats: WorkoutViewModel.PeriodStats
    let previousStats: WorkoutViewModel.PeriodStats
    let chartData: [WorkoutViewModel.ChartDataPoint]
    let recentPRs: [WorkoutViewModel.PersonalRecord]
    let bestWeek: WorkoutViewModel.PeriodStats
    let bestMonth: WorkoutViewModel.PeriodStats
    
    @State private var showProfile = false
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            List {
                streakSection
                periodPicker
                highlightsSection
                chartSection
                prSection
                bestStatsSection
            }
            .navigationTitle("Progress")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showProfile = true } label: {
                        Image(systemName: "person.circle").font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showProfile) {
                ProfileView()
                    .environmentObject(viewModel.progressManager)
            }
        }
    }
    
    // MARK: - View Sections
    
    private var streakSection: some View {
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
    }
    
    private var periodPicker: some View {
        Picker("Period", selection: $selectedPeriod) {
            ForEach(StatsView.Period.allCases) { Text($0.rawValue) }
        }
        .pickerStyle(.segmented)
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .listRowBackground(Color.clear)
    }
    
    private var highlightsSection: some View {
        Section(header: Text("Highlights for this \(selectedPeriod.rawValue)")) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // 1. Workouts
                    metricButton(
                        metric: .count,
                        title: "Workouts",
                        value: "\(currentStats.workoutCount)",
                        icon: "figure.run",
                        prevValue: Double(previousStats.workoutCount),
                        currValue: Double(currentStats.workoutCount)
                    )
                    
                    // 2. Volume
                    metricButton(
                        metric: .volume,
                        title: "Volume (kg)",
                        value: "\(Int(currentStats.totalVolume))",
                        icon: "scalemass.fill",
                        prevValue: previousStats.totalVolume,
                        currValue: currentStats.totalVolume
                    )
                    
                    // 3. Distance
                    metricButton(
                        metric: .distance,
                        title: "Distance (km)",
                        value: String(format: "%.1f", currentStats.totalDistance),
                        icon: "map.fill",
                        prevValue: previousStats.totalDistance,
                        currValue: currentStats.totalDistance
                    )
                    
                    // 4. Time
                    metricButton(
                        metric: .time,
                        title: "Time (min)",
                        value: "\(currentStats.totalDuration)",
                        icon: "stopwatch.fill",
                        prevValue: Double(previousStats.totalDuration),
                        currValue: Double(currentStats.totalDuration)
                    )
                }
                .padding(.vertical, 5)
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
        }
    }
    
    private var chartSection: some View {
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
    }
    
    @ViewBuilder
    private var prSection: some View {
        if !recentPRs.isEmpty {
            Section(header: Text("New Personal Records")) {
                ForEach(recentPRs) { pr in
                    HStack {
                        Image(systemName: "trophy.fill").foregroundColor(.orange)
                        VStack(alignment: .leading) {
                            Text(pr.exerciseName).fontWeight(.bold)
                            Text(pr.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                        Text("\(Int(pr.weight)) kg")
                            .font(.headline).foregroundColor(.blue)
                    }
                }
            }
        }
    }
    
    private var bestStatsSection: some View {
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
    
    // MARK: - Helpers
    
    private func metricButton(metric: StatsView.GraphMetric, title: String, value: String, icon: String, prevValue: Double, currValue: Double) -> some View {
        Button {
            withAnimation { selectedMetric = metric }
        } label: {
            HighlightCard(
                title: title,
                value: value,
                icon: icon,
                isSelected: selectedMetric == metric,
                change: calculateChange(current: currValue, previous: prevValue)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func calculateChange(current: Double, previous: Double) -> Double {
        if previous == 0 { return current > 0 ? 100.0 : 0.0 }
        return ((current - previous) / previous) * 100.0
    }
}

// MARK: - 3. Helper Components

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

// MARK: - Preview

#Preview {
    StatsView()
        .environmentObject(WorkoutViewModel())
}
