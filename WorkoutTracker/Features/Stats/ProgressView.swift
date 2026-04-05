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
    
    // Оригинальные данные
    var currentStats: PeriodStats?
    var previousStats: PeriodStats?
    var chartData: [ChartDataPoint] = []
    var recentPRs: [PersonalRecord] = []
    var detailedComparison: [DetailedComparison] = []
    
    // Новые данные для расширенной аналитики
    var anatomyStats: AnatomyStatsDTO?
    var setsOverTime: [SetsOverTimePoint] = []
    
    private let analyticsService: AnalyticsService
    
    init(analyticsService: AnalyticsService) {
        self.analyticsService = analyticsService
    }
    
    func loadPeriodData(prCache: [String: Double]) async {
        let currentInterval = calculateCurrentInterval()
        let previousInterval = calculatePreviousInterval()
        
        // 1. Базовая статистика
        let result = await analyticsService.fetchStatsData(
            period: selectedPeriod,
            metric: selectedMetric,
            currentInterval: currentInterval,
            previousInterval: previousInterval,
            prCache: prCache
        )
        
        // 2. Загружаем тренировки для новых графиков
        let bgContext = ModelContext(analyticsService.modelContainer)
        let minDate = currentInterval.start
        let maxDate = currentInterval.end
        var desc = FetchDescriptor<Workout>(predicate: #Predicate<Workout> { $0.date >= minDate && $0.date <= maxDate })
        let workouts = (try? bgContext.fetch(desc)) ?? []
        
        // 3. Вычисляем новую расширенную статистику
        let anatomy = await analyticsService.fetchAnatomyStats(for: currentInterval, workouts: workouts)
        let setsData = await analyticsService.fetchSetsOverTime(period: selectedPeriod, workouts: workouts)
        
        // 4. Обновляем стейт
        self.currentStats = result.currentStats
        self.previousStats = result.previousStats
        self.recentPRs = result.recentPRs
        self.detailedComparison = result.detailedComparison
        self.chartData = result.chartData
        self.anatomyStats = anatomy
        self.setsOverTime = setsData
        
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
    
    @State private var viewModel: StatsViewModel?
    
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
                        loadingView
                    }
                } else {
                    loadingView
                }
            }
        }
        .task {
            if viewModel == nil {
                viewModel = di.makeStatsViewModel()
                await viewModel?.loadPeriodData(prCache: dashboardViewModel.personalRecordsCache)
            }
        }
        .onChange(of: viewModel?.selectedPeriod) { _, _ in refreshData() }
        .onChange(of: viewModel?.selectedMetric) { _, _ in refreshData() }
        .onChange(of: dashboardViewModel.dashboardTotalExercises) { _, _ in refreshData() }
    }
    
    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView(LocalizedStringKey("Loading stats..."))
                .controlSize(.large)
            Spacer()
        }
        .navigationTitle(LocalizedStringKey("Progress"))
    }
    
    private func refreshData() {
        Task { await viewModel?.loadPeriodData(prCache: dashboardViewModel.personalRecordsCache) }
    }
}

// MARK: - 3. Redesigned StatsContentView

struct StatsContentView: View {
    @Bindable var viewModel: StatsViewModel
    let currentStats: PeriodStats
    let previousStats: PeriodStats
    
    @Environment(UserStatsViewModel.self) var userStatsViewModel
    @Environment(DashboardViewModel.self) var dashboardViewModel
    @Environment(DIContainer.self) private var di
    @Environment(UnitsManager.self) var unitsManager
    @AppStorage("userGender") private var userGender = "male"
    
    @State private var showProfile = false
    @State private var showAIReviewSheet = false
    
    var body: some View {
        List {
            streakSection
            aiReviewButtonSection
            periodPicker
            highlightsSection
            chartSection
            
            // 1. Детальное сравнение СРАЗУ после графика
            if !viewModel.detailedComparison.isEmpty {
                Section(header: Text(LocalizedStringKey("Detailed Comparison"))) {
                    DetailedComparisonView(comparisons: viewModel.detailedComparison, period: viewModel.selectedPeriod.rawValue)
                }
            }
            
            // 2. Новая секция продвинутой статистики (Drill-down)
            advancedStatisticsSection
            
            // 3. Рекорды в самом конце
            prSection
            bestStatsSection
        }
        .navigationTitle(LocalizedStringKey("Progress"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showProfile = true } label: {
                    Image(systemName: "person.crop.circle")
                        .font(.title3)
                        .foregroundColor(.primary)
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
                weakPoints: dashboardViewModel.weakPoints, // Данные остаются в памяти для ИИ, даже если скрыты из UI
                recentPRs: viewModel.recentPRs,
                aiLogicService: di.aiLogicService
            )
        }
    }
    
    // MARK: - Sections
    
    private var streakSection: some View {
        Section {
            HStack(spacing: 15) {
                Image(systemName: "flame.fill").font(.largeTitle).foregroundColor(.orange)
                VStack(alignment: .leading) {
                    Text(LocalizedStringKey("\(dashboardViewModel.streakCount) Day Streak")).font(.headline)
                    let streakMessage: LocalizedStringKey = dashboardViewModel.streakCount > 0 ? "Keep the fire burning!" : "Start your streak today!"
                    Text(streakMessage).font(.caption).foregroundColor(.secondary)
                }
            }
        }
        .listRowBackground(Color.orange.opacity(0.1))
        .listRowSeparator(.hidden)
    }
    
