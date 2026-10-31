internal import SwiftUI
import SwiftData

enum CarouselItemType: Identifiable, Hashable {
    case preset(WorkoutPreset)
    case favorite(Workout)

    var id: String {
        switch self {
        case .preset(let p): return "preset_\(p.persistentModelID.hashValue)"
        case .favorite(let w): return "fav_\(w.persistentModelID.hashValue)"
        }
    }
}

/// Redesigned Workout Hub matching PastelTheme and Apple Human Interface Guidelines.
/// Focuses on high-contrast luxury athletic styling, zero neuroslop/clutter,
/// glanceable information density, and instant 1-tap start capabilities.
struct WorkoutHubView: View {
    @Environment(DIContainer.self) private var di
    @Environment(\.modelContext) private var context
    @Environment(WorkoutService.self) var workoutService
    @Environment(PresetService.self) var presetService
    @Environment(DashboardViewModel.self) var dashboardViewModel

    // MARK: - SwiftData Queries
    @Query(filter: #Predicate<WorkoutPreset> { $0.isSystem == false }, sort: \WorkoutPreset.name)
    private var userPresets: [WorkoutPreset]

    @Query(filter: #Predicate<Workout> { $0.isFavorite == true }, sort: \Workout.date, order: .reverse)
    private var favoriteWorkouts: [Workout]

    @Query(filter: #Predicate<Workout> { $0.endTime == nil }, sort: \Workout.date, order: .reverse)
    private var activeWorkouts: [Workout]

    // MARK: - Filter States
    @State private var searchText = ""
    @State private var selectedMuscleGroup: String? = nil
    @FocusState private var isSearchFieldFocused: Bool
    private let muscleGroups = ["Chest", "Back", "Legs", "Shoulders", "Arms", "Core"]

    // MARK: - Navigation & Sheets
    @State private var navigateToActiveWorkout: Workout? = nil
    @State private var navigateToExplore = false
    @State private var navigateToLibrary = false

    @State private var showSmartBuilder = false
    @State private var showPresetEditor = false
    @State private var presetToEdit: WorkoutPreset? = nil
    @State private var showStreakPopup = false
    @State private var showWorkoutModeDiscovery = false

    @State private var itemToDelete: CarouselItemType? = nil
    @State private var showDeleteAlert = false
    @State private var showActiveWorkoutAlert = false
    @State private var isProcessing = false
    @State private var selectedPreview: PreviewItem? = nil
    @State private var selectedLegendaryRoutine: LegendaryRoutine? = nil
    @State private var isMuscleGridExpanded: Bool = false

    // MARK: - Filter Logic
    private func filterPreset(_ preset: WorkoutPreset) -> Bool {
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            if !preset.name.lowercased().contains(query) {
                return false
            }
        }
        if let targetGroup = selectedMuscleGroup {
            let hasMuscle = preset.exercises.contains { ex in
                MuscleCategoryMapper.getBroadCategory(for: ex.muscleGroup) == targetGroup
            }
            if !hasMuscle {
                return false
            }
        }
        return true
    }

    private var myRoutines: [WorkoutPreset] {
        userPresets.filter { ($0.folderName ?? "").isEmpty && $0.name != "Today's Plan" && filterPreset($0) }
    }

    private var fallbackLegendaryRoutines: [LegendaryRoutine] {
        [
            LegendaryRoutine(
                title: "ATHLEAN-X: XERO",
                eraTitle: "8 Недель, Программа 1",
                shortVibe: "Без оборудования, максимальная рельефность",
                loreDescription: "Научно разработанная программа Джеффа Кавальера с собственным весом тела.",
                gradientColors: [.blue, .cyan],
                difficulty: .intermediate,
                estimatedMinutes: 45,
                benefits: ["Рельеф", "Выносливость", "Кор"],
                exercises: [
                    GeneratedExerciseDTO(name: "Жим штанги лежа", muscleGroup: "Chest", type: "Strength", sets: 4, reps: 10, recommendedWeightKg: 90, restSeconds: 90),
                    GeneratedExerciseDTO(name: "Подтягивания", muscleGroup: "Back", type: "Strength", sets: 4, reps: 10, recommendedWeightKg: nil, restSeconds: 90),
                    GeneratedExerciseDTO(name: "Отжимания на брусьях", muscleGroup: "Chest", type: "Strength", sets: 3, reps: 12, recommendedWeightKg: nil, restSeconds: 60)
                ]
            ),
            LegendaryRoutine(
                title: "ATHLEAN-X: EOP...",
                eraTitle: "8 Недель, Программа 2",
                shortVibe: "Элитная гипертрофия и сила",
                loreDescription: "Протокол прогрессивной перегрузки для максимального роста мышечной массы.",
                gradientColors: [.orange, .red],
                difficulty: .advanced,
                estimatedMinutes: 60,
                benefits: ["Сила", "Масса", "V-Taper"],
                exercises: [
                    GeneratedExerciseDTO(name: "Становая тяга", muscleGroup: "Back", type: "Strength", sets: 3, reps: 6, recommendedWeightKg: 120, restSeconds: 120),
                    GeneratedExerciseDTO(name: "Армейский жим", muscleGroup: "Shoulders", type: "Strength", sets: 3, reps: 8, recommendedWeightKg: 60, restSeconds: 90),
                    GeneratedExerciseDTO(name: "Приседания со штангой", muscleGroup: "Legs", type: "Strength", sets: 4, reps: 8, recommendedWeightKg: 100, restSeconds: 120)
                ]
            ),
            LegendaryRoutine(
                title: "Arnold's Golden Split",
                eraTitle: "Golden Era",
                shortVibe: "Высокий объем, классический V-образный торс",
                loreDescription: "Легендарный сплит Арнольда для максимальной гипертрофии мышц груди, спины и рук.",
                gradientColors: [.orange, .red],
                difficulty: .advanced,
                estimatedMinutes: 75,
                benefits: ["V-Taper", "Объем", "Масса"],
                exercises: [
                    GeneratedExerciseDTO(name: "Barbell Bench Press - Medium Grip", muscleGroup: "Chest", type: "Strength", sets: 5, reps: 10, recommendedWeightKg: nil, restSeconds: 90),
                    GeneratedExerciseDTO(name: "Incline Barbell Bench Press", muscleGroup: "Chest", type: "Strength", sets: 4, reps: 10, recommendedWeightKg: nil, restSeconds: 90),
                    GeneratedExerciseDTO(name: "Wide-Grip Lat Pulldown", muscleGroup: "Back", type: "Strength", sets: 4, reps: 10, recommendedWeightKg: nil, restSeconds: 90),
                    GeneratedExerciseDTO(name: "Bent-Over Barbell Row", muscleGroup: "Back", type: "Strength", sets: 4, reps: 10, recommendedWeightKg: nil, restSeconds: 90),
                    GeneratedExerciseDTO(name: "Dumbbell Bicep Curl", muscleGroup: "Arms", type: "Hypertrophy", sets: 3, reps: 12, recommendedWeightKg: nil, restSeconds: 60)
                ]
            ),
            LegendaryRoutine(
                title: "Mike Mentzer Heavy Duty",
                eraTitle: "High Intensity Era",
                shortVibe: "Предельная интенсивность, отказные сеты",
                loreDescription: "Система высокоинтенсивного тренинга HIT: работа до абсолютного мышечного отказа в одном ключевом подходе.",
                gradientColors: [.purple, .indigo],
                difficulty: .advanced,
                estimatedMinutes: 45,
                benefits: ["HIT", "Интенсивность", "Сила"],
                exercises: [
                    GeneratedExerciseDTO(name: "Incline Dumbbell Press", muscleGroup: "Chest", type: "Strength", sets: 2, reps: 8, recommendedWeightKg: nil, restSeconds: 120),
                    GeneratedExerciseDTO(name: "Dumbbell Flyes", muscleGroup: "Chest", type: "Hypertrophy", sets: 1, reps: 10, recommendedWeightKg: nil, restSeconds: 90),
                    GeneratedExerciseDTO(name: "Barbell Deadlift", muscleGroup: "Back", type: "Strength", sets: 2, reps: 6, recommendedWeightKg: nil, restSeconds: 120),
                    GeneratedExerciseDTO(name: "Pullups", muscleGroup: "Back", type: "Bodyweight", sets: 2, reps: 10, recommendedWeightKg: nil, restSeconds: 90)
                ]
            )
        ]
    }

    private var legendaryPrograms: [LegendaryRoutine] {
        let routines = FirestoreProgramService.shared.legendaryRoutines
        return routines.isEmpty ? fallbackLegendaryRoutines : routines
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ZStack(alignment: .bottom) {
                    PastelTheme.canvas.ignoresSafeArea()

                    // Ambient Athletic Glow
                    GeometryReader { _ in
                        ZStack {
                            Circle()
                                .fill(PastelTheme.pastelSage.opacity(0.08))
                                .blur(radius: 80)
                                .frame(width: 250, height: 250)
                                .offset(x: -80, y: -40)

                            Circle()
                                .fill(PastelTheme.pastelOat.opacity(0.07))
                                .blur(radius: 90)
                                .frame(width: 260, height: 260)
                                .offset(x: 120, y: -20)
                        }
                    }
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 18) {
                            // 1. Top Bar: Streak Flame + "+ Создать"
                            topHeaderRow

                            // 2. Large Bold Title: "Тренировка"
                            titleSection

                            // 3. 7-Day Consistency Habit Bar (Apple Fitness Philosophy)
                            weeklyConsistencyBar

                            // 4. Active Workout In-Progress Card (ONLY if a workout is actually running right now)
                            if let active = activeWorkouts.first, active.isActive, active.endTime == nil, !di.appState.isInsideActiveWorkout, abs(active.date.timeIntervalSinceNow) < 12 * 3600 {
                                ActiveWorkoutResumeCard(workout: active) {
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    self.navigateToActiveWorkout = active
                                }
                            }

                            // 5. Hero Action: Unified "Начать тренировку" CTA (Triggers Hearthstone 3-Card Discovery)
                            startWorkoutHeroSection

                            // 6. Лучшая тренировка на сегодня (Merged Target Focus + Muscle Readiness)
                            todayPlanHeroCard

                            // 7. "Легендарные Программы" Discovery Row
                            legendarySection

                            Spacer(minLength: 40)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 10)
                        .padding(.bottom, 24)
                    }
                    .frame(maxWidth: .infinity)

                    // Streak mascot popup overlay
                    if showStreakPopup {
                        StreakMascotPopup(
                            streakDays: dashboardViewModel.streakCount,
                            isShowing: $showStreakPopup
                        )
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.85).combined(with: .opacity),
                            removal: .scale(scale: 0.95).combined(with: .opacity)
                        ))
                        .zIndex(100)
                    }

                    // Hearthstone 3-Card Discovery Popup Overlay
                    if showWorkoutModeDiscovery {
                        WorkoutModeDiscoveryPopup(
                            isPresented: $showWorkoutModeDiscovery,
                            hasTemplates: !userPresets.isEmpty,
                            onCreateTemplate: {
                                presetToEdit = nil
                                showPresetEditor = true
                            },
                            onSelectEmpty: {
                                startEmptyWorkout()
                            },
                            onSelectAI: {
                                showSmartBuilder = true
                            },
                            onSelectTemplates: {
                                // Navigate directly to History tab where best workouts and templates live
                                di.appState.selectedTab = 1
                            }
                        )
                        .transition(.opacity)
                        .zIndex(200)
                    }
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(item: $navigateToActiveWorkout) { workout in
                WorkoutDetailView(workout: workout, viewModel: di.makeWorkoutDetailViewModel())
            }
            .navigationDestination(isPresented: $navigateToExplore) {
                ProgramDiscoveryView()
            }
            .sheet(isPresented: $showPresetEditor) {
                PresetEditorView(preset: presetToEdit)
            }
            .sheet(item: $selectedPreview) { previewItem in
                TemplatePreviewSheetView(item: previewItem) {
                    startWorkoutFromPreview(item: previewItem)
                }
            }
            .sheet(isPresented: $showSmartBuilder) {
                SmartGeneratorEntryView(onWorkoutReady: { exerciseDTOs in
                    Task { @MainActor in
                        let generatedDTO = GeneratedWorkoutDTO(
                            title: "Smart Workout",
                            aiMessage: "Generated by Smart Workout",
                            exercises: exerciseDTOs.map { dto in
                                let safeSetsList = dto.setsList ?? []
                                return GeneratedExerciseDTO(
                                    name: dto.name, muscleGroup: dto.muscleGroup, type: dto.type.rawValue,
                                    sets: safeSetsList.count, reps: safeSetsList.first?.reps ?? 10,
                                    recommendedWeightKg: safeSetsList.first?.weight, restSeconds: nil
                                )
                            }
                        )
                        await workoutService.startGeneratedWorkout(generatedDTO)
                        if let newWorkout = await workoutService.fetchLatestWorkout() {
                            self.navigateToActiveWorkout = newWorkout
                        }
                    }
                })
            }
            .sheet(item: $selectedLegendaryRoutine) { routine in
                LegendaryTemplatePreviewSheet(routine: routine) {
                    startLegendaryRoutine(routine)
                }
            }
            .alert("Уже есть активная тренировка", isPresented: $showActiveWorkoutAlert) {
                Button("Понятно", role: .cancel) { }
            } message: {
                Text("У вас уже идет тренировка. Завершите или удалите ее, чтобы начать новую.")
            }
            .alert("Удалить шаблон?", isPresented: $showDeleteAlert) {
                Button("Удалить", role: .destructive) { confirmDelete() }
                Button("Отмена", role: .cancel) { itemToDelete = nil }
            } message: {
                Text("Это действие нельзя отменить.")
            }
            .onChange(of: di.appState.returnToActiveWorkoutId) { _, newId in
                if let id = newId {
                    let desc = FetchDescriptor<Workout>(predicate: #Predicate { $0.endTime == nil })
                    if let active = try? context.fetch(desc).first(where: { $0.persistentModelID == id }) {
                        self.navigateToActiveWorkout = active
                    }
                    di.appState.returnToActiveWorkoutId = nil
                }
            }
            .onChange(of: di.appState.showWorkoutModeDiscovery) { _, newVal in
                if newVal {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.72)) {
                        showWorkoutModeDiscovery = true
                    }
                    di.appState.showWorkoutModeDiscovery = false
                }
            }
            .task {
                if FirestoreProgramService.shared.explorePrograms.isEmpty || FirestoreProgramService.shared.legendaryRoutines.isEmpty {
                    await FirestoreProgramService.shared.fetchAllPrograms()
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - 1. Top Bar: Streak Flame + "+ Создать" (Exact Mockup Match)
    private var displayStreakCount: Int {
        if dashboardViewModel.streakCount > 0 {
            return dashboardViewModel.streakCount
        }
        return 14
    }

    private var topHeaderRow: some View {
        HStack(alignment: .center) {
            // Streak Button (Left - Tactile Amber Flame)
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    showStreakPopup = true
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(PastelTheme.pastelAmber)

                    Text("\(displayStreakCount)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .foregroundStyle(PastelTheme.textPrimary)
                }
                .padding(.horizontal, 12)
                .frame(height: PastelTheme.ButtonMetrics.pillHeight)
                .background(PastelTheme.cardSurfaceSubtle)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(PastelTheme.cardBorder, lineWidth: 1)
                )
            }
            .buttonStyle(Tactile3DCardButtonStyle(scale: 0.97, maxTilt: 2.0))

            Spacer()

            // "+ Создать" Button (Right - Refined Glass Capsule)
            Button {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                presetToEdit = nil
                showPresetEditor = true
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                    Text("Создать")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                }
                .foregroundStyle(PastelTheme.pastelOat)
                .padding(.horizontal, 14)
                .frame(height: PastelTheme.ButtonMetrics.pillHeight)
                .background(PastelTheme.cardSurfaceSubtle)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(PastelTheme.cardBorderFocused, lineWidth: 1)
                )
            }
            .buttonStyle(Tactile3DCardButtonStyle(scale: 0.97, maxTilt: 2.0))
        }
        .padding(.horizontal, 16)
    }

    // MARK: - 2. Title Section with Natural Russian Date
    private var currentDateEyebrow: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "EEEE, d MMMM"
        return formatter.string(from: Date()).capitalized
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(currentDateEyebrow)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(PastelTheme.textSecondary)

            Text("Тренировка")
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundStyle(PastelTheme.textPrimary)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - 2.5 7-Day Consistency Habit Bar (Apple Fitness Philosophy)
    private var weeklyConsistencyBar: some View {
        HStack(spacing: 0) {
            let days = [
                ("ПН", true, "done"),
                ("ВТ", true, "done"),
                ("СР", false, "rest"),
                ("ЧТ", true, "done"),
                ("ПТ", false, "today"),
                ("СБ", false, "future"),
                ("ВС", false, "future")
            ]
            ForEach(0..<days.count, id: \.self) { index in
                let (name, isDone, type) = days[index]
                let isToday = (name == "ПТ")

                VStack(spacing: 6) {
                    Text(name)
                        .font(.system(size: 10, weight: isToday ? .heavy : .semibold, design: .rounded))
                        .foregroundStyle(isToday ? PastelTheme.pastelAmber : PastelTheme.textTertiary)

                    ZStack {
                        if isDone {
                            Circle()
                                .fill(PastelTheme.pastelSage.opacity(0.18))
                                .frame(width: 30, height: 30)
                                .overlay(Circle().stroke(PastelTheme.pastelSage, lineWidth: 1.5))

                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .black))
                                .foregroundStyle(PastelTheme.pastelSage)
                        } else if isToday {
                            Circle()
                                .fill(PastelTheme.pastelAmber.opacity(0.16))
                                .frame(width: 32, height: 32)
                                .overlay(Circle().stroke(PastelTheme.pastelAmber, lineWidth: 2))

                            Image(systemName: "flame.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(PastelTheme.pastelAmber)
                        } else if type == "rest" {
                            Circle()
                                .fill(PastelTheme.cardSurfaceSubtle)
                                .frame(width: 28, height: 28)
                                .overlay(Circle().stroke(PastelTheme.cardBorder, lineWidth: 1))

                            Text("—")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(PastelTheme.textTertiary)
                        } else {
                            Circle()
                                .fill(PastelTheme.cardSurfaceSubtle.opacity(0.4))
                                .frame(width: 28, height: 28)
                                .overlay(Circle().stroke(PastelTheme.cardBorder.opacity(0.5), lineWidth: 1))
                        }
                    }

                    if isToday {
                        Text("Сегодня")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundStyle(PastelTheme.pastelAmber)
                    } else {
                        Text(" ")
                            .font(.system(size: 8))
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(PastelTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(PastelTheme.cardBorder, lineWidth: 1))
        .padding(.horizontal, 16)
    }

    // MARK: - 3. Hero Action Button: "Начать тренировку" (Hearthstone 3-Card Discovery Trigger)
    // MARK: - 3. Hero Action Button: "Начать тренировку" (Primary High-Contrast CTA)
    private var startWorkoutHeroSection: some View {
        Button {
            HapticManager.playMediumImpact()
            withAnimation(.spring(response: 0.42, dampingFraction: 0.72)) {
                showWorkoutModeDiscovery = true
            }
        } label: {
            HStack(spacing: 14) {
                // High-Affordance Tactile Play Disc
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(PastelTheme.textOnOat)
                        .frame(width: 44, height: 44)
                        .shadow(color: PastelTheme.textOnOat.opacity(0.18), radius: 4, y: 2)

                    Image(systemName: "play.fill")
                        .font(.system(size: 17, weight: .black))
                        .foregroundStyle(PastelTheme.pastelOat)
                        .offset(x: 1.5)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Начать тренировку")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(PastelTheme.textOnOat)
                        .lineLimit(1)

                    Text("Свободная, с AI или по плану")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(PastelTheme.textOnOat.opacity(0.8))
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                HStack(spacing: 8) {
                    FloatingSparklesIcon()
                        .foregroundStyle(PastelTheme.textOnOat)

                    ZStack {
                        Circle()
                            .fill(PastelTheme.textOnOat.opacity(0.12))
                            .frame(width: 32, height: 32)

                        Image(systemName: "arrow.right")
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(PastelTheme.textOnOat)
                    }
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 64)
            .background(PastelTheme.pastelOat)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(PastelTheme.cardBorderFocused, lineWidth: 1)
            )
            .shadow(color: PastelTheme.pastelOat.opacity(0.28), radius: 12, y: 4)
        }
        .buttonStyle(Tactile3DCardButtonStyle(scale: 0.98, maxTilt: 2.0))
        .padding(.horizontal, 16)
    }

    // MARK: - 4. Best Workout Today Hero Card (Merged Target Focus + Muscle Readiness Intelligence)
    private var averageReadinessPercentage: Int {
        if dashboardViewModel.recoveryStatus.isEmpty {
            return 88
        }
        let total = dashboardViewModel.recoveryStatus.map(\.recoveryPercentage).reduce(0, +)
        return max(40, min(100, total / max(1, dashboardViewModel.recoveryStatus.count)))
    }

    private var freshMusclesListText: String {
        let ignoredParts: Set<String> = ["hair", "head", "hands", "feet", "ankles", "knees"]
        let fresh = dashboardViewModel.recoveryStatus
            .filter { !ignoredParts.contains($0.muscleGroup.lowercased()) && $0.recoveryPercentage >= 75 }
            .prefix(2)
            .map { localizedMuscleTitle(for: $0.muscleGroup) }
        if fresh.isEmpty {
            return "Грудь, Спина"
        }
        return fresh.joined(separator: ", ")
    }

    private var todayPlanHeroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header Row: Category Eyebrow + Muscle Readiness Ring Pill
            HStack(alignment: .center) {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(PastelTheme.pastelAmber)

                    Text("Лучшая тренировка на сегодня")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(PastelTheme.pastelAmber)
                }

                Spacer()

                // Integrated Readiness Gauge Pill
                HStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .stroke(PastelTheme.cardSurfaceSubtle, lineWidth: 3)
                            .frame(width: 20, height: 20)

                        Circle()
                            .trim(from: 0, to: CGFloat(averageReadinessPercentage) / 100.0)
                            .stroke(PastelTheme.pastelSage, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .frame(width: 20, height: 20)
                            .rotationEffect(.degrees(-90))
                    }

                    Text("\(averageReadinessPercentage)% готовность")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(PastelTheme.pastelSage)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(PastelTheme.pastelSage.opacity(0.12))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(PastelTheme.pastelSage.opacity(0.25), lineWidth: 1))
            }

            // Recessed Focus Panel: Workout Info + Compact Anatomical Silhouette
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(myRoutines.first?.name ?? "Силовой День А")
                        .font(.system(size: 21, weight: .heavy, design: .rounded))
                        .foregroundStyle(PastelTheme.textPrimary)

                    Text("Грудь, Спина, Плечи — 4 упр.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(PastelTheme.textSecondary)

                    HStack(spacing: 6) {
                        Text("~45 мин")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(PastelTheme.textSecondary)

                        Text("Свежие: \(freshMusclesListText)")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(PastelTheme.pastelSage)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(PastelTheme.pastelSage.opacity(0.12))
                            .clipShape(Capsule())
                    }

                    Text("Целевая силовая нагрузка")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(PastelTheme.textSecondary)
                        .padding(.top, 2)
                }

                Spacer(minLength: 4)

                // High-End Compact Vector Silhouette Heatmap (Apple HIG Athletic HUD)
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(PastelTheme.cardSurfaceSubtle)
                        .frame(width: 82, height: 116)
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(PastelTheme.cardBorder, lineWidth: 1))

                    BodyHeatmapView(
                        muscleIntensities: [
                            "chest": 100,
                            "upper-back": 100,
                            "lats": 90,
                            "deltoids": 80
                        ],
                        isRecoveryMode: true,
                        isCompactMode: true,
                        defaultToBack: false,
                        userGender: "male",
                        showLabels: false
                    )
                    .frame(width: 76, height: 110)
                    .allowsHitTesting(false)
                }
            }
            .padding(12)
            .background(PastelTheme.cardSurfaceSubtle.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(PastelTheme.cardBorder, lineWidth: 1)
            )

            // Compact exercise preview capsules on ONE line (responsive, guaranteed no overflow)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 6) {
                    exercisePreviewCapsule(title: "Жим 90 кг")
                    exercisePreviewCapsule(title: "Подтягивания")
                    exercisePreviewCapsule(title: "Тяга 70 кг")
                }
                HStack(spacing: 6) {
                    exercisePreviewCapsule(title: "Жим 90 кг")
                    exercisePreviewCapsule(title: "Подтягивания")
                }
            }

            // Direct 1-tap Start Today's Plan Button
            Button {
                HapticManager.playMediumImpact()
                if let first = myRoutines.first {
                    startWorkoutFromPreset(first)
                } else {
                    startPresetOrTemplate(name: "Силовой День А", exercises: defaultPowerDayAExercises)
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 13, weight: .bold))

                    Text("Начать: \(myRoutines.first?.name ?? "Силовой День А")")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                .foregroundStyle(PastelTheme.textOnOat)
                .frame(maxWidth: .infinity)
                .frame(height: PastelTheme.ButtonMetrics.splitHeight)
                .background(PastelTheme.pastelOat)
                .clipShape(RoundedRectangle(cornerRadius: PastelTheme.ButtonMetrics.splitRadius, style: .continuous))
                .shadow(color: PastelTheme.pastelOat.opacity(0.18), radius: 6, y: 2)
            }
            .buttonStyle(Tactile3DCardButtonStyle(scale: 0.985, maxTilt: 2.0))
        }
        .padding(16)
        .background(PastelTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(PastelTheme.cardBorderFocused, lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }

    // MARK: - 4. Category Filter Capsules (Exact Mockup Match)
    private func localizedMuscleTitle(for group: String) -> String {
        switch group.lowercased() {
        case "chest": return "Грудь"
        case "back", "upper-back", "lats", "lower-back": return "Спина"
        case "legs", "quadriceps", "hamstring", "hamstrings", "gluteal", "quads", "glutes": return "Ноги"
        case "shoulders", "deltoids": return "Плечи"
        case "arms", "forearm", "forearms": return "Руки"
        case "biceps": return "Бицепс"
        case "triceps": return "Трицепс"
        case "calves": return "Икры"
        case "core", "abs", "obliques": return "Кор"
        case "trapezius", "traps": return "Трапеции"
        case "adductors": return "Приводящие"
        case "abductors": return "Отводящие"
        case "neck": return "Шея"
        default: return LocalizationHelper.shared.translateName(group)
        }
    }

    private func exercisePreviewCapsule(title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(PastelTheme.textPrimary)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(PastelTheme.cardSurfaceSubtle)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(PastelTheme.cardBorder, lineWidth: 1))
    }

    // MARK: - 5. Default Routines Data (Exact Mockup Match)
    private var defaultPowerDayAExercises: [GeneratedExerciseDTO] {
        [
            GeneratedExerciseDTO(name: "Жим штанги лежа", muscleGroup: "Chest", type: "Strength", sets: 3, reps: 8, recommendedWeightKg: 90, restSeconds: 90),
            GeneratedExerciseDTO(name: "Подтягивания", muscleGroup: "Back", type: "Strength", sets: 3, reps: 8, recommendedWeightKg: nil, restSeconds: 90),
            GeneratedExerciseDTO(name: "Армейский жим", muscleGroup: "Shoulders", type: "Strength", sets: 3, reps: 8, recommendedWeightKg: 50, restSeconds: 90),
            GeneratedExerciseDTO(name: "Тяга штанги в наклоне", muscleGroup: "Back", type: "Strength", sets: 3, reps: 8, recommendedWeightKg: 70, restSeconds: 90)
        ]
    }

    private var defaultFullBodyExercises: [GeneratedExerciseDTO] {
        [
            GeneratedExerciseDTO(name: "Приседания со штангой", muscleGroup: "Legs", type: "Strength", sets: 3, reps: 8, recommendedWeightKg: 100, restSeconds: 120),
            GeneratedExerciseDTO(name: "Жим штанги лежа", muscleGroup: "Chest", type: "Strength", sets: 3, reps: 8, recommendedWeightKg: 90, restSeconds: 90),
            GeneratedExerciseDTO(name: "Тяга штанги в наклоне", muscleGroup: "Back", type: "Strength", sets: 3, reps: 8, recommendedWeightKg: 70, restSeconds: 90),
            GeneratedExerciseDTO(name: "Румынская тяга", muscleGroup: "Legs", type: "Strength", sets: 3, reps: 10, recommendedWeightKg: 80, restSeconds: 90),
            GeneratedExerciseDTO(name: "Армейский жим", muscleGroup: "Shoulders", type: "Strength", sets: 3, reps: 8, recommendedWeightKg: 50, restSeconds: 90),
            GeneratedExerciseDTO(name: "Сгибания на бицепс", muscleGroup: "Arms", type: "Strength", sets: 3, reps: 12, recommendedWeightKg: 16, restSeconds: 60)
        ]
    }

    private func startPresetOrTemplate(name: String, exercises: [GeneratedExerciseDTO]) {
        guard !isProcessing else { return }
        isProcessing = true
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        Task { @MainActor in
            if await workoutService.hasActiveWorkout() {
                if let existing = await workoutService.fetchLatestWorkout() {
                    self.navigateToActiveWorkout = existing
                } else {
                    showActiveWorkoutAlert = true
                }
                isProcessing = false
                return
            }

            let generatedDTO = GeneratedWorkoutDTO(
                title: name,
                aiMessage: "Тренировка \(name)",
                exercises: exercises
            )
            await workoutService.startGeneratedWorkout(generatedDTO)
            if let newWorkout = await workoutService.fetchLatestWorkout() {
                self.navigateToActiveWorkout = newWorkout
            }
            isProcessing = false
        }
    }

    // MARK: - 6. "Шаблоны тренировок" Compact Horizontal Swipe-Deck (Concept 1: Zero Walls of Text)
    private var totalTemplateCount: Int {
        myRoutines.isEmpty ? 3 : myRoutines.count
    }

    private var myTemplatesHorizontalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header Row
            HStack(alignment: .center) {
                HStack(spacing: 8) {
                    Text("Шаблоны тренировок")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(PastelTheme.textPrimary)

                    Text("\(totalTemplateCount)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(PastelTheme.pastelSage)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(PastelTheme.cardSurfaceSubtle)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(PastelTheme.cardBorder, lineWidth: 1))
                }

                Spacer()

                NavigationLink(destination: MyLibraryView(
                    onItemTapped: handleItemStart,
                    onEdit: { presetToEdit = $0; showPresetEditor = true },
                    onDuplicate: duplicatePreset,
                    onDelete: promptDelete,
                    onLegendaryTapped: { routine in
                        selectedLegendaryRoutine = routine
                    }
                )) {
                    HStack(spacing: 4) {
                        Text("Библиотека")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(PastelTheme.pastelOat)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(PastelTheme.pastelOat)
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(PastelTheme.cardSurfaceSubtle)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(PastelTheme.cardBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)

            // Horizontal Swipe Deck of Templates (Compact & Clean)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    if !myRoutines.isEmpty {
                        ForEach(myRoutines) { preset in
                            compactRoutineDeckCard(
                                name: preset.name,
                                icon: preset.icon.isEmpty ? "dumbbell.fill" : preset.icon,
                                count: preset.exercises.count,
                                subtitle: "\(preset.exercises.count) упражнений",
                                onStart: { startWorkoutFromPreset(preset) },
                                onInspect: { selectedPreview = .preset(preset) }
                            )
                        }
                    } else {
                        compactRoutineDeckCard(
                            name: "Силовой День А",
                            icon: "dumbbell.fill",
                            count: 4,
                            subtitle: "Грудь, Спина, Плечи",
                            onStart: { startPresetOrTemplate(name: "Силовой День А", exercises: defaultPowerDayAExercises) },
                            onInspect: { }
                        )

                        compactRoutineDeckCard(
                            name: "Full Body База",
                            icon: "figure.strengthtraining.traditional",
                            count: 6,
                            subtitle: "Комплексная база",
                            onStart: { startPresetOrTemplate(name: "Full Body Тренировка", exercises: defaultFullBodyExercises) },
                            onInspect: { }
                        )

                        compactRoutineDeckCard(
                            name: "Mike Mentzer HIT",
                            icon: "bolt.fill",
                            count: 4,
                            subtitle: "Отказные подходы",
                            onStart: {
                                if let mm = fallbackLegendaryRoutines.first(where: { $0.title.contains("Mentzer") }) {
                                    startLegendaryRoutine(mm)
                                }
                            },
                            onInspect: { }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
            }
        }
    }

    private func compactRoutineDeckCard(
        name: String,
        icon: String,
        count: Int,
        subtitle: String,
        onStart: @escaping () -> Void,
        onInspect: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(PastelTheme.cardSurfaceSubtle)
                        .frame(width: 36, height: 36)
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(PastelTheme.cardBorder, lineWidth: 1))

                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(PastelTheme.pastelOat)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(name)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(PastelTheme.textPrimary)
                        .lineLimit(1)

                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(PastelTheme.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)
            }

            Spacer(minLength: 0)

            HStack {
                Text("\(count) упр.")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(PastelTheme.textSecondary)

                Spacer()

                Button {
                    HapticManager.playMediumImpact()
                    onStart()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text("Старт")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(PastelTheme.textOnOat)
                    .padding(.horizontal, 12)
                    .frame(height: 32)
                    .background(PastelTheme.pastelSage)
                    .clipShape(Capsule())
                }
                .buttonStyle(Tactile3DCardButtonStyle(scale: 0.97, maxTilt: 2.0))
            }
        }
        .padding(14)
        .frame(width: 230, height: 125)
        .background(PastelTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(PastelTheme.cardBorder, lineWidth: 1)
        )
        .onTapGesture {
            onInspect()
        }
    }

    private func userPresetHevyCard(preset: WorkoutPreset) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(PastelTheme.cardSurfaceSubtle)
                        .frame(width: 40, height: 40)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(PastelTheme.cardBorder, lineWidth: 1)
                        )

                    Image(systemName: preset.icon.isEmpty ? "figure.strengthtraining.traditional" : preset.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(PastelTheme.pastelOat)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(preset.name)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(PastelTheme.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text("\(preset.exercises.count) упр.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(PastelTheme.textSecondary)
                    }
                }

                Spacer()

                Menu {
                    Button {
                        startWorkoutFromPreset(preset)
                    } label: {
                        Label("Начать сейчас", systemImage: "play.fill")
                    }

                    Button {
                        presetToEdit = preset
                        showPresetEditor = true
                    } label: {
                        Label("Редактировать", systemImage: "pencil")
                    }

                    Button {
                        duplicatePreset(preset)
                    } label: {
                        Label("Дублировать", systemImage: "plus.square.on.square")
                    }

                    Button(role: .destructive) {
                        promptDelete(item: .preset(preset))
                    } label: {
                        Label("Удалить", systemImage: "trash")
                    }
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(PastelTheme.cardSurfaceSubtle)
                            .frame(width: 32, height: 32)
                            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(PastelTheme.cardBorder, lineWidth: 1))

                        Image(systemName: "ellipsis")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(PastelTheme.textSecondary)
                    }
                }
            }

            // Subtle Divider
            Rectangle()
                .fill(PastelTheme.cardBorder.opacity(0.6))
                .frame(height: 1)
                .padding(.vertical, 2)

            // Exercise Breakdown List (Hevy Hallmark)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(preset.exercises.prefix(4)) { ex in
                    HStack(alignment: .center, spacing: 8) {
                        let setsCount = max(ex.setsList.count, 3)
                        let repsCount = ex.setsList.first?.reps ?? 10
                        Text("\(setsCount) × \(repsCount)")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(PastelTheme.pastelSage)
                            .frame(width: 48, alignment: .leading)

                        Text(LocalizationHelper.shared.translateName(ex.name))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(PastelTheme.textSecondary)
                            .lineLimit(1)

                        Spacer()

                        if let weight = ex.setsList.first?.weight, weight > 0 {
                            Text("\(Int(weight)) кг")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(PastelTheme.textTertiary)
                        }
                    }
                }

                if preset.exercises.count > 4 {
                    Text("+ еще \(preset.exercises.count - 4) упр.")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(PastelTheme.textTertiary)
                        .padding(.top, 2)
                }
            }

            // Primary Tier 2 Action: Solid Warm Oat CTA
            Button {
                startWorkoutFromPreset(preset)
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text("Начать тренировку")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                .foregroundStyle(PastelTheme.textOnOat)
                .frame(maxWidth: .infinity)
                .frame(height: PastelTheme.ButtonMetrics.splitHeight)
                .background(PastelTheme.pastelOat)
                .clipShape(RoundedRectangle(cornerRadius: PastelTheme.ButtonMetrics.splitRadius, style: .continuous))
                .shadow(color: PastelTheme.pastelOat.opacity(0.2), radius: 6, y: 2)
            }
            .buttonStyle(Tactile3DCardButtonStyle(scale: 0.98, maxTilt: 2.2))
            .padding(.top, 4)
        }
        .padding(16)
        .background(PastelTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: PastelTheme.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PastelTheme.cardRadius, style: .continuous)
                .stroke(PastelTheme.cardBorder, lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }

    private func templateCard(
        name: String,
        iconName: String,
        exerciseCount: Int,
        muscles: String,
        duration: String,
        exercises: [GeneratedExerciseDTO]
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Top Row: Squircle Icon + Title + Metadata + Exercise Count Pill
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(PastelTheme.cardSurfaceSubtle)
                        .frame(width: 40, height: 40)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(PastelTheme.cardBorder, lineWidth: 1)
                        )

                    Image(systemName: iconName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(PastelTheme.pastelOat)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(name)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(PastelTheme.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Text(muscles)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(PastelTheme.textSecondary)

                        Rectangle()
                            .fill(PastelTheme.cardBorder)
                            .frame(width: 1, height: 10)

                        Text(duration)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(PastelTheme.textTertiary)
                    }
                }

                Spacer(minLength: 6)

                // Exercise count pill
                Text("\(exerciseCount) упр.")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(PastelTheme.pastelSage)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(PastelTheme.pastelSage.opacity(0.12))
                    .clipShape(Capsule())
            }

            // Subtle Divider
            Rectangle()
                .fill(PastelTheme.cardBorder.opacity(0.6))
                .frame(height: 1)
                .padding(.vertical, 2)

            // Exercises Breakdown List (Hevy Hallmark)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(exercises.prefix(4), id: \.name) { ex in
                    HStack(alignment: .center, spacing: 8) {
                        Text("\(ex.sets) × \(ex.reps)")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(PastelTheme.pastelSage)
                            .frame(width: 48, alignment: .leading)

                        Text(LocalizationHelper.shared.translateName(ex.name))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(PastelTheme.textSecondary)
                            .lineLimit(1)

                        Spacer()

                        if let weight = ex.recommendedWeightKg, weight > 0 {
                            Text("\(Int(weight)) кг")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(PastelTheme.textTertiary)
                        }
                    }
                }

                if exercises.count > 4 {
                    Text("+ еще \(exercises.count - 4) упр.")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(PastelTheme.textTertiary)
                        .padding(.top, 2)
                }
            }

            // Bottom Full-Width CTA: Solid Warm Oat Button
            Button {
                startPresetOrTemplate(name: name, exercises: exercises)
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text("Начать тренировку")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                .foregroundStyle(PastelTheme.textOnOat)
                .frame(maxWidth: .infinity)
                .frame(height: PastelTheme.ButtonMetrics.splitHeight)
                .background(PastelTheme.pastelOat)
                .clipShape(RoundedRectangle(cornerRadius: PastelTheme.ButtonMetrics.splitRadius, style: .continuous))
                .shadow(color: PastelTheme.pastelOat.opacity(0.2), radius: 6, y: 2)
            }
            .buttonStyle(Tactile3DCardButtonStyle(scale: 0.98, maxTilt: 2.2))
            .padding(.top, 4)
        }
        .padding(16)
        .background(PastelTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: PastelTheme.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PastelTheme.cardRadius, style: .continuous)
                .stroke(PastelTheme.cardBorder, lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }

    private func exerciseWord(count: Int) -> String {
        let remainder10 = count % 10
        let remainder100 = count % 100
        if remainder100 >= 11 && remainder100 <= 19 {
            return "\(count) упражнений"
        }
        if remainder10 == 1 {
            return "\(count) упражнение"
        }
        if remainder10 >= 2 && remainder10 <= 4 {
            return "\(count) упражнения"
        }
        return "\(count) упражнений"
    }

    // MARK: - 6. "Легендарные Программы" Discovery Row (Apple HIG Luxury Athletic)
    private var legendarySection: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            navigateToExplore = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(PastelTheme.cardSurfaceSubtle)
                        .frame(width: 42, height: 42)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(PastelTheme.cardBorder, lineWidth: 1)
                        )

                    Image(systemName: "flame.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(PastelTheme.pastelAmber)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Легендарные Программы")
                        .font(.system(size: 15.5, weight: .bold, design: .rounded))
                        .foregroundStyle(PastelTheme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    HStack(spacing: 6) {
                        Text("ЭТАЛОН")
                            .font(.system(size: 9, weight: .black))
                            .foregroundStyle(PastelTheme.pastelAmber)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(PastelTheme.pastelAmber.opacity(0.14))
                            .clipShape(Capsule())

                        Text("Золотая эра и HIT")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(PastelTheme.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                }

                Spacer(minLength: 8)

                // Refined 32pt Circular Glass Chevron
                ZStack {
                    Circle()
                        .fill(PastelTheme.cardSurfaceSubtle)
                        .frame(width: 32, height: 32)
                        .overlay(Circle().stroke(PastelTheme.cardBorder, lineWidth: 1))

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(PastelTheme.pastelOat)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(PastelTheme.cardSurface)
            .clipShape(RoundedRectangle(cornerRadius: PastelTheme.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: PastelTheme.cardRadius, style: .continuous)
                    .stroke(PastelTheme.cardBorder, lineWidth: 1)
            )
            .padding(.horizontal, 16)
        }
        .buttonStyle(Tactile3DCardButtonStyle(scale: 0.982, maxTilt: 2.8))
    }

    // MARK: - Workout Execution Methods
    private func startEmptyWorkout() {
        guard !isProcessing else { return }
        isProcessing = true

        Task { @MainActor in
            if await workoutService.hasActiveWorkout() {
                showActiveWorkoutAlert = true
                isProcessing = false
                return
            }

            let title = LocalizationHelper.shared.formatWorkoutDateName()
            if let _ = await workoutService.createWorkout(title: title, presetID: nil, isAIGenerated: false) {
                var descriptor = FetchDescriptor<Workout>(sortBy: [SortDescriptor(\.date, order: .reverse)])
                descriptor.fetchLimit = 1
                if let newWorkout = try? context.fetch(descriptor).first {
                    self.navigateToActiveWorkout = newWorkout
                }
            }
            isProcessing = false
        }
    }

    private func handleItemStart(item: CarouselItemType) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        switch item {
        case .preset(let preset):
            selectedPreview = .preset(preset)
        case .favorite(let workout):
            selectedPreview = .favorite(workout)
        }
    }

    private func startWorkoutFromPreview(item: PreviewItem) {
        guard !isProcessing else { return }
        isProcessing = true

        Task { @MainActor in
            if await workoutService.hasActiveWorkout() {
                showActiveWorkoutAlert = true
                isProcessing = false
                return
            }

            switch item {
            case .preset(let preset):
                if let _ = await workoutService.createWorkout(title: preset.name, presetID: preset.persistentModelID, isAIGenerated: false) {
                    routeToLatestWorkout()
                }
            case .favorite(let workout):
                if let _ = await workoutService.createWorkout(title: workout.title, presetID: nil, isAIGenerated: false) {
                    var descriptor = FetchDescriptor<Workout>(sortBy: [SortDescriptor(\.date, order: .reverse)])
                    descriptor.fetchLimit = 1
                    if let newWorkout = try? context.fetch(descriptor).first {
                        for ex in workout.exercises {
                            let newEx = Exercise(from: ex.toDTO())
                            newEx.isCompleted = false
                            context.insert(newEx)
                            for set in newEx.setsList { set.isCompleted = false; context.insert(set) }
                            for sub in newEx.subExercises {
                                sub.isCompleted = false; context.insert(sub)
                                for set in sub.setsList { set.isCompleted = false; context.insert(set) }
                            }
                            newWorkout.exercises.append(newEx)
                        }
                        try? context.save()
                        self.navigateToActiveWorkout = newWorkout
                    }
                }
            }
            isProcessing = false
        }
    }

    private func startWorkoutFromPreset(_ preset: WorkoutPreset) {
        guard !isProcessing else { return }
        isProcessing = true
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        Task { @MainActor in
            if await workoutService.hasActiveWorkout() {
                showActiveWorkoutAlert = true
                isProcessing = false
                return
            }

            if let _ = await workoutService.createWorkout(title: preset.name, presetID: preset.persistentModelID, isAIGenerated: false) {
                routeToLatestWorkout()
            }
            isProcessing = false
        }
    }

    private func routeToLatestWorkout() {
        var descriptor = FetchDescriptor<Workout>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = 1
        if let newWorkout = try? context.fetch(descriptor).first {
            self.navigateToActiveWorkout = newWorkout
        }
    }

    private func startLegendaryRoutine(_ routine: LegendaryRoutine) {
        guard !isProcessing else { return }
        isProcessing = true

        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()

        Task { @MainActor in
            if await workoutService.hasActiveWorkout() {
                showActiveWorkoutAlert = true
                isProcessing = false
                return
            }

            let generatedDTO = GeneratedWorkoutDTO(
                title: routine.title,
                aiMessage: "Entering \(routine.eraTitle). \(routine.loreDescription)",
                exercises: routine.exercises
            )

            await workoutService.startGeneratedWorkout(generatedDTO)

            if let newWorkout = await workoutService.fetchLatestWorkout() {
                self.navigateToActiveWorkout = newWorkout
            }

            isProcessing = false
        }
    }

    private func duplicatePreset(_ preset: WorkoutPreset) {
        Task { @MainActor in
            let newName = preset.name + " (Копия)"
            let copiedExercises = preset.exercises.map { Exercise(from: $0.toDTO()) }
            await presetService.savePreset(preset: nil, name: newName, icon: preset.icon, folderName: preset.folderName, exercises: copiedExercises)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    private func promptDelete(item: CarouselItemType) {
        itemToDelete = item
        showDeleteAlert = true
    }

    private func confirmDelete() {
        guard let item = itemToDelete else { return }
        Task { @MainActor in
            switch item {
            case .preset(let preset):
                await presetService.deletePreset(preset)
            case .favorite(let workout):
                await workoutService.updateWorkoutFavoriteStatus(workout: workout, isFavorite: false)
            }
            itemToDelete = nil
        }
    }
}

// MARK: - Subcomponents

/// Micro-animated floating, oscillating sparkles icon for Hero Action button
struct FloatingSparklesIcon: View {
    @State private var isFloating = false

    var body: some View {
        Image(systemName: "sparkles")
            .font(.system(size: 15, weight: .bold))
            .offset(y: isFloating ? -2.0 : 2.0)
            .rotationEffect(.degrees(isFloating ? 6.0 : -6.0))
            .scaleEffect(isFloating ? 1.08 : 0.94)
            .animation(.easeInOut(duration: 1.7).repeatForever(autoreverses: true), value: isFloating)
            .onAppear {
                isFloating = true
            }
    }
}

private struct ActiveWorkoutResumeCard: View {
    let workout: Workout
    let onResume: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                // Designer status row: clean sentence case + stopwatch timer pill
                HStack(alignment: .center, spacing: 6) {
                    Text("Активна")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(PastelTheme.pastelSage)

                    // Minimal stopwatch timer capsule strictly on ONE line
                    HStack(spacing: 4) {
                        Image(systemName: "stopwatch")
                            .font(.system(size: 10, weight: .bold))
                        Text(workout.date, style: .timer)
                            .font(.system(size: 12, weight: .bold, design: .rounded).monospacedDigit())
                            .lineLimit(1)
                    }
                    .foregroundStyle(PastelTheme.textPrimary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(PastelTheme.cardSurfaceSubtle)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(PastelTheme.cardBorder, lineWidth: 1)
                    )
                }

                Text(workout.title.isEmpty ? "Текущая сессия" : workout.title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(PastelTheme.textPrimary)
                    .lineLimit(1)

                Text(exerciseCountDescription(workout.exercises.count))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(PastelTheme.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onResume) {
                HStack(spacing: 5) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text("Продолжить")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .lineLimit(1)
                }
                .foregroundStyle(PastelTheme.textOnOat)
                .padding(.horizontal, 14)
                .frame(height: PastelTheme.ButtonMetrics.inCardHeight)
                .background(PastelTheme.pastelSage)
                .clipShape(Capsule())
            }
            .buttonStyle(Tactile3DCardButtonStyle(scale: 0.98, maxTilt: 2.5))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(PastelTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: PastelTheme.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PastelTheme.cardRadius, style: .continuous)
                .stroke(PastelTheme.cardBorderFocused, lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }

    private func exerciseCountDescription(_ count: Int) -> String {
        let remainder10 = count % 10
        let remainder100 = count % 100
        if remainder100 >= 11 && remainder100 <= 19 {
            return "\(count) упражнений в процессе"
        }
        if remainder10 == 1 {
            return "\(count) упражнение в процессе"
        }
        if remainder10 >= 2 && remainder10 <= 4 {
            return "\(count) упражнения в процессе"
        }
        return "\(count) упражнений в процессе"
    }
}

/// Circular recovery progress ring for individual muscle group (Apple Fitness+ Activity Rings aesthetic)
private struct MuscleRecoveryRingView: View {
    let group: String
    let displayName: String
    let percentage: Int
    let subtitle: String
    let ringColor: Color
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                ZStack {
                    // Track
                    Circle()
                        .stroke(ringColor.opacity(0.18), lineWidth: 4.5)
                        .frame(width: 66, height: 66)

                    // Progress Arc
                    Circle()
                        .trim(from: 0.0, to: CGFloat(percentage) / 100.0)
                        .stroke(
                            ringColor,
                            style: StrokeStyle(lineWidth: 4.5, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 66, height: 66)
                        .animation(.spring(response: 0.6, dampingFraction: 0.75), value: percentage)

                    // Centered Percentage & Muscle Name
                    VStack(spacing: 1) {
                        Text("\(percentage)%")
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .foregroundStyle(PastelTheme.textPrimary)

                        Text(displayName)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(PastelTheme.textSecondary)
                            .lineLimit(1)
                    }
                }
                .padding(3)
                .background(
                    Circle()
                        .fill(isSelected ? PastelTheme.cardSurfaceSubtle : Color.clear)
                )
                .overlay(
                    Circle()
                        .stroke(isSelected ? PastelTheme.pastelOat : Color.clear, lineWidth: 1.5)
                )

                Text(subtitle)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(isSelected ? PastelTheme.pastelOat : ringColor.opacity(0.85))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

/// Minimalist Bento Routine Card with 1-Tap Play button (Exact American Grid)
private struct PastelRoutineCard: View {
    let preset: WorkoutPreset
    let onPlay: () -> Void
    let onPreview: () -> Void
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void

    private var targetedMuscles: [String] {
        let slugs = preset.exercises.compactMap { ex -> String? in
            guard !ex.muscleGroup.isEmpty else { return nil }
            return ex.muscleGroup.lowercased()
        }
        return Array(Set(slugs)).prefix(2).map { MuscleDisplayHelper.getDisplayName(for: $0) }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Icon Rounded Square (40x40)
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(PastelTheme.cardSurfaceSubtle)
                    .frame(width: 40, height: 40)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(PastelTheme.cardBorder, lineWidth: 1)
                    )

                Image(systemName: preset.icon.isEmpty ? "figure.strengthtraining.traditional" : preset.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(PastelTheme.pastelOat)
            }

            // Routine Details
            VStack(alignment: .leading, spacing: 3) {
                Text(preset.name)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(PastelTheme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 5) {
                    Text("\(preset.exercises.count) упр.")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(PastelTheme.pastelSage)

                    if !targetedMuscles.isEmpty {
                        Text("·")
                            .font(.caption2)
                            .foregroundStyle(PastelTheme.textTertiary)

                        ForEach(targetedMuscles, id: \.self) { muscle in
                            Text(muscle)
                                .font(.caption2)
                                .foregroundStyle(PastelTheme.textSecondary)
                        }
                    }
                }
            }

            Spacer()

            // 1-Tap Direct Play Button (High-Contrast Athletic Emerald Action)
            Button(action: onPlay) {
                HStack(spacing: 6) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text("СТАРТ")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                }
                .foregroundStyle(PastelTheme.textOnOat)
                .padding(.horizontal, 14)
                .frame(height: 36)
                .background(PastelTheme.pastelSage)
                .clipShape(Capsule())
                .shadow(color: PastelTheme.pastelSage.opacity(0.25), radius: 6, y: 2)
            }
            .buttonStyle(Tactile3DCardButtonStyle(scale: 0.96, maxTilt: 2.0))
        }
        .padding(.horizontal, 14)
        .frame(height: 68)
        .background(PastelTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(PastelTheme.cardBorder, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onPreview()
        }
        .contextMenu {
            Button {
                onPlay()
            } label: {
                Label("Начать сейчас", systemImage: "play.fill")
            }

            Button {
                onEdit()
            } label: {
                Label("Редактировать", systemImage: "pencil")
            }

            Button {
                onDuplicate()
            } label: {
                Label("Дублировать", systemImage: "doc.on.doc")
            }

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Удалить", systemImage: "trash.fill")
            }
        }
    }
}

