// ============================================================
// FILE: WorkoutTracker/Views/Stats/ProgressView.swift
// ============================================================

internal import SwiftUI
import SwiftData
import Charts

// MARK: - 1. View Model (Чистая бизнес-логика)

@Observable
@MainActor
final class StatsViewModel {
    var selectedPeriod: StatsView.Period = .week
    var selectedMetric: StatsView.GraphMetric = .count
    
    var isDataLoaded = false
    
    var currentStats: PeriodStats?
    var previousStats: PeriodStats?
    var chartData: [ChartDataPoint] = []
    var recentPRs: [PersonalRecord] = []
    var detailedComparison: [DetailedComparison] = []
    
    private let analyticsService: AnalyticsService
    
    init(analyticsService: AnalyticsService) {
        self.analyticsService = analyticsService
    }
    
    // Загрузка данных полностью вынесена из View
    func loadPeriodData(prCache: [String: Double]) async {
        let currentInterval = calculateCurrentInterval()
        let previousInterval = calculatePreviousInterval()
        
        let result = await analyticsService.fetchStatsData(
            period: selectedPeriod,
            metric: selectedMetric,
            currentInterval: currentInterval,
            previousInterval: previousInterval,
            prCache: prCache
        )
        
        self.currentStats = result.currentStats
        self.previousStats = result.previousStats
        self.recentPRs = result.recentPRs
        self.detailedComparison = result.detailedComparison
        self.chartData = result.chartData
        self.isDataLoaded = true
    }
    
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

// MARK: - 2. Smart Container View

struct StatsView: View {
    
    // MARK: - Nested Types
    
    enum Period: String, CaseIterable, Identifiable {
        case week = "Week"
        case month = "Month"
        case year = "Year"
        var id: Self { self }
        
        var localizedName: LocalizedStringKey {
            switch self {
            case .week: return "Week"
            case .month: return "Month"
            case .year: return "Year"
            }
        }
    }
    
    enum GraphMetric: Identifiable {
        case count, volume, time, distance
        
        var id: Self { self }
        
