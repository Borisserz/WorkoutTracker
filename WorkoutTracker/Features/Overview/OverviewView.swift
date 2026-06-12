
internal import SwiftUI
import SwiftData
import Charts
import ActivityKit
import Combine

@Observable
@MainActor
final class OverviewRouter {
    var path = NavigationPath()
    var activeSheet: SheetDestination? = nil

    enum SheetDestination: Identifiable {
        case settings, addWorkout, muscleColor, profile
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
            case workoutDetail(Workout), exercises, detailedRecovery, calendar
            case exerciseDetail(String) 
        }

    func push(_ route: RouteDestination) { path.append(route) }
    func present(_ sheet: SheetDestination) { activeSheet = sheet }
    func dismissSheet() { activeSheet = nil }
}

struct OverviewView: View {
    @Environment(\.colorScheme) private var colorScheme: ColorScheme 
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.modelContext) private var context
    @Environment(WorkoutService.self) var workoutService
    @Environment(DashboardViewModel.self) var dashboardViewModel
    @Environment(UserStatsViewModel.self) var userStatsViewModel
    @Environment(DIContainer.self) private var di

    @AppStorage("userGender") private var userGender = "male"
    @AppStorage("cnsScore") private var cnsScore: Double = 85.0
    @Query(sort: \Workout.date, order: .reverse) private var recentWorkouts: [Workout]

    @State private var router = OverviewRouter()
    @State private var isFrontView = true

    @AppStorage("dailyPlanDateString") private var dailyPlanDateString: String = ""
    @State private var showExerciseSelector = false
    @Query(filter: #Predicate<WorkoutPreset> { $0.name == "Today's Plan" }) private var dailyPlanPresets: [WorkoutPreset]
    private var dailyPlan: WorkoutPreset? { dailyPlanPresets.first }

    @State private var showSettingsDropdown = false
    @State private var isProcessing = false

    @AppStorage("hasSeenCommitmentSheet") private var hasSeenCommitmentSheet = false
    @State private var showCommitmentSheet = false



    var body: some View {
        NavigationStack(path: $router.path) {
            ZStack(alignment: .topLeading) {

                PremiumAdaptiveBackground()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 30) {

                        headerSection



                        if recentWorkouts.isEmpty {
                            FirstStepsChecklistView { targetTab in
                                di.appState.selectedTab = targetTab
                            }
                        } else {
                            DailyActivityRings(recentWorkouts: recentWorkouts, viewModel: dashboardViewModel)
                        }

                        LiveVitalsCard()

                        dailyPlanSection

                        MusclePieChartIsland(viewModel: dashboardViewModel)

                        ZStack {
                            AnatomyRecoveryIsland(
                                isFrontView: $isFrontView,
                                cnsScore: cnsScore,
                                recoveryDict: recoveryDict,
                                userGender: userGender,
                                router: router
                            )
                            .blur(radius: recentWorkouts.isEmpty ? 10 : 0)
                            .opacity(recentWorkouts.isEmpty ? 0.5 : 1.0)
                            .disabled(recentWorkouts.isEmpty)

                            if recentWorkouts.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "figure.mind.and.body")
                                        .font(.system(size: 40))
                                        .foregroundStyle(LinearGradient(colors: [.cyan, .blue], startPoint: .top, endPoint: .bottom))
                                    Text("Anatomy Locked")
                                        .font(.system(size: 20, weight: .bold, design: .rounded))
                                        .foregroundColor(colorScheme == .dark ? .white : .black)
                                    Text("Complete a workout to map your muscles and see them light up.")
                                        .font(.system(size: 14))
                                        .foregroundColor(.gray)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 40)
                                }
                                .padding(20)
                                .background(colorScheme == .dark ? Color.black.opacity(0.6) : Color.white.opacity(0.8))
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 24))
                                .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
                                .padding(.horizontal, 20)
                            }
                        }

                        topExercisesSection

                        Spacer(minLength: 120)
                    }
                    .padding(.horizontal, 20)
                }

                if showSettingsDropdown {
                    Color.black.opacity(0.01)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                showSettingsDropdown = false
                            }
                        }

                    SettingsDropdownMenu(isShowing: $showSettingsDropdown) {
                        router.present(.settings)
                    }
                    .offset(x: 20, y: 65)
                    .transition(.scale(scale: 0.8, anchor: .topLeading).combined(with: .opacity))
                    .zIndex(100)
                }

            }
            .navigationBarHidden(true)
            .navigationDestination(for: OverviewRouter.RouteDestination.self) { route in
                switch route {
                case .workoutDetail(let workout):
                    WorkoutDetailView(workout: workout, viewModel: di.makeWorkoutDetailViewModel())
                case .exercises: ExerciseView()
                case .detailedRecovery: DetailedRecoveryView()
                case .calendar: WorkoutCalendarView()
                case .exerciseDetail(let name): 
                    ExerciseHistoryView(exerciseName: name)
                }
            }

            .sheet(isPresented: $showExerciseSelector) {
                ExerciseSelectionView { newExercise in
                    Task { @MainActor in
                        var currentExercises = dailyPlan?.exercises ?? []
                        currentExercises.append(newExercise)

                        await di.presetService.savePreset(
                            preset: dailyPlan,
                            name: "Today's Plan",
                            icon: "calendar.badge.clock",
                            folderName: "HiddenFolder",
                            exercises: currentExercises
                        )

                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyy-MM-dd"
                        dailyPlanDateString = formatter.string(from: Date())

                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    }
                }
            }
            .sheet(item: $router.activeSheet) { sheet in
                switch sheet {
                case .settings: SettingsView()
                case .addWorkout: AddWorkoutView(onWorkoutCreated: {
                    Task { @MainActor in
                        var desc = FetchDescriptor<Workout>(sortBy: [SortDescriptor(\.date, order: .reverse)]); desc.fetchLimit = 1
                        if let newWorkout = try? context.fetch(desc).first { router.push(.workoutDetail(newWorkout)) }
                    }
                })
                case .muscleColor: MuscleColorSettingsView()
                case .profile: ProfileView().environment(userStatsViewModel.progressManager)
                }
            }
            .preferredColorScheme(.dark)
            .sheet(isPresented: $showCommitmentSheet) {
                FutureSelfCommitmentSheet {
                    hasSeenCommitmentSheet = true
                    showCommitmentSheet = false
                }
                .presentationDetents([.fraction(0.55)])
                .presentationDragIndicator(.visible)
            }
            .onAppear {
                if recentWorkouts.isEmpty && !hasSeenCommitmentSheet {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        showCommitmentSheet = true
                    }
                }
            }
        }
    }

    private var recoveryDict: [String: Int] {
        var dict = [String: Int]()
        for status in dashboardViewModel.recoveryStatus { dict[status.muscleGroup] = status.recoveryPercentage }
        return dict
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Button {
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        showSettingsDropdown.toggle()
                    }
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.primary) 
                        .padding(12)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(Circle().stroke(Color.primary.opacity(0.1), lineWidth: 1))
                        .shadow(color: .black.opacity(0.05), radius: 10)
                }
                Spacer()
            }

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Overview")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text("Ready to crush it?")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                }
                Spacer()

                Button {
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                    router.push(.calendar)
                } label: {
                    Image(systemName: "calendar")
                        .font(.system(size: 22))
                        .foregroundStyle(.primary)
                        .padding(12)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(Circle().stroke(Color.primary.opacity(0.1), lineWidth: 1))
                        .shadow(color: .black.opacity(0.05), radius: 10)
                }
            }
        }
        .padding(.top, 10)
    }



    private var dailyPlanSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Today's Plan")
                    .font(.title2.weight(.bold))

                    .foregroundStyle(colorScheme == .dark ? .white : .black)
                Spacer()
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showExerciseSelector = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(Color.green)
                        .shadow(color: Color.green.opacity(0.3), radius: 8)
                }
            }

            if let plan = dailyPlan, !plan.exercises.isEmpty {
                VStack(spacing: 12) {
                    ForEach(plan.exercises) { exercise in
                        DailyPlanExerciseRow(
                            exercise: exercise,
                            isCompleted: isExerciseCompletedToday(exercise.name),
                            onDelete: { removeExerciseFromPlan(exercise) }
                        )
                    }
                }

                Button {
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    startDailyPlan()
                } label: {
                    Text("Start Workout")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(LinearGradient(colors: [.green, .mint], startPoint: .leading, endPoint: .trailing))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: .green.opacity(0.3), radius: 10, y: 5)
                }
                .padding(.top, 8)

            } else {
                Text("Tap + to add exercises")
                    .font(.subheadline)
                    .foregroundStyle(colorScheme == .dark ? .white.opacity(0.5) : .black.opacity(0.5))
                    .padding(.top, 4)
            }
        }
        .onAppear {
            checkAndResetDailyPlan()
        }
    }

    private func isExerciseCompletedToday(_ exerciseName: String) -> Bool {
        let calendar = Calendar.current
        let todayWorkouts = recentWorkouts.filter { calendar.isDateInToday($0.date) }

        for workout in todayWorkouts {
            if workout.exercises.contains(where: { ex in
                ex.name == exerciseName && ex.setsList.contains(where: { $0.isCompleted })
            }) {
                return true
            }
        }
        return false
    }

    private func checkAndResetDailyPlan() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayString = formatter.string(from: Date())

        if dailyPlanDateString != todayString {
            if let plan = dailyPlan, !plan.exercises.isEmpty {
                Task { @MainActor in
                    await di.presetService.savePreset(
                        preset: plan,
                        name: "Today's Plan",
                        icon: "calendar.badge.clock",
                        folderName: "HiddenFolder",
                        exercises: []
                    )
                }
            }
            dailyPlanDateString = todayString
        }
    }

    private func removeExerciseFromPlan(_ exercise: Exercise) {
        guard let plan = dailyPlan else { return }
        Task { @MainActor in
            var updatedExercises = plan.exercises
            updatedExercises.removeAll { $0.id == exercise.id }
            await di.presetService.savePreset(
                preset: plan, name: "Today's Plan", icon: "calendar.badge.clock",
                folderName: "HiddenFolder", exercises: updatedExercises
            )
        }
    }

    private func startDailyPlan() {
        guard let plan = dailyPlan, !isProcessing else { return }
        isProcessing = true
        Task { @MainActor in
            if await workoutService.hasActiveWorkout() {
                router.present(.addWorkout)
                isProcessing = false; return
            }
            if let _ = await workoutService.createWorkout(title: "Today's Plan", presetID: plan.persistentModelID, isAIGenerated: false) {
                var descriptor = FetchDescriptor<Workout>(sortBy: [SortDescriptor(\.date, order: .reverse)]); descriptor.fetchLimit = 1
                if let newWorkout = try? context.fetch(descriptor).first {
                    router.push(.workoutDetail(newWorkout))
                }
            }
            isProcessing = false
        }
    }

    private var topExercisesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Top Exercises")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(colorScheme == .dark ? .white : .black) 

                Spacer()

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    router.push(.exercises)
                } label: {
                    Text("ALL")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(themeManager.current.primaryAccent)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(themeManager.current.primaryAccent.opacity(0.15))
                        .clipShape(Capsule())
                }
            }

            if dashboardViewModel.dashboardTopExercises.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.title2)
                        .foregroundColor(themeManager.current.primaryAccent.opacity(0.5))

                    Text("Complete a workout to see top exercises")
                        .font(.subheadline)
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.5) : .black.opacity(0.5))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(colorScheme == .dark ? Color.white.opacity(0.03) : Color.black.opacity(0.03))
                .cornerRadius(20)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.05), lineWidth: 1))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        Spacer().frame(width: 4)

                        ForEach(Array(dashboardViewModel.dashboardTopExercises.prefix(5).enumerated()), id: \.offset) { index, item in
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                router.push(.exerciseDetail(item.name))
                            } label: {
                                TopExerciseGlassCard(index: index + 1, item: item)
                            }
                            .buttonStyle(.plain)
                        }
                        Spacer().frame(width: 4)
                    }
                    .padding(.vertical, 20)
                }
                .padding(.horizontal, -20)
                .padding(.top, -10)
            }
        }
    }

    struct DailyPlanExerciseRow: View {
        let exercise: Exercise
        let isCompleted: Bool
        let onDelete: () -> Void

        @StateObject private var colorManager = MuscleColorManager.shared
        @State private var offset: CGFloat = 0
        @Environment(\.colorScheme) var colorScheme

        var body: some View {
            ZStack(alignment: .trailing) {

                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    withAnimation(.spring()) { offset = 0 }
                    onDelete()
                }) {
                    Image(systemName: "trash.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 80)
                        .frame(maxHeight: .infinity)
                        .background(Color.red)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                HStack(spacing: 16) {

                    let broadCategory = MuscleCategoryMapper.getBroadCategory(for: exercise.muscleGroup)
                    let muscleColor = colorManager.getColor(for: broadCategory)

                    Circle()
                        .fill(muscleColor)
                        .frame(width: 12, height: 12)
                        .shadow(color: muscleColor.opacity(0.6), radius: 4)

                    Text(LocalizationHelper.shared.translateName(exercise.name))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                        .lineLimit(2).minimumScaleFactor(0.8)

                    Spacer()

                    Image(systemName: isCompleted ? "checkmark.circle.fill" : "checkmark.circle")
                        .font(.title3)
                        .foregroundColor(isCompleted ? .green : (colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.15)))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)

                .background(colorScheme == .dark ? Color(red: 0.15, green: 0.15, blue: 0.18) : Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.primary.opacity(0.05), lineWidth: 1.5))
                .shadow(color: Color.black.opacity(0.06), radius: 15, x: 0, y: 4)
                .offset(x: offset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if value.translation.width < 0 {
                                offset = max(value.translation.width, -80)
                            } else if offset < 0 {
                                offset = min(0, -80 + value.translation.width)
                            }
                        }
                        .onEnded { value in

                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                if offset < -40 {
                                    offset = -80
                                } else {
                                    offset = 0
                                }
                            }
                        }
                )
            }
        }
    }

    struct TopExerciseGlassCard: View {
        let index: Int
        let item: ExerciseCountDTO
        @Environment(ThemeManager.self) private var themeManager
        @Environment(\.colorScheme) private var colorScheme: ColorScheme 

        private var rankColor: Color {
            switch index {
            case 1: return .yellow
            case 2: return .gray
            case 3: return .orange
            default: return themeManager.current.primaryAccent
            }
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    ZStack {
                        Circle()
                            .fill(rankColor.opacity(0.2))
                            .frame(width: 36, height: 36)

                        Text("#\(index)")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundColor(rankColor)
                    }
                    Spacer()
                    Image(systemName: "chart.bar.fill")
                        .font(.caption)
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.2) : .black.opacity(0.2))
                }

                Spacer(minLength: 16)

                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizationHelper.shared.translateName(item.name))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                        .lineLimit(3).minimumScaleFactor(0.8)
                        .multilineTextAlignment(.leading)

                    Text("\(item.count) sets")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(colorScheme == .dark ? themeManager.current.secondaryText : .gray)
                }
            }
            .padding(16)
            .frame(width: 150, height: 150, alignment: .leading)
            .background(colorScheme == .dark ? Color(red: 0.1, green: 0.1, blue: 0.13).opacity(0.8) : Color(UIColor.secondarySystemGroupedBackground))
            .background(colorScheme == .dark ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.clear))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(
                        colorScheme == .dark
                        ? LinearGradient(colors: [rankColor.opacity(0.4), .clear, .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(colors: [Color.primary.opacity(0.05)], startPoint: .top, endPoint: .bottom),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: colorScheme == .dark ? (index == 1 ? rankColor.opacity(0.2) : .black.opacity(0.05)) : .black.opacity(0.08), radius: 15, x: 0, y: 5)
        }
    }

    struct DailyActivityRings: View {
        let recentWorkouts: [Workout]
        let viewModel: DashboardViewModel
        @State private var animate = false

        @State private var selectedRing: ActivityRingType? = nil

        let targetCalories = 500.0
        let targetSteps = 10000.0
        let targetWater = 2.5 

        private var todayStats: (cals: CGFloat, steps: CGFloat, water: CGFloat, rawCals: Int) {
            let userWeight = UserDefaults.standard.double(forKey: Constants.UserDefaultsKeys.userBodyWeight.rawValue)
            let todayWorkouts = recentWorkouts.filter { Calendar.current.isDateInToday($0.date) }

            let totalCals = todayWorkouts.reduce(0) { sum, workout in
                sum + CalorieCalculator.calculate(for: workout, userWeight: userWeight)
            }

            return (
                cals: min(CGFloat(totalCals) / targetCalories, 1.0),
                steps: min(CGFloat(viewModel.todaySteps) / targetSteps, 1.0),
                water: min(CGFloat(viewModel.todayWaterLiters) / targetWater, 1.0),
                rawCals: totalCals
            )
        }

        var body: some View {
            HStack(spacing: 30) {

                ActivityRing(
                    color: Color(red: 1.0, green: 0.15, blue: 0.3),
                    progress: todayStats.cals,
                    icon: "flame.fill",
                    title: "Kcal",
                    valueText: "\(todayStats.rawCals)"
                ) {
                    selectedRing = .calories
                }

                ActivityRing(
                    color: Color(red: 0.2, green: 0.9, blue: 0.2),
                    progress: todayStats.steps,
                    icon: "figure.walk",
                    title: "Steps",
                    valueText: "\(viewModel.todaySteps)"
                ) {
                    selectedRing = .steps
                }

                ActivityRing(
                    color: Color.cyan,
                    progress: todayStats.water,
                    icon: "drop.fill",
                    title: "Water",
                    valueText: String(format: "%.1f L", viewModel.todayWaterLiters)
                ) {
                    selectedRing = .water
                }
            }
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .onAppear {
                withAnimation(.spring(response: 1.5, dampingFraction: 0.7).delay(0.2)) { animate = true }
            }
            .sheet(item: $selectedRing) { ringType in
                ActivityRingDetailSheet(
                    type: ringType,
                    rawCals: todayStats.rawCals,
                    rawSteps: viewModel.todaySteps,
                    rawWater: viewModel.todayWaterLiters
                )
                .presentationDetents([.height(420)]) 
                .presentationCornerRadius(32)
                .presentationDragIndicator(.visible)
            }
        }
    }
    enum ActivityRingType: String, Identifiable {
        case calories, steps, water
        var id: String { rawValue }
    }
    struct ActivityRing: View {
        var color: Color
        var progress: CGFloat
        var icon: String
        var title: String
        var valueText: String
        var action: () -> Void 

        @State private var currentProgress: CGFloat = 0
        @Environment(\.colorScheme) var colorScheme

        var body: some View {
            Button(action: {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                action()
            }) {
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .stroke(color.opacity(0.15), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                            .frame(width: 70, height: 70)

                        Circle()
                            .trim(from: 0, to: currentProgress)
                            .stroke(color, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                            .frame(width: 70, height: 70)
                            .rotationEffect(.degrees(-90))
                            .shadow(color: color.opacity(0.6), radius: 10)

                        Image(systemName: icon)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(color)
                    }

                    VStack(spacing: 0) {
                        Text(valueText)
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                            .contentTransition(.numericText())

                        Text(title)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(colorScheme == .dark ? .white.opacity(0.5) : .black.opacity(0.5))
                    }
                }
            }
            .buttonStyle(ScaleButtonStyle()) 
            .onAppear {
                withAnimation(.easeOut(duration: 1.5)) { currentProgress = progress }
            }
            .onChange(of: progress) { _, newValue in
                withAnimation(.easeOut(duration: 1.5)) { currentProgress = newValue }
            }
        }
    }

    struct ActivityRingDetailSheet: View {
        let type: ActivityRingType
        let rawCals: Int
        let rawSteps: Int
        let rawWater: Double

        @Environment(\.dismiss) private var dismiss
        @Environment(\.colorScheme) private var colorScheme
        @Environment(ThemeManager.self) private var themeManager

        var config: (title: String, value: String, unit: String, icon: String, color: Color, description: String, canOpenFoodTracker: Bool) {
            switch type {
            case .calories:
                return ("Burned Today", "\(rawCals)", "kcal", "flame.fill", Color(red: 1.0, green: 0.15, blue: 0.3), "Calories burned exclusively during strength and cardio workouts in WorkoutTracker.", false)
            case .steps:
                return ("Steps Today", "\(rawSteps)", "steps", "figure.walk", Color(red: 0.2, green: 0.9, blue: 0.2), "Your daily activity. Data is automatically synced with Apple Health and FoodTracker.", true)
            case .water:
                return ("Water Balance", String(format: "%.1f", rawWater), "liters", "drop.fill", .cyan, "Water intake. Staying hydrated is critical for muscle growth.", true)
            }
        }

        var body: some View {
            ZStack {
                (colorScheme == .dark ? themeManager.current.surface : Color(UIColor.systemGroupedBackground))
                    .ignoresSafeArea()

                Circle()
                    .fill(config.color.opacity(0.15))
                    .frame(width: 250, height: 250)
                    .blur(radius: 60)
                    .offset(y: -100)

                VStack(spacing: 24) {

                    ZStack {
                        Circle()
                            .fill(config.color.opacity(0.2))
                            .frame(width: 80, height: 80)
                        Image(systemName: config.icon)
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(config.color)
                            .shadow(color: config.color.opacity(0.5), radius: 10, y: 5)
                    }
                    .padding(.top, 30)

                    VStack(spacing: 8) {
                        Text(config.title)
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.gray)
                            .textCase(.uppercase)

                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(config.value)
                                .font(.system(size: 56, weight: .bold, design: .rounded))
                                .foregroundColor(colorScheme == .dark ? .white : .black)
                            Text(config.unit)
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(config.color)
                        }

                        Text(config.description)
                            .font(.callout)
                            .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true) 
                            .padding(.horizontal, 30)
                            .padding(.top, 8)
                    }

                    Spacer()
                }
            }
        }

    }

    struct LiveVitalsCard: View {
        @Environment(\.colorScheme) private var colorScheme: ColorScheme
        @State private var isPulsing = false

        @State private var vitals = VitalsMonitor()

        let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
        @State private var timeAgoTrigger = false

        var body: some View {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.2))
                        .frame(width: 40, height: 40)
                        .scaleEffect(isPulsing ? 1.3 : 1.0)
                        .opacity(isPulsing ? 0 : 1)

                    Circle()
                        .fill(Color.red.opacity(0.2))
                        .frame(width: 40, height: 40)
                        .scaleEffect(isPulsing ? 1.1 : 1.0)

                    Image(systemName: "heart.fill")
                        .foregroundStyle(Color.red)
                        .font(.system(size: 20))
                        .scaleEffect(isPulsing ? 1.1 : 0.9)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("Current heart rate").font(.caption).foregroundStyle(.secondary)

                        Text(vitals.timeAgoText)
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.15))
                            .foregroundStyle(.secondary)
                            .clipShape(Capsule())
                            .id(timeAgoTrigger) 
                    }

                    HStack(alignment: .bottom, spacing: 2) {
                        if vitals.currentBPM > 0 {
                            Text("\(Int(vitals.currentBPM))")
                                .font(.system(size: 28, weight: .black, design: .rounded))
                                .foregroundStyle(.primary)
                                .contentTransition(.numericText())
                            Text("BPM").font(.caption.bold()).foregroundStyle(Color.red).padding(.bottom, 4)
                        } else {
                            UnavailableMetricView(icon: "applewatch.slash", text: "No Sensor Data")
                                .padding(.top, 4)
                        }
                    }
                }

                Spacer()

                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 30))
                    .foregroundStyle(Color.red.opacity(0.5))
            }
            .padding(20)
            .background(colorScheme == .dark ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color(UIColor.secondarySystemGroupedBackground)), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.primary.opacity(0.05), lineWidth: 1.5))
            .shadow(color: colorScheme == .dark ? Color.red.opacity(0.1) : Color.black.opacity(0.08), radius: 20, x: 0, y: 5)
            .onAppear {

                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { isPulsing = true }
                vitals.startMonitoring()
            }
            .onReceive(timer) { _ in

                timeAgoTrigger.toggle()
            }
        }
    }

    struct MusclePieChartIsland: View {
        let viewModel: DashboardViewModel
        @StateObject private var colorManager = MuscleColorManager.shared
        @State private var animateChart = false
        @Environment(\.colorScheme) private var colorScheme: ColorScheme 

        var chartData: [(color: Color, percentage: Double, name: String)] {
            let total = max(1, viewModel.dashboardTotalExercises)
            return viewModel.dashboardMuscleData.map { dto in
                (colorManager.getColor(for: dto.muscle), Double(dto.count) / Double(total), dto.muscle)
            }
        }

        private var cardBackground: AnyShapeStyle {
            colorScheme == .dark ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color(UIColor.secondarySystemGroupedBackground))
        }
        private var cardOverlayGradient: LinearGradient {
            LinearGradient(colors: [colorScheme == .dark ? .white.opacity(0.3) : .black.opacity(0.2), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
        }

        var body: some View {
            VStack {
                Text("Muscle Groups")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.8))

                ZStack {
                    Circle().stroke(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.05), lineWidth: 20).frame(width: 150, height: 150)

                    if viewModel.dashboardMuscleData.isEmpty {
                        Text("Empty").font(.headline).foregroundStyle(.gray)
                    } else {
                        ForEach(0..<chartData.count, id: \.self) { index in
                            if chartData[index].percentage > 0 {
                                Circle()
                                    .trim(from: trimStart(for: index), to: trimEnd(for: index))
                                    .stroke(chartData[index].color, style: StrokeStyle(lineWidth: 20, lineCap: .round))
                                    .frame(width: 150, height: 150)
                                    .rotationEffect(.degrees(-90))
                                    .shadow(color: chartData[index].color.opacity(0.6), radius: 10)
                                    .scaleEffect(animateChart ? 1 : 0.8)
                                    .opacity(animateChart ? 1 : 0)
                                    .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(Double(index) * 0.1), value: animateChart)
                            }
                        }

                        VStack {
                            Text("\(viewModel.dashboardTotalExercises)")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(colorScheme == .dark ? .white : .black)
                            Text("Sets")
                                .font(.caption)
                                .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.6))
                        }
                    }
                }
                .padding(.vertical, 10)

                if !viewModel.dashboardMuscleData.isEmpty {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 3),
                        alignment: .center,
                        spacing: 12
                    ) {
                        ForEach(viewModel.dashboardMuscleData, id: \.muscle) { item in
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(colorManager.getColor(for: item.muscle))
                                    .frame(width: 10, height: 10)

                                Text(LocalizedStringKey(item.muscle))
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.8))
                                    .lineLimit(2).minimumScaleFactor(0.8)
                                    .minimumScaleFactor(0.8)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 10)
                        }
                    }
                    .padding(.top, 16)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(24)
            .background(cardBackground, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 32).stroke(cardOverlayGradient, lineWidth: 1.5))
            .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 5)
            .onAppear { animateChart = true }
        }

        func trimStart(for index: Int) -> Double {
            if index == 0 { return 0 }
            return (0..<index).reduce(0) { $0 + chartData[$1].percentage }
        }

        func trimEnd(for index: Int) -> Double {
            return trimStart(for: index) + chartData[index].percentage
        }
    }

    struct AnatomyRecoveryIsland: View {
        @Binding var isFrontView: Bool
        let cnsScore: Double
        let recoveryDict: [String: Int]
        let userGender: String
        var router: OverviewRouter

        @Environment(DashboardViewModel.self) private var dashboardViewModel
        @Environment(\.colorScheme) private var colorScheme: ColorScheme 

        @State private var pulseReady = false
        @State private var showRecoverySettings = false
        @State private var isCollapsed = false

        var fatiguedMuscles: [String] {
            recoveryDict.filter { $0.value < 75 }.map { $0.key.capitalized }
        }

        var fatiguedMusclesText: String {
            let list = fatiguedMuscles
            if list.isEmpty {
                return "All muscles fully recovered"
            } else {
                return "Fatigued: " + list.joined(separator: ", ")
            }
        }

        var compactView: some View {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(Color.primary.opacity(0.05), lineWidth: 4)
                        .frame(width: 54, height: 54)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(Double(muscleReadiness) / 100.0))
                        .stroke(
                            LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 54, height: 54)
                        .rotationEffect(.degrees(-90))
                    
                    Text("\(muscleReadiness)%")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recovery Index")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                    Text(fatiguedMusclesText)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.gray)
            }
            .padding(20)
            .background(islandBackground)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.primary.opacity(0.05), lineWidth: 1.5)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 10, y: 5)
            .contentShape(Rectangle())
            .onTapGesture {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isCollapsed = false
                }
            }
        }

        var muscleReadiness: Int {
            guard !recoveryDict.isEmpty else { return 100 }
            let total = recoveryDict.values.reduce(0, +)
            return total / recoveryDict.count
        }

        private var islandBackground: Color {
            colorScheme == .dark ? Color.clear : Color(UIColor.secondarySystemGroupedBackground)
        }
        private var silhouetteBackground: Color {
            colorScheme == .dark ? Color(red: 0.13, green: 0.13, blue: 0.15) : Color.black.opacity(0.06)
        }
        private var buttonBackground: AnyShapeStyle {
            colorScheme == .dark ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.white.opacity(0.8))
        }

        private var expandedView: some View {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("Muscle Recovery")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(colorScheme == .dark ? .white : .black)
                    Spacer()
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            isCollapsed = true
                        }
                    } label: {
                        Image(systemName: "chevron.up.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 12) {
                    AnatomyToggleButton(title: "Front", isSelected: isFrontView) { isFrontView = true }
                    AnatomyToggleButton(title: "Back", isSelected: !isFrontView) { isFrontView = false }
                }

                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(silhouetteBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                        )

                    BodyHeatmapView(
                        muscleIntensities: recoveryDict,
                        isRecoveryMode: true,
                        isCompactMode: true,
                        defaultToBack: !isFrontView,
                        userGender: userGender
                    )
                    .background(Color.clear)
                    .frame(height: 500)
                    .scaleEffect(1.05)
                    .offset(y: 10)
                    .clipped()

                    VStack {
                        HStack {
                            Spacer()

                            Button {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                showRecoverySettings = true
                            } label: {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 6, height: 6)
                                        .opacity(pulseReady ? 1.0 : 0.3)

                                    Text("Readiness")
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundStyle(colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.8))

                                    Text("\(muscleReadiness)%")
                                        .font(.system(size: 14, weight: .black, design: .rounded))
                                        .foregroundStyle(Color.green)

                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(colorScheme == .dark ? .white.opacity(0.5) : .black.opacity(0.5))
                                        .padding(.leading, 2)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(buttonBackground)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.1), lineWidth: 1))
                                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                            }
                            .buttonStyle(.plain)
                        }
                        Spacer()
                    }
                    .padding(16)
                    .zIndex(10)
                }
                .frame(height: 580)
                .background(islandBackground)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.primary.opacity(0.05), lineWidth: 1.5))
                .shadow(color: Color.black.opacity(0.08), radius: 20, x: 0, y: 5)
            }
        }

        var body: some View {
            Group {
                if isCollapsed {
                    compactView
                } else {
                    expandedView
                }
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    pulseReady = true
                }
            }
            .sheet(isPresented: $showRecoverySettings, onDismiss: {
                dashboardViewModel.refreshAllCaches()
            }) {
                RecoverySettingsQuickSheet()
                    .presentationDetents([.height(300)])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    struct AnatomyToggleButton: View {
        let title: String
        let isSelected: Bool
        let action: () -> Void
        @Environment(\.colorScheme) private var colorScheme: ColorScheme 

        var body: some View {
            Button(action: {
                UISelectionFeedbackGenerator().selectionChanged()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { action() }
            }) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(isSelected ? Color.blue.opacity(0.2) : Color.clear)
                    .foregroundStyle(isSelected ? Color.blue : (colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.6)))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(isSelected ? Color.blue : (colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.15)), lineWidth: 1)
                    )
            }
        }
    }

    struct RecoverySettingsQuickSheet: View {
        @Environment(ThemeManager.self) private var themeManager
        @Environment(\.dismiss) private var dismiss
        @Environment(\.colorScheme) private var colorScheme 

        @AppStorage(Constants.UserDefaultsKeys.userRecoveryHours.rawValue) private var storedRecoveryHours: Double = 48.0
        @State private var localRecoveryHours: Double = 48.0

        var body: some View {
            ZStack {

                (colorScheme == .dark ? themeManager.current.surface : Color(UIColor.systemGroupedBackground))
                    .ignoresSafeArea()

                VStack(spacing: 24) {

                    HStack {
                        ZStack {
                            Circle()
                                .fill(themeManager.current.primaryAccent.opacity(0.2))
                                .frame(width: 40, height: 40)
                            Image(systemName: "battery.100.bolt")
                                .font(.title3)
                                .foregroundStyle(themeManager.current.primaryAccent)
                        }

                        Text("Rest Settings")
                            .font(.title2.bold())

                            .foregroundStyle(colorScheme == .dark ? themeManager.current.primaryText : .black)

                        Spacer()

                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(Color.gray.opacity(0.5))
                        }
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Base Recovery Time")
                                .font(.subheadline)
                                .foregroundColor(colorScheme == .dark ? themeManager.current.secondaryText : .secondary)
                            Spacer()
                            Text("\(Int(localRecoveryHours)) hours")
                                .font(.headline)
                                .foregroundColor(themeManager.current.primaryAccent)
                                .contentTransition(.numericText())
                        }

                        Slider(
                            value: $localRecoveryHours,
                            in: 12...96,
                            step: 4,
                            onEditingChanged: { isEditing in
                                if !isEditing {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    storedRecoveryHours = localRecoveryHours
                                }
                            }
                        )
                        .tint(themeManager.current.primaryAccent)

                        Text("Adjust this to your body's needs. It directly impacts Readiness and AI coach recommendations.")
                            .font(.caption)
                            .foregroundColor(colorScheme == .dark ? themeManager.current.secondaryText : .secondary)
                            .lineSpacing(4)
                    }
                    .padding(20)

                    .background(colorScheme == .dark ? themeManager.current.surfaceVariant : Color.white)
                    .cornerRadius(20)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(colorScheme == .dark ? Color.white.opacity(0.05) : Color.clear, lineWidth: 1))
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.05), radius: 10, x: 0, y: 5)

                    Spacer()
                }
                .padding(24)
                .padding(.top, 10)
            }
            .onAppear {
                localRecoveryHours = storedRecoveryHours > 0 ? storedRecoveryHours : 48.0
            }
        }
    }
    
    // MARK: - Hero Action Card Component
    struct HeroActionCard: View {
        let title: String
        let subtitle: String
        let iconName: String
        let gradientColors: [Color]
        @Environment(\.colorScheme) private var colorScheme

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 48, height: 48)
                    Image(systemName: iconName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                }
                .shadow(color: gradientColors[0].opacity(0.3), radius: 6, y: 3)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.7))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                ZStack {
                    if colorScheme == .dark {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(Color.white.opacity(0.05))
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(.ultraThinMaterial)
                    } else {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(Color.white)
                    }

                    GeometryReader { geo in
                        Circle()
                            .fill(gradientColors[0].opacity(0.12))
                            .blur(radius: 20)
                            .frame(width: geo.size.width * 0.8)
                            .offset(x: -geo.size.width * 0.1, y: -geo.size.height * 0.1)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(
                        colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.06),
                        lineWidth: 0.7
                    )
            )
            .shadow(color: colorScheme == .dark ? .black.opacity(0.15) : .black.opacity(0.04), radius: 10, x: 0, y: 6)
        }
    }

    struct HeroActionRowCard: View {
        let title: String
        let subtitle: String
        let iconName: String
        let gradientColors: [Color]
        @Environment(\.colorScheme) private var colorScheme

        var body: some View {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 44, height: 44)
                    Image(systemName: iconName)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
                .shadow(color: gradientColors[0].opacity(0.3), radius: 6, y: 3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.7))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.4) : .black.opacity(0.3))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                ZStack {
                    if colorScheme == .dark {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.white.opacity(0.05))
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(.ultraThinMaterial)
                    } else {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.white)
                    }

                    GeometryReader { geo in
                        Circle()
                            .fill(gradientColors[0].opacity(0.1))
                            .blur(radius: 15)
                            .frame(width: geo.size.width * 0.4)
                            .offset(x: -geo.size.width * 0.05, y: -geo.size.height * 0.1)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.06),
                        lineWidth: 0.7
                    )
            )
            .shadow(color: colorScheme == .dark ? .black.opacity(0.15) : .black.opacity(0.04), radius: 10, x: 0, y: 6)
        }
    }

    struct PremiumAdaptiveBackground: View {
        @Environment(\.colorScheme) var colorScheme

        var body: some View {
            ZStack {

                (colorScheme == .dark ? Color(hex: "0A0A0A") : Color(UIColor.systemGroupedBackground))
                    .ignoresSafeArea()

                Circle()
                    .fill(Color.cyan.opacity(colorScheme == .dark ? 0.15 : 0.08))
                    .frame(width: 350)
                    .blur(radius: 120)
                    .offset(x: -100, y: -150)

                Circle()
                    .fill(Color.purple.opacity(colorScheme == .dark ? 0.12 : 0.05))
                    .frame(width: 400)
                    .blur(radius: 130)
                    .offset(x: 100, y: 100)
            }
        }
    }

    @Observable
    @MainActor
    final class VitalsMonitor {
        var currentBPM: Double = 0.0
        var lastUpdated: Date? = nil

        var timeAgoText: String {
            guard let date = lastUpdated else { return "No data" }
            let minutes = Int(Date().timeIntervalSince(date) / 60)
            if minutes == 0 { return "Just now" }
            if minutes < 60 { return "" }
            let hours = minutes / 60
            return "\(hours) h back"
        }

        func startMonitoring() {
            Task {

                try? await HealthKitManager.shared.requestAuthorization()

                if let initial = try? await HealthKitManager.shared.fetchLatestHeartRate() {
                    self.currentBPM = initial.value
                    self.lastUpdated = initial.date
                }

                await HealthKitManager.shared.startHeartRateObservation { hrValue, date in
                    Task { @MainActor in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            self.currentBPM = hrValue
                            self.lastUpdated = date
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Zero-To-Hero UX: First Steps Checklist

struct FirstStepsChecklistView: View {
    var onNavigate: (Int) -> Void
    @Environment(\.colorScheme) private var colorScheme
    @State private var appear = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("First Steps")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                    Text("Unlock the full potential")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                Spacer()
                ZStack {
                    Circle().stroke(Color.cyan.opacity(0.2), lineWidth: 4)
                    Circle().trim(from: 0, to: appear ? 0.33 : 0)
                        .stroke(Color.cyan, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("1/3")
                        .font(.system(size: 10, weight: .bold))
                }
                .frame(width: 36, height: 36)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            VStack(spacing: 0) {
                ChecklistItemRow(title: "Create Profile", subtitle: "Tell AI about your goals", isCompleted: true) {}
                Divider().padding(.horizontal, 20)
                ChecklistItemRow(title: "First Workout", subtitle: "Start tracking your progress", isCompleted: false) {
                    onNavigate(2) // Workout Tab
                }
                Divider().padding(.horizontal, 20)
                ChecklistItemRow(title: "Try AI Coach", subtitle: "Ask for a custom program", isCompleted: false) {
                    onNavigate(3) // AICoach Tab
                }
            }
            .padding(.bottom, 8)
        }
        .background(colorScheme == .dark ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.white))
        .background(Color.cyan.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.primary.opacity(0.05), lineWidth: 1))
        .shadow(color: .cyan.opacity(0.1), radius: 15, y: 10)
        .padding(.horizontal, 20)
        .onAppear {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.8).delay(0.3)) { appear = true }
        }
    }
}