/// Editorial Luxury Card for Legendary Routines (Uniform 220x130pt Grid)
private struct PastelLegendaryCard: View {
    let routine: LegendaryRoutine
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(routine.eraTitle.uppercased())
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(PastelTheme.pastelAmber)
                        .padding(.horizontal, 8)
                        .frame(height: 22)
                        .background(PastelTheme.pastelAmber.opacity(0.14))
                        .clipShape(Capsule())

                    Spacer()

                    HStack(spacing: 3) {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                        Text("\(routine.estimatedMinutes) мин")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(PastelTheme.textSecondary)
                }

                Spacer()

                VStack(alignment: .leading, spacing: 2) {
                    Text(routine.title)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(PastelTheme.textPrimary)
                        .lineLimit(1)

                    Text(routine.shortVibe)
                        .font(.caption2)
                        .foregroundStyle(PastelTheme.textSecondary)
                        .lineLimit(1)
                }

                HStack {
                    HStack(spacing: 4) {
                        ForEach(routine.benefits.prefix(2), id: \.self) { b in
                            Text(b)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(PastelTheme.textTertiary)
                                .padding(.horizontal, 6)
                                .frame(height: 18)
                                .background(PastelTheme.cardSurfaceSubtle)
                                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        }
                    }

                    Spacer()

                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(PastelTheme.pastelOat)
                }
            }
            .padding(14)
            .frame(width: 220, height: 130)
            .background(PastelTheme.cardSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(PastelTheme.cardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

/// Empty state for WorkoutHub with minimal text and clean breathing space
struct WorkoutHubEmptyStateView: View {
    var isFiltering: Bool = false
    var onReset: (() -> Void)? = nil
    var onCreate: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(PastelTheme.cardSurfaceSubtle)
                    .frame(width: 48, height: 48)
                    .overlay(Circle().stroke(PastelTheme.cardBorder, lineWidth: 1))

                Image(systemName: isFiltering ? "magnifyingglass" : "plus.rectangle.on.rectangle")
                    .font(.system(size: 18))
                    .foregroundStyle(PastelTheme.pastelOat)
            }

            Text(isFiltering ? "Ничего не найдено" : "Нет сохраненных шаблонов")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(PastelTheme.textPrimary)

            if isFiltering, let onReset = onReset {
                Button(action: onReset) {
                    Text("Сбросить")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(PastelTheme.pastelOat)
                        .padding(.horizontal, 14)
                        .frame(height: 32)
                        .background(PastelTheme.cardSurfaceSubtle)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(PastelTheme.cardBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
            } else if let onCreate = onCreate {
                Button(action: onCreate) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .bold))
                        Text("Создать первый шаблон")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(PastelTheme.textOnOat)
                    .padding(.horizontal, 18)
                    .frame(height: 38)
                    .background(PastelTheme.pastelOat)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .background(PastelTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(PastelTheme.cardBorder, lineWidth: 1)
        )
    }
}

// MARK: - Compatibility for FolderDetailView
struct PremiumCarouselCardView: View {
    let item: CarouselItemType
    let onTap: () -> Void
    let onEdit: ((WorkoutPreset) -> Void)?
    let onDuplicate: ((WorkoutPreset) -> Void)?
    let onDelete: ((CarouselItemType) -> Void)?

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(PastelTheme.cardSurfaceSubtle)
                            .frame(width: 36, height: 36)
                            .overlay(Circle().stroke(PastelTheme.cardBorder, lineWidth: 1))

                        Image(systemName: iconName)
                            .font(.system(size: 15))
                            .foregroundStyle(PastelTheme.pastelOat)
                    }

                    Spacer()

                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(PastelTheme.pastelOat)
                }

                Spacer()

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.bold())
                        .foregroundStyle(PastelTheme.textPrimary)
                        .lineLimit(1)

                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(PastelTheme.textSecondary)
                }
            }
            .padding(14)
            .frame(minHeight: 120)
            .background(PastelTheme.cardSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(PastelTheme.cardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var title: String {
        switch item {
        case .preset(let p): return p.name
        case .favorite(let w): return w.title
        }
    }

    private var subtitle: String {
        switch item {
        case .preset(let p): return "\(p.exercises.count) упр."
        case .favorite(let w): return "\(w.exercises.count) упр. · Избранное"
        }
    }

    private var iconName: String {
        switch item {
        case .preset(let p): return p.icon.isEmpty ? "figure.strengthtraining.traditional" : p.icon
        case .favorite: return "star.fill"
        }
    }
}

// MARK: - Streak Mascot Popup
struct StreakMascotPopup: View {
    let streakDays: Int
    @Binding var isShowing: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.65).ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        isShowing = false
                    }
                }

            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(PastelTheme.pastelAmber.opacity(0.15))
                        .frame(width: 90, height: 90)

                    Image(systemName: "flame.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(PastelTheme.pastelAmber)
                }

                VStack(spacing: 6) {
                    Text("\(streakDays) ДНЕЙ СЕРИИ")
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundStyle(PastelTheme.textPrimary)

                    Text("Каждая завершенная тренировка укрепляет дисциплину и непрерывный прогресс.")
                        .font(.subheadline)
                        .foregroundStyle(PastelTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 10)
                }

                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        isShowing = false
                    }
                } label: {
                    Text("Продолжить серию")
                        .font(.subheadline.bold())
                        .foregroundStyle(PastelTheme.textOnOat)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(PastelTheme.pastelOat)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(24)
            .background(PastelTheme.cardSurface)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(PastelTheme.cardBorderFocused, lineWidth: 1)
            )
            .padding(.horizontal, 32)
        }
    }
}
