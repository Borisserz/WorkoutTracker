//
//  StatsView.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 24.12.25.
//
//  Экран "Прогресс" (Статистика).
//  ОПТИМИЗИРОВАНО: Математика вынесена в фон, устранены проблемы N+1 запросов.
//

internal import SwiftUI
import SwiftData
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
    
    @Environment(\.modelContext) private var context
    @EnvironmentObject var viewModel: WorkoutViewModel
    
    // ИСПРАВЛЕНИЕ: Грузим только одну тренировку, чтобы SwiftUI перерисовывал при изменениях
    @Query private var dbTrigger: [Workout]
    
    @State private var selectedPeriod: Period = .week
    @State private var selectedMetric: GraphMetric = .count
    
    @State private var isDataLoaded = false
    
    @State private var currentStats: WorkoutViewModel.PeriodStats?
    @State private var previousStats: WorkoutViewModel.PeriodStats?
    @State private var chartData: [WorkoutViewModel.ChartDataPoint] = []
    @State private var recentPRs: [WorkoutViewModel.PersonalRecord] = []
    @State private var detailedComparison: [WorkoutViewModel.DetailedComparison] = []
    
    private var dbTriggerHash: String {
        guard let latest = dbTrigger.first else { return "empty" }
        return "\(latest.id.uuidString)-\(latest.endTime?.timeIntervalSince1970 ?? 0)-\(latest.exercises.count)"
    }
    
    init() {
        var descriptor = FetchDescriptor<Workout>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = 1
        _dbTrigger = Query(descriptor)
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Group {
                if isDataLoaded,
                   let currentStats = currentStats,
                   let previousStats = previousStats {
                    
                    StatsContentView(
                        selectedPeriod: $selectedPeriod,
                        selectedMetric: $selectedMetric,
                        streakCount: viewModel.streakCount,
                        currentStats: currentStats,
                        previousStats: previousStats,
                        chartData: chartData,
                        recentPRs: recentPRs,
                        bestWeek: viewModel.bestWeekStats,
                        bestMonth: viewModel.bestMonthStats,
                        weakPoints: viewModel.weakPoints,
                        recommendations: viewModel.recommendations,
                        detailedComparison: detailedComparison
                    )
                    
                } else {
                    VStack {
                        Spacer()
                        ProgressView(LocalizedStringKey("Loading stats..."))
                            .controlSize(.large)
                        Spacer()
                    }
                    .navigationTitle(LocalizedStringKey("Progress"))
                }
            }
        }
        .task {
            if !isDataLoaded {
                await loadPeriodData()
            }
        }
        .onChange(of: selectedPeriod) { _, _ in
            Task {
                // Моментальная перерисовка при смене периода
                await loadPeriodData()
            }
        }
        .onChange(of: selectedMetric) { _, _ in
            Task {
                await loadPeriodData()
            }
        }
        .onChange(of: dbTriggerHash) { _, _ in
            Task {
                await loadPeriodData()
            }
        }
    }
    
    // MARK: - Data Loading Logic
    
    @MainActor
    private func loadPeriodData() async {
        let container = context.container
        let period = selectedPeriod
        let metric = selectedMetric
        
        // Мы берем из ViewModel уже подсчитанные рекордные веса, чтобы не сканировать всю историю
        let prCache = viewModel.personalRecordsCache
        
        let currentInterval = calculateCurrentInterval()
        let previousInterval = calculatePreviousInterval()
        
        // ОПТИМИЗАЦИЯ: Мы скачиваем тренировки ТОЛЬКО за выбранный период и предыдущий
        let minDate = previousInterval.start
        let maxDate = currentInterval.end
        
        let result = await Task.detached(priority: .userInitiated) {
            let bgContext = ModelContext(container)
            var descriptor = FetchDescriptor<Workout>(
                predicate: #Predicate<Workout> { $0.date >= minDate && $0.date <= maxDate },
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            descriptor.relationshipKeyPathsForPrefetching = [\.exercises]
            // Вместо 1000 мы скачиваем только ~30 тренировок, если выбран месяц!
            let bgWorkouts = (try? bgContext.fetch(descriptor)) ?? []
            
            let currentStats = StatisticsManager.getStats(for: currentInterval, workouts: bgWorkouts)
            let previousStats = StatisticsManager.getStats(for: previousInterval, workouts: bgWorkouts)
            let recentPRs = StatisticsManager.getRecentPRs(in: currentInterval, workouts: bgWorkouts, allTimePRs: prCache)
            let detailedComparison = AnalyticsManager.getDetailedComparison(workouts: bgWorkouts, period: period)
            let chartData = StatisticsManager.getChartData(for: period, metric: metric, workouts: bgWorkouts)
            
            return (currentStats, previousStats, recentPRs, detailedComparison, chartData)
        }.value
        
        withAnimation {
            self.currentStats = result.0
            self.previousStats = result.1
            self.recentPRs = result.2
            self.detailedComparison = result.3
            self.chartData = result.4
            self.isDataLoaded = true
        }
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
            let lastWeek = calendar.date(byAdding: .day, value: -7, to: now)!
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
    
    // Новые данные аналитики
    let weakPoints: [WorkoutViewModel.WeakPoint]
    let recommendations: [WorkoutViewModel.Recommendation]
    let detailedComparison: [WorkoutViewModel.DetailedComparison]
    
    @State private var showProfile = false
    
    // MARK: - Body
    
    var body: some View {
        List {
            streakSection
            periodPicker
            highlightsSection
            chartSection
            
            // Детальное сравнение с предыдущим периодом
            if !detailedComparison.isEmpty {
                Section(header: Text(LocalizedStringKey("Detailed Comparison"))) {
                    DetailedComparisonView(comparisons: detailedComparison, period: selectedPeriod.rawValue)
                }
            }
            
            // Анализ слабых мест
            if !weakPoints.isEmpty {
                Section(header: Text(LocalizedStringKey("Weak Points Analysis"))) {
                    WeakPointsView(weakPoints: weakPoints)
                }
            }
            
            // Рекомендации (всегда показываем секцию)
            Section(header: Text(LocalizedStringKey("Recommendations"))) {
                RecommendationsView(recommendations: recommendations)
            }
            
            prSection
            bestStatsSection
        }
        .navigationTitle(LocalizedStringKey("Progress"))
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
    
    // MARK: - View Sections
    
    private var streakSection: some View {
        Section {
            HStack(spacing: 15) {
                Image(systemName: "flame.fill")
                    .font(.largeTitle)
                    .foregroundColor(.orange)
                
                VStack(alignment: .leading) {
                    Text(LocalizedStringKey("\(streakCount) Day Streak"))
                        .font(.headline)
                    Text(streakCount > 0 ? LocalizedStringKey("Keep the fire burning!") : LocalizedStringKey("Start your streak today!"))
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
        Section(header: Text(LocalizedStringKey("Highlights for this \(selectedPeriod.rawValue)"))) {
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
                        value: LocalizationHelper.shared.formatDecimal(currentStats.totalDistance),
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
                .padding(.horizontal, 16)
                .padding(.vertical, 5)
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
        }
    }
    
    private var chartSection: some View {
        Section(header: Text(selectedMetric.title)) {
            if chartData.isEmpty || chartData.reduce(0, { $0 + $1.value }) == 0 {
                EmptyStateView(
                    icon: "chart.bar.fill",
                    title: LocalizedStringKey("No data for this period"),
                    message: LocalizedStringKey("Complete some workouts to see your progress chart here. The more you train, the more insights you'll get!")
                )
                .frame(height: 180)
            } else {
                // Для дистанции на год используем линейный график для лучшей видимости
                let useLineChart = selectedMetric == .distance && selectedPeriod == .year && chartData.count > 1
                
                // Вычисляем диапазон значений для правильного масштабирования
                let maxValue = chartData.map { $0.value }.max() ?? 0
                let minValue = chartData.map { $0.value }.min() ?? 0
                let valueRange = maxValue - minValue
                // Если значения очень маленькие или диапазон мал, используем масштаб без нуля
                let shouldExcludeZero = valueRange > 0 && (maxValue / valueRange < 0.1 || maxValue < 1.0)
                
                if useLineChart {
                    Chart(chartData) { dataPoint in
                        LineMark(
                            x: .value("Label", dataPoint.label),
                            y: .value("Value", dataPoint.value)
                        )
                        .foregroundStyle(Color.blue)
                        .interpolationMethod(.linear)
                        .lineStyle(StrokeStyle(lineWidth: 3))
                        
                        PointMark(
                            x: .value("Label", dataPoint.label),
                            y: .value("Value", dataPoint.value)
                        )
                        .foregroundStyle(Color.blue)
                        .symbolSize(30)
                    }
                    .frame(height: 180)
                    .chartYScale(domain: shouldExcludeZero ? .automatic(includesZero: false) : .automatic(includesZero: true))
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
                    .chartYScale(domain: shouldExcludeZero ? .automatic(includesZero: false) : .automatic(includesZero: true))
                }
            }
        }
    }
    
    @ViewBuilder
    private var prSection: some View {
        if !recentPRs.isEmpty {
            Section(header: Text(LocalizedStringKey("New Personal Records"))) {
                ForEach(recentPRs) { pr in
                    HStack {
                        Image(systemName: "trophy.fill").foregroundColor(.orange)
                        VStack(alignment: .leading) {
                            Text(pr.exerciseName).fontWeight(.bold)
                            Text(pr.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(LocalizedStringKey("\(Int(pr.weight)) kg"))
                            .font(.headline).foregroundColor(.blue)
                    }
                }
            }
        }
    }
    
    private var bestStatsSection: some View {
        Section(header: Text(LocalizedStringKey("All-Time Bests"))) {
            HStack {
                Image(systemName: "calendar.badge.exclamationmark").foregroundColor(.green)
                Text(LocalizedStringKey("Best Week:"))
                Spacer()
                Text(LocalizedStringKey("\(bestWeek.workoutCount) workouts, \(Int(bestWeek.totalVolume)) kg")).bold()
            }
            
            HStack {
                Image(systemName: "calendar").foregroundColor(.green)
                Text(LocalizedStringKey("Best Month:"))
                Spacer()
                Text(LocalizedStringKey("\(bestMonth.workoutCount) workouts, \(Int(bestMonth.totalVolume)) kg")).bold()
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