struct ChecklistItemRow: View {
    let title: String
    let subtitle: String
    let isCompleted: Bool
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: {
            if !isCompleted {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                action()
            }
        }) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(isCompleted ? Color.cyan : Color.gray.opacity(0.2))
                        .frame(width: 28, height: 28)
                    if isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(isCompleted ? .gray : (colorScheme == .dark ? .white : .black))
                        .strikethrough(isCompleted, color: .gray)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                Spacer()
                if !isCompleted {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.gray.opacity(0.5))
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Day 1 Retention: Future Self Commitment

struct FutureSelfCommitmentSheet: View {
    let onCommit: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @State private var appear = false

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "figure.mind.and.body")
                .font(.system(size: 60))
                .foregroundStyle(LinearGradient(colors: [.cyan, .blue], startPoint: .top, endPoint: .bottom))
                .shadow(color: .cyan.opacity(0.3), radius: 10, y: 5)
                .padding(.top, 20)

            VStack(spacing: 8) {
                Text("Your Future Self is Waiting")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(colorScheme == .dark ? .white : .black)

                Text("A goal without a timeline is just a wish. When are we crushing our first real session?")
                    .font(.system(size: 15))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            VStack(spacing: 12) {
                CommitmentButton(title: "Tonight", icon: "moon.stars.fill") { schedulePush(title: "Tonight's the night", body: "Time to crush your first session!"); onCommit() }
                CommitmentButton(title: "Tomorrow Morning", icon: "sun.max.fill") { schedulePush(title: "Rise and grind", body: "Your future self is waiting. Let's work out."); onCommit() }
                CommitmentButton(title: "This Weekend", icon: "calendar.badge.clock") { schedulePush(title: "Weekend Warrior", body: "No excuses this weekend. Let's hit it."); onCommit() }
            }
            .padding(.horizontal, 24)
            .padding(.top, 10)

            Spacer()
        }
        .background(colorScheme == .dark ? Color(red: 0.1, green: 0.1, blue: 0.12) : Color.white)
        .opacity(appear ? 1 : 0)
        .offset(y: appear ? 0 : 20)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { appear = true }
        }
    }

    private func schedulePush(title: String, body: String) {
        // Mock scheduling push notification
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }
}

struct CommitmentButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(.cyan)
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray.opacity(0.5))
            }
            .padding()
            .background(colorScheme == .dark ? Color.white.opacity(0.05) : Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.primary.opacity(0.05), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