        var title: LocalizedStringKey {
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
    @Environment(DashboardViewModel.self) var dashboardViewModel
    @Environment(DIContainer.self) private var di
    
    // Наш новый чистый стейт
    @State private var viewModel: StatsViewModel?
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Group {
                if let vm = viewModel {
                    if vm.isDataLoaded,
                       let currentStats = vm.currentStats,
                       let previousStats = vm.previousStats {
                        
                        StatsContentView(
                            viewModel: vm,
                            currentStats: currentStats,
                            previousStats: previousStats
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
            if viewModel == nil {
                viewModel = di.makeStatsViewModel()
                await viewModel?.loadPeriodData(prCache: dashboardViewModel.personalRecordsCache)
            }
        }
        .onChange(of: viewModel?.selectedPeriod) { _, _ in
            Task { await viewModel?.loadPeriodData(prCache: dashboardViewModel.personalRecordsCache) }
        }
        .onChange(of: viewModel?.selectedMetric) { _, _ in
            Task { await viewModel?.loadPeriodData(prCache: dashboardViewModel.personalRecordsCache) }
        }
        .onChange(of: dashboardViewModel.dashboardTotalExercises) { _, _ in
            Task { await viewModel?.loadPeriodData(prCache: dashboardViewModel.personalRecordsCache) }
        }
    }
}

// MARK: - 3. Dumb Content View

struct StatsContentView: View {
    @Bindable var viewModel: StatsViewModel
    
    @Environment(UserStatsViewModel.self) var userStatsViewModel
    @Environment(DashboardViewModel.self) var dashboardViewModel
    @Environment(DIContainer.self) private var di
    
    let currentStats: PeriodStats
    let previousStats: PeriodStats
    
    @State private var showProfile = false
    @State private var showAIReviewSheet = false
    
    var body: some View {
        List {
            streakSection
            aiReviewButtonSection
            
            periodPicker
            highlightsSection
            chartSection
            
            if !viewModel.detailedComparison.isEmpty {
                Section(header: Text(LocalizedStringKey("Detailed Comparison"))) {
                    DetailedComparisonView(comparisons: viewModel.detailedComparison, period: viewModel.selectedPeriod.rawValue)
                }
            }
            
            if !dashboardViewModel.weakPoints.isEmpty {
                Section(header: Text(LocalizedStringKey("Weak Points Analysis"))) {
                    WeakPointsView(weakPoints: dashboardViewModel.weakPoints)
                }
            }
            
            Section(header: Text(LocalizedStringKey("Recommendations"))) {
                RecommendationsView(recommendations: dashboardViewModel.recommendations, onTap: { selectedRec in
                    if selectedRec.type == .recovery {
                        showProfile = true
                    }
                })
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
                .environment(userStatsViewModel.progressManager)
        }
        .sheet(isPresented: $showAIReviewSheet) {
            AIWeeklyReviewSheet(
                currentStats: currentStats,
                previousStats: previousStats,
                weakPoints: dashboardViewModel.weakPoints,
                recentPRs: viewModel.recentPRs,
                aiLogicService: di.aiLogicService
            )
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
                    Text(LocalizedStringKey("\(dashboardViewModel.streakCount) Day Streak"))
                        .font(.headline)
                    let streakMessage: LocalizedStringKey = dashboardViewModel.streakCount > 0 ? "Keep the fire burning!" : "Start your streak today!"
                    Text(streakMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .listRowBackground(Color.orange.opacity(0.1))
        .listRowSeparator(.hidden)
    }
    
    private var aiReviewButtonSection: some View {
        Section {
            Button {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                showAIReviewSheet = true
            } label: {
                HStack(spacing: 16) {
                    Image(systemName: "sparkles")
                        .font(.title2)
                        .foregroundColor(.yellow)
                        .shadow(color: .yellow.opacity(0.5), radius: 5, x: 0, y: 0)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(LocalizedStringKey("Generate AI Weekly Review"))
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text(LocalizedStringKey("Get personalized insights and tips"))
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.white.opacity(0.6))
                        .font(.caption)
                }
                .padding(.vertical, 8)
            }
        }
        .listRowBackground(
            LinearGradient(
                colors: [Color.purple.opacity(0.8), Color.blue.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
    
    private var periodPicker: some View {
        Picker(LocalizedStringKey("Period"), selection: $viewModel.selectedPeriod) {
            ForEach(StatsView.Period.allCases) { Text($0.localizedName).tag($0) }
        }
        .pickerStyle(.segmented)
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .listRowBackground(Color.clear)
    }
    
    private var highlightsTitle: LocalizedStringKey {
        switch viewModel.selectedPeriod {
        case .week: return "Highlights for this Week"
        case .month: return "Highlights for this Month"
        case .year: return "Highlights for this Year"
        }
    }
    
    private var highlightsSection: some View {
        Section(header: Text(highlightsTitle)) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    metricButton(metric: .count, title: "Workouts", value: "\(currentStats.workoutCount)", icon: "figure.run", prevValue: Double(previousStats.workoutCount), currValue: Double(currentStats.workoutCount))
                    metricButton(metric: .volume, title: "Volume (kg)", value: "\(Int(currentStats.totalVolume))", icon: "scalemass.fill", prevValue: previousStats.totalVolume, currValue: currentStats.totalVolume)
                    metricButton(metric: .distance, title: "Distance (km)", value: LocalizationHelper.shared.formatDecimal(currentStats.totalDistance), icon: "map.fill", prevValue: previousStats.totalDistance, currValue: currentStats.totalDistance)
                    metricButton(metric: .time, title: "Time (min)", value: "\(currentStats.totalDuration)", icon: "stopwatch.fill", prevValue: Double(previousStats.totalDuration), currValue: Double(currentStats.totalDuration))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 5)
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
        }
    }
    
    private var chartSection: some View {
        Section(header: Text(viewModel.selectedMetric.title)) {
            if viewModel.chartData.isEmpty || viewModel.chartData.reduce(0, { $0 + $1.value }) == 0 {
                EmptyStateView(
                    icon: "chart.bar.fill",
                    title: "No data for this period",
                    message: "Complete some workouts to see your progress chart here. The more you train, the more insights you'll get!"
                )
                .frame(height: 180)
            } else {
                let useLineChart = viewModel.selectedMetric == .distance && viewModel.selectedPeriod == .year && viewModel.chartData.count > 1
                let maxValue = viewModel.chartData.map { $0.value }.max() ?? 0
                let minValue = viewModel.chartData.map { $0.value }.min() ?? 0
                let valueRange = maxValue - minValue
                let shouldExcludeZero = valueRange > 0 && (maxValue / valueRange < 0.1 || maxValue < 1.0)
                
                if useLineChart {
                    Chart(viewModel.chartData) { dataPoint in
                        LineMark(x: .value("Label", dataPoint.label), y: .value("Value", dataPoint.value))
                            .foregroundStyle(Color.blue).interpolationMethod(.linear).lineStyle(StrokeStyle(lineWidth: 3))
                        PointMark(x: .value("Label", dataPoint.label), y: .value("Value", dataPoint.value))
                            .foregroundStyle(Color.blue).symbolSize(30)
                    }
                    .frame(height: 180)
                    .chartYScale(domain: shouldExcludeZero ? .automatic(includesZero: false) : .automatic(includesZero: true))
                } else {
                    Chart(viewModel.chartData) { dataPoint in
                        BarMark(x: .value("Label", dataPoint.label), y: .value("Value", dataPoint.value))
                            .foregroundStyle(Color.blue.gradient).cornerRadius(6)
                    }
                    .frame(height: 180)
                    .chartYScale(domain: shouldExcludeZero ? .automatic(includesZero: false) : .automatic(includesZero: true))
                }
            }
        }
    }
    
    @ViewBuilder
    private var prSection: some View {
        if !viewModel.recentPRs.isEmpty {
            Section(header: Text(LocalizedStringKey("New Personal Records"))) {
                ForEach(viewModel.recentPRs) { pr in
                    HStack {
                        Image(systemName: "trophy.fill").foregroundColor(.orange)
                        VStack(alignment: .leading) {
                            Text(LocalizedStringKey(pr.exerciseName)).fontWeight(.bold)
                            Text(pr.date.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(LocalizedStringKey("\(Int(pr.weight)) kg")).font(.headline).foregroundColor(.blue)
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
                Text(LocalizedStringKey("\(dashboardViewModel.bestWeekStats.workoutCount) workouts, \(Int(dashboardViewModel.bestWeekStats.totalVolume)) kg")).bold()
            }
            HStack {
                Image(systemName: "calendar").foregroundColor(.green)
                Text(LocalizedStringKey("Best Month:"))
                Spacer()
                Text(LocalizedStringKey("\(dashboardViewModel.bestMonthStats.workoutCount) workouts, \(Int(dashboardViewModel.bestMonthStats.totalVolume)) kg")).bold()
            }
        }
    }
    
    // MARK: - Helpers
    
    private func metricButton(metric: StatsView.GraphMetric, title: LocalizedStringKey, value: String, icon: String, prevValue: Double, currValue: Double) -> some View {
        Button {
            withAnimation { viewModel.selectedMetric = metric }
        } label: {
            HighlightCard(title: title, value: value, icon: icon, isSelected: viewModel.selectedMetric == metric, change: calculateChange(current: currValue, previous: prevValue))
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func calculateChange(current: Double, previous: Double) -> Double {
        if previous == 0 { return current > 0 ? 100.0 : 0.0 }
        return ((current - previous) / previous) * 100.0
    }
}

struct HighlightCard: View {
    let title: LocalizedStringKey
    let value: String
    let icon: String
    let isSelected: Bool
    let change: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon).font(.title2).foregroundColor(.blue)
            Text(value).font(.system(size: 28, weight: .bold, design: .rounded))
            VStack(alignment: .leading) {
                Text(title).font(.caption).foregroundColor(.secondary)
                Text("\(change, specifier: "%.0f")%").font(.caption.bold()).foregroundColor(change >= 0 ? .green : .red)
            }
        }
        .padding().frame(minWidth: 140).background(Color(UIColor.secondarySystemBackground)).cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2.5))
        .compositingGroup()
    }
}