    private var aiReviewButtonSection: some View {
        Section {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showAIReviewSheet = true
            } label: {
                HStack(spacing: 16) {
                    Image(systemName: "sparkles").font(.title2).foregroundColor(.yellow)
                        .shadow(color: .yellow.opacity(0.5), radius: 5, x: 0, y: 0)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(LocalizedStringKey("Generate AI Weekly Review")).font(.headline).foregroundColor(.white)
                        Text(LocalizedStringKey("Get personalized insights and tips")).font(.caption).foregroundColor(.white.opacity(0.8))
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundColor(.white.opacity(0.6)).font(.caption)
                }
                .padding(.vertical, 8)
            }
        }
        .listRowBackground(LinearGradient(colors: [.purple.opacity(0.8), .blue.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing))
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
                    metricButton(metric: .volume, title: "Volume (\(unitsManager.weightUnitString()))", value: "\(Int(unitsManager.convertFromKilograms(currentStats.totalVolume)))", icon: "scalemass.fill", prevValue: previousStats.totalVolume, currValue: currentStats.totalVolume)
                    metricButton(metric: .distance, title: "Distance (\(unitsManager.distanceUnitString()))", value: LocalizationHelper.shared.formatDecimal(unitsManager.convertFromMeters(currentStats.totalDistance)), icon: "map.fill", prevValue: previousStats.totalDistance, currValue: currentStats.totalDistance)
                    metricButton(metric: .time, title: "Time (min)", value: "\(currentStats.totalDuration)", icon: "stopwatch.fill", prevValue: Double(previousStats.totalDuration), currValue: Double(currentStats.totalDuration))
                }
                .padding(.horizontal, 16).padding(.vertical, 5)
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
        }
    }
    
    private var chartSection: some View {
        Section(header: Text(viewModel.selectedMetric.title)) {
            if viewModel.chartData.isEmpty || viewModel.chartData.reduce(0, { $0 + $1.value }) == 0 {
                EmptyStateView(icon: "chart.bar.fill", title: "No data for this period", message: "Complete some workouts to see your progress chart here.")
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
                    .frame(height: 200)
                    .chartYScale(domain: shouldExcludeZero ? .automatic(includesZero: false) : .automatic(includesZero: true))
                } else {
                    Chart(viewModel.chartData) { dataPoint in
                        BarMark(x: .value("Label", dataPoint.label), y: .value("Value", dataPoint.value))
                            .foregroundStyle(Color.blue.gradient).cornerRadius(6)
                    }
                    .frame(height: 200)
                    .chartYScale(domain: shouldExcludeZero ? .automatic(includesZero: false) : .automatic(includesZero: true))
                }
            }
        }
    }

    // MARK: - Advanced Statistics Section
    
    private var advancedStatisticsSection: some View {
        Section(header: Text(LocalizedStringKey("Advanced statistics"))) {
            
            NavigationLink(destination: SetsTrendDetailView()) {
                AdvancedStatRow(
                    icon: "chart.xyaxis.line",
                    title: "Set count per muscle group",
                    subtitle: "Number of sets logged for each muscle group."
                )
            }
            
            if let anatomy = viewModel.anatomyStats {
                NavigationLink(destination: RadarChartDetailView()) {
                    AdvancedStatRow(
                        icon: "pentagon",
                        title: "Muscle distribution (Chart)",
                        subtitle: "Compare your current and previous muscle distributions."
                    )
                }
                
                NavigationLink(destination: HeatmapDetailView(gender: userGender)) {
                    AdvancedStatRow(
                        icon: "figure.arms.open",
                        title: "Muscle distribution (Body)",
                        subtitle: "Heat map of muscles worked during this period."
                    )
                }
            }
            
            NavigationLink(destination: MonthlyReportDetailView()) {
                    AdvancedStatRow(
                        icon: "doc.text",
                        title: LocalizedStringKey("30-Day Report"),
                        subtitle: LocalizedStringKey("Recap of your workouts and volume changes.")
                    )
                }
        }
    }
    
    // MARK: - Bottom Sections
    
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
                        Text(LocalizedStringKey("\(Int(unitsManager.convertFromKilograms(pr.weight))) \(unitsManager.weightUnitString())")).font(.headline).foregroundColor(.blue)
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
                Text(LocalizedStringKey("\(dashboardViewModel.bestWeekStats.workoutCount) workouts, \(Int(unitsManager.convertFromKilograms(dashboardViewModel.bestWeekStats.totalVolume))) \(unitsManager.weightUnitString())")).bold()
            }
            HStack {
                Image(systemName: "calendar").foregroundColor(.green)
                Text(LocalizedStringKey("Best Month:"))
                Spacer()
                Text(LocalizedStringKey("\(dashboardViewModel.bestMonthStats.workoutCount) workouts, \(Int(unitsManager.convertFromKilograms(dashboardViewModel.bestMonthStats.totalVolume))) \(unitsManager.weightUnitString())")).bold()
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

// MARK: - Reusable Advanced Stat Row

struct AdvancedStatRow: View {
    let icon: String
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.primary)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Detail Screens (Drill-Downs)



// MARK: - Beautiful Sets Trend Detail View

struct SetsTrendDetailView: View {
    // 1. Изолированный источник данных (SwiftData)
    @Query(filter: #Predicate<Workout> { $0.endTime != nil }, sort: \.date, order: .reverse)
    private var allWorkouts: [Workout]
    
    enum TrendPeriod: String, CaseIterable, Identifiable {
        case week = "Week"
        case month = "Month"
        case year = "Year"
        case allTime = "All Time"
        var id: String { self.rawValue }
        var localizedName: LocalizedStringKey { LocalizedStringKey(self.rawValue) }
    }
    
    @State private var selectedPeriod: TrendPeriod = .month
    @State private var selectedMuscle: String = "Chest"
    @StateObject private var colorManager = MuscleColorManager.shared
    
    private let primaryMuscles = ["Chest", "Back", "Legs", "Shoulders", "Arms", "Core"]
    
    // 2. Реактивная динамическая агрегация данных
    private var aggregatedData: [SetsOverTimePoint] {
        let calendar = Calendar.current
        let now = Date()
        
        let cutoffDate: Date?
        switch selectedPeriod {
        case .week: cutoffDate = calendar.date(byAdding: .day, value: -7, to: now)
        case .month: cutoffDate = calendar.date(byAdding: .month, value: -1, to: now)
        case .year: cutoffDate = calendar.date(byAdding: .year, value: -1, to: now)
        case .allTime: cutoffDate = nil
        }
        
        let validWorkouts = allWorkouts.filter { workout in
            if let cutoff = cutoffDate { return workout.date >= cutoff }
            return true
        }
        
        var groupedSets: [Date: Int] = [:]
        
        for workout in validWorkouts {
            var workoutSetsCount = 0
            for ex in workout.exercises {
                let targets = ex.isSuperset ? ex.subExercises : [ex]
                for sub in targets where sub.type == .strength && sub.muscleGroup == selectedMuscle {
                    let completed = sub.setsList.filter { $0.isCompleted && $0.type != .warmup }.count
                    workoutSetsCount += completed
                }
            }
            
            if workoutSetsCount > 0 {
                let dateKey: Date
                if selectedPeriod == .year || selectedPeriod == .allTime {
                    let comps = calendar.dateComponents([.year, .month], from: workout.date)
                    dateKey = calendar.date(from: comps) ?? workout.date
                } else {
                    dateKey = calendar.startOfDay(for: workout.date)
                }
                groupedSets[dateKey, default: 0] += workoutSetsCount
            }
        }
        
        return groupedSets.map { SetsOverTimePoint(date: $0.key, muscleGroup: selectedMuscle, sets: $0.value) }
            .sorted { $0.date < $1.date }
    }
    
    // 3. Алгоритм детекции пиков для подписей на графике
    private var annotatedDates: Set<Date> {
        let data = aggregatedData
        // Если точек мало (неделя/месяц), подписываем все
        guard data.count > 14 else {
            return Set(data.map { $0.date })
        }
        
        // Если точек много, ищем локальные максимумы в топ-10% значений
        let threshold = Int(Double(maxSetsInPoint) * 0.90)
        var peaks = Set<Date>()
        
        for i in 0..<data.count {
            let current = data[i]
            if current.sets >= threshold {
                let prev = i > 0 ? data[i-1].sets : -1
                let next = i < data.count - 1 ? data[i+1].sets : -1
                
                // Проверка на локальный пик (строго больше или равно соседям)
                if current.sets >= prev && current.sets >= next {
                    peaks.insert(current.date)
                }
            }
        }
        
        // Гарантируем, что абсолютный максимум всегда будет подписан
        if peaks.isEmpty, let absoluteMax = data.max(by: { $0.sets < $1.sets }) {
            peaks.insert(absoluteMax.date)
        }
        
        return peaks
    }
    
    // Быстрая статистика для заголовка
    private var totalSets: Int {
        aggregatedData.reduce(0) { $0 + $1.sets }
    }
    
    private var maxSetsInPoint: Int {
        aggregatedData.map { $0.sets }.max() ?? 0
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Picker(LocalizedStringKey("Period"), selection: $selectedPeriod) {
                    ForEach(TrendPeriod.allCases) { period in
                        Text(period.localizedName).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 10)
                
                muscleSelector
                summaryHeader
                
                if aggregatedData.isEmpty {
                    EmptyStateView(
                        icon: "chart.xyaxis.line",
                        title: "No Data",
                        message: "You haven't trained \(selectedMuscle) in this period."
                    )
                    .frame(height: 300)
                } else {
                    beautifulChart
                }
            }
            .padding(.vertical)
        }
        .navigationTitle(LocalizedStringKey("Set count per muscle group"))
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(UIColor.systemGroupedBackground))
    }
    
    // MARK: - UI Components
    
    private var muscleSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(primaryMuscles, id: \.self) { muscle in
                    let isSelected = selectedMuscle == muscle
                    let muscleColor = colorManager.getColor(for: muscle)
                    
                    Button {
                        let generator = UISelectionFeedbackGenerator()
                        generator.selectionChanged()
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            selectedMuscle = muscle
                        }
                    } label: {
                        Text(LocalizedStringKey(muscle))
                            .font(.subheadline)
                            .fontWeight(isSelected ? .bold : .medium)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(isSelected ? muscleColor : Color(UIColor.secondarySystemBackground))
                            .foregroundColor(isSelected ? .white : .primary)
                            .cornerRadius(20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(isSelected ? muscleColor : muscleColor.opacity(0.5), lineWidth: 1.5)
                            )
                            .shadow(color: isSelected ? muscleColor.opacity(0.4) : .clear, radius: 8, x: 0, y: 4)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 5)
        }
    }
    
    private var summaryHeader: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey("Total Sets"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("\(totalSets)")
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .foregroundColor(colorManager.getColor(for: selectedMuscle))
                    .contentTransition(.numericText())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(16)
            
            VStack(alignment: .leading, spacing: 4) {
                let maxLabel: LocalizedStringKey = (selectedPeriod == .year || selectedPeriod == .allTime) ? "Monthly Max" : "Daily Max"
                
                Text(maxLabel)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("\(maxSetsInPoint)")
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .foregroundColor(.primary)
                    .contentTransition(.numericText())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(16)
        }
        .padding(.horizontal)
    }
    
    private var beautifulChart: some View {
        let muscleColor = colorManager.getColor(for: selectedMuscle)
        let isSinglePoint = aggregatedData.count == 1
        
        return VStack(alignment: .leading) {
            Text(LocalizedStringKey("Training Volume Over Time"))
                .font(.headline)
                .padding(.horizontal)
                .padding(.top, 16)
            
            Chart(aggregatedData) { point in
                if isSinglePoint {
                    BarMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("Sets", point.sets)
                    )
                    .foregroundStyle(muscleColor.gradient)
                    .cornerRadius(6)
                } else {
                    LineMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("Sets", point.sets)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(muscleColor)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    
                    AreaMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("Sets", point.sets)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [muscleColor.opacity(0.4), muscleColor.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    
                    PointMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("Sets", point.sets)
                    )
                    .foregroundStyle(muscleColor)
                    .symbolSize(40)
                    // ✅ ГЛАВНЫЙ ФИКС: Рендерим подпись только для избранных точек
                    .annotation(position: .top) {
                        if annotatedDates.contains(point.date) {
                            Text("\(point.sets)")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .frame(height: 280)
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisGridLine().foregroundStyle(.gray.opacity(0.2))
                    AxisTick()
                    if selectedPeriod == .year || selectedPeriod == .allTime {
                        AxisValueLabel(format: .dateTime.month(.abbreviated).year(.twoDigits), centered: true)
                    } else {
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day(), centered: true)
                    }
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine().foregroundStyle(.gray.opacity(0.2))
                    AxisValueLabel()
                }
            }
            .chartYScale(domain: .automatic(includesZero: true))
            .padding()
        }
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(20)
        .padding(.horizontal)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: aggregatedData.count)
        .animation(.easeInOut(duration: 0.3), value: selectedMuscle)
    }
}

