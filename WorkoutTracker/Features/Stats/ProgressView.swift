internal import SwiftUI
import SwiftData
import Charts
import Combine

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

    var anatomyStats: AnatomyStatsDTO?
    var setsOverTime: [SetsOverTimePoint] = []

    var activeGoals: [UserGoal] = []
    var activeGoalValues: [UUID: Double] = [:]

    private let analyticsService: AnalyticsService

    init(analyticsService: AnalyticsService) {
        self.analyticsService = analyticsService
    }

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

        let bgContext = ModelContext(analyticsService.modelContainer)
        let minDate = currentInterval.start
        let maxDate = currentInterval.end
        var desc = FetchDescriptor<Workout>(predicate: #Predicate<Workout> { $0.date >= minDate && $0.date <= maxDate })
        let workouts = (try? bgContext.fetch(desc)) ?? []

        let anatomy = await analyticsService.fetchAnatomyStats(for: currentInterval, workouts: workouts)
        let setsData = await analyticsService.fetchSetsOverTime(period: selectedPeriod, workouts: workouts)

        self.currentStats = result.currentStats
        self.previousStats = result.previousStats
        self.recentPRs = result.recentPRs
        self.detailedComparison = result.detailedComparison
        self.chartData = result.chartData
        self.anatomyStats = anatomy
        self.setsOverTime = setsData

        await loadActiveGoals(prCache: prCache)

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

    func loadActiveGoals(prCache: [String: Double]) async {
            let bgContext = ModelContext(analyticsService.modelContainer)
            let descriptor = FetchDescriptor<UserGoal>(predicate: #Predicate { $0.isCompleted == false }, sortBy: [SortDescriptor(\.createdAt, order: .reverse)])

            let goals = (try? bgContext.fetch(descriptor)) ?? []
            self.activeGoals = goals

            var newValues: [UUID: Double] = [:]

            let widgetData = WidgetDataManager.load()
            let weightDesc = FetchDescriptor<WeightEntry>(sortBy: [SortDescriptor(\.date, order: .reverse)])
            let latestWeight = (try? bgContext.fetch(weightDesc).first)?.weight

            let activeWorkoutsDesc = FetchDescriptor<Workout>(predicate: #Predicate { $0.endTime == nil })
            let activeWorkouts = (try? bgContext.fetch(activeWorkoutsDesc)) ?? []

            for goal in goals {
                switch goal.type {
                case .strength:
                    if let exName = goal.exerciseName {
                        var maxLifted = prCache[exName] ?? 0.0
                        for w in activeWorkouts {
                            let activeMax = w.exercises
                                .filter { $0.name == exName }
                                .flatMap { $0.setsList }
                                .filter { $0.isCompleted && $0.type != .warmup && ($0.reps ?? 0) >= goal.targetReps }
                                .compactMap { $0.weight }
                                .max() ?? 0.0
                            maxLifted = max(maxLifted, activeMax)
                        }
                        newValues[goal.id] = maxLifted
                    }
                case .consistency:
                    newValues[goal.id] = Double(widgetData.streak)
                case .bodyweight:
                    newValues[goal.id] = latestWeight ?? goal.startingValue
                }
            }

            self.activeGoalValues = newValues
        }
    }

struct StatsView: View {

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
struct StatsContentView: View {
    @Bindable var viewModel: StatsViewModel
    let currentStats: PeriodStats
    let previousStats: PeriodStats

    @Environment(DIContainer.self) private var di
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.modelContext) private var context
    @Environment(UserStatsViewModel.self) var userStatsViewModel
    @Environment(DashboardViewModel.self) var dashboardViewModel
    @Environment(UnitsManager.self) var unitsManager
    @Environment(\.colorScheme) private var colorScheme 
    @AppStorage("userGender") private var userGender = "male"

    @State private var showingAddGoal = false
    @State private var showProfile = false

    @State private var showAIReviewSheet = false
    @State private var isFetchingReviewData = false
    @State private var reviewData: StatsDataResultDTO?

    let bgDark = Color(red: 0.05, green: 0.05, blue: 0.07)

    var body: some View {
        ZStack {

            (colorScheme == .dark ? bgDark : Color(UIColor.systemGroupedBackground))
                .edgesIgnoringSafeArea(.all)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    HeaderView(showProfile: $showProfile)

                    MascotStreakView(streak: dashboardViewModel.streakCount)

                    GoalsSectionView(showingAddGoal: $showingAddGoal, viewModel: viewModel, unitsManager: unitsManager)

                    AIIslandView { fetchReviewDataAndShowSheet() }
                        .disabled(isFetchingReviewData)
                        .opacity(isFetchingReviewData ? 0.5 : 1.0)

                    VStack(spacing: 16) {
                        PeriodPicker(selectedPeriod: $viewModel.selectedPeriod)
                        QuickStatsView(stats: currentStats, unitsManager: unitsManager, period: viewModel.selectedPeriod, viewModel: viewModel)
                    }

                    ComparisonSectionView(viewModel: viewModel, unitsManager: unitsManager)

                    AdvancedStatsSectionView(viewModel: viewModel, userGender: userGender)

                    AllTimeResultsView(bestStats: dashboardViewModel.bestMonthStats, unitsManager: unitsManager)

                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 20)
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingAddGoal) {
            GoalSelectionSheet(onGoalCreated: {
                Task { await viewModel.loadActiveGoals(prCache: dashboardViewModel.personalRecordsCache) }
            })
            .environment(unitsManager)
            .environment(dashboardViewModel)
            .presentationDetents([.fraction(0.85), .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showProfile) {
            ProfileView()
                .environment(userStatsViewModel.progressManager)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showAIReviewSheet) {
            if let data = reviewData {
                AIWeeklyReviewSheet(
                    currentStats: data.currentStats,
                    previousStats: data.previousStats,
                    weakPoints: dashboardViewModel.weakPoints,
                    recentPRs: data.recentPRs,
                    aiLogicService: di.aiLogicService
                )
            } else {
                ProgressView("AI is analyzing...")
                    .presentationDetents([.medium])
            }
        }
    }

    private func fetchReviewDataAndShowSheet() {
        guard !isFetchingReviewData else { return }
        isFetchingReviewData = true

        Task {
            let calendar = Calendar.current
            let now = Date()
            let currentInterval = calendar.dateInterval(of: .weekOfYear, for: now)!
            let lastWeek = calendar.date(byAdding: .day, value: -7, to: now)!
            let previousInterval = calendar.dateInterval(of: .weekOfYear, for: lastWeek)!

            let data = await di.analyticsService.fetchStatsData(
                period: .week,
                metric: .volume,
                currentInterval: currentInterval,
                previousInterval: previousInterval,
                prCache: dashboardViewModel.personalRecordsCache
            )

            await MainActor.run {
                self.reviewData = data
                self.isFetchingReviewData = false
                self.showAIReviewSheet = true
            }
        }
    }
}

struct HeaderView: View {
    @Binding var showProfile: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack {
            Text("Progress")
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundColor(colorScheme == .dark ? .white : .black)
            Spacer()

            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showProfile = true
            }) {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(colorScheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.1), lineWidth: 1))
                    .foregroundStyle(colorScheme == .dark ? .purple : .blue, colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.1))
            }
        }
        .padding(.top, 10)
    }
}

struct MascotStreakView: View {
    let streak: Int
    @Environment(\.colorScheme) private var colorScheme
    @Environment(ThemeManager.self) private var themeManager
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 60, height: 60)
                    .shadow(color: .orange.opacity(0.5), radius: 10, x: 0, y: 5)

                if UIImage(named: "fire_mascot") != nil {
                    Image("fire_mascot")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 50, height: 50)
                        .offset(y: -3)
                } else {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.white)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(streak > 0 ? "You're on fire! 🔥" : "Start your streak today!")
                    .font(.subheadline)
                    .foregroundColor(colorScheme == .dark ? .gray : .secondary)
                Text("\(streak) дней тренировок подряд")
                    .font(.headline)
                    .foregroundColor(colorScheme == .dark ? .white : .black)
            }
            Spacer()
        }
        .padding()
        .background(colorScheme == .dark ? themeManager.current.surface : Color.white)
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(colorScheme == .dark ? Color.white.opacity(0.05) : Color.clear, lineWidth: 1))
        .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.05), radius: 10, y: 4)
    }
}

struct GoalsSectionView: View {
    @Binding var showingAddGoal: Bool
    let viewModel: StatsViewModel
    let unitsManager: UnitsManager
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var colorScheme
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Goals")
                        .font(.title2).bold()
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                    Text("Challenge Yourself")
                        .font(.subheadline)
                        .foregroundColor(colorScheme == .dark ? .gray : .secondary)
                }
                Spacer()

                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showingAddGoal = true
                }) {
                    HStack {
                        Image(systemName: "plus")
                        Text("Add")
                    }
                    .font(.system(size: 14, weight: .bold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(colorScheme == .dark ? Color.white : themeManager.current.primaryAccent)
                    .foregroundColor(colorScheme == .dark ? .black : .white)
                    .clipShape(Capsule())
                    .shadow(color: colorScheme == .dark ? .clear : themeManager.current.primaryAccent.opacity(0.3), radius: 5, y: 2)
                }
            }

            if viewModel.activeGoals.isEmpty {
                VStack(spacing: 12) {
                    Text("You have no active goals yet.")
                        .foregroundColor(colorScheme == .dark ? .gray : .secondary)
                        .font(.subheadline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(colorScheme == .dark ? Color.white.opacity(0.03) : Color.white)
                .cornerRadius(16)
                .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.03), radius: 5, y: 2)
            } else {
                ForEach(viewModel.activeGoals) { goal in
                    DesignerGoalCard(goal: goal, currentValue: viewModel.activeGoalValues[goal.id] ?? 0, unitsManager: unitsManager) {
                        deleteGoal(goal)
                    }
                }
            }
        }
    }

    private func deleteGoal(_ goal: UserGoal) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            viewModel.activeGoals.removeAll { $0.id == goal.id }
        }
        Task {
            context.delete(goal)
            try? context.save()
        }
    }
}

