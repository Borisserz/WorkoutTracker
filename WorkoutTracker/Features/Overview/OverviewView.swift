// MARK: - FILE: WorkoutTracker/Features/Overview/OverviewView.swift

internal import SwiftUI
import SwiftData
import Charts
import ActivityKit

// MARK: - 1. Router (Чистая логика навигации)

@Observable
@MainActor
final class OverviewRouter {
    var path = NavigationPath()
    var activeSheet: SheetDestination? = nil
    
    enum SheetDestination: Identifiable {
        case settings
        case addWorkout
        case muscleColor
        case profile
        
        var id: String {
            switch self {
            case .settings: return "settings"
            case .addWorkout: return "addWorkout"
            case .muscleColor: return "muscleColor"
            case .profile: return "profile"
            }
        }
    }
    
    enum RouteDestination: Hashable {
        case workoutDetail(Workout)
        case exercises
        case detailedRecovery
    }
    
    func push(_ route: RouteDestination) {
        path.append(route)
    }
    
    func present(_ sheet: SheetDestination) {
        activeSheet = sheet
    }
    
    func dismissSheet() {
        activeSheet = nil
    }
}

// MARK: - 2. Main View

struct OverviewView: View {
    // MARK: - Environment
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.modelContext) private var context
    @Environment(TutorialManager.self) var tutorialManager
    @Environment(WorkoutService.self) var workoutService
    @Environment(DashboardViewModel.self) var dashboardViewModel
    @Environment(UserStatsViewModel.self) var userStatsViewModel
    @Environment(DIContainer.self) private var di
    @AppStorage(Constants.UserDefaultsKeys.userGender.rawValue) private var userGender = "male"
    @Query(sort: \Workout.date, order: .reverse) private var recentWorkouts: [Workout]
    
    // MARK: - State
    @State private var router = OverviewRouter()
    
    // Только UI стейты остаются во View
    @State private var selectedChartMuscle: String? = nil
    @StateObject private var colorManager = MuscleColorManager.shared
    
    // AI Review State
    @State private var showAIReviewSheet = false
    @State private var isFetchingReviewData = false
    @State private var reviewData: StatsDataResultDTO?
    
    var body: some View {
        NavigationStack(path: $router.path) {
            ZStack(alignment: .topTrailing) {
                ScrollView {
                    VStack(spacing: 20) {
                        chartSection
                        recoverySection
                        
                        if !recentWorkouts.isEmpty {
                            aiReviewButtonSection
                            topExercisesSection
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle(LocalizedStringKey("Overview"))
            .navigationDestination(for: OverviewRouter.RouteDestination.self) { route in
                switch route {
                case .workoutDetail(let workout):
                    WorkoutDetailView(workout: workout, viewModel: di.makeWorkoutDetailViewModel())
                case .exercises:
                    ExerciseView()
                case .detailedRecovery:
                    DetailedRecoveryView()
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { router.present(.settings) } label: {
                        Image(systemName: "gearshape.fill").foregroundColor(themeManager.current.primaryText)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: WorkoutCalendarView()) {
                        Image(systemName: "calendar")
                    }
                }
            }
            .sheet(item: $router.activeSheet) { sheet in
                switch sheet {
                case .settings:
                    SettingsView()
                case .addWorkout:
                    AddWorkoutView(onWorkoutCreated: {
                        Task { @MainActor in
                            var descriptor = FetchDescriptor<Workout>(sortBy: [SortDescriptor(\.date, order: .reverse)])
                            descriptor.fetchLimit = 1
                            if let newWorkout = try? context.fetch(descriptor).first {
                                router.push(.workoutDetail(newWorkout))
                            }
                        }
                    })
                case .muscleColor:
                    MuscleColorSettingsView()
                case .profile:
                    ProfileView()
                        .environment(userStatsViewModel)
                        .environment(userStatsViewModel.progressManager)
                }
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
                    ProgressView("Loading data...")
                        .presentationDetents([.medium])
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var recoveryDict: [String: Int] {
        var dict = [String: Int]()
        for status in dashboardViewModel.recoveryStatus { dict[status.muscleGroup] = status.recoveryPercentage }
        return dict
    }
    
    private var selectedMuscleInfo: MuscleCountDTO? {
        guard let selectedChartMuscle else { return nil }
        return dashboardViewModel.dashboardMuscleData.first(where: { $0.muscle == selectedChartMuscle })
    }
    
    // MARK: - View Sections
    
    private var recoverySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                Text(LocalizedStringKey("Muscle Recovery"))
                    .font(.title3)
                    .bold()
                    .foregroundColor(themeManager.current.primaryText)
                
                Spacer()
                
                Button {
                    router.push(.detailedRecovery)
                } label: {
                    HStack(spacing: 4) {
                        Text(LocalizedStringKey("See details"))
                            .font(.subheadline)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .fontWeight(.bold)
                    }
                    .foregroundColor(themeManager.current.primaryAccent)
                }
            }
            .padding(.horizontal, 4)
            
            Divider()
            
            BodyHeatmapView(
                muscleIntensities: recoveryDict,
                isRecoveryMode: true,
                isCompactMode: false,
                userGender: userGender
            )
        }
        .padding(16)
        .background(themeManager.current.surface)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 4)
    }
    
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(LocalizedStringKey("Muscles Worked")).font(.headline).foregroundColor(themeManager.current.secondaryText)
                Spacer()
                Button { router.present(.muscleColor) } label: { Image(systemName: "gearshape.fill").font(.caption).foregroundColor(themeManager.current.secondaryText) }
            }
            if dashboardViewModel.dashboardMuscleData.isEmpty {
                ZStack {
                    Circle()
                        .stroke(themeManager.current.secondaryAccent.opacity(0.2), lineWidth: 30)
                        .frame(height: 180)
                    VStack {
                        Text(LocalizedStringKey("Total")).font(.caption).foregroundColor(themeManager.current.secondaryText)
                        Text("0").font(.title).bold().foregroundColor(themeManager.current.primaryText)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 220)
            } else {
                Chart(dashboardViewModel.dashboardMuscleData, id: \.muscle) { item in
                    SectorMark(angle: .value("Count", item.count), innerRadius: .ratio(0.65), angularInset: 2)
                        .cornerRadius(5)
                        .foregroundStyle(colorManager.getColor(for: item.muscle))
                        .opacity(selectedChartMuscle == nil || selectedChartMuscle == item.muscle ? 1.0 : 0.3)
                }
                .frame(height: 220)
                .chartBackground { proxy in
                    GeometryReader { geometry in
                        VStack {
                            if let selected = selectedMuscleInfo {
                                Text(LocalizedStringKey(selected.muscle))
                                    .font(.headline)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.6)
                                
                                Text(LocalizedStringKey("\(selected.count) sets"))
                                    .font(.title2)
                                    .bold()
                                    .foregroundColor(themeManager.current.primaryAccent)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.25)
                            } else {
                                Text(LocalizedStringKey("Total"))
                                    .font(.caption)
                                    .foregroundColor(themeManager.current.secondaryText)
                                Text("\(dashboardViewModel.dashboardTotalExercises)")
                                    .font(.title)
                                    .bold()
                                    .foregroundColor(themeManager.current.primaryText)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.5)
                            }
                        }
                        .frame(maxWidth: geometry.size.width * 0.40)
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    }
                }
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), alignment: .leading)], spacing: 12) {
                    ForEach(dashboardViewModel.dashboardMuscleData, id: \.muscle) { item in
                        HStack(spacing: 6) {
                            Circle().fill(colorManager.getColor(for: item.muscle)).frame(width: 10, height: 10)
                                .opacity(selectedChartMuscle == nil || selectedChartMuscle == item.muscle ? 1.0 : 0.3)
                            Text(LocalizedStringKey(item.muscle)).font(.caption).fontWeight(selectedChartMuscle == item.muscle ? .bold : .regular)
                                .foregroundColor(selectedChartMuscle == item.muscle ? .primary : .secondary).lineLimit(1).minimumScaleFactor(0.8)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(.easeInOut(duration: 0.2)) { selectedChartMuscle = selectedChartMuscle == item.muscle ? nil : item.muscle }
                        }
                    }
                }.padding(.top, 8).padding(.horizontal, 4)
            }
        }
        .padding().background(themeManager.current.surface).cornerRadius(12)
    }
    
    private var topExercisesSection: some View {
           VStack(alignment: .leading, spacing: 10) {
               if !dashboardViewModel.dashboardTopExercises.isEmpty {
                   HStack {
                       Text(LocalizedStringKey("Exercises")).font(.title2).bold()
                       Spacer()
                       Button { router.push(.exercises) } label: {
                           Text(LocalizedStringKey("See all")).font(.subheadline).foregroundColor(themeManager.current.primaryAccent)
                       }
                   }
                .padding(.top, 10)
                
                ForEach(Array(dashboardViewModel.dashboardTopExercises.enumerated()), id: \.element.name) { index, item in
                    NavigationLink(destination: ExerciseHistoryView(exerciseName: item.name)) {
                        HStack {
                            rankIcon(rank: index + 1)
                            
                            Text(LocalizationHelper.shared.translateName(item.name))
                                .font(.headline)
                                .foregroundColor(themeManager.current.primaryText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            
                            Spacer(minLength: 8)
                            
                            Text("\(item.count) times")
                                .font(.subheadline)
                                .foregroundColor(themeManager.current.secondaryText)
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(themeManager.current.secondaryAccent)
                        }
                        .padding().background(themeManager.current.surface).cornerRadius(10).shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                    }
                }
            }
        }
    }
    
    // MARK: - AI Weekly Review Section
    
    private var aiReviewButtonSection: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            fetchReviewDataAndShowSheet()
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 48, height: 48)
                    
                    if isFetchingReviewData {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "sparkles")
                            .font(.title2)
                            .foregroundColor(.white)
                            .shadow(color: .white.opacity(0.8), radius: 8, x: 0, y: 0)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStringKey("AI Performance Review"))
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text(LocalizedStringKey("Get personalized insights and tips"))
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.white.opacity(0.5))
                    .font(.body.bold())
            }
            .padding(16)
            .background(
                LinearGradient(colors: [Color(hex: "4A00E0"), Color(hex: "8E2DE2")], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .cornerRadius(20)
            .shadow(color: Color(hex: "8E2DE2").opacity(0.4), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .disabled(isFetchingReviewData)
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
            
            // Вытягиваем данные для текущей недели прямо из AnalyticsService
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

    @ViewBuilder
    private func rankIcon(rank: Int) -> some View {
           ZStack {
               Circle()
                   .fill(rank == 1 ? Color.yellow : rank == 2 ? Color.gray : rank == 3 ? Color.brown : themeManager.current.primaryAccent.opacity(0.1))
                   .frame(width: 30, height: 30)
               
               Text("\(rank)")
                   .font(.caption).bold()
                   .foregroundColor(rank <= 3 ? themeManager.current.background : themeManager.current.primaryAccent)
           }.padding(.trailing, 5)
       }
}
