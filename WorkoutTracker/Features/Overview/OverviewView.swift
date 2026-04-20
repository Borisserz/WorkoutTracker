// MARK: - FILE: WorkoutTracker/Features/Overview/OverviewView.swift
internal import SwiftUI
import SwiftData
import Charts
import ActivityKit

// MARK: - 1. Router (Логика навигации)
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
            case exerciseDetail(String) // <--- ДОБАВИТЬ ЭТУ СТРОКУ
        }
    
    func push(_ route: RouteDestination) { path.append(route) }
    func present(_ sheet: SheetDestination) { activeSheet = sheet }
    func dismissSheet() { activeSheet = nil }
}

// MARK: - 2. Главный экран (Обзор)

struct OverviewView: View {
    @Environment(\.colorScheme) private var colorScheme: ColorScheme // 👈 ЯВНЫЙ ТИП
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
    
    // Стейты для Плана на сегодня
    @AppStorage("dailyPlanDateString") private var dailyPlanDateString: String = ""
    @State private var showExerciseSelector = false
    @Query(filter: #Predicate<WorkoutPreset> { $0.name == "План на сегодня" }) private var dailyPlanPresets: [WorkoutPreset]
    private var dailyPlan: WorkoutPreset? { dailyPlanPresets.first }
    
    // Стейт для управления выпадающим меню настроек
    @State private var showSettingsDropdown = false
    @State private var isProcessing = false
    
    var body: some View {
        NavigationStack(path: $router.path) {
            ZStack(alignment: .topLeading) {
                
                PremiumAdaptiveBackground()
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 30) {
                        
                        headerSection
                        
                        // НОВЫЕ КОЛЬЦА АКТИВНОСТИ
                        DailyActivityRings(recentWorkouts: recentWorkouts, unitsManager: UnitsManager.shared)
                        
                        LiveVitalsCard()
                        
                        MusclePieChartIsland(viewModel: dashboardViewModel)
                        
                        AnatomyRecoveryIsland(
                            isFrontView: $isFrontView,
                            cnsScore: cnsScore,
                            recoveryDict: recoveryDict,
                            userGender: userGender,
                            router: router
                        )
                        
                        dailyPlanSection
                        
                        topExercisesSection
                        
                        Spacer(minLength: 120)
                    }
                    .padding(.horizontal, 20)
                }
                
                // ВЫПАДАЮЩЕЕ МЕНЮ НАСТРОЕК
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
                case .exerciseDetail(let name): // <--- ДОБАВИТЬ ЭТИ ДВЕ СТРОКИ
                    ExerciseHistoryView(exerciseName: name)
                }
            }
            // Шторка добавления упражнений в план
            .sheet(isPresented: $showExerciseSelector) {
                ExerciseSelectionView { newExercise in
                    Task { @MainActor in
                        var currentExercises = dailyPlan?.exercises ?? []
                        currentExercises.append(newExercise)
                        
                        await di.presetService.savePreset(
                            preset: dailyPlan,
                            name: "План на сегодня",
                            icon: "calendar.badge.clock",
                            folderName: "СкрытаяПапка",
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
        }
    }
    
    private var recoveryDict: [String: Int] {
        var dict = [String: Int]()
        for status in dashboardViewModel.recoveryStatus { dict[status.muscleGroup] = status.recoveryPercentage }
        return dict
    }
    
    // MARK: - View Components
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
                        .foregroundStyle(.primary) // Адаптивный цвет
                        .padding(12)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(Circle().stroke(Color.primary.opacity(0.1), lineWidth: 1))
                        .shadow(color: .black.opacity(0.05), radius: 10)
                }
                Spacer()
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Обзор")
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .foregroundStyle(.primary)
                    Text("Готов крушить рекорды?")
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
    
    // MARK: - План на сегодня
    private var dailyPlanSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("План на сегодня")
                    .font(.title2.weight(.bold))
                // Строгий контроль цвета: исходный белый в темной, черный в светлой
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
                    Text("Начать тренировку")
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
                Text("Нажми +, чтобы добавить упражнения")
                    .font(.subheadline)
                    .foregroundStyle(colorScheme == .dark ? .white.opacity(0.5) : .black.opacity(0.5))
                    .padding(.top, 4)
            }
        }
        .onAppear {
            checkAndResetDailyPlan()
        }
    }
    // MARK: - Вспомогательная логика для Плана на сегодня
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
                        name: "План на сегодня",
                        icon: "calendar.badge.clock",
                        folderName: "СкрытаяПапка",
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
                preset: plan, name: "План на сегодня", icon: "calendar.badge.clock",
                folderName: "СкрытаяПапка", exercises: updatedExercises
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
            if let _ = await workoutService.createWorkout(title: "План на сегодня", presetID: plan.persistentModelID, isAIGenerated: false) {
                di.liveActivityManager.startWorkoutActivity(title: "План на сегодня")
                var descriptor = FetchDescriptor<Workout>(sortBy: [SortDescriptor(\.date, order: .reverse)]); descriptor.fetchLimit = 1
                if let newWorkout = try? context.fetch(descriptor).first {
                    router.push(.workoutDetail(newWorkout))
                }
            }
            isProcessing = false
        }
    }
    
    // MARK: - Топ Упражнений
    private var topExercisesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Топ упражнений")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(colorScheme == .dark ? .white : .black) // Исходный белый в темной
                
                Spacer()
                
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    router.push(.exercises)
                } label: {
                    Text("Все")
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
                    
                    Text("Выполни тренировку, чтобы увидеть топ")
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
    
    // MARK: - Строка упражнения в Плане на сегодня (Дизайн со скриншота + Свайп)
    struct DailyPlanExerciseRow: View {
        let exercise: Exercise
        let isCompleted: Bool
        let onDelete: () -> Void
        
        @StateObject private var colorManager = MuscleColorManager.shared
        @State private var offset: CGFloat = 0
        @Environment(\.colorScheme) var colorScheme
        
        var body: some View {
            ZStack(alignment: .trailing) {
                // Кнопка удаления сзади (Скрыта под карточкой)
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
                
                // Сама карточка (Спереди)
                HStack(spacing: 16) {
                    // ✅ ИСПРАВЛЕНИЕ: Форматируем группу мышц, чтобы цвет всегда находился
                    let broadCategory = MuscleCategoryMapper.getBroadCategory(for: exercise.muscleGroup)
                    let muscleColor = colorManager.getColor(for: broadCategory)
                    
                    Circle()
                        .fill(muscleColor)
                        .frame(width: 12, height: 12)
                        .shadow(color: muscleColor.opacity(0.6), radius: 4)
                    
                    Text(LocalizationHelper.shared.translateName(exercise.name))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Image(systemName: isCompleted ? "checkmark.circle.fill" : "checkmark.circle")
                        .font(.title3)
                        .foregroundColor(isCompleted ? .green : (colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.15)))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
                // ✅ ИСПРАВЛЕНИЕ: Фон ДОЛЖЕН БЫТЬ непрозрачным (Color.white в светлой теме), чтобы скрыть мусорку
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
                            // ✅ ИСПРАВЛЕНИЕ СВАЙПА: Открываем или закрываем в зависимости от того, как далеко свайпнули
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
    // MARK: - Карточка Топ-упражнения (Glassmorphism)
    struct TopExerciseGlassCard: View {
        let index: Int
        let item: ExerciseCountDTO
        @Environment(ThemeManager.self) private var themeManager
        @Environment(\.colorScheme) private var colorScheme: ColorScheme // 👈 ЯВНЫЙ ТИП
        
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
                
                // 👇 ИСПРАВЛЕНО: VStack вместо Stack
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizationHelper.shared.translateName(item.name))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    Text("\(item.count) подходов")
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
    // MARK: - Кольца Активности (Новый дизайн)
    struct DailyActivityRings: View {
        let recentWorkouts: [Workout]
        let unitsManager: UnitsManager
        @State private var animate = false
        
        private var todayStats: (cals: CGFloat, mins: CGFloat, volume: CGFloat) {
            let todayWorkouts = recentWorkouts.filter { Calendar.current.isDateInToday($0.date) }
            let totalSecs = todayWorkouts.reduce(0) { $0 + $1.durationSeconds }
            let totalVol = todayWorkouts.reduce(0.0) { $0 + $1.totalStrengthVolume }
            let cals = CGFloat(totalSecs / 60) * 6.5
            
            return (
                cals: min(cals / 500.0, 1.0),
                mins: min(CGFloat(totalSecs / 60) / 60.0, 1.0),
                volume: min(CGFloat(totalVol) / 5000.0, 1.0)
            )
        }
        
        var body: some View {
            HStack(spacing: 30) {
                ActivityRing(color: Color(red: 1.0, green: 0.15, blue: 0.3), progress: todayStats.cals, icon: "flame.fill", title: "Ккал")
                ActivityRing(color: Color(red: 0.2, green: 0.9, blue: 0.2), progress: todayStats.mins, icon: "figure.run", title: "Мин")
                ActivityRing(color: Color.blue, progress: todayStats.volume, icon: "drop.fill", title: "Объем")
            }
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .onAppear {
                withAnimation(.spring(response: 1.5, dampingFraction: 0.7).delay(0.2)) { animate = true }
            }
        }
    }
    
    struct ActivityRing: View {
        var color: Color
        var progress: CGFloat
        var icon: String
        var title: String
        @State private var currentProgress: CGFloat = 0
        @Environment(\.colorScheme) var colorScheme // 👈 ДОБАВЛЕНО ДЛЯ ПРОВЕРКИ ТЕМЫ
        
        var body: some View {
            VStack(spacing: 12) {
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
                
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                // 👈 ИСПРАВЛЕНИЕ: Черный текст для светлой темы, белый для темной
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.8))
            }
            .onAppear {
                withAnimation(.easeOut(duration: 1.5)) { currentProgress = progress }
            }
        }
    }
    
    // MARK: - Пульс Карточка
    struct LiveVitalsCard: View {
        @Environment(\.colorScheme) private var colorScheme: ColorScheme 
        @State private var isPulsing = false
        var body: some View {
            HStack(spacing: 16) {
                ZStack {
                    Circle().fill(Color.red.opacity(0.2)).frame(width: 40, height: 40).scaleEffect(isPulsing ? 1.3 : 1.0).opacity(isPulsing ? 0 : 1)
                    Circle().fill(Color.red.opacity(0.2)).frame(width: 40, height: 40).scaleEffect(isPulsing ? 1.1 : 1.0)
                    Image(systemName: "heart.fill").foregroundStyle(Color.red).font(.system(size: 20)).scaleEffect(isPulsing ? 1.1 : 0.9)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Текущий пульс").font(.caption).foregroundStyle(.secondary)
                    HStack(alignment: .bottom, spacing: 2) {
                        Text("--").font(.system(size: 28, weight: .black, design: .rounded)).foregroundStyle(.primary)
                        Text("BPM").font(.caption.bold()).foregroundStyle(Color.red).padding(.bottom, 4)
                    }
                }
                Spacer()
                Image(systemName: "waveform.path.ecg").font(.system(size: 30)).foregroundStyle(Color.red.opacity(0.5))
            }
            .padding(20)
            // 👇 УНИФИЦИРОВАННЫЙ СТИЛЬ: Фон, рамка 1.5, мягкая тень
            .background(colorScheme == .dark ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color(UIColor.secondarySystemGroupedBackground)), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.primary.opacity(0.05), lineWidth: 1.5))
            .shadow(color: colorScheme == .dark ? Color.red.opacity(0.1) : Color.black.opacity(0.08), radius: 20, x: 0, y: 5)
            .onAppear { withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { isPulsing = true } }
        }
    }
    // MARK: - Интеграция Диаграммы Мышц
    struct MusclePieChartIsland: View {
        let viewModel: DashboardViewModel
        @StateObject private var colorManager = MuscleColorManager.shared
        @State private var animateChart = false
        @Environment(\.colorScheme) private var colorScheme: ColorScheme // 👈 ЯВНЫЙ ТИП
        
        var chartData: [(color: Color, percentage: Double, name: String)] {
            let total = max(1, viewModel.dashboardTotalExercises)
            return viewModel.dashboardMuscleData.map { dto in
                (colorManager.getColor(for: dto.muscle), Double(dto.count) / Double(total), dto.muscle)
            }
        }
        
        // Вспомогательные переменные для быстрого рендера
        private var cardBackground: AnyShapeStyle {
            colorScheme == .dark ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color(UIColor.secondarySystemGroupedBackground))
        }
        private var cardOverlayGradient: LinearGradient {
            LinearGradient(colors: [colorScheme == .dark ? .white.opacity(0.3) : .black.opacity(0.2), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        
        var body: some View {
            VStack {
                Text("Задействованные мышцы")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.8))
                
                ZStack {
                    Circle().stroke(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.05), lineWidth: 20).frame(width: 150, height: 150)
                    
                    if viewModel.dashboardMuscleData.isEmpty {
                        Text("Пусто").font(.headline).foregroundStyle(.gray)
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
                            Text("Подходы")
                                .font(.caption)
                                .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.6))
                        }
                    }
                }
                .padding(.vertical, 10)
                
                if !viewModel.dashboardMuscleData.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(viewModel.dashboardMuscleData, id: \.muscle) { item in
                                HStack(spacing: 6) {
                                    Circle().fill(colorManager.getColor(for: item.muscle)).frame(width: 10, height: 10)
                                    Text(LocalizedStringKey(item.muscle))
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.8))
                                }
                            }
                        }
                    }
                    .padding(.top, 8)
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
    // MARK: - HEATMAP (Анатомия)
    struct AnatomyRecoveryIsland: View {
        @Binding var isFrontView: Bool
        let cnsScore: Double
        let recoveryDict: [String: Int]
        let userGender: String
        var router: OverviewRouter
        
        @Environment(DashboardViewModel.self) private var dashboardViewModel
        @Environment(\.colorScheme) private var colorScheme: ColorScheme // 👈 ЯВНЫЙ ТИП
        
        @State private var pulseReady = false
        @State private var showRecoverySettings = false
        
        var muscleReadiness: Int {
            guard !recoveryDict.isEmpty else { return 100 }
            let total = recoveryDict.values.reduce(0, +)
            return total / recoveryDict.count
        }
        
        // Вспомогательные свойства для ускорения компиляции
        private var islandBackground: Color {
            colorScheme == .dark ? Color.clear : Color(UIColor.secondarySystemGroupedBackground)
        }
        private var silhouetteBackground: Color {
            colorScheme == .dark ? Color(red: 0.13, green: 0.13, blue: 0.15) : Color.black.opacity(0.06)
        }
        private var buttonBackground: AnyShapeStyle {
            colorScheme == .dark ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.white.opacity(0.8))
        }
        
        var body: some View {
            VStack(alignment: .leading, spacing: 20) {
                
                Text("Восстановление мышц")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(colorScheme == .dark ? .white : .black)
                
                HStack(spacing: 12) {
                    AnatomyToggleButton(title: "Спереди", isSelected: isFrontView) { isFrontView = true }
                    AnatomyToggleButton(title: "Сзади", isSelected: !isFrontView) { isFrontView = false }
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
                                    
                                    Text("Готовность")
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
    
    // Кнопки "Спереди/Сзади"
    struct AnatomyToggleButton: View {
        let title: String
        let isSelected: Bool
        let action: () -> Void
        @Environment(\.colorScheme) private var colorScheme: ColorScheme // 👈 ЯВНЫЙ ТИП
        
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
    // MARK: - UI Шторки настроек отдыха (Redesign)
    struct RecoverySettingsQuickSheet: View {
        @Environment(ThemeManager.self) private var themeManager
        @Environment(\.dismiss) private var dismiss
        @Environment(\.colorScheme) private var colorScheme // 👈 ДОБАВЛЕНО
        
        @AppStorage(Constants.UserDefaultsKeys.userRecoveryHours.rawValue) private var storedRecoveryHours: Double = 48.0
        @State private var localRecoveryHours: Double = 48.0
        
        var body: some View {
            ZStack {
                // 👈 АДАПТИВНЫЙ ФОН ШТОРКИ
                (colorScheme == .dark ? themeManager.current.surface : Color(UIColor.systemGroupedBackground))
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Заголовок
                    HStack {
                        ZStack {
                            Circle()
                                .fill(themeManager.current.primaryAccent.opacity(0.2))
                                .frame(width: 40, height: 40)
                            Image(systemName: "battery.100.bolt")
                                .font(.title3)
                                .foregroundStyle(themeManager.current.primaryAccent)
                        }
                        
                        Text("Настройки отдыха")
                            .font(.title2.bold())
                        // 👈 АДАПТИВНЫЙ ТЕКСТ
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
                    
                    // Основной блок с ползунком
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Базовое время восстановления")
                                .font(.subheadline)
                                .foregroundColor(colorScheme == .dark ? themeManager.current.secondaryText : .secondary)
                            Spacer()
                            Text("\(Int(localRecoveryHours)) часов")
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
                        
                        Text("Настрой этот параметр под особенности своего организма. Изменение скорости напрямую повлияет на карту Готовности и рекомендации ИИ-тренера.")
                            .font(.caption)
                            .foregroundColor(colorScheme == .dark ? themeManager.current.secondaryText : .secondary)
                            .lineSpacing(4)
                    }
                    .padding(20)
                    // 👈 АДАПТИВНЫЙ ФОН КАРТОЧКИ
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
    struct PremiumAdaptiveBackground: View {
        @Environment(\.colorScheme) var colorScheme
        
        var body: some View {
            ZStack {
                // Базовый цвет (Светло-серый для светлой темы, глубокий темный для темной)
                (colorScheme == .dark ? Color(hex: "0A0A0A") : Color(UIColor.systemGroupedBackground))
                    .ignoresSafeArea()
                
                // Статичные сферы (Неоновые блики)
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
}
