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

                            // 3. Active Workout In-Progress Card (if present)
                            if let active = activeWorkouts.first {
                                ActiveWorkoutResumeCard(workout: active) {
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    self.navigateToActiveWorkout = active
                                }
                            }

                            // 4. Two 50/50 Dual Launch Cards: "Старт (Пустая сессия)" & "AI План (Умная сборка)"
                            dualLaunchCardsRow

                            // 5. Category Filter Capsules: "Все мышцы", "Грудь", "Спина", "Ноги", "Плечи"
                            filterPillsSection

                            // 6. "Мои шаблоны" with "Силовой День А" (and "▶ Старт") & "Full Body Тренировка"
                            myTemplatesSection

                            // 7. "Легендарные Программы" with ATHLEAN-X horizontal cards
                            legendarySection

                            Spacer(minLength: 40)
                        }
                        .padding(.top, 10)
                        .padding(.bottom, 24)
                    }

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
            .task {
                if CommandLine.arguments.contains("-autoStartWorkout") {
                    startPresetOrTemplate(name: "Силовой День А", exercises: defaultPowerDayAExercises)
                }
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
            // Streak Button (Left)
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    showStreakPopup = true
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(PastelTheme.pastelAmber)

                    Text("\(displayStreakCount)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(PastelTheme.textPrimary)
                }
                .padding(.horizontal, 11)
                .frame(height: 34)
                .background(PastelTheme.cardSurfaceSubtle)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(PastelTheme.cardBorder, lineWidth: 1))
            }
            .buttonStyle(.plain)

            Spacer()

            // "+ Создать" Button (Right, Oat Capsule)
            Button {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                presetToEdit = nil
                showPresetEditor = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                    Text("Создать")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                }
                .foregroundStyle(PastelTheme.textOnOat)
                .padding(.horizontal, 14)
                .frame(height: 34)
                .background(PastelTheme.pastelOat)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - 2. Title Section (Exact Mockup Match)
    private var titleSection: some View {
        Text("Тренировка")
            .font(.system(size: 34, weight: .heavy, design: .rounded))
            .foregroundStyle(PastelTheme.textPrimary)
            .padding(.horizontal, 16)
    }

    // MARK: - 3. Dual Launch 50/50 Cards (Exact Mockup Match)
    private var dualLaunchCardsRow: some View {
        HStack(spacing: 12) {
            // Card 1: "Старт (Пустая сессия)"
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                startEmptyWorkout()
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(PastelTheme.pastelOat)
                            .frame(width: 44, height: 44)
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(PastelTheme.textOnOat)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Старт")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(PastelTheme.textPrimary)

                        Text("(Пустая сессия)")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(PastelTheme.textSecondary)
                    }

                    Spacer()
                }
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity)
                .frame(height: 74)
                .background(PastelTheme.cardSurface)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(PastelTheme.cardBorder, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            // Card 2: "AI План (Умная сборка)"
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                showSmartBuilder = true
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(PastelTheme.pastelSage.opacity(0.85))
                            .frame(width: 44, height: 44)
                        Image(systemName: "sparkles")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(PastelTheme.textOnOat)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("AI План")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(PastelTheme.textPrimary)

                        Text("(Умная сборка)")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(PastelTheme.textSecondary)
                    }

                    Spacer()
                }
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity)
                .frame(height: 74)
                .background(PastelTheme.cardSurface)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(PastelTheme.cardBorder, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - 4. Category Filter Capsules (Exact Mockup Match)
    private func localizedMuscleTitle(for group: String) -> String {
        switch group.lowercased() {
        case "chest": return "Грудь"
        case "back": return "Спина"
        case "legs": return "Ноги"
        case "shoulders": return "Плечи"
        case "arms": return "Руки"
        case "core": return "Кор"
        default: return MuscleDisplayHelper.getDisplayName(for: group)
        }
    }

    private var filterPillsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // "Все мышцы" Pill (Oat Capsule when selected)
                Button {
                    UISelectionFeedbackGenerator().selectionChanged()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedMuscleGroup = nil
                    }
                } label: {
                    Text("Все мышцы")
                        .font(.system(size: 13, weight: selectedMuscleGroup == nil ? .bold : .medium, design: .rounded))
                        .foregroundStyle(selectedMuscleGroup == nil ? PastelTheme.textOnOat : PastelTheme.textSecondary)
                        .padding(.horizontal, 16)
                        .frame(height: PastelTheme.ButtonMetrics.pillHeight)
                        .background(selectedMuscleGroup == nil ? PastelTheme.pastelOat : PastelTheme.cardSurfaceSubtle)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(selectedMuscleGroup == nil ? PastelTheme.cardBorderFocused : PastelTheme.cardBorder, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

                // Muscle group pills: Грудь, Спина, Ноги, Плечи, Руки, Кор
                ForEach(muscleGroups, id: \.self) { group in
                    let isSelected = selectedMuscleGroup == group
                    Button {
                        UISelectionFeedbackGenerator().selectionChanged()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedMuscleGroup = isSelected ? nil : group
                        }
                    } label: {
                        Text(localizedMuscleTitle(for: group))
                            .font(.system(size: 13, weight: isSelected ? .bold : .medium, design: .rounded))
                            .foregroundStyle(isSelected ? PastelTheme.textOnOat : PastelTheme.textSecondary)
                            .padding(.horizontal, 16)
                            .frame(height: PastelTheme.ButtonMetrics.pillHeight)
                            .background(isSelected ? PastelTheme.pastelOat : PastelTheme.cardSurfaceSubtle)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(isSelected ? PastelTheme.cardBorderFocused : PastelTheme.cardBorder, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
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

    // MARK: - 6. "Мои шаблоны" Section (Exact Mockup Match)
    private var myTemplatesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header Row
            HStack(alignment: .center) {
                HStack(spacing: 8) {
                    Text("Мои шаблоны")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(PastelTheme.textPrimary)

                    Text("2")
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
                        Text("Все (2)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(PastelTheme.pastelOat)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(PastelTheme.pastelOat)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)

            // Template Card 1: Силовой День А (Hero Template)
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Силовой День А")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(PastelTheme.textPrimary)

                        Text("4 Упражнения • Сила и масса")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(PastelTheme.textSecondary)
                    }

                    Spacer()

                    // Start Button (Tier 2/3 Warm Oat Action Capsule)
                    Button {
                        startPresetOrTemplate(name: "Силовой День А", exercises: defaultPowerDayAExercises)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 11, weight: .bold))
                            Text("Старт")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(PastelTheme.textOnOat)
                        .padding(.horizontal, 18)
                        .frame(height: 38)
                        .background(PastelTheme.pastelOat)
                        .clipShape(Capsule())
                        .shadow(color: PastelTheme.pastelOat.opacity(0.18), radius: 8, y: 3)
                    }
                    .buttonStyle(.plain)
                }

                // Divider line
                Rectangle()
                    .fill(PastelTheme.cardBorder)
                    .frame(height: 1)

                // Exercises Bullet Preview (Exact Mockup Match)
                VStack(alignment: .leading, spacing: 6) {
                    exerciseRowPreview(index: 1, name: "Жим штанги лежа", detail: "Грудь • 3×8 (90 кг)")
                    exerciseRowPreview(index: 2, name: "Подтягивания с весом", detail: "Спина • 3×8")
                    exerciseRowPreview(index: 3, name: "Армейский жим стоя", detail: "Плечи • 3×8 (50 кг)")
                    exerciseRowPreview(index: 4, name: "Тяга штанги в наклоне", detail: "Спина • 3×8 (70 кг)")
                }
            }
            .padding(16)
            .background(PastelTheme.cardSurface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(PastelTheme.cardBorder, lineWidth: 1)
            )
            .padding(.horizontal, 16)

            // Template Card 2: Full Body Тренировка
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Full Body Тренировка")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(PastelTheme.textPrimary)

                        Text("6 Упражнений • Комплексная база")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(PastelTheme.textSecondary)
                    }

                    Spacer()

                    Button {
                        startPresetOrTemplate(name: "Full Body Тренировка", exercises: defaultFullBodyExercises)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 11, weight: .bold))
                            Text("Старт")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(PastelTheme.textOnOat)
                        .padding(.horizontal, 18)
                        .frame(height: 38)
                        .background(PastelTheme.pastelOat)
                        .clipShape(Capsule())
                        .shadow(color: PastelTheme.pastelOat.opacity(0.18), radius: 8, y: 3)
                    }
                    .buttonStyle(.plain)
                }

                // Divider line
                Rectangle()
                    .fill(PastelTheme.cardBorder)
                    .frame(height: 1)

                // Exercises Bullet Preview
                VStack(alignment: .leading, spacing: 6) {
                    exerciseRowPreview(index: 1, name: "Приседания со штангой", detail: "Ноги • 3×8 (100 кг)")
                    exerciseRowPreview(index: 2, name: "Жим штанги лежа", detail: "Грудь • 3×8 (90 кг)")
                    exerciseRowPreview(index: 3, name: "Тяга штанги в наклоне", detail: "Спина • 3×8 (70 кг)")
                }
            }
            .padding(16)
            .background(PastelTheme.cardSurface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(PastelTheme.cardBorder, lineWidth: 1)
            )
            .padding(.horizontal, 16)
        }
    }

    private func exerciseRowPreview(index: Int, name: String, detail: String) -> some View {
        HStack(spacing: 8) {
            Text("\(index).")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(PastelTheme.pastelSage)
                .frame(width: 18, alignment: .leading)

            Text(name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(PastelTheme.textPrimary)

            Spacer()

            Text(detail)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(PastelTheme.textTertiary)
        }
    }

    // MARK: - 7. "Легендарные Программы" Section (Exact Mockup Match)
    private var legendarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text("Легендарные Программы")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(PastelTheme.textPrimary)

                        Text("ЭТАЛОН")
                            .font(.system(size: 9, weight: .black))
                            .foregroundStyle(PastelTheme.pastelAmber)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(PastelTheme.pastelAmber.opacity(0.12))
                            .clipShape(Capsule())
                    }

                    Text("Классические протоколы золотой эры бодибилдинга")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(PastelTheme.textSecondary)
                }

                Spacer()
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(legendaryPrograms) { routine in
                        PastelLegendaryCard(routine: routine) {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            startLegendaryRoutine(routine)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
            }
        }
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

/// Card showing the in-progress session with direct 1-tap resume
private struct ActiveWorkoutResumeCard: View {
    let workout: Workout
    let onResume: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(PastelTheme.pastelSage)
                        .frame(width: 8, height: 8)

                    Text("ТРЕНИРОВКА ИДЕТ")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(PastelTheme.pastelSage)
                }

                Text(workout.title.isEmpty ? "Текущая сессия" : workout.title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(PastelTheme.textPrimary)
                    .lineLimit(1)

                Text("\(workout.exercises.count) упр. в процессе")
                    .font(.caption2)
                    .foregroundStyle(PastelTheme.textSecondary)
            }

            Spacer()

            Button(action: onResume) {
                HStack(spacing: 6) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text("Продолжить")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(PastelTheme.textOnOat)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(PastelTheme.pastelSage)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(PastelTheme.pastelSage, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(PastelTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(PastelTheme.pastelSage.opacity(0.35), lineWidth: 1)
        )
        .padding(.horizontal, 16)
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
            .buttonStyle(.plain)
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