struct RadarChartDetailView: View {
    @Query(filter: #Predicate<Workout> { $0.endTime != nil }, sort: \.date, order: .reverse)
    private var allWorkouts: [Workout]
    
    enum TrendPeriod: String, CaseIterable, Identifiable {
        case week = "Week", month = "Month", year = "Year", allTime = "All Time"
        var id: String { self.rawValue }
        var localizedName: LocalizedStringKey { LocalizedStringKey(self.rawValue) }
    }
    
    @State private var selectedPeriod: TrendPeriod = .month
    @State private var highlightedMuscle: String? = nil
    @StateObject private var colorManager = MuscleColorManager.shared
    
    private let axes = ["Chest", "Back", "Legs", "Shoulders", "Arms", "Core"]
    
    // Обертка для данных текущего и прошлого периодов
    private struct RadarAggregatedData {
        let current: [RadarDataPoint]
        let previous: [RadarDataPoint]
        let listStats: [MuscleCountDTO]
        let balanceScore: Int
        let totalCurrentSets: Int
    }
    
    private var aggregatedData: RadarAggregatedData {
        let calendar = Calendar.current
        let now = Date()
        
        var curStart: Date = .distantPast
        var prevStart: Date = .distantPast
        var prevEnd: Date = .distantPast
        
        switch selectedPeriod {
        case .week:
            curStart = calendar.date(byAdding: .day, value: -7, to: now)!
            prevEnd = curStart
            prevStart = calendar.date(byAdding: .day, value: -14, to: now)!
        case .month:
            curStart = calendar.date(byAdding: .month, value: -1, to: now)!
            prevEnd = curStart
            prevStart = calendar.date(byAdding: .month, value: -2, to: now)!
        case .year:
            curStart = calendar.date(byAdding: .year, value: -1, to: now)!
            prevEnd = curStart
            prevStart = calendar.date(byAdding: .year, value: -2, to: now)!
        case .allTime:
            curStart = .distantPast
            // Для All Time не рисуем предыдущий период
            prevStart = .distantFuture
            prevEnd = .distantFuture
        }
        
        var curSets: [String: Double] = [:]
        var prevSets: [String: Double] = [:]
        var totalCur = 0
        
        for workout in allWorkouts {
            let isCurrent = workout.date >= curStart
            let isPrev = workout.date >= prevStart && workout.date < prevEnd
            
            if !isCurrent && !isPrev { continue }
            
            for ex in workout.exercises {
                let targets = ex.isSuperset ? ex.subExercises : [ex]
                for sub in targets where sub.type == .strength {
                    let completed = sub.setsList.filter { $0.isCompleted && $0.type != .warmup }.count
                    if completed > 0 {
                        if isCurrent {
                            curSets[sub.muscleGroup, default: 0] += Double(completed)
                            totalCur += completed
                        } else if isPrev {
                            prevSets[sub.muscleGroup, default: 0] += Double(completed)
                        }
                    }
                }
            }
        }
        
        // Находим глобальный максимум для нормализации шкалы радара
        let maxCur = curSets.values.max() ?? 1.0
        let maxPrev = prevSets.values.max() ?? 1.0
        let globalMax = max(10.0, max(maxCur, maxPrev)) // Минимум 10 для красивой сетки
        
        let curData = axes.map { RadarDataPoint(axis: $0, value: curSets[$0] ?? 0, maxValue: globalMax) }
        let prevData = axes.map { RadarDataPoint(axis: $0, value: prevSets[$0] ?? 0, maxValue: globalMax) }
        let listStats = axes.map { MuscleCountDTO(muscle: $0, count: Int(curSets[$0] ?? 0)) }.sorted { $0.count > $1.count }
        
        // Алгоритм Symmetry Score (Баланс мышц)
        let curValues = curData.map { $0.value }
        let avg = curValues.reduce(0, +) / Double(axes.count)
        let score: Int
        if avg == 0 {
            score = 0
        } else {
            let variance = curValues.reduce(0) { $0 + pow($1 - avg, 2) } / Double(axes.count)
            let stdDev = sqrt(variance)
            let cv = stdDev / avg
            // cv обычно от 0 (идеал) до 1.5+. Формула дает от 0 до 100.
            score = max(0, min(100, Int(100 - (cv * 45))))
        }
        
        return RadarAggregatedData(current: curData, previous: prevData, listStats: listStats, balanceScore: score, totalCurrentSets: totalCur)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Picker(LocalizedStringKey("Period"), selection: $selectedPeriod) {
                    ForEach(TrendPeriod.allCases) { period in
                        Text(period.localizedName).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 10)
                
                let data = aggregatedData
                
                // Карточка Баланса
                balanceScoreCard(score: data.balanceScore)
                
                // Радар
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(LocalizedStringKey("Distribution Chart")).font(.headline)
                        Spacer()
                        if selectedPeriod != .allTime {
                            HStack(spacing: 12) {
                                HStack(spacing: 4) { Circle().fill(Color.gray.opacity(0.5)).frame(width: 8); Text(LocalizedStringKey("Previous")).font(.caption2).foregroundColor(.secondary) }
                                HStack(spacing: 4) { Circle().fill(Color.blue).frame(width: 8); Text(LocalizedStringKey("Current")).font(.caption2).foregroundColor(.secondary) }
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    RadarChartView(
                        currentData: data.current,
                        previousData: selectedPeriod == .allTime ? nil : data.previous,
                        highlightedAxis: highlightedMuscle,
                        color: .blue
                    )
                    .frame(height: 320)
                    .padding()
                }
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(20)
                .padding(.horizontal)
                
                // Список мышц с интерактивом
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text(LocalizedStringKey("Muscle")).font(.caption).foregroundColor(.secondary)
                        Spacer()
                        Text(LocalizedStringKey("Sets (Share)")).font(.caption).foregroundColor(.secondary)
                    }
                    .padding(.horizontal).padding(.vertical, 12)
                    
                    Divider()
                    
                    ForEach(data.listStats, id: \.muscle) { item in
                        let isHighlighted = highlightedMuscle == item.muscle
                        let percentage = data.totalCurrentSets > 0 ? Double(item.count) / Double(data.totalCurrentSets) * 100 : 0
                        
                        HStack {
                            Circle()
                                .fill(colorManager.getColor(for: item.muscle))
                                .frame(width: 10, height: 10)
                                .opacity(isHighlighted || highlightedMuscle == nil ? 1.0 : 0.3)
                            
                            Text(LocalizedStringKey(item.muscle))
                                .font(.subheadline)
                                .fontWeight(isHighlighted ? .bold : .regular)
                                .foregroundColor(isHighlighted || highlightedMuscle == nil ? .primary : .secondary)
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(item.count)")
                                    .font(.subheadline)
                                    .bold()
                                    .foregroundColor(isHighlighted || highlightedMuscle == nil ? .primary : .secondary)
                                Text("\(percentage, specifier: "%.1f")%")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                        .background(isHighlighted ? Color.blue.opacity(0.1) : Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            let generator = UISelectionFeedbackGenerator()
                            generator.selectionChanged()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                highlightedMuscle = isHighlighted ? nil : item.muscle
                            }
                        }
                        
                        if item.muscle != data.listStats.last?.muscle {
                            Divider().padding(.leading, 36)
                        }
                    }
                }
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(20)
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle(LocalizedStringKey("Muscle distribution (Chart)"))
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(UIColor.systemGroupedBackground))
    }
    