struct DesignerGoalCard: View {
    let goal: UserGoal
    let currentValue: Double
    let unitsManager: UnitsManager
    let onDelete: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                ZStack {
                    Circle().fill(iconColor.opacity(0.15)).frame(width: 40, height: 40)
                    Image(systemName: iconName).foregroundColor(iconColor)
                }
                VStack(alignment: .leading) {
                    Text(title).font(.headline).foregroundColor(colorScheme == .dark ? .white : .black)
                    Text(subtitle).font(.caption).foregroundColor(colorScheme == .dark ? .gray : .secondary)
                }
                Spacer()
                Menu {
                    Button(role: .destructive, action: onDelete) { Label("Delete", systemImage: "trash") }
                } label: { Image(systemName: "ellipsis").foregroundColor(colorScheme == .dark ? .gray : .secondary).padding(8) }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05)).frame(height: 8)
                    Capsule()
                        .fill(LinearGradient(colors: [iconColor.opacity(0.6), iconColor], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * CGFloat(calculateProgress()), height: 8)
                }
            }.frame(height: 8)

            HStack {
                Text(currentText).font(.caption).bold().foregroundColor(colorScheme == .dark ? .white : .black)
                Spacer()
                Text(targetText).font(.caption).foregroundColor(colorScheme == .dark ? .gray : .secondary)
            }
        }
        .padding()
        .background(colorScheme == .dark ? Color.white.opacity(0.03) : Color.white)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(colorScheme == .dark ? Color.white.opacity(0.05) : Color.clear, lineWidth: 1))
        .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.05), radius: 8, y: 4)
    }

    private var iconName: String { goal.type == .strength ? "dumbbell.fill" : (goal.type == .bodyweight ? "scalemass.fill" : "flame.fill") }
    private var iconColor: Color { goal.type == .strength ? .blue : (goal.type == .bodyweight ? .purple : .orange) }
    private var title: String { goal.type == .strength ? (goal.exerciseName ?? "Exercise") : (goal.type == .bodyweight ? "Body Weight" : "Streak") }
    private var subtitle: String { goal.type == .strength ? "Strength Goal" : (goal.type == .bodyweight ? "Transformation" : "Discipline") }

    private func calculateProgress() -> Double {
        if goal.type == .bodyweight {
            let totalDist = abs(goal.targetValue - goal.startingValue)
            let curDist = abs(currentValue - goal.startingValue)
            if totalDist == 0 { return 1.0 }
            return min(1.0, curDist / totalDist)
        } else {
            let totalDist = goal.targetValue - goal.startingValue
            let curDist = currentValue - goal.startingValue
            if totalDist <= 0 { return 1.0 }
            return min(1.0, max(0.0, curDist / totalDist))
        }
    }

    private var currentText: String {
        switch goal.type {
        case .strength, .bodyweight: return "\(LocalizationHelper.shared.formatDecimal(unitsManager.convertFromKilograms(currentValue))) \(unitsManager.weightUnitString())"
        case .consistency: return "\(Int(currentValue)) дней"
        }
    }

    private var targetText: String {
        switch goal.type {
        case .strength: return "\(LocalizationHelper.shared.formatDecimal(unitsManager.convertFromKilograms(goal.targetValue))) \(unitsManager.weightUnitString()) x \(goal.targetReps) reps"
        case .bodyweight: return "\(LocalizationHelper.shared.formatDecimal(unitsManager.convertFromKilograms(goal.targetValue))) \(unitsManager.weightUnitString())"
        case .consistency: return "\(Int(goal.targetValue)) дней"
        }
    }
}

struct AIIslandView: View {
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            action()
        }) {
            HStack(spacing: 16) {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundStyle(LinearGradient(colors: [.purple, .cyan], startPoint: .top, endPoint: .bottom))

                Text("AI Efficiency Overview")
                    .font(.system(size: 16, weight: .semibold))

                    .foregroundColor(colorScheme == .dark ? .white : .black)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.5) : .gray)
            }
            .padding()

            .background(colorScheme == .dark ? Color.white.opacity(0.05) : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(LinearGradient(colors: [colorScheme == .dark ? .white.opacity(0.4) : .purple.opacity(0.4), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
            )
            .shadow(color: .purple.opacity(colorScheme == .dark ? 0.15 : 0.1), radius: 15, x: 0, y: 8)
        }
        .buttonStyle(.plain)
    }
}

struct PeriodPicker: View {
    @Binding var selectedPeriod: StatsView.Period
    @Namespace private var animation
    @Environment(\.colorScheme) private var colorScheme
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        HStack {
            ForEach(StatsView.Period.allCases) { period in
                Button(action: {
                    UISelectionFeedbackGenerator().selectionChanged()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedPeriod = period
                    }
                }) {
                    Text(period.localizedName)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(selectedPeriod == period ? (colorScheme == .dark ? .black : .white) : .gray)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(
                            ZStack {
                                if selectedPeriod == period {
                                    Capsule()
                                        .fill(colorScheme == .dark ? Color.white : themeManager.current.primaryAccent)
                                        .matchedGeometryEffect(id: "ACTIVETAB", in: animation)
                                }
                            }
                        )
                }
            }
        }
        .padding(4)
        .background(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.05))
        .clipShape(Capsule())
    }
}

struct QuickStatsView: View {
    let stats: PeriodStats
    let unitsManager: UnitsManager
    let period: StatsView.Period
    @Bindable var viewModel: StatsViewModel 

    var body: some View {
        HStack(spacing: 12) {
            InteractiveStatCard(
                icon: "figure.run",
                title: "Workouts",
                value: "\(stats.workoutCount)",
                metric: .count,
                selectedMetric: $viewModel.selectedMetric
            )

            let vol = unitsManager.convertFromKilograms(stats.totalVolume)
            if vol > 1000 {
                InteractiveStatCard(
                    icon: "dumbbell.fill",
                    title: "Volume (Tons)",
                    value: LocalizationHelper.shared.formatTwoDecimals(vol / 1000.0),
                    metric: .volume,
                    selectedMetric: $viewModel.selectedMetric
                )
            } else {
                InteractiveStatCard(
                    icon: "dumbbell.fill",
                    title: "Объем (\(unitsManager.weightUnitString()))",
                    value: "\(Int(vol))",
                    metric: .volume,
                    selectedMetric: $viewModel.selectedMetric
                )
            }

            InteractiveStatCard(
                icon: "map.fill",
                title: "Distance",
                value: "\(LocalizationHelper.shared.formatDecimal(unitsManager.convertFromMeters(stats.totalDistance))) км",
                metric: .distance,
                selectedMetric: $viewModel.selectedMetric
            )
        }
    }
}

struct InteractiveStatCard: View {
    var icon: String
    var title: String
    var value: String
    var metric: StatsView.GraphMetric
    @Binding var selectedMetric: StatsView.GraphMetric
    @Environment(\.colorScheme) private var colorScheme
    @Environment(ThemeManager.self) private var themeManager

    let activeColor = Color(hex: "E020FF")

    var isSelected: Bool {
        selectedMetric == metric
    }

    var body: some View {
        Button(action: {
            UISelectionFeedbackGenerator().selectionChanged()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                selectedMetric = metric
            }
        }) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(isSelected ? activeColor : .gray)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 4) {
                    Text(value)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .contentTransition(.numericText())
                    Text(title)
                        .font(.system(size: 11))
                        .foregroundColor(isSelected ? (colorScheme == .dark ? .white.opacity(0.9) : .black.opacity(0.8)) : .gray)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()

            .background(isSelected ? (colorScheme == .dark ? Color.white.opacity(0.1) : activeColor.opacity(0.1)) : (colorScheme == .dark ? Color.white.opacity(0.03) : Color.white))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? activeColor.opacity(0.6) : (colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.05)), lineWidth: isSelected ? 1.5 : 1)
            )
            .shadow(color: isSelected ? activeColor.opacity(0.3) : .black.opacity(colorScheme == .dark ? 0 : 0.03), radius: 10, y: 5)
        }
        .buttonStyle(.plain)
    }
}

struct ComparisonSectionView: View {
    let viewModel: StatsViewModel
    let unitsManager: UnitsManager
    @Environment(\.colorScheme) private var colorScheme

    let chartGradient = LinearGradient(
        colors: [Color(hex: "E020FF"), Color(hex: "FA64FF")],
        startPoint: .bottom,
        endPoint: .top
    )

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            Text("Детальное сравнение")
                .font(.title3).bold()
                .foregroundColor(colorScheme == .dark ? .white : .black)