    private func balanceScoreCard(score: Int) -> some View {
        let color: Color = score > 80 ? .green : (score > 50 ? .orange : .red)
        let message: LocalizedStringKey = score > 80 ? "Excellent balance!" : (score > 50 ? "Slight imbalance detected." : "High imbalance. Don't skip weak points!")
        
        return HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 6)
                    .frame(width: 60, height: 60)
                Circle()
                    .trim(from: 0, to: CGFloat(score) / 100.0)
                    .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                Text("\(score)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey("Symmetry Score"))
                    .font(.headline)
                    .foregroundColor(.primary)
                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(20)
        .padding(.horizontal)
    }
}

// MARK: - 4. Custom Radar Chart Component & Helpers

struct RadarChartView: View {
    let currentData: [RadarDataPoint]
    let previousData: [RadarDataPoint]?
    let highlightedAxis: String?
    let color: Color
    
    private func gridDimension(for level: Int, totalSize: CGFloat) -> CGFloat {
        let ratio = CGFloat(level) / 4.0
        return totalSize * ratio * 0.75 // Чуть уменьшили чтобы влезли подписи и точки
    }
    
    private func computeAngle(for index: Int, totalCount: Int) -> CGFloat {
        let slice = (2.0 * CGFloat.pi) / CGFloat(totalCount)
        return (CGFloat(index) * slice) - (CGFloat.pi / 2.0)
    }
    
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let centerX = geometry.size.width / 2.0
            let centerY = geometry.size.height / 2.0
            let center = CGPoint(x: centerX, y: centerY)
            let radius = size / 2.5 * 0.95
            let totalCount = currentData.count
            
            ZStack {
                // 1. Фоновая сетка (4 уровня)
                ForEach(1...4, id: \.self) { level in
                    let dimension = gridDimension(for: level, totalSize: size)
                    PolygonShape(sides: totalCount)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        .frame(width: dimension, height: dimension)
                }
                
                // 2. Оси и подписи
                ForEach(Array(currentData.enumerated()), id: \.offset) { index, point in
                    let currentAngle = computeAngle(for: index, totalCount: totalCount)
                    let isAxisHighlighted = highlightedAxis == point.axis
                    let isDimmed = highlightedAxis != nil && !isAxisHighlighted
                    
                    let endX = centerX + (radius * cos(currentAngle))
                    let endY = centerY + (radius * sin(currentAngle))
                    let endPoint = CGPoint(x: endX, y: endY)
                    
                    // Ось
                    Path { path in
                        path.move(to: center)
                        path.addLine(to: endPoint)
                    }
                    .stroke(isAxisHighlighted ? color.opacity(0.8) : Color.gray.opacity(0.3), lineWidth: isAxisHighlighted ? 2 : 1)
                    
                    // Подпись оси
                    let labelX = centerX + ((radius + 25.0) * cos(currentAngle))
                    let labelY = centerY + ((radius + 20.0) * sin(currentAngle))
                    
                    Text(LocalizedStringKey(point.axis))
                        .font(.caption2)
                        .fontWeight(isAxisHighlighted ? .bold : .regular)
                        .foregroundColor(isAxisHighlighted ? color : (isDimmed ? .gray.opacity(0.3) : .secondary))
                        .position(x: labelX, y: labelY)
                }
                
                // 3. ПРЕДЫДУЩИЙ период (Ghost Polygon)
                if let prev = previousData {
                    DataPolygonShape(data: prev)
                        .fill(Color.gray.opacity(0.1))
                    DataPolygonShape(data: prev)
                        .stroke(Color.gray.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                }
                
                // 4. ТЕКУЩИЙ период (Main Polygon)
                DataPolygonShape(data: currentData)
                    .fill(color.opacity(0.3))
                DataPolygonShape(data: currentData)
                    .stroke(color, lineWidth: 2)
                
                // 5. Точки на вершинах текущего периода
                ForEach(Array(currentData.enumerated()), id: \.offset) { index, point in
                    let currentAngle = computeAngle(for: index, totalCount: totalCount)
                    let isAxisHighlighted = highlightedAxis == point.axis
                    
                    let ratio = point.maxValue == 0 ? 0 : CGFloat(point.value / point.maxValue)
                    let ptRadius = radius * ratio
                    
                    let ptX = centerX + (ptRadius * cos(currentAngle))
                    let ptY = centerY + (ptRadius * sin(currentAngle))
                    
                    Circle()
                        .fill(isAxisHighlighted ? Color.white : color)
                        .frame(width: isAxisHighlighted ? 10 : 6, height: isAxisHighlighted ? 10 : 6)
                        .overlay(
                            Circle().stroke(color, lineWidth: isAxisHighlighted ? 3 : 0)
                        )
                        .position(x: ptX, y: ptY)
                        .shadow(color: color.opacity(0.5), radius: 3)
                }
            }
        }
        .drawingGroup() // Аппаратное ускорение Metal
    }
}

struct PolygonShape: Shape {
    let sides: Int
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.width / 2, y: rect.height / 2)
        let radius = min(rect.width, rect.height) / 2
        for i in 0..<sides {
            let angle = (CGFloat(i) * (2.0 * .pi / CGFloat(sides))) - .pi / 2
            let point = CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}

struct DataPolygonShape: Shape {
    let data: [RadarDataPoint]
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.width / 2, y: rect.height / 2)
        let maxRadius = min(rect.width, rect.height) / 2
        for (i, point) in data.enumerated() {
            let angle = (CGFloat(i) * (2.0 * .pi / CGFloat(data.count))) - .pi / 2
            let ratio = point.maxValue == 0 ? 0 : CGFloat(point.value / point.maxValue)
            let radius = maxRadius * ratio
            let pt = CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        path.closeSubpath()
        return path
    }
}




// MARK: - Heatmap Detail View & Processor

struct HeatmapDetailItem: Identifiable, Sendable {
    let id = UUID()
    let slug: String
    let displayName: String
    let sets: Int
    let relativeIntensity: Double // 0.0 to 1.0
}

struct HeatmapAggregatedData: Sendable {
    let intensities: [String: Int] // Нормализованные значения 0-100 для рендеринга
    let rawCounts: [String: Int]   // Сырые значения для тултипов
    let detailedList: [HeatmapDetailItem]
    let totalSets: Int
    let topMuscle: HeatmapDetailItem?
}