            VStack(spacing: 0) {

                if viewModel.chartData.isEmpty {
                    Text("No data for chart")
                        .foregroundColor(.gray)
                        .padding(.vertical, 60)
                } else {
                    Chart {
                        ForEach(viewModel.chartData) { item in
                            let displayVal = viewModel.selectedMetric == .volume ? unitsManager.convertFromKilograms(item.value) : item.value

                            BarMark(
                                x: .value("Период", item.label),
                                y: .value("Значение", displayVal)
                            )
                            .foregroundStyle(chartGradient)
                            .cornerRadius(8)
                        }
                    }
                    .frame(height: 180)
                    .chartYAxis(.hidden)
                    .chartXAxis {
                        AxisMarks { value in
                            AxisValueLabel(centered: true)
                                .foregroundStyle(Color.gray)
                                .font(.caption2)
                        }
                    }
                    .padding(20)
                }

                Divider().background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1))

                if let first = viewModel.chartData.first, let last = viewModel.chartData.last, viewModel.chartData.count > 1 {
                    let fVal = viewModel.selectedMetric == .volume ? unitsManager.convertFromKilograms(first.value) : first.value
                    let lVal = viewModel.selectedMetric == .volume ? unitsManager.convertFromKilograms(last.value) : last.value
                    let unitStr = viewModel.selectedMetric == .volume ? unitsManager.weightUnitString() : (viewModel.selectedMetric == .time ? "min" : (viewModel.selectedMetric == .distance ? "km" : ""))

                    let diff = lVal - fVal
                    let pct = fVal == 0 ? (lVal > 0 ? 100 : 0) : (diff / fVal) * 100.0

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Previous (\(first.label))").font(.caption).foregroundColor(.gray)
                            Text("\(LocalizationHelper.shared.formatFlexible(fVal)) \(unitStr)")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(colorScheme == .dark ? .white : .black)
                        }

                        Spacer()

                        VStack {
                            Text("VS")
                                .font(.system(size: 16, weight: .black))
                                .foregroundColor(colorScheme == .dark ? .white.opacity(0.2) : .black.opacity(0.15))

                            Text("\(pct >= 0 ? "+" : "")\(Int(pct))%")
                                .font(.caption).bold()
                                .foregroundColor(pct >= 0 ? .green : .red)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Current (\(last.label))").font(.caption).foregroundColor(.gray)
                            Text("\(LocalizationHelper.shared.formatFlexible(lVal)) \(unitStr)")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(Color(hex: "E020FF"))
                        }
                    }
                    .padding(20)
                }
            }
            .background(colorScheme == .dark ? Color.white.opacity(0.03) : Color.white)
            .cornerRadius(24)
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(colorScheme == .dark ? Color.white.opacity(0.05) : Color.clear, lineWidth: 1))
            .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.05), radius: 10, y: 5)
        }
        .padding(.top, 10)
    }
}

struct AdvancedStatsSectionView: View {
    @State private var openTab: Int? = nil
    let viewModel: StatsViewModel
    let userGender: String
    @Environment(\.colorScheme) private var colorScheme
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Extended Statistics")
                .font(.title3).bold()
                .foregroundColor(colorScheme == .dark ? .white : .black)

            VStack(spacing: 12) {

                PremiumDisclosureCard(
                    title: "Стиль и оборудование",
                    subtitle: "База против Изоляции и ваш арсенал.",
                    icon: "dumbbell.fill",
                    iconColor: .orange,
                    isExpanded: Binding(get: { openTab == 0 }, set: { openTab = $0 ? 0 : nil })
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Learn which mechanics and equipment dominate your workouts.")
                            .font(.subheadline)
                            .foregroundColor(colorScheme == .dark ? .gray : .secondary)

                        InnerCardNavigationButton(title: "Mechanics Breakdown", icon: "scale.3d", color: .orange) {
                            TrainingStyleDetailView()
                        }
                    }
                }

                PremiumDisclosureCard(
                    title: "Подходы на группу мышц",
                    subtitle: "Количество подходов для каждой мышцы.",
                    icon: "chart.line.uptrend.xyaxis",
                    iconColor: .blue,
                    isExpanded: Binding(get: { openTab == 1 }, set: { openTab = $0 ? 1 : nil })
                ) {
                    VStack(spacing: 16) {
                        if let anatomy = viewModel.anatomyStats, !anatomy.setsPerMuscle.isEmpty {
                            let topMuscles = Array(anatomy.setsPerMuscle.prefix(3))
                            let maxSets = topMuscles.max(by: { $0.count < $1.count })?.count ?? 1

                            VStack(spacing: 12) {
                                ForEach(Array(topMuscles.enumerated()), id: \.element.muscle) { index, item in
                                    let color: Color = index == 0 ? .blue : (index == 1 ? .green : .red)
                                    MuscleRow(name: item.muscle, sets: item.count, color: color, max: max(maxSets, 1))
                                }
                            }
                            .padding()
                            .background(colorScheme == .dark ? Color.white.opacity(0.03) : Color(UIColor.secondarySystemGroupedBackground))
                            .cornerRadius(16)

                            InnerCardNavigationButton(title: "Dynamics and Trends", icon: "waveform.path.ecg", color: .blue) {
                                SetsTrendDetailView()
                            }
                        } else {
                            Text("No data for this period").foregroundColor(.gray)
                        }
                    }
                }

                PremiumDisclosureCard(
                    title: "Баланс развития",
                    subtitle: "Сравнение распределения нагрузки.",
                    icon: "chart.pie.fill",
                    iconColor: .purple,
                    isExpanded: Binding(get: { openTab == 2 }, set: { openTab = $0 ? 2 : nil })
                ) {
                    VStack(spacing: 16) {
                        if let anatomy = viewModel.anatomyStats, !anatomy.setsPerMuscle.isEmpty {

                            ZStack {
                                Chart(anatomy.setsPerMuscle) { item in
                                    SectorMark(angle: .value("Sets", item.count), innerRadius: .ratio(0.65), angularInset: 2)
                                        .foregroundStyle(by: .value("Muscle", item.muscle))
                                        .cornerRadius(4)
                                }
                                .frame(height: 180)
                                .chartLegend(.hidden)

                                VStack {
                                    Text("Leader")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    Text(LocalizedStringKey(anatomy.setsPerMuscle.first?.muscle ?? ""))
                                        .font(.headline)
                                        .bold()
                                        .foregroundColor(colorScheme == .dark ? .white : .black)
                                }
                            }
                            .padding(.vertical, 10)

                            InnerCardNavigationButton(title: "Open Muscle Radar", icon: "viewfinder", color: .purple) {
                                RadarChartDetailView()
                            }
                        } else {
                            Text("No data").foregroundColor(.gray)
                        }
                    }
                }

                PremiumDisclosureCard(
                    title: "Карта тела (Анатомия)",
                    subtitle: "Тепловая карта работавших мышц.",
                    icon: "figure.arms.open", 
                    iconColor: .red,
                    isExpanded: Binding(get: { openTab == 3 }, set: { openTab = $0 ? 3 : nil })
                ) {
                    VStack(spacing: 0) {

                        ZStack {

                            (colorScheme == .dark ? Color(hex: "151517") : Color(UIColor.secondarySystemGroupedBackground))

                            RadialGradient(
                                colors: [Color.red.opacity(0.15), .clear],
                                center: .center,
                                startRadius: 10,
                                endRadius: 120
                            )

                            if let anatomy = viewModel.anatomyStats, !anatomy.heatmapIntensities.isEmpty {
                                BodyHeatmapView(
                                    muscleIntensities: anatomy.heatmapIntensities,
                                    isRecoveryMode: false,
                                    isCompactMode: true,
                                    defaultToBack: false,
                                    userGender: userGender
                                )
                                .frame(height: 240)
                                .scaleEffect(0.9)
                                .offset(y: 10)
                                .allowsHitTesting(false) 
                            } else {

                                Image(systemName: "figure.arms.open")
                                    .font(.system(size: 100))
                                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.1) : .black.opacity(0.1))
                            }
                        }
                        .frame(height: 240)

                        Divider()
                            .background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1))

                        NavigationLink(destination: HeatmapDetailView(gender: userGender)) {
                            HStack {
                                Image(systemName: "flame.fill")
                                    .foregroundColor(.red)
                                Text("Open Tension Map")
                                    .font(.subheadline)
                                    .bold()
                                    .foregroundColor(colorScheme == .dark ? .white : .black)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.bold())
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .background(colorScheme == .dark ? Color.white.opacity(0.02) : Color.white)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.05), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0.2 : 0.05), radius: 10, y: 5)
                }

                PremiumDisclosureCard(
                    title: "30-Дневный Отчет",
                    subtitle: "Итоги ваших тренировок в формате Stories.",
                    icon: "doc.text.fill",
                    iconColor: .cyan,
                    isExpanded: Binding(get: { openTab == 4 }, set: { openTab = $0 ? 4 : nil })
                ) {
                    VStack(alignment: .leading) {
                        InnerCardNavigationButton(title: "View Stories", icon: "play.rectangle.fill", color: .cyan) {
                            MonthlyReportStoryView()
                        }
                    }
                }
            }
        }
        .padding(.top, 10)
    }
}
struct PremiumDisclosureCard<Content: View>: View {
    let title: String
    let subtitle: String
    let icon: String
    let iconColor: Color
    @Binding var isExpanded: Bool
    let content: () -> Content
    @Environment(\.colorScheme) private var colorScheme
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                UISelectionFeedbackGenerator().selectionChanged()
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(iconColor.opacity(0.15))
                            .frame(width: 48, height: 48)
                        Image(systemName: icon)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(iconColor)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(LocalizedStringKey(title))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                        Text(LocalizedStringKey(subtitle))
                            .font(.system(size: 12))
                            .foregroundColor(colorScheme == .dark ? .gray : .secondary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.gray.opacity(0.5))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(16)
                .background(colorScheme == .dark ? Color.white.opacity(0.03) : Color.white)
            }

            if isExpanded {
                VStack(alignment: .leading) {
                    Divider().background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1))
                        .padding(.horizontal, 16)

                    content()
                        .padding(16)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(colorScheme == .dark ? Color.white.opacity(0.01) : Color.white)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(colorScheme == .dark ? Color.white.opacity(0.05) : Color.clear, lineWidth: 1))
        .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.05), radius: 8, y: 4)
    }
}
struct InnerCardNavigationButton<Destination: View>: View {
    let title: String
    let icon: String
    let color: Color
    let destination: () -> Destination

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(color)
                }

                Text(LocalizedStringKey(title))
                    .font(.subheadline)
                    .bold()
                    .foregroundColor(colorScheme == .dark ? .white : .black)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundColor(.gray)
            }
            .padding(12)
            .background(colorScheme == .dark ? Color.white.opacity(0.03) : Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.05), lineWidth: 1)
            )
        }
    }
}
struct MuscleRow: View {
    var name: String
    var sets: Int
    var color: Color
    var max: Int
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(LocalizedStringKey(name)).font(.caption).foregroundColor(.gray)
                Spacer()
                Text("\(sets) подх.").font(.caption).bold().foregroundColor(colorScheme == .dark ? .white : .black)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05)).frame(height: 8)
                    Capsule().fill(color).frame(width: geo.size.width * CGFloat(sets) / CGFloat(max), height: 8)
                }
            }
            .frame(height: 8)
        }
    }
}