/// 🚀 Фоновый процессор (Sendable) для защиты Main Thread от тяжелых вычислений
struct HeatmapDataProcessor: Sendable {
    static func process(workouts: [Workout], period: SetsTrendDetailView.TrendPeriod) async -> HeatmapAggregatedData {
        let calendar = Calendar.current
        let now = Date()
        let cutoffDate: Date?
        
        switch period {
        case .week: cutoffDate = calendar.date(byAdding: .day, value: -7, to: now)
        case .month: cutoffDate = calendar.date(byAdding: .month, value: -1, to: now)
        case .year: cutoffDate = calendar.date(byAdding: .year, value: -1, to: now)
        case .allTime: cutoffDate = nil
        }
        
        var slugCounts: [String: Int] = [:]
        var totalSets = 0
        
        // 1. Агрегация сырых данных
        for workout in workouts {
            if let cutoff = cutoffDate, workout.date < cutoff { continue }
            
            for exercise in workout.exercises {
                let targets = exercise.isSuperset ? exercise.subExercises : [exercise]
                for sub in targets where sub.type == .strength {
                    let completedSets = sub.setsList.filter { $0.isCompleted && $0.type != .warmup }.count
                    if completedSets > 0 {
                        // Получаем точные детализированные мышцы
                        let slugs = MuscleMapping.getMuscles(for: sub.name, group: sub.muscleGroup)
                        for slug in slugs {
                            slugCounts[slug, default: 0] += completedSets
                        }
                        totalSets += completedSets
                    }
                }
            }
        }
        
        // 2. Нормализация интенсивности
        let maxSets = Double(slugCounts.values.max() ?? 1)
        var normalizedIntensities: [String: Int] = [:]
        var detailedList: [HeatmapDetailItem] = []
        
        for (slug, count) in slugCounts {
            let relativeIntensity = Double(count) / maxSets
            normalizedIntensities[slug] = Int(relativeIntensity * 100) // Масштаб 0-100 для прозрачности
            
            let displayName = MuscleDisplayHelper.getDisplayName(for: slug)
            detailedList.append(HeatmapDetailItem(slug: slug, displayName: displayName, sets: count, relativeIntensity: relativeIntensity))
        }
        
        // Сортируем по убыванию нагрузки
        detailedList.sort { $0.sets > $1.sets }
        
        return HeatmapAggregatedData(
            intensities: normalizedIntensities, // Передаем шкалу для красивой карты
            rawCounts: slugCounts,              // Передаем сырые сеты для тултипов
            detailedList: detailedList,
            totalSets: totalSets,
            topMuscle: detailedList.first
        )
    }
}

struct HeatmapDetailView: View {
    @Query(filter: #Predicate<Workout> { $0.endTime != nil }, sort: \.date, order: .reverse)
    private var allWorkouts: [Workout]
    
    let gender: String
    
    @State private var selectedPeriod: SetsTrendDetailView.TrendPeriod = .month
    @State private var aggregatedData: HeatmapAggregatedData? = nil
    @State private var isProcessing = true
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                
                Picker(LocalizedStringKey("Period"), selection: $selectedPeriod) {
                    ForEach(SetsTrendDetailView.TrendPeriod.allCases) { period in
                        Text(period.localizedName).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 10)
                
                if isProcessing {
                    ProgressView()
                        .frame(height: 300)
                } else if let data = aggregatedData, data.totalSets > 0 {
                    
                    // Самая нагруженная мышца
                    if let top = data.topMuscle {
                        topFocusCard(topMuscle: top)
                    }
                    
                    // Интерактивная карта
                    VStack {
                        BodyHeatmapView(
                            muscleIntensities: data.intensities,
                            rawMuscleCounts: data.rawCounts, // ✅ Проброс сырых данных
                            isRecoveryMode: false,
                            isCompactMode: false,
                            userGender: gender
                        )
                        .frame(height: 480)
                        .padding(.vertical)
                    }
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(20)
                    .padding(.horizontal)
                    
                    // Детализированный лист по каждой мышце
                    detailedBreakdownList(data: data)
                    
                } else {
                    EmptyStateView(
                        icon: "figure.arms.open",
                        title: LocalizedStringKey("No Data"),
                        message: LocalizedStringKey("Complete workouts in this period to see your muscle distribution.")
                    )
                    .frame(height: 300)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle(LocalizedStringKey("Muscle distribution (Body)"))
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(UIColor.systemGroupedBackground))
        .task(id: selectedPeriod) {
            await calculateData()
        }
    }
    
    // MARK: - UI Components
    
    @ViewBuilder
    private func topFocusCard(topMuscle: HeatmapDetailItem) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.2))
                    .frame(width: 50, height: 50)
                Image(systemName: "flame.fill")
                    .foregroundColor(.red)
                    .font(.title2)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey("Primary Focus"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                
                Text(LocalizedStringKey(topMuscle.displayName))
                    .font(.title3)
                    .bold()
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(LocalizedStringKey("Sets"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                Text("\(topMuscle.sets)")
                    .font(.title2)
                    .bold()
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.red.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .red.opacity(0.1), radius: 10, x: 0, y: 4)
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private func detailedBreakdownList(data: HeatmapAggregatedData) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(LocalizedStringKey("Detailed Breakdown"))
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Text(LocalizedStringKey("Sets"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            
            Divider()
            
            ForEach(data.detailedList) { item in
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(LocalizedStringKey(item.displayName))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        // Burn Index Bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 6)
                                
                                Capsule()
                                    .fill(intensityColor(for: item.relativeIntensity))
                                    .frame(width: geo.size.width * CGFloat(item.relativeIntensity), height: 6)
                            }
                        }
                        .frame(height: 6)
                    }
                    
                    Spacer()
                    
                    Text("\(item.sets)")
                        .font(.subheadline)
                        .bold()
                        .monospacedDigit()
                        .foregroundColor(.primary)
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
                
                if item.id != data.detailedList.last?.id {
                    Divider().padding(.leading, 16)
                }
            }
        }
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(20)
        .padding(.horizontal)
    }
    
    // MARK: - Logic
    
    private func calculateData() async {
        isProcessing = true
        // 🚀 Переносим тяжелые вычисления в фоновый поток
        let processedData = await Task.detached(priority: .userInitiated) {
            return await HeatmapDataProcessor.process(workouts: allWorkouts, period: selectedPeriod)
        }.value
        
        await MainActor.run {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                self.aggregatedData = processedData
                self.isProcessing = false
            }
        }
    }
    
    private func intensityColor(for relativeIntensity: Double) -> Color {
        if relativeIntensity > 0.8 { return .red }
        if relativeIntensity > 0.5 { return .orange }
        return .blue
    }
}
// MARK: - 30-Day Report Detail View & Processor

enum ReportChartMetric: String, CaseIterable, Identifiable {
    case workouts = "Workouts"
    case duration = "Duration"
    case volume = "Volume"
    case sets = "Sets"
    var id: String { self.rawValue }
}

struct ReportDailyPoint: Identifiable, Sendable {
    let id = UUID()
    let date: Date
    let value: Double
}

struct ReportSummary: Sendable {
    let currentWorkouts: Int; let prevWorkouts: Int
    let currentDuration: Int; let prevDuration: Int
    let currentVolume: Double; let prevVolume: Double
    let currentSets: Int; let prevSets: Int
}

struct PeriodReportPayload: Sendable {
    let title: String
    let summary: ReportSummary
    let chartWorkouts: [ReportDailyPoint]
    let chartDuration: [ReportDailyPoint]
    let chartVolume: [ReportDailyPoint]
    let chartSets: [ReportDailyPoint]
    let activeDays: Set<Date>
    let streakDays: Int
    let radarCurrent: [RadarDataPoint]
    let radarPrevious: [RadarDataPoint]
}

/// Строго изолированный процессор для отчета за последние 30 дней
struct PeriodReportProcessor: Sendable {
    static func process(workouts: [Workout]) async -> PeriodReportPayload {
        let calendar = Calendar.current
        let now = Date()
        
        // Жестко фиксируем: Текущий период = последние 30 дней. Предыдущий = 30 дней до этого.
        let curStart = calendar.date(byAdding: .day, value: -30, to: now)!
        let prevEnd = curStart
        let prevStart = calendar.date(byAdding: .day, value: -60, to: now)!
        
        let df = DateFormatter()
        df.dateFormat = "MMMM yyyy"
        let title = "\(df.string(from: now)) Report"
        
        // 1. Агрегация сводки
        var sCW = 0, sPW = 0, sCD = 0, sPD = 0, sCS = 0, sPS = 0
        var sCV = 0.0, sPV = 0.0
        
        // 2. Данные для графиков и календаря (только текущий период)
        var dictWorkouts: [Date: Double] = [:]
        var dictDuration: [Date: Double] = [:]
        var dictVolume: [Date: Double] = [:]
        var dictSets: [Date: Double] = [:]
        var activeDays = Set<Date>()
        
        // 3. Данные для Радара
        let axes = ["Chest", "Back", "Legs", "Shoulders", "Arms", "Core"]
        var radarCur: [String: Double] = [:]
        var radarPrev: [String: Double] = [:]
        
        for workout in workouts {
            let isCur = workout.date >= curStart
            let isPrev = workout.date >= prevStart && workout.date < prevEnd
            if !isCur && !isPrev { continue }
            
            let dayStart = calendar.startOfDay(for: workout.date)
            var wVolume = 0.0
            var wSets = 0
            
            for ex in workout.exercises {
                let targets = ex.isSuperset ? ex.subExercises : [ex]
                for sub in targets where sub.type == .strength {
                    let cSets = sub.setsList.filter { $0.isCompleted && $0.type != .warmup }
                    wSets += cSets.count
                    wVolume += cSets.reduce(0.0) { $0 + (($1.weight ?? 0) * Double($1.reps ?? 0)) }
                    
                    if cSets.count > 0 {
                        if isCur { radarCur[sub.muscleGroup, default: 0] += Double(cSets.count) }
                        else if isPrev { radarPrev[sub.muscleGroup, default: 0] += Double(cSets.count) }
                    }
                }
            }
            
            if isCur {
                sCW += 1; sCD += workout.durationSeconds / 60; sCV += wVolume; sCS += wSets
                
                dictWorkouts[dayStart, default: 0] += 1
                dictDuration[dayStart, default: 0] += Double(workout.durationSeconds / 60)
                dictVolume[dayStart, default: 0] += wVolume
                dictSets[dayStart, default: 0] += Double(wSets)
                activeDays.insert(dayStart)
                
            } else if isPrev {
                sPW += 1; sPD += workout.durationSeconds / 60; sPV += wVolume; sPS += wSets
            }
        }
        
        // 4. Форматируем графики (ровно 30 дней)
        var cW: [ReportDailyPoint] = [], cD: [ReportDailyPoint] = [], cV: [ReportDailyPoint] = [], cS: [ReportDailyPoint] = []
        for i in 0..<30 {
            let date = calendar.date(byAdding: .day, value: i, to: curStart)!
            let dayStart = calendar.startOfDay(for: date)
            cW.append(.init(date: dayStart, value: dictWorkouts[dayStart] ?? 0))
            cD.append(.init(date: dayStart, value: dictDuration[dayStart] ?? 0))
            cV.append(.init(date: dayStart, value: dictVolume[dayStart] ?? 0))
            cS.append(.init(date: dayStart, value: dictSets[dayStart] ?? 0))
        }
        
        // 5. Радар
        let globalMax = max(10.0, max(radarCur.values.max() ?? 1, radarPrev.values.max() ?? 1))
        let rC = axes.map { RadarDataPoint(axis: $0, value: radarCur[$0] ?? 0, maxValue: globalMax) }
        let rP = axes.map { RadarDataPoint(axis: $0, value: radarPrev[$0] ?? 0, maxValue: globalMax) }
        
        return PeriodReportPayload(
            title: title,
            summary: ReportSummary(currentWorkouts: sCW, prevWorkouts: sPW, currentDuration: sCD, prevDuration: sPD, currentVolume: sCV, prevVolume: sPV, currentSets: sCS, prevSets: sPS),
            chartWorkouts: cW, chartDuration: cD, chartVolume: cV, chartSets: cS,
            activeDays: activeDays,
            streakDays: StreakCalculator.calculate(from: Array(activeDays), maxRestDays: 2),
            radarCurrent: rC, radarPrevious: rP
        )
    }
}