struct AllTimeResultsView: View {
    let bestStats: PeriodStats
    let unitsManager: UnitsManager
    @Environment(\.colorScheme) private var colorScheme

    @Query(filter: #Predicate<Workout> { $0.endTime != nil }, sort: \.date, order: .reverse)
    private var allWorkouts: [Workout]

    @State private var historicalData: [Double] = Array(repeating: 0.0, count: 6)

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("All Time")
                .font(.title3).bold()
                .foregroundColor(colorScheme == .dark ? .white : .black)

            VStack(spacing: 20) {

                Chart {
                    ForEach(Array(historicalData.enumerated()), id: \.offset) { i, val in
                        LineMark(
                            x: .value("Month", i),
                            y: .value("Volume", val)
                        )
                        .foregroundStyle(LinearGradient(colors: [.purple, .cyan], startPoint: .leading, endPoint: .trailing))
                        .interpolationMethod(.catmullRom) 
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))

                        AreaMark(
                            x: .value("Month", i),
                            y: .value("Volume", val)
                        )
                        .foregroundStyle(LinearGradient(colors: [.purple.opacity(0.3), .clear], startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.catmullRom)
                    }
                }
                .frame(height: 120)
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .chartYScale(domain: .automatic(includesZero: true))

                HStack {
                    VStack(alignment: .leading) {
                        Text("Best Month (Volume)").font(.subheadline).foregroundColor(.gray)
                        let vol = unitsManager.convertFromKilograms(bestStats.totalVolume)
                        if vol > 1000 {
                            Text("\(LocalizationHelper.shared.formatTwoDecimals(vol / 1000.0)) тонн").font(.title2).bold().foregroundColor(.purple)
                        } else {
                            Text("\(Int(vol)) \(unitsManager.weightUnitString())").font(.title2).bold().foregroundColor(.purple)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("PR Record").font(.subheadline).foregroundColor(.gray)
                        Text("\(bestStats.workoutCount)").font(.title2).bold().foregroundColor(colorScheme == .dark ? .white : .black)
                    }
                }
            }
            .padding()
            .background(colorScheme == .dark ? Color.white.opacity(0.03) : Color.white)
            .cornerRadius(20)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(colorScheme == .dark ? Color.white.opacity(0.05) : Color.clear, lineWidth: 1))
            .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.05), radius: 10, y: 5)
        }
        .padding(.top, 10)
        .onAppear {
            calculateHistoricalData()
        }
    }

    private func calculateHistoricalData() {
        let cal = Calendar.current
        let now = Date()

        var monthlyVolumes: [Double] = Array(repeating: 0.0, count: 6)

        for workout in allWorkouts {

            let monthsAgo = cal.dateComponents([.month], from: workout.date, to: now).month ?? 0

            if monthsAgo >= 0 && monthsAgo < 6 {

                let index = 5 - monthsAgo

                let convertedVolume = unitsManager.convertFromKilograms(workout.totalStrengthVolume)
                monthlyVolumes[index] += convertedVolume
            }
        }

        withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
            self.historicalData = monthlyVolumes
        }
    }
}

struct SetsTrendDetailView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(ThemeManager.self) private var themeManager

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
                for sub in targets where sub.type == .strength && MuscleCategoryMapper.getBroadCategory(for: sub.muscleGroup) == selectedMuscle {
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

    private var annotatedDates: Set<Date> {
        let data = aggregatedData

        guard data.count > 14 else {
            return Set(data.map { $0.date })
        }

        let threshold = Int(Double(maxSetsInPoint) * 0.90)
        var peaks = Set<Date>()

        for i in 0..<data.count {
            let current = data[i]
            if current.sets >= threshold {
                let prev = i > 0 ? data[i-1].sets : -1
                let next = i < data.count - 1 ? data[i+1].sets : -1

                if current.sets >= prev && current.sets >= next {
                    peaks.insert(current.date)
                }
            }
        }

        if peaks.isEmpty, let absoluteMax = data.max(by: { $0.sets < $1.sets }) {
            peaks.insert(absoluteMax.date)
        }

        return peaks
    }

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

                                .background(isSelected ? muscleColor : (colorScheme == .dark ? themeManager.current.surface : Color.white))

                                .foregroundColor(isSelected ? .white : (colorScheme == .dark ? .white : .black))
                                .cornerRadius(20)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)

                                        .stroke(isSelected ? muscleColor : (colorScheme == .dark ? muscleColor.opacity(0.5) : Color.black.opacity(0.05)), lineWidth: 1.5)
                                )

                                .shadow(color: isSelected ? muscleColor.opacity(0.4) : .black.opacity(colorScheme == .dark ? 0 : 0.05), radius: 8, x: 0, y: 4)
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
                    .foregroundColor(colorScheme == .dark ? themeManager.current.secondaryText : .gray) 

                Text("\(totalSets)")
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .foregroundColor(colorManager.getColor(for: selectedMuscle))
                    .contentTransition(.numericText())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(colorScheme == .dark ? themeManager.current.surface : Color.white) 
            .cornerRadius(16)
            .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.05), radius: 5, y: 2) 

            VStack(alignment: .leading, spacing: 4) {
                let maxLabel: LocalizedStringKey = (selectedPeriod == .year || selectedPeriod == .allTime) ? "Monthly Max" : "Daily Max"

                Text(maxLabel)
                    .font(.subheadline)
                    .foregroundColor(colorScheme == .dark ? themeManager.current.secondaryText : .gray) 

                Text("\(maxSetsInPoint)")
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .foregroundColor(colorScheme == .dark ? themeManager.current.primaryText : .black) 
                    .contentTransition(.numericText())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(colorScheme == .dark ? themeManager.current.surface : Color.white) 
            .cornerRadius(16)
            .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.05), radius: 5, y: 2) 
        }
        .padding(.horizontal)
    }

    private var beautifulChart: some View {
        let muscleColor = colorManager.getColor(for: selectedMuscle)
        let isSinglePoint = aggregatedData.count == 1

        return VStack(alignment: .leading) {
            Text(LocalizedStringKey("Training Volume Over Time"))
                .font(.headline)
                .foregroundColor(colorScheme == .dark ? .white : .black) 
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

                    .annotation(position: .top) {
                        if annotatedDates.contains(point.date) {
                            Text("\(point.sets)")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(colorScheme == .dark ? themeManager.current.secondaryText : .gray) 
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

        .background(colorScheme == .dark ? themeManager.current.surface : Color.white)
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(colorScheme == .dark ? Color.clear : Color.black.opacity(0.05), lineWidth: 1))
        .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.05), radius: 8, y: 4)
        .padding(.horizontal)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: aggregatedData.count)
        .animation(.easeInOut(duration: 0.3), value: selectedMuscle)
    }
}
struct RadarChartDetailView: View {
    @Query(filter: #Predicate<Workout> { $0.endTime != nil }, sort: \.date, order: .reverse)
    private var allWorkouts: [Workout]
    @Environment(\.colorScheme) private var colorScheme
    @Environment(ThemeManager.self) private var themeManager
    enum TrendPeriod: String, CaseIterable, Identifiable {
        case week = "Week", month = "Month", year = "Year", allTime = "All Time"
        var id: String { self.rawValue }
        var localizedName: LocalizedStringKey { LocalizedStringKey(self.rawValue) }
    }

    @State private var selectedPeriod: TrendPeriod = .month
    @State private var highlightedMuscle: String? = nil
    @StateObject private var colorManager = MuscleColorManager.shared

    private let axes = ["Chest", "Back", "Legs", "Shoulders", "Arms", "Core"]

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

        let includeWarmups = UserDefaults.standard.bool(forKey: Constants.UserDefaultsKeys.includeWarmupsInStats.rawValue)

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
                    let completed = sub.setsList.filter { $0.isCompleted && (includeWarmups || $0.type != .warmup) }.count
                    if completed > 0 {
                        let broadCategory = MuscleCategoryMapper.getBroadCategory(for: sub.muscleGroup)
                        if broadCategory != "Other" {
                            if isCurrent {
                                curSets[broadCategory, default: 0] += Double(completed)
                                totalCur += completed
                            } else if isPrev {
                                prevSets[broadCategory, default: 0] += Double(completed)
                            }
                        }
                    }
                } 
            } 
        } 

        let maxCur = curSets.values.max() ?? 1.0
        let maxPrev = prevSets.values.max() ?? 1.0
        let globalMax = max(10.0, max(maxCur, maxPrev))

        let curData = axes.map { RadarDataPoint(axis: $0, value: curSets[$0] ?? 0, maxValue: globalMax) }
        let prevData = axes.map { RadarDataPoint(axis: $0, value: prevSets[$0] ?? 0, maxValue: globalMax) }
        let listStats = axes.map { MuscleCountDTO(muscle: $0, count: Int(curSets[$0] ?? 0)) }.sorted { $0.count > $1.count }

        let curValues = curData.map { $0.value }
        let avg = curValues.reduce(0, +) / Double(axes.count)
        let score: Int
        if avg == 0 {
            score = 0
        } else {
            let variance = curValues.reduce(0) { $0 + pow($1 - avg, 2) } / Double(axes.count)
            let stdDev = sqrt(variance)
            let cv = stdDev / avg
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

                    balanceScoreCard(score: data.balanceScore)

                    radarChartSection(data: data)

                    muscleListSection(data: data)
                }
                .padding(.vertical)
            }
            .navigationTitle(LocalizedStringKey("Muscle distribution (Chart)"))
            .navigationBarTitleDisplayMode(.inline)
            .background(colorScheme == .dark ? themeManager.current.background : Color(UIColor.systemGroupedBackground))
        }

        @ViewBuilder
        private func radarChartSection(data: RadarAggregatedData) -> some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(LocalizedStringKey("Distribution Chart"))
                        .font(.headline)
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                    Spacer()
                    if selectedPeriod != .allTime {
                        HStack(spacing: 12) {
                            HStack(spacing: 4) { Circle().fill(Color.gray.opacity(0.5)).frame(width: 8); Text(LocalizedStringKey("Previous")).font(.caption2).foregroundColor(colorScheme == .dark ? themeManager.current.secondaryText : .gray) }
                            HStack(spacing: 4) { Circle().fill(themeManager.current.primaryAccent).frame(width: 8); Text(LocalizedStringKey("Current")).font(.caption2).foregroundColor(colorScheme == .dark ? themeManager.current.secondaryText : .gray) }
                        }
                    }
                }
                .padding(.horizontal)

                RadarChartView(
                    currentData: data.current,
                    previousData: selectedPeriod == .allTime ? nil : data.previous,
                    highlightedAxis: highlightedMuscle,
                    color: themeManager.current.primaryAccent
                )
                .frame(height: 320)
                .padding()
            }
            .background(colorScheme == .dark ? themeManager.current.surface : Color.white)
            .cornerRadius(20)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(colorScheme == .dark ? Color.clear : Color.black.opacity(0.05), lineWidth: 1))
            .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.05), radius: 8, y: 4)
            .padding(.horizontal)
        }

        @ViewBuilder
        private func muscleListSection(data: RadarAggregatedData) -> some View {
            VStack(alignment: .leading, spacing: 0) {

                HStack {
                    Text(LocalizedStringKey("Muscle")).font(.caption).foregroundColor(colorScheme == .dark ? themeManager.current.secondaryText : .gray)
                    Spacer()
                    Text(LocalizedStringKey("Sets (Share)")).font(.caption).foregroundColor(colorScheme == .dark ? themeManager.current.secondaryText : .gray)
                }
                .padding(.horizontal).padding(.vertical, 12)

                Divider()

                ForEach(data.listStats, id: \.muscle) { item in
                    muscleRow(item: item, totalSets: data.totalCurrentSets)

                    if item.muscle != data.listStats.last?.muscle {
                        Divider().padding(.leading, 36)
                    }
                }
            }
            .background(colorScheme == .dark ? themeManager.current.surface : Color.white)
            .cornerRadius(20)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(colorScheme == .dark ? Color.clear : Color.black.opacity(0.05), lineWidth: 1))
            .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.05), radius: 8, y: 4)
            .padding(.horizontal)
        }

        @ViewBuilder
        private func muscleRow(item: MuscleCountDTO, totalSets: Int) -> some View {
            let isHighlighted = highlightedMuscle == item.muscle
            let percentage = totalSets > 0 ? Double(item.count) / Double(totalSets) * 100 : 0

            let isActive = isHighlighted || highlightedMuscle == nil
            let textColor: Color = isActive ? (colorScheme == .dark ? .white : .black) : .gray
            let subTextColor: Color = colorScheme == .dark ? themeManager.current.secondaryText : .gray

            HStack {
                Circle()
                    .fill(colorManager.getColor(for: item.muscle))
                    .frame(width: 10, height: 10)
                    .opacity(isActive ? 1.0 : 0.3)

                Text(LocalizedStringKey(item.muscle))
                    .font(.subheadline)
                    .fontWeight(isHighlighted ? .bold : .regular)
                    .foregroundColor(textColor)

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(item.count)")
                        .font(.subheadline)
                        .bold()
                        .foregroundColor(textColor)

                    Text("\(percentage, specifier: "%.1f")%")
                        .font(.caption2)
                        .foregroundColor(subTextColor)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(isHighlighted ? themeManager.current.primaryAccent.opacity(0.1) : Color.clear)
            .contentShape(Rectangle())
            .onTapGesture {
                let generator = UISelectionFeedbackGenerator()
                generator.selectionChanged()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    highlightedMuscle = isHighlighted ? nil : item.muscle
                }
            }
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
                    .foregroundColor(colorScheme == .dark ? themeManager.current.primaryText : .black)
                Text(message)
                    .font(.caption)
                    .foregroundColor(colorScheme == .dark ? themeManager.current.secondaryText : .gray)
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding()

        .background(colorScheme == .dark ? themeManager.current.surface : Color.white)
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(colorScheme == .dark ? Color.clear : Color.black.opacity(0.05), lineWidth: 1))
        .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.05), radius: 8, y: 4)
        .padding(.horizontal)
    }
}

    struct RadarChartView: View {
        let currentData: [RadarDataPoint]
        let previousData: [RadarDataPoint]?
        let highlightedAxis: String?
        let color: Color
        @Environment(ThemeManager.self) private var themeManager

        @Environment(\.colorScheme) private var colorScheme 
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

                let chartRadius = (size / 2.0) * 0.70
                let chartDiameter = chartRadius * 2

                let totalCount = currentData.count

                ZStack {

                    ForEach(1...4, id: \.self) { level in
                        let levelRatio = CGFloat(level) / 4.0
                        let levelDiameter = chartDiameter * levelRatio

                        PolygonShape(sides: totalCount)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            .frame(width: levelDiameter, height: levelDiameter)
                    }

                    ForEach(Array(currentData.enumerated()), id: \.offset) { index, point in
                        let currentAngle = computeAngle(for: index, totalCount: totalCount)
                        let isAxisHighlighted = highlightedAxis == point.axis
                        let isDimmed = highlightedAxis != nil && !isAxisHighlighted

                        let endX = centerX + (chartRadius * cos(currentAngle))
                        let endY = centerY + (chartRadius * sin(currentAngle))
                        let endPoint = CGPoint(x: endX, y: endY)

                        Path { path in
                            path.move(to: center)
                            path.addLine(to: endPoint)
                        }
                        .stroke(isAxisHighlighted ? color.opacity(0.8) : Color.gray.opacity(0.3), lineWidth: isAxisHighlighted ? 2 : 1)

                        let labelX = centerX + ((chartRadius + 30.0) * cos(currentAngle))
                        let labelY = centerY + ((chartRadius + 20.0) * sin(currentAngle))

                        Text(LocalizedStringKey(point.axis))
                            .font(.caption2)
                            .fontWeight(isAxisHighlighted ? .bold : .regular)
                            .foregroundColor(isAxisHighlighted ? color : (isDimmed ? .gray.opacity(0.3) : .secondary))
                            .position(x: labelX, y: labelY)
                    }

                    if let prev = previousData {
                        DataPolygonShape(data: prev)

                            .fill(colorScheme == .dark ? themeManager.current.surfaceVariant : Color.gray.opacity(0.15))
                            .frame(width: chartDiameter, height: chartDiameter)

                        DataPolygonShape(data: prev)
                            .stroke(Color.gray.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                            .frame(width: chartDiameter, height: chartDiameter)
                    }

                    DataPolygonShape(data: currentData)
                        .fill(color.opacity(0.3))
                        .frame(width: chartDiameter, height: chartDiameter) 

                    DataPolygonShape(data: currentData)
                        .stroke(color, lineWidth: 2)
                        .frame(width: chartDiameter, height: chartDiameter)

                    ForEach(Array(currentData.enumerated()), id: \.offset) { index, point in
                        let currentAngle = computeAngle(for: index, totalCount: totalCount)
                        let isAxisHighlighted = highlightedAxis == point.axis

                        let ratio = point.maxValue == 0 ? 0 : CGFloat(point.value / point.maxValue)
                        let ptRadius = chartRadius * ratio

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
            .drawingGroup() 
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

    struct HeatmapDetailItem: Identifiable, Sendable {
        let id = UUID()
        let slug: String
        let displayName: String
        let sets: Int
        let relativeIntensity: Double 
    }

    struct HeatmapAggregatedData: Sendable {
        let intensities: [String: Int] 
        let rawCounts: [String: Int]   
        let detailedList: [HeatmapDetailItem]
        let totalSets: Int
        let topMuscle: HeatmapDetailItem?
    }

    @MainActor
    struct HeatmapDataProcessor: Sendable {
        static func process(workouts: [Workout], period: SetsTrendDetailView.TrendPeriod) async -> HeatmapAggregatedData {
            let calendar = Calendar.current
            let now = Date()
            let cutoffDate: Date?

            let includeWarmups = UserDefaults.standard.bool(forKey: Constants.UserDefaultsKeys.includeWarmupsInStats.rawValue)

            switch period {
            case .week: cutoffDate = calendar.date(byAdding: .day, value: -7, to: now)
            case .month: cutoffDate = calendar.date(byAdding: .month, value: -1, to: now)
            case .year: cutoffDate = calendar.date(byAdding: .year, value: -1, to: now)
            case .allTime: cutoffDate = nil
            }

            var slugCounts: [String: Int] = [:]
            var totalSets = 0

            for workout in workouts {
                if let cutoff = cutoffDate, workout.date < cutoff { continue }

                for exercise in workout.exercises {
                    let targets = exercise.isSuperset ? exercise.subExercises : [exercise]
                    for sub in targets where sub.type == .strength {
                        let completedSets = sub.setsList.filter { $0.isCompleted && (includeWarmups || $0.type != .warmup) }.count
                        if completedSets > 0 {
                            let broadCategory = MuscleCategoryMapper.getBroadCategory(for: sub.muscleGroup)
                            let slugs = MuscleMapping.getMuscles(for: sub.name, group: broadCategory)
                            for slug in slugs {
                                slugCounts[slug, default: 0] += completedSets
                            }
                            totalSets += completedSets
                        }
                    } 
                } 
            } 

            let maxSets = Double(slugCounts.values.max() ?? 1)
            var normalizedIntensities: [String: Int] = [:]
            var detailedList: [HeatmapDetailItem] = []

            for (slug, count) in slugCounts {
                let relativeIntensity = Double(count) / maxSets
                normalizedIntensities[slug] = Int(relativeIntensity * 100)
                let displayName = MuscleDisplayHelper.getDisplayName(for: slug)
                detailedList.append(HeatmapDetailItem(slug: slug, displayName: displayName, sets: count, relativeIntensity: relativeIntensity))
            }

            detailedList.sort { $0.sets > $1.sets }

            return HeatmapAggregatedData(
                intensities: normalizedIntensities,
                rawCounts: slugCounts,
                detailedList: detailedList,
                totalSets: totalSets,
                topMuscle: detailedList.first
            )
        }}

struct HeatmapDetailView: View {
       @Query(filter: #Predicate<Workout> { $0.endTime != nil }, sort: \.date, order: .reverse)
       private var allWorkouts: [Workout]
       @Environment(ThemeManager.self) private var themeManager
       let gender: String
       @Environment(\.colorScheme) private var colorScheme 
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

                       if let top = data.topMuscle {
                           topFocusCard(topMuscle: top)
                       }

                       VStack {
                           BodyHeatmapView(
                               muscleIntensities: data.intensities,
                               rawMuscleCounts: data.rawCounts, 
                               isRecoveryMode: false,
                               isCompactMode: false,
                               userGender: gender
                           )
                           .frame(height: 480)
                           .padding(.vertical)
                       }

                       .background(colorScheme == .dark ? themeManager.current.surface : Color.white)
                       .cornerRadius(24)
                       .overlay(RoundedRectangle(cornerRadius: 24).stroke(colorScheme == .dark ? Color.clear : Color.black.opacity(0.05), lineWidth: 1))
                       .shadow(color: .black.opacity(colorScheme == .dark ? 0.05 : 0.05), radius: 10, y: 5)
                       .padding(.horizontal)

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

           .background(colorScheme == .dark ? themeManager.current.background : Color(UIColor.systemGroupedBackground))
           .task(id: selectedPeriod) {
               await calculateData()
           }
       }

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
                       .foregroundColor(colorScheme == .dark ? themeManager.current.secondaryText : .gray) 
                       .textCase(.uppercase)

                   Text(LocalizedStringKey(topMuscle.displayName))
                       .font(.title3)
                       .bold()
                       .foregroundColor(colorScheme == .dark ? themeManager.current.primaryText : .black) 
               }

               Spacer()

               VStack(alignment: .trailing, spacing: 4) {
                   Text(LocalizedStringKey("Sets"))
                       .font(.caption)
                       .foregroundColor(colorScheme == .dark ? themeManager.current.secondaryText : .gray) 
                       .textCase(.uppercase)
                   Text("\(topMuscle.sets)")
                       .font(.title2)
                       .bold()
                       .foregroundColor(.red)
               }
           }
           .padding()

           .background(colorScheme == .dark ? themeManager.current.surface : Color.white)
           .cornerRadius(20)
           .overlay(
               RoundedRectangle(cornerRadius: 20)
                   .stroke(Color.red.opacity(colorScheme == .dark ? 0.3 : 0.15), lineWidth: 1)
           )
           .shadow(color: .red.opacity(colorScheme == .dark ? 0.1 : 0.05), radius: 10, x: 0, y: 4)
           .padding(.horizontal)
       }

       @ViewBuilder
       private func detailedBreakdownList(data: HeatmapAggregatedData) -> some View {
           VStack(alignment: .leading, spacing: 0) {
               HStack {
                   Text(LocalizedStringKey("Detailed Breakdown"))
                       .font(.headline)
                       .foregroundColor(colorScheme == .dark ? themeManager.current.primaryText : .black) 
                   Spacer()
                   Text(LocalizedStringKey("Sets"))
                       .font(.caption)
                       .foregroundColor(colorScheme == .dark ? themeManager.current.secondaryText : .gray) 
               }
               .padding(.horizontal)
               .padding(.vertical, 12)

               Divider().background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1)) 

               ForEach(data.detailedList) { item in
                   HStack(spacing: 16) {
                       VStack(alignment: .leading, spacing: 6) {
                           Text(LocalizedStringKey(item.displayName))
                               .font(.subheadline)
                               .fontWeight(.medium)
                               .foregroundColor(colorScheme == .dark ? themeManager.current.primaryText : .black) 

                           GeometryReader { geo in
                               ZStack(alignment: .leading) {
                                   Capsule()
                                       .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05)) 
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
                           .foregroundColor(colorScheme == .dark ? themeManager.current.primaryText : .black) 
                   }
                   .padding(.horizontal)
                   .padding(.vertical, 12)

                   if item.id != data.detailedList.last?.id {
                       Divider().padding(.leading, 16)
                           .background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1)) 
                   }
               }
           }
           .padding(.bottom, 12)

           .background(colorScheme == .dark ? themeManager.current.surface : Color.white)
           .cornerRadius(24)
           .overlay(RoundedRectangle(cornerRadius: 24).stroke(colorScheme == .dark ? Color.clear : Color.black.opacity(0.05), lineWidth: 1))
           .shadow(color: .black.opacity(colorScheme == .dark ? 0.05 : 0.05), radius: 10, y: 5)
           .padding(.horizontal)
       }

       private func calculateData() async {
           isProcessing = true

           let processedData = await HeatmapDataProcessor.process(workouts: allWorkouts, period: selectedPeriod)

           withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
               self.aggregatedData = processedData
               self.isProcessing = false
           }
       }

       private func intensityColor(for relativeIntensity: Double) -> Color {
           if relativeIntensity > 0.8 { return .red }
           if relativeIntensity > 0.5 { return .orange }
           return .blue
       }
   }

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

        let topMuscle: String
        let favoriteDay: String
        let totalVolumeTons: Double
        let funFactVolume: String
    }

    @MainActor
    struct PeriodReportProcessor: Sendable {

        static func calculateMaxStreak(from dates: Set<Date>, maxRestDays: Int) -> Int {
            let sortedDates = Array(dates).sorted(by: <) 
            guard !sortedDates.isEmpty else { return 0 }

            var maxStreak = 1
            var currentStreak = 1
            let calendar = Calendar.current

            for i in 1..<sortedDates.count {
                let prevDate = sortedDates[i-1]
                let currDate = sortedDates[i]

                let daysBetween = calendar.dateComponents([.day], from: prevDate, to: currDate).day ?? 0

                if daysBetween <= (maxRestDays + 1) {
                    currentStreak += 1
                    maxStreak = max(maxStreak, currentStreak)
                } else {
                    currentStreak = 1 
                }
            }

            return maxStreak
        }

        static func process(workouts: [Workout]) async -> PeriodReportPayload {
            let calendar = Calendar.current
            let now = Date()
            let includeWarmups = UserDefaults.standard.bool(forKey: Constants.UserDefaultsKeys.includeWarmupsInStats.rawValue)

            let curStart = calendar.date(byAdding: .day, value: -30, to: now)!
            let prevEnd = curStart
            let prevStart = calendar.date(byAdding: .day, value: -60, to: now)!

            let df = DateFormatter()
            df.dateFormat = "MMMM yyyy"
            let title = "\(df.string(from: now)) Review"

            var sCW = 0, sPW = 0, sCD = 0, sPD = 0, sCS = 0, sPS = 0
            var sCV = 0.0, sPV = 0.0

            var dictWorkouts: [Date: Double] = [:]
            var dictDuration: [Date: Double] = [:]
            var dictVolume: [Date: Double] = [:]
            var dictSets: [Date: Double] = [:]
            var activeDays = Set<Date>()
            var weekdayCounts: [Int: Int] = [:]

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
                        let cSets = sub.setsList.filter { $0.isCompleted && (includeWarmups || $0.type != .warmup) }
                        wSets += cSets.count

                        var tempSubVol = 0.0
                        for set in cSets {
                            let setWeight = set.weight ?? 0.0
                            let setReps = Double(set.reps ?? 0)
                            tempSubVol += (setWeight * setReps)
                        }
                        wVolume += tempSubVol

                        if cSets.count > 0 {
                            let category = MuscleCategoryMapper.getBroadCategory(for: sub.muscleGroup)
                            if category != "Other" {
                                if isCur { radarCur[category, default: 0] += Double(cSets.count) }
                                else if isPrev { radarPrev[category, default: 0] += Double(cSets.count) }
                            }
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

                    let weekday = calendar.component(.weekday, from: workout.date)
                    weekdayCounts[weekday, default: 0] += 1
                } else if isPrev {
                    sPW += 1; sPD += workout.durationSeconds / 60; sPV += wVolume; sPS += wSets
                }
            }

            var cW: [ReportDailyPoint] = [], cD: [ReportDailyPoint] = [], cV: [ReportDailyPoint] = [], cS: [ReportDailyPoint] = []
            for i in 0..<30 {
                let date = calendar.date(byAdding: .day, value: i, to: curStart)!
                let dayStart = calendar.startOfDay(for: date)
                cW.append(.init(date: dayStart, value: dictWorkouts[dayStart] ?? 0))
                cD.append(.init(date: dayStart, value: dictDuration[dayStart] ?? 0))
                cV.append(.init(date: dayStart, value: dictVolume[dayStart] ?? 0))
                cS.append(.init(date: dayStart, value: dictSets[dayStart] ?? 0))
            }

            let globalMax = max(10.0, max(radarCur.values.max() ?? 1, radarPrev.values.max() ?? 1))
            let rC = axes.map { RadarDataPoint(axis: $0, value: radarCur[$0] ?? 0, maxValue: globalMax) }
            let rP = axes.map { RadarDataPoint(axis: $0, value: radarPrev[$0] ?? 0, maxValue: globalMax) }

            let topMuscle = radarCur.max(by: { $0.value < $1.value })?.key ?? "Chest"

            let topWeekdayIndex = weekdayCounts.max(by: { $0.value < $1.value })?.key ?? 2
            let favoriteDayStr = calendar.weekdaySymbols[topWeekdayIndex - 1]

            let tons = sCV / 1000.0
            let funFact: String
            if tons > 10 { funFact = "That's like lifting 2 Elephants! 🐘🐘" }
            else if tons > 5 { funFact = "That's a T-Rex! 🦖" }
            else if tons > 2 { funFact = "That's a heavy SUV! 🚙" }
            else if tons > 1 { funFact = "That's a Walrus! 🦏" }
            else { funFact = "Every kilo counts! 🏋️" }

            let maxRestDays = UserDefaults.standard.integer(forKey: Constants.UserDefaultsKeys.streakRestDays.rawValue) > 0 ? UserDefaults.standard.integer(forKey: Constants.UserDefaultsKeys.streakRestDays.rawValue) : 2
            let monthMaxStreak = calculateMaxStreak(from: activeDays, maxRestDays: maxRestDays)

            return PeriodReportPayload(
                title: title,
                summary: ReportSummary(currentWorkouts: sCW, prevWorkouts: sPW, currentDuration: sCD, prevDuration: sPD, currentVolume: sCV, prevVolume: sPV, currentSets: sCS, prevSets: sPS),
                chartWorkouts: cW, chartDuration: cD, chartVolume: cV, chartSets: cS,
                activeDays: activeDays,
                streakDays: monthMaxStreak, 
                radarCurrent: rC, radarPrevious: rP,
                topMuscle: topMuscle,
                favoriteDay: favoriteDayStr,
                totalVolumeTons: tons,
                funFactVolume: funFact
            )
        }
    }

    enum ReportSlide: Int, CaseIterable {
        case intro = 0
        case volume = 1
        case focus = 2
        case outro = 3
    }

    struct MonthlyReportStoryView: View {
        @Query(filter: #Predicate<Workout> { $0.endTime != nil }, sort: \.date, order: .reverse)
        private var allWorkouts: [Workout]

        @Environment(\.dismiss) private var dismiss
        @Environment(UnitsManager.self) var unitsManager

        @State private var payload: PeriodReportPayload?
        @State private var currentSlide: ReportSlide = .intro
        @State private var slideProgress: CGFloat = 0.0
        @State private var isPaused: Bool = false
        @State private var isProcessing: Bool = true

        let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
        let ticksPerSlide: CGFloat = 140.0

        @State private var dragStartTime: Date? = nil

        var body: some View {
            ZStack {
                Color.black.ignoresSafeArea()

                if isProcessing {
                    ProgressView().tint(.white).scaleEffect(1.5)
                } else if let data = payload {

                    GeometryReader { geo in
                        ZStack {
                            switch currentSlide {
                            case .intro:
                                StorySlideIntro(data: data)
                            case .volume:
                                StorySlideVolume(data: data, unitsManager: unitsManager)
                            case .focus:
                                StorySlideFocus(data: data)
                            case .outro:
                                StorySlideOutro(data: data, dismissAction: { dismiss() })
                            }
                        }
                        .frame(width: geo.size.width, height: geo.size.height)
                        .contentShape(Rectangle())

                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { _ in
                                    isPaused = true
                                    if dragStartTime == nil { dragStartTime = Date() }
                                }
                                .onEnded { value in
                                    isPaused = false
                                    let duration = Date().timeIntervalSince(dragStartTime ?? Date())
                                    dragStartTime = nil

                                    if duration < 0.3 {
                                        let generator = UIImpactFeedbackGenerator(style: .light)
                                        generator.impactOccurred()
                                        if value.location.x < geo.size.width / 2 {
                                            prevSlide()
                                        } else {
                                            nextSlide()
                                        }
                                    }
                                }
                        )
                    }

                    VStack {
                        StoryProgressBar(
                            slidesCount: ReportSlide.allCases.count,
                            currentIndex: currentSlide.rawValue,
                            progress: slideProgress
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 16) 

                        HStack {
                            Button { dismiss() } label: {
                                Image(systemName: "xmark")
                                    .font(.title2.bold())
                                    .foregroundColor(.white)
                                    .padding(16)
                                    .shadow(color: .black.opacity(0.5), radius: 5)
                            }
                            Spacer()
                        }
                        Spacer()
                    }
                    .ignoresSafeArea(edges: .bottom)
                }
            }
            .navigationBarHidden(true)
            .toolbar(.hidden, for: .tabBar) 
            .onReceive(timer) { _ in
                guard !isPaused, !isProcessing else { return }
                slideProgress += 1.0 / ticksPerSlide
                if slideProgress >= 1.0 {
                    nextSlide()
                }
            }
            .task {

                let processed = await PeriodReportProcessor.process(workouts: allWorkouts)

                self.payload = processed
                withAnimation { self.isProcessing = false }
            }
        }

        private func nextSlide() {
            slideProgress = 0.0
            if let next = ReportSlide(rawValue: currentSlide.rawValue + 1) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentSlide = next
                }
            } else {

                dismiss()
            }
        }

        private func prevSlide() {
            slideProgress = 0.0
            if let prev = ReportSlide(rawValue: currentSlide.rawValue - 1) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentSlide = prev
                }
            } else {
                slideProgress = 0.0
            }
        }
    }

    struct StoryProgressBar: View {
        let slidesCount: Int
        let currentIndex: Int
        let progress: CGFloat

        var body: some View {
            HStack(spacing: 6) {
                ForEach(0..<slidesCount, id: \.self) { index in
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.3))

                            Capsule()
                                .fill(Color.white)
                                .frame(width: geo.size.width * widthMultiplier(for: index))
                        }
                    }
                    .frame(height: 4)
                }
            }
            .shadow(color: .black.opacity(0.5), radius: 2)
        }

        private func widthMultiplier(for index: Int) -> CGFloat {
            if index < currentIndex { return 1.0 }
            if index == currentIndex { return progress }
            return 0.0
        }
    }

    struct StorySlideIntro: View {
        let data: PeriodReportPayload
        @Environment(ThemeManager.self) private var themeManager

        @State private var isAnimatingBg = false
        @State private var floatAnim1 = false
        @State private var floatAnim2 = false
        @State private var floatAnim3 = false

        var body: some View {
            ZStack {

                Color.black.ignoresSafeArea()

                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.6))
                        .frame(width: 400, height: 400)
                        .blur(radius: 120)
                        .offset(x: isAnimatingBg ? 150 : -200, y: isAnimatingBg ? -200 : 200)

                    Circle()
                        .fill(Color.cyan.opacity(0.6))
                        .frame(width: 350, height: 350)
                        .blur(radius: 120)
                        .offset(x: isAnimatingBg ? -150 : 200, y: isAnimatingBg ? 200 : -150)
                }

                VStack(spacing: 40) {
                    Spacer()

                    Text("Your Month\nin Review")
                        .font(.system(size: 50, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .shadow(color: .purple.opacity(0.8), radius: 20, x: 0, y: 10)

                    VStack(spacing: 20) {
                        neoGlassCard(title: "Workouts", value: "\(data.summary.currentWorkouts)", icon: "bolt.fill", color: .cyan)
                            .offset(y: floatAnim1 ? -8 : 8)
                            .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: floatAnim1)

                        neoGlassCard(title: "Minutes", value: "\(data.summary.currentDuration)", icon: "stopwatch.fill", color: .purple)
                            .offset(y: floatAnim2 ? 8 : -8)
                            .animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true).delay(0.5), value: floatAnim2)

                        neoGlassCard(
                            title: "Favorite Day",
                            value: data.favoriteDay.capitalized, 
                            icon: "star.fill",                   
                            color: .green
                        )
                        .offset(y: floatAnim3 ? -6 : 6)
                        .animation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true).delay(1.0), value: floatAnim3)
                    }
                    .padding(.horizontal, 24)

                    Spacer()
                }
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true)) {
                    isAnimatingBg = true
                }
                floatAnim1 = true
                floatAnim2 = true
                floatAnim3 = true
            }
        }

        private func neoGlassCard(title: String, value: String, icon: String, color: Color) -> some View {
            HStack {
                ZStack {
                    Circle().fill(color.opacity(0.2)).frame(width: 50, height: 50)
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(color)
                        .shadow(color: color, radius: 5)
                }

                Text(LocalizedStringKey(title))
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.8))

                Spacer()

                Text(value)
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: color.opacity(0.8), radius: 10)
            }
            .padding(20)
            .background(.ultraThinMaterial)
            .environment(\.colorScheme, ColorScheme.dark)
            .cornerRadius(24)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(LinearGradient(colors: [color.opacity(0.8), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
            )
            .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
        }
    }

    struct StorySlideVolume: View {
        let data: PeriodReportPayload
        let unitsManager: UnitsManager
        @Environment(ThemeManager.self) private var themeManager

        @State private var animateChart = false

        var body: some View {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()

                    VStack(spacing: 8) {
                        Text(LocalizedStringKey("You moved\nmountains."))
                            .font(.system(size: 40, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)

                        let volStr = LocalizationHelper.shared.formatTwoDecimals(data.totalVolumeTons)

                        Text("\(volStr) tons")
                            .font(.system(size: 65, weight: .black, design: .rounded))
                            .foregroundColor(.cyan)
                            .shadow(color: .cyan.opacity(0.8), radius: 25, x: 0, y: 0)
                            .contentTransition(.numericText())

                        Text("Daily lifting volume over the last 30 days")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white.opacity(0.5))
                            .textCase(.uppercase)
                            .padding(.bottom, 10) 
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)

                    Chart(data.chartVolume) { point in
                        let val = unitsManager.convertFromKilograms(point.value)

                        LineMark(
                            x: .value("Day", point.date),
                            y: .value("Vol", animateChart ? val : 0)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(.cyan)
                        .lineStyle(StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                        .shadow(color: .cyan.opacity(0.6), radius: 10, y: 5)

                        AreaMark(
                            x: .value("Day", point.date),
                            y: .value("Vol", animateChart ? val : 0)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.cyan.opacity(0.5), .black.opacity(0.0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .frame(height: 300)
                    .padding(.horizontal, -10) 

                    Spacer()
                }
            }
            .onAppear {
                withAnimation(.spring(response: 1.5, dampingFraction: 0.8).delay(0.2)) {
                    animateChart = true
                }
            }
        }
    }

    struct StorySlideFocus: View {
        let data: PeriodReportPayload
        @Environment(ThemeManager.self) private var themeManager

        var body: some View {
            ZStack {
                Color.black.ignoresSafeArea()

                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 400, height: 400)
                    .blur(radius: 100)

                VStack(spacing: 30) {
                    Spacer()

                    VStack(spacing: 10) {
                        Text(LocalizedStringKey("You destroyed your"))
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.9))

                        Text(LocalizedStringKey(data.topMuscle))
                            .font(.system(size: 60, weight: .black, design: .rounded))
                            .textCase(.uppercase)

                            .foregroundStyle(LinearGradient(colors: [.green, .cyan], startPoint: .leading, endPoint: .trailing))
                            .shadow(color: .green.opacity(0.8), radius: 25, x: 0, y: 0)
                    }
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)

                    RadarChartView(
                        currentData: data.radarCurrent,
                        previousData: nil,
                        highlightedAxis: data.topMuscle,
                        color: .cyan
                    )
                    .frame(height: 350)
                    .padding(30)
                    .background(Color(white: 0.05))
                    .cornerRadius(40)
                    .overlay(
                        RoundedRectangle(cornerRadius: 40)
                            .stroke(LinearGradient(colors: [.cyan, .green], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2)
                    )
                    .shadow(color: .cyan.opacity(0.2), radius: 30, x: 0, y: 15)
                    .padding(.horizontal, 24)

                    Spacer()
                }
            }
        }
    }

    struct StorySlideOutro: View {
        let data: PeriodReportPayload
        var dismissAction: () -> Void
        @Environment(ThemeManager.self) private var themeManager

        @State private var dragOffset: CGSize = .zero
        @State private var isPulsing = false

        private var last28Days: [Date] {
            let cal = Calendar.current
            let today = cal.startOfDay(for: Date())
            return (0..<28).compactMap { cal.date(byAdding: .day, value: -$0, to: today) }.reversed()
        }

        var body: some View {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()

                    ZStack {
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .fill(Color(white: 0.08))

                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .environment(\.colorScheme, ColorScheme.dark)

                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .stroke(LinearGradient(colors: [.purple, .cyan, .green], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2)

                        VStack(spacing: 30) {
                            Text("DISCIPLINE")
                                .font(.system(size: 24, weight: .black, design: .rounded))
                                .tracking(4)
                                .foregroundStyle(LinearGradient(colors: [.purple, .cyan], startPoint: .leading, endPoint: .trailing))

                            HStack(spacing: 20) {
                                holoStat(value: "\(data.streakDays)", title: "Max Streak", color: .orange)
                                holoStat(value: "\(data.activeDays.count)", title: "Gym Days", color: .cyan)
                                holoStat(value: "\(data.summary.currentSets)", title: "Sets Done", color: .green)
                            }

                            Divider().background(Color.white.opacity(0.2))

                            VStack(alignment: .leading, spacing: 8) {
                                Text("ACTIVITY HEATMAP (LAST 28 DAYS)")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white.opacity(0.5))

                                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                                    ForEach(last28Days, id: \.self) { date in
                                        let isActive = data.activeDays.contains(where: { Calendar.current.isDate($0, inSameDayAs: date) })

                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(isActive ? Color.cyan : Color.white.opacity(0.1))
                                            .aspectRatio(1, contentMode: .fit)
                                            .shadow(color: isActive ? Color.cyan.opacity(0.6) : .clear, radius: 4)
                                    }
                                }
                            }
                        } 
                        .padding(30)
                    }
                    .frame(width: 340, height: 460)
                    .rotation3DEffect(.degrees(Double(dragOffset.width / 10)), axis: (x: 0, y: 1, z: 0))
                    .rotation3DEffect(.degrees(Double(-dragOffset.height / 10)), axis: (x: 1, y: 0, z: 0))
                    .shadow(color: .cyan.opacity(0.3), radius: 40, x: dragOffset.width/3, y: dragOffset.height/3)
                    .gesture(
                        DragGesture()
                            .onChanged { val in withAnimation(.interactiveSpring()) { dragOffset = val.translation } }
                            .onEnded { _ in withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { dragOffset = .zero } }
                    )

                    Spacer()

                    Button {
                        let generator = UIImpactFeedbackGenerator(style: .heavy)
                        generator.impactOccurred()

                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.title2.bold())
                            Text(LocalizedStringKey("SHARE STATS"))
                                .font(.title2.bold())
                                .tracking(2)
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 22)
                        .background(LinearGradient(colors: [.cyan, .green], startPoint: .leading, endPoint: .trailing))
                        .clipShape(Capsule())
                        .scaleEffect(isPulsing ? 1.05 : 1.0)
                        .shadow(color: .green.opacity(isPulsing ? 0.8 : 0.4), radius: isPulsing ? 25 : 10, y: 5)
                    }
                    .padding(.horizontal, 30)
                    .padding(.bottom, 40)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                            isPulsing = true
                        }
                    }
                }
            }
        }

        private func holoStat(value: String, title: String, color: Color) -> some View {
            VStack(spacing: 6) {
                Text(value)
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: color.opacity(0.8), radius: 10)

                Text(LocalizedStringKey(title))
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(color)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }

    struct MonthlyReportDetailsView: View {
        let data: PeriodReportPayload
        @Environment(ThemeManager.self) private var themeManager

        @Environment(UnitsManager.self) var unitsManager
        @State private var selectedMetric: ReportChartMetric = .workouts

        var body: some View {
            ScrollView {
                VStack(spacing: 20) {
                    summaryGrid(data: data.summary)
                    chartSection(data: data)
                    calendarSection(data: data)
                    radarSection(data: data)
                }
            }
        }

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
                    .foregroundStyle(themeManager.current.primaryGradient)
                    .cornerRadius(4)
                    .annotation(position: .top) {
                        if val > 0 {
                            Text(LocalizationHelper.shared.formatFlexible(val))
                                .font(.caption2)
                                .foregroundColor(themeManager.current.secondaryText)
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
            .background(themeManager.current.surface)
        }

        @ViewBuilder
        private func summaryGrid(data: ReportSummary) -> some View {
            VStack(alignment: .leading, spacing: 12) {
                Text(LocalizedStringKey("Summary"))
                    .font(.headline)
                    .foregroundColor(themeManager.current.secondaryText)
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
                    .foregroundColor(themeManager.current.primaryText)

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
            .background(themeManager.current.surface)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(themeManager.current.surfaceVariant, lineWidth: 1))
        }

        @ViewBuilder
        private func calendarSection(data: PeriodReportPayload) -> some View {
            VStack(alignment: .center, spacing: 16) {
                HStack {
                    Text(LocalizedStringKey("Workout Days Log"))
                        .font(.headline)
                        .foregroundColor(themeManager.current.secondaryText)
                    Spacer()
                }
                .padding(.horizontal)

                VStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 40))
                        .foregroundColor(themeManager.current.secondaryMidTone)
                        .shadow(color: themeManager.current.secondaryMidTone.opacity(0.5), radius: 10, x: 0, y: 5)

                    Text("\(data.streakDays) Day Streak")
                        .font(.title2)
                        .bold()
                }
                .padding(.vertical, 10)

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
                                .foregroundColor(themeManager.current.secondaryText)
                                .frame(maxWidth: .infinity)
                        }
                    }

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                        ForEach(0..<offset, id: \.self) { _ in Color.clear.aspectRatio(1, contentMode: .fill) }

                        ForEach(days, id: \.self) { date in
                            let isActive = data.activeDays.contains(cal.startOfDay(for: date))
                            ZStack {
                                Circle()
                                    .fill(isActive ? themeManager.current.primaryAccent : themeManager.current.surfaceVariant)
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
                .background(themeManager.current.surface)
                .cornerRadius(16)
                .padding(.horizontal)
            }
        }

        @ViewBuilder
        private func radarSection(data: PeriodReportPayload) -> some View {
            VStack(alignment: .leading, spacing: 16) {
                Text(LocalizedStringKey("Muscle Distribution"))
                    .font(.headline)
                    .foregroundColor(themeManager.current.secondaryText)
                    .padding(.horizontal)

                VStack {
                    RadarChartView(
                        currentData: data.radarCurrent,
                        previousData: data.radarPrevious,
                        highlightedAxis: nil,
                        color: themeManager.current.primaryAccent
                    )
                    .frame(height: 250)
                    .padding()

                    HStack(spacing: 16) {
                        HStack(spacing: 4) { Circle().fill(Color.gray.opacity(0.5)).frame(width: 8); Text(LocalizedStringKey("Previous")).font(.caption) }
                        HStack(spacing: 4) { Circle().fill(themeManager.current.primaryAccent).frame(width: 8); Text(LocalizedStringKey("Current")).font(.caption) }
                    }
                    .padding(.bottom, 16)
                }
                .background(themeManager.current.surface)
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
        @Environment(ThemeManager.self) private var themeManager

        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : themeManager.current.primaryAccent)

                Text(value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                    .foregroundColor(isSelected ? .white : .primary)

                VStack(alignment: .leading) {
                    Text(title)
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)

                    Text("\(change >= 0 ? "+" : "")\(change, specifier: "%.0f")%")
                        .font(.caption.bold())
                        .foregroundColor(isSelected ? .white : (change >= 0 ? .green : .red))
                }
            }
            .padding()
            .frame(minWidth: 140, alignment: .leading)
            .background(isSelected ? themeManager.current.primaryAccent : themeManager.current.surface)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(isSelected ? Color.white.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: isSelected ? themeManager.current.primaryAccent.opacity(0.4) : .black.opacity(0.04), radius: 8, x: 0, y: 4)
            .compositingGroup()
        }
    }