struct MonthlyReportDetailView: View {
    @Query(filter: #Predicate<Workout> { $0.endTime != nil }, sort: \.date, order: .reverse)
    private var allWorkouts: [Workout]
    
    @Environment(UnitsManager.self) var unitsManager
    
    @State private var payload: PeriodReportPayload?
    @State private var selectedMetric: ReportChartMetric = .workouts
    @State private var isProcessing = true
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if isProcessing {
                    ProgressView().frame(height: 300)
                } else if let data = payload {
                    
                    // 1. Chart Section
                    chartSection(data: data)
                    
                    // 2. Summary Grid
                    summaryGrid(data: data.summary)
                    
                    // 3. Calendar / Active Days
                    calendarSection(data: data)
                    
                    // 4. Radar Comparison
                    radarSection(data: data)
                    
                    // 5. Share Button
                    Button {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text(LocalizedStringKey("Share Report"))
                                .bold()
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle(LocalizedStringKey(payload?.title ?? "Report"))
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(UIColor.systemGroupedBackground))
        .task {
            isProcessing = true
            let processed = await Task.detached(priority: .userInitiated) {
                return await PeriodReportProcessor.process(workouts: allWorkouts)
            }.value
            
            await MainActor.run {
                withAnimation {
                    self.payload = processed
                    self.isProcessing = false
                }
            }
        }
    }
    
    // MARK: - UI Components
    
    @ViewBuilder
    private func chartSection(data: PeriodReportPayload) -> some View {
        VStack(spacing: 16) {
            Picker("Metric", selection: $selectedMetric) {
                ForEach(ReportChartMetric.allCases) { metric in
                    Text(LocalizedStringKey(metric.rawValue)).tag(metric)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            
            let chartData: [ReportDailyPoint] = {
                switch selectedMetric {
                case .workouts: return data.chartWorkouts
                case .duration: return data.chartDuration
                case .volume: return data.chartVolume
                case .sets: return data.chartSets
                }
            }()
            
            Chart(chartData) { point in
                let val = selectedMetric == .volume ? unitsManager.convertFromKilograms(point.value) : point.value
                BarMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value("Value", val)
                )
                .foregroundStyle(Color.blue.gradient)
                .cornerRadius(4)
                .annotation(position: .top) {
                    if val > 0 {
                        Text(LocalizationHelper.shared.formatFlexible(val))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(height: 200)
            .chartYScale(domain: .automatic(includesZero: true))
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisGridLine().foregroundStyle(.gray.opacity(0.1))
                    AxisTick()
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day(), centered: true)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
        .background(Color(UIColor.secondarySystemBackground))
    }
    
    @ViewBuilder
    private func summaryGrid(data: ReportSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(LocalizedStringKey("Summary"))
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            let cVol = unitsManager.convertFromKilograms(data.currentVolume)
            let pVol = unitsManager.convertFromKilograms(data.prevVolume)
            let wUnit = unitsManager.weightUnitString()
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                reportCard(title: "Workouts", current: "\(data.currentWorkouts)", prev: "\(data.prevWorkouts)", change: calcChange(Double(data.currentWorkouts), Double(data.prevWorkouts)))
                reportCard(title: "Duration", current: "\(data.currentDuration)m", prev: "\(data.prevDuration)m", change: calcChange(Double(data.currentDuration), Double(data.prevDuration)))
                reportCard(title: "Volume", current: "\(Int(cVol))\(wUnit)", prev: "\(Int(pVol))\(wUnit)", change: calcChange(cVol, pVol))
                reportCard(title: "Sets", current: "\(data.currentSets)", prev: "\(data.prevSets)", change: calcChange(Double(data.currentSets), Double(data.prevSets)))
            }
            .padding(.horizontal)
        }
    }
    
    private func calcChange(_ cur: Double, _ prev: Double) -> Double {
        if prev == 0 { return cur > 0 ? 100 : 0 }
        return ((cur - prev) / prev) * 100.0
    }
    
    @ViewBuilder
    private func reportCard(title: String, current: String, prev: String, change: Double) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(LocalizedStringKey(title))
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Text(current)
                .font(.title2)
                .bold()
            
            HStack(spacing: 4) {
                Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                Text("\(abs(change), specifier: "%.0f")%")
                Text("vs \(prev)")
            }
            .font(.caption)
            .foregroundColor(change >= 0 ? .green : .red)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.gray.opacity(0.1), lineWidth: 1))
    }
    
    @ViewBuilder
    private func calendarSection(data: PeriodReportPayload) -> some View {
        VStack(alignment: .center, spacing: 16) {
            HStack {
                Text(LocalizedStringKey("Workout Days Log"))
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal)
            
            VStack(spacing: 8) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.orange)
                    .shadow(color: .orange.opacity(0.5), radius: 10, x: 0, y: 5)
                
                Text("\(data.streakDays) Day Streak")
                    .font(.title2)
                    .bold()
            }
            .padding(.vertical, 10)
            
            // Календарь всегда строим для текущего календарного месяца!
            let cal = Calendar.current
            let now = Date()
            let startOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: now))!
            let range = cal.range(of: .day, in: .month, for: startOfMonth)!
            let firstWeekday = cal.component(.weekday, from: startOfMonth)
            let offset = (firstWeekday - cal.firstWeekday + 7) % 7
            let days = range.map { cal.date(byAdding: .day, value: $0 - 1, to: startOfMonth)! }
            
            VStack(spacing: 8) {
                HStack {
                    ForEach(0..<7, id: \.self) { i in
                        Text(cal.shortWeekdaySymbols[(cal.firstWeekday - 1 + i) % 7].prefix(1))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                    ForEach(0..<offset, id: \.self) { _ in Color.clear.aspectRatio(1, contentMode: .fill) }
                    
                    ForEach(days, id: \.self) { date in
                        let isActive = data.activeDays.contains(cal.startOfDay(for: date))
                        ZStack {
                            Circle()
                                .fill(isActive ? Color.blue : Color.gray.opacity(0.1))
                            Text("\(cal.component(.day, from: date))")
                                .font(.caption)
                                .fontWeight(isActive ? .bold : .regular)
                                .foregroundColor(isActive ? .white : .primary)
                        }
                        .aspectRatio(1, contentMode: .fit)
                    }
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(16)
            .padding(.horizontal)
        }
    }
    
    @ViewBuilder
    private func radarSection(data: PeriodReportPayload) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(LocalizedStringKey("Muscle Distribution"))
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            VStack {
                RadarChartView(
                    currentData: data.radarCurrent,
                    previousData: data.radarPrevious,
                    highlightedAxis: nil,
                    color: .blue
                )
                .frame(height: 250)
                .padding()
                
                HStack(spacing: 16) {
                    HStack(spacing: 4) { Circle().fill(Color.gray.opacity(0.5)).frame(width: 8); Text(LocalizedStringKey("Previous")).font(.caption) }
                    HStack(spacing: 4) { Circle().fill(Color.blue).frame(width: 8); Text(LocalizedStringKey("Current")).font(.caption) }
                }
                .padding(.bottom, 16)
            }
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(16)
            .padding(.horizontal)
        }
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
        .padding()
        .frame(minWidth: 140)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2.5))
        .compositingGroup()
    }
}
