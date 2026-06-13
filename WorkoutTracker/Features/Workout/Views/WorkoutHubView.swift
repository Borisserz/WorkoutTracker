

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

struct WorkoutHubView: View {
    @Environment(DIContainer.self) private var di
    @Environment(\.modelContext) private var context
    @Environment(WorkoutService.self) var workoutService
    @Environment(PresetService.self) var presetService
    @Environment(DashboardViewModel.self) var dashboardViewModel
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme 

    @Query(filter: #Predicate<WorkoutPreset> { $0.isSystem == false }, sort: \WorkoutPreset.name)
    private var userPresets: [WorkoutPreset]

    @Query(filter: #Predicate<Workout> { $0.isFavorite == true }, sort: \Workout.date, order: .reverse)
    private var favoriteWorkouts: [Workout]

    @State private var searchText = ""
    @State private var selectedMuscleGroup: String? = nil
    private let muscleGroups = ["Chest", "Back", "Legs", "Shoulders", "Arms", "Core"]

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

    private func filterWorkout(_ workout: Workout) -> Bool {
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            if !workout.title.lowercased().contains(query) {
                return false
            }
        }
        if let targetGroup = selectedMuscleGroup {
            let hasMuscle = workout.exercises.contains { ex in
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

    private var savedSingleRoutines: [WorkoutPreset] {
        userPresets.filter { $0.folderName == PresetService.savedRoutinesFolderName && filterPreset($0) }
    }

    private var programFolders: [String: [WorkoutPreset]] {
        var dict = [String: [WorkoutPreset]]()
        let favStr = String(localized: "Favorites")
        for p in userPresets where !(p.folderName ?? "").isEmpty && p.folderName != PresetService.savedRoutinesFolderName && p.folderName != "HiddenFolder" && p.folderName != "Favorites" && p.folderName != favStr { 
            if filterPreset(p) {
                dict[p.folderName!, default: []].append(p)
            }
        }
        return dict
    }

    private var filteredFavorites: [Workout] {
        favoriteWorkouts.filter { filterWorkout($0) }
    }

    @State private var navigateToActiveWorkout: Workout? = nil
    @State private var navigateToExplore = false

    @State private var showSmartBuilder = false
    @State private var showPresetEditor = false
    @State private var presetToEdit: WorkoutPreset? = nil
    @State private var showStreakPopup = false
    @State private var showWorkoutLauncher = false

    @State private var itemToDelete: CarouselItemType? = nil
    @State private var showDeleteAlert = false
    @State private var showActiveWorkoutAlert = false
    @State private var isProcessing = false
    @State private var selectedPreview: PreviewItem? = nil
    @State private var selectedLegendaryRoutine: LegendaryRoutine? = nil

    private func fallbackRoutine(_ name: String, _ icon: String, _ exercises: [ExerciseDTO]) -> WorkoutPresetDTO {
        WorkoutPresetDTO(name: name, icon: icon, folderName: nil, exercises: exercises)
    }

    private func fallbackEx(_ name: String, _ group: String, _ sets: Int, _ reps: Int) -> ExerciseDTO {
        let setList = (1...sets).map { i in
            WorkoutSetDTO(index: i, weight: 0.0, reps: reps, distance: nil, time: nil, isCompleted: false, type: .normal)
        }
        return ExerciseDTO(
            name: name,
            muscleGroup: group,
            type: .strength,
            category: .other,
            effort: 5,
            isCompleted: false,
            setsList: setList,
            subExercises: [],
            sets: sets,
            reps: reps,
            recommendedWeightKg: 0.0
        )
    }

    private var fallbackPrograms: [WorkoutProgramDefinition] {
        MockProgramCatalog.shared.featuredPrograms
    }

    private var featuredPrograms: [WorkoutProgramDefinition] {
        let progs = FirestoreProgramService.shared.explorePrograms
        if progs.isEmpty {
            return fallbackPrograms
        }
        return Array(progs.prefix(5))
    }

    private var fallbackLegendaryRoutines: [LegendaryRoutine] {
        [
            LegendaryRoutine(
                title: "Arnold's Golden Split",
                eraTitle: "Golden Era",
                shortVibe: "High Volume, Classic V-Taper focus",
                loreDescription: "The exact weekly protocol Arnold used to dominate the stage. Focused heavily on chest, back, and building the classic aesthetic proportion.",
                gradientColors: [.orange, .red],
                difficulty: .advanced,
                estimatedMinutes: 75,
                benefits: ["V-Taper", "Volume", "Mass"],
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
                shortVibe: "Maximum Intensity, Low Volume",
                loreDescription: "The revolutionary High-Intensity Training (HIT) system. Train to absolute failure with one heavy working set, followed by complete rest for ultimate growth.",
                gradientColors: [.purple, .indigo],
                difficulty: .advanced,
                estimatedMinutes: 45,
                benefits: ["HIT", "Intensity", "Hypertrophy"],
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
        if routines.isEmpty {
            return fallbackLegendaryRoutines
        }
        return routines
    }

    var body: some View {
        NavigationStack {
            ZStack {

                (colorScheme == .dark ? themeManager.current.background : Color(UIColor.systemGroupedBackground))
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 32) {
                        headerSection
                        topActionsSection
                        myLibraryActionSection
                        carouselsSection
                        Spacer(minLength: 120)
                    }
                    .padding(.top, 20)
                }

                if showStreakPopup {
                    StreakMascotPopup(
                        streakDays: dashboardViewModel.streakCount,
                        isShowing: $showStreakPopup
                    )
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.8).combined(with: .opacity),
                        removal: .scale(scale: 0.9).combined(with: .opacity)
                    ))
                    .zIndex(100)
                }
            }
            .navigationTitle(LocalizedStringKey("Workout"))
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
            .sheet(isPresented: $showWorkoutLauncher) {
                SmartWorkoutLauncherSheet(
                    onStartEmptySession: { startEmptyWorkout() },
                    onSmartWorkoutTap: { 
                        showWorkoutLauncher = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            showSmartBuilder = true
                        }
                    },
                    onPresetTap: { preset in 
                        showWorkoutLauncher = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            startWorkoutFromPreview(item: .preset(preset))
                        }
                    },
                    onExploreTap: { 
                        showWorkoutLauncher = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            navigateToExplore = true
                        }
                    },
                    onNewProgramTap: { 
                        showWorkoutLauncher = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            presetToEdit = nil; showPresetEditor = true
                        }
                    }
                )
                .presentationDetents([.fraction(0.85), .large])
                .presentationDragIndicator(.visible)
            }
            .sheet(item: $selectedLegendaryRoutine) { routine in
                LegendaryTemplatePreviewSheet(routine: routine) {
                    startLegendaryRoutine(routine)
                }
            }
            .alert(LocalizedStringKey("Active Workout Exists"), isPresented: $showActiveWorkoutAlert) {
                Button(LocalizedStringKey("OK"), role: .cancel) { }
            } message: { Text(LocalizedStringKey("You already have an active workout in progress. Please finish or delete it before starting a new one.")) }
            .alert(LocalizedStringKey("Delete Item?"), isPresented: $showDeleteAlert) {
                Button(LocalizedStringKey("Delete"), role: .destructive) { confirmDelete() }
                Button(LocalizedStringKey("Cancel"), role: .cancel) { itemToDelete = nil }
            } message: { Text(LocalizedStringKey("This action cannot be undone.")) }
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
                if FirestoreProgramService.shared.explorePrograms.isEmpty || FirestoreProgramService.shared.legendaryRoutines.isEmpty {
                    await FirestoreProgramService.shared.fetchAllPrograms()
                }
            }
        }
    }

    private var headerSection: some View {
        HStack {
            Text(LocalizedStringKey("Workout"))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(colorScheme == .dark ? .white : .black) 

            Spacer()

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { showStreakPopup = true }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill").foregroundStyle(Color.orange)
                    Text("\(dashboardViewModel.streakCount) \(String(localized: "days"))")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(colorScheme == .dark ? .white : .black) 
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(colorScheme == .dark ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.white), in: Capsule())
                .overlay(Capsule().stroke(colorScheme == .dark ? Color.white.opacity(0.3) : Color.black.opacity(0.1), lineWidth: 1))
                .shadow(color: Color.orange.opacity(0.2), radius: 8, x: 0, y: 4)
            }.buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
    }

    private var topActionsSection: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            showWorkoutLauncher = true
        }) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [.neonBlue.opacity(0.15), .neonPurple.opacity(0.15)], startPoint: .top, endPoint: .bottom))
                        .frame(width: 50, height: 50)
                    Image(systemName: "bolt.fill")
                        .font(.title2)
                        .foregroundStyle(LinearGradient(colors: [.neonBlue, .neonPurple], startPoint: .topLeading, endPoint: .bottomTrailing))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStringKey("Start Session"))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text(LocalizedStringKey("AI Smart Generator, freestyle session, or routines"))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.gray)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    .font(.headline)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(themeManager.current.surface)
                    
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.neonBlue, .neonPurple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .opacity(0.12)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [.neonBlue.opacity(0.5), .neonPurple.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: .neonPurple.opacity(0.2), radius: 15, x: 0, y: 6)
            .padding(.horizontal, 20)
        }
        .buttonStyle(.plain)
    }

    private var searchAndFilterSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField(String(localized: "Search routines..."), text: $searchText)
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                    .font(.system(.body, design: .rounded))
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                colorScheme == .dark ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.white)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.06), lineWidth: 0.7)
            )
            .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        selectedMuscleGroup = nil
                    }) {
                        Text(LocalizedStringKey("All"))
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(selectedMuscleGroup == nil ? .white : (colorScheme == .dark ? .white : .black))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                selectedMuscleGroup == nil ? themeManager.current.primaryAccent : (colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.04)),
                                in: Capsule()
                            )
                            .overlay(
                                Capsule()
                                    .stroke(
                                        selectedMuscleGroup == nil ? Color.clear : (colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.06)),
                                        lineWidth: 0.7
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    
                    ForEach(muscleGroups, id: \.self) { group in
                        let isSelected = selectedMuscleGroup == group
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            selectedMuscleGroup = isSelected ? nil : group
                        }) {
                            Text(LocalizedStringKey(group))
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(isSelected ? .white : (colorScheme == .dark ? .white : .black))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    isSelected ? themeManager.current.primaryAccent : (colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.04)),
                                    in: Capsule()
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(
                                            isSelected ? Color.clear : (colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.06)),
                                            lineWidth: 0.7
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private var carouselsSection: some View {
            VStack(alignment: .leading, spacing: 32) {
                
                if !featuredPrograms.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .foregroundStyle(LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing))
                            Text(LocalizedStringKey("New Programs"))
                        }
                        .font(.title2.weight(.bold))
                        .foregroundStyle(colorScheme == .dark ? .white : .black)
                        .padding(.horizontal, 20)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(featuredPrograms) { program in
                                    NavigationLink(destination: ProgramDetailView(program: program)) {
                                        PremiumProgramCardView(program: program)
                                            .frame(width: 300)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 10)
                        }
                    }
                }

                if !legendaryPrograms.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(LocalizedStringKey("Legendary Programs"))
                            .font(.title2.weight(.bold))
                            .foregroundStyle(colorScheme == .dark ? .white : .black)
                            .padding(.horizontal, 20)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(legendaryPrograms) { routine in
                                    Button {
                                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                        selectedLegendaryRoutine = routine
                                    } label: {
                                        LegendaryHubCardView(routine: routine)
                                    }
                                    .buttonStyle(PremiumScaleButtonStyle())
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 10)
                        }
                    }
                }

                if let dailyPlan = userPresets.first(where: { $0.name == "Today's Plan" }), !dailyPlan.exercises.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Today's Plan")
                            .font(.title3).bold()
                            .foregroundColor(colorScheme == .dark ? .white : .black) 
                            .padding(.horizontal, 20)

                        PremiumRoutineCard(
                            preset: dailyPlan,
                            onStart: { startWorkoutFromPreview(item: .preset(dailyPlan)) },
                            onEdit: { presetToEdit = dailyPlan; showPresetEditor = true },
                            onDuplicate: nil,
                            onDelete: {
                                Task { @MainActor in
                                    await presetService.deletePreset(dailyPlan)
                                }
                            }
                        )
                        .padding(.horizontal, 20)
                    }
                }

        }
    }

    private var myLibraryActionSection: some View {
        NavigationLink(destination: MyLibraryView(
            onItemTapped: handleItemStart,
            onEdit: { presetToEdit = $0; showPresetEditor = true },
            onDuplicate: duplicatePreset,
            onDelete: promptDelete,
            onLegendaryTapped: { routine in
                selectedLegendaryRoutine = routine
            }
        )) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [.cyan.opacity(0.15), .blue.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 50, height: 50)
                    Image(systemName: "books.vertical.fill")
                        .font(.title2)
                        .foregroundStyle(LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStringKey("My Library"))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                    Text(LocalizedStringKey("Saved workouts, custom programs & folders"))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    .font(.headline)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(themeManager.current.surface)
                    
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.cyan, .blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .opacity(0.08)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [.cyan.opacity(0.4), .blue.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: .blue.opacity(colorScheme == .dark ? 0.15 : 0.05), radius: 15, x: 0, y: 6)
            .padding(.horizontal, 20)
        }
        .buttonStyle(.plain)
    }

    private func startEmptyWorkout() {
        guard !isProcessing else { return }
        isProcessing = true
        Task { @MainActor in
            if await workoutService.hasActiveWorkout() {
                showActiveWorkoutAlert = true; isProcessing = false; return
            }
            let title = LocalizationHelper.shared.formatWorkoutDateName()
            if let _ = await workoutService.createWorkout(title: title, presetID: nil, isAIGenerated: false) {
                var descriptor = FetchDescriptor<Workout>(sortBy: [SortDescriptor(\.date, order: .reverse)]); descriptor.fetchLimit = 1
                if let newWorkout = try? context.fetch(descriptor).first { self.navigateToActiveWorkout = newWorkout }
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
                showActiveWorkoutAlert = true; isProcessing = false; return
            }

            switch item {
            case .preset(let preset):
                if let _ = await workoutService.createWorkout(title: preset.name, presetID: preset.persistentModelID, isAIGenerated: false) {
                    routeToLatestWorkout()
                }
            case .favorite(let workout):
                if let _ = await workoutService.createWorkout(title: workout.title, presetID: nil, isAIGenerated: false) {
                    var descriptor = FetchDescriptor<Workout>(sortBy: [SortDescriptor(\.date, order: .reverse)]); descriptor.fetchLimit = 1
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
        var descriptor = FetchDescriptor<Workout>(sortBy: [SortDescriptor(\.date, order: .reverse)]); descriptor.fetchLimit = 1
        if let newWorkout = try? context.fetch(descriptor).first { self.navigateToActiveWorkout = newWorkout }
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
            let newName = preset.name + " (Copy)"
            let copiedExercises = preset.exercises.map { Exercise(from: $0.toDTO()) }
            await presetService.savePreset(preset: nil, name: newName, icon: preset.icon, folderName: preset.folderName, exercises: copiedExercises)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    private func promptDelete(item: CarouselItemType) { itemToDelete = item; showDeleteAlert = true }

    private func confirmDelete() {
        guard let item = itemToDelete else { return }
        Task { @MainActor in
            switch item {
            case .preset(let preset): await presetService.deletePreset(preset)
            case .favorite(let workout): await workoutService.updateWorkoutFavoriteStatus(workout: workout, isFavorite: false)
            }
            itemToDelete = nil
        }
    }
}

struct CarouselSectionView: View {
    let title: LocalizedStringKey
    let folderName: String?
    let items: [CarouselItemType]

    let onItemTapped: (CarouselItemType) -> Void
    let onEdit: ((WorkoutPreset) -> Void)?
    let onDuplicate: ((WorkoutPreset) -> Void)?
    let onDelete: ((CarouselItemType) -> Void)?

    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme 

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .bottom) {
                    Text(title)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(colorScheme == .dark ? .white : .black) 
                        .lineLimit(2)
                        .minimumScaleFactor(0.9)
                        .allowsTightening(true)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer()

                    NavigationLink(destination: FolderDetailView(
                        folderTitle: title,
                        folderName: folderName,
                        items: items,
                        onItemTapped: onItemTapped,
                        onEdit: onEdit,
                        onDuplicate: onDuplicate,
                        onDelete: onDelete
                    )) {
                        Text(LocalizedStringKey("View All"))
                            .font(.subheadline)
                            .foregroundColor(themeManager.current.primaryAccent)
                    }
                }
                .padding(.horizontal)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 16) {
                        ForEach(items.prefix(7), id: \.id) { item in
                            PremiumCarouselCardView(
                                item: item,
                                onTap: { onItemTapped(item) },
                                onEdit: onEdit,
                                onDuplicate: onDuplicate,
                                onDelete: onDelete
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
            }
        }
    }
}

struct PremiumCarouselCardView: View {
    @Environment(\.colorScheme) private var colorScheme 
    let item: CarouselItemType

    let onTap: () -> Void
    let onEdit: ((WorkoutPreset) -> Void)?
    let onDuplicate: ((WorkoutPreset) -> Void)?
    let onDelete: ((CarouselItemType) -> Void)?

    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {

                HStack(alignment: .top) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(LinearGradient(colors: cardGradients, startPoint: .topLeading, endPoint: .bottomTrailing).opacity(0.2))
                            .frame(width: 44, height: 44)

                        if isSystemIcon {
                            Image(systemName: iconName)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(LinearGradient(colors: cardGradients, startPoint: .topLeading, endPoint: .bottomTrailing))
                        } else if UIImage(named: iconName) != nil {
                            Image(iconName)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                        } else {
                            Image(systemName: "dumbbell.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(LinearGradient(colors: cardGradients, startPoint: .topLeading, endPoint: .bottomTrailing))
                        }
                    }

                    Spacer()

                    Menu {
                        if let p = extractPreset(), let onEdit = onEdit {
                            Button { onEdit(p) } label: { Label(LocalizedStringKey("Edit"), systemImage: "pencil") }
                        }
                        if let p = extractPreset(), let onDuplicate = onDuplicate {
                            Button { onDuplicate(p) } label: { Label(LocalizedStringKey("Duplicate"), systemImage: "plus.square.on.square") }
                        }
                        if let onDelete = onDelete {
                            Button(role: .destructive) { onDelete(item) } label: { Label(LocalizedStringKey("Delete"), systemImage: "trash") }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.headline)
                            .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.6))
                            .frame(width: 30, height: 30)
                            .background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                            .clipShape(Circle())
                    }
                    .highPriorityGesture(TapGesture().onEnded { })
                }

                Spacer()

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                        .lineLimit(3)
                        .minimumScaleFactor(0.8)
                        .allowsTightening(true)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .lineLimit(2).minimumScaleFactor(0.8).allowsTightening(true)
                        .minimumScaleFactor(0.8)
                }
            }
            .padding(16)
            .frame(width: 160, height: 200)

            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(LinearGradient(colors: cardGradients, startPoint: .topLeading, endPoint: .bottomTrailing).opacity(0.15))

                    GeometryReader { geo in
                        Circle()
                            .fill(cardGradients[0])
                            .blur(radius: 50)
                            .frame(width: geo.size.width)
                            .offset(x: -geo.size.width * 0.2, y: -geo.size.height * 0.2)
                            .opacity(0.3)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            )

            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(
                        LinearGradient(colors: cardGradients, startPoint: .topLeading, endPoint: .bottomTrailing).opacity(colorScheme == .dark ? 0.4 : 0.2),
                        lineWidth: 1
                    )
            )
            .shadow(color: cardGradients[0].opacity(0.15), radius: 15, x: 0, y: 8)
        }
        .buttonStyle(.plain)
    }

    private var title: String {
        switch item {
        case .preset(let p): return p.name
        case .favorite(let w): return w.title
        }
    }

    private var subtitle: LocalizedStringKey {
        switch item {
        case .preset(let p): return LocalizedStringKey("\(p.exercises.count) exercises")
        case .favorite(let w): return LocalizedStringKey("\(w.exercises.count) exercises")
        }
    }

    private var iconName: String {
        switch item {
        case .preset(let p): return p.icon
        case .favorite(let w): return w.icon
        }
    }

    private var isSystemIcon: Bool {
        switch item {
        case .preset(let p): return p.isSystem
        case .favorite: return true
        }
    }

    private var cardGradients: [Color] {
        var hash = 0
        for char in title.utf8 {
            hash = (hash &<< 5) &+ hash &+ Int(char)
        }
        let hashAbs = abs(hash)
        
        let hue1 = Double(hashAbs % 360) / 360.0
        let hue2 = Double((hashAbs + 45) % 360) / 360.0
        
        let c1 = Color(hue: hue1, saturation: 0.8, brightness: colorScheme == .dark ? 0.7 : 0.9)
        let c2 = Color(hue: hue2, saturation: 0.9, brightness: colorScheme == .dark ? 0.4 : 0.8)
        return [c1, c2]
    }

    private func extractPreset() -> WorkoutPreset? {
        if case .preset(let p) = item { return p }
        return nil
    }
}

struct PremiumHubGlassButton: View {
    @Environment(\.colorScheme) private var colorScheme 
    let title: LocalizedStringKey
    var subtitle: LocalizedStringKey? = nil
    let icon: String
    let colorTint: Color
    var isSmall: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            if isSmall {
                VStack(alignment: .leading, spacing: 12) {
                    ZStack {
                        Circle().fill(colorTint.opacity(0.2)).frame(width: 44, height: 44)
                        Image(systemName: icon).font(.title3).foregroundColor(colorTint)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                            .allowsTightening(true)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        if let sub = subtitle {
                            Text(sub)
                                .font(.caption2)
                                .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .gray)
                                .lineLimit(1)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)

                .background(colorScheme == .dark ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.white), in: RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.06), lineWidth: 0.7))
                .shadow(color: colorScheme == .dark ? .black.opacity(0.15) : .black.opacity(0.04), radius: 10, x: 0, y: 6)
            } else {
                HStack(spacing: 16) {
                    ZStack {
                        Circle().fill(colorTint.opacity(0.2)).frame(width: 48, height: 48)
                        Image(systemName: icon).font(.title2).foregroundColor(colorTint)
                    }

                    VStack(alignment: .leading, spacing: 2) {

                        Text(title).font(.headline).fontWeight(.bold).foregroundColor(colorScheme == .dark ? .white : .black)
                        if let sub = subtitle {
                            Text(sub).font(.caption).foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .gray)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundColor(colorScheme == .dark ? .white.opacity(0.5) : .gray.opacity(0.5))
                }
                .padding(16)

                .background(colorScheme == .dark ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.white), in: RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.06), lineWidth: 0.7))
                .shadow(color: colorScheme == .dark ? .black.opacity(0.15) : .black.opacity(0.04), radius: 10, x: 0, y: 6)
            }
        }
        .buttonStyle(.plain)
    }
}

struct StreakMascotPopup: View {
    var streakDays: Int
    @Binding var isShowing: Bool
    @State private var dragOffset: CGSize = .zero
    @State private var isGlowing: Bool = false
    @State private var isFloating: Bool = false
    @Environment(\.colorScheme) private var colorScheme 

    var body: some View {
        ZStack {

            Color.black.opacity(colorScheme == .dark ? 0.6 : 0.15)
                .background(colorScheme == .dark ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(.regularMaterial))
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring()) { isShowing = false }
                }

            VStack(spacing: 5) {
                FierySpeechBubble(text: String(localized: "Keep crushing it!\nYou\'re on fire! 🔥"))
                    .offset(y: 15)
                    .zIndex(1)
                    .rotation3DEffect(.degrees(isGlowing ? 10 : 0), axis: (x: -dragOffset.height, y: dragOffset.width, z: 0.0), perspective: 0.3)
                    .offset(y: isFloating ? -5 : 5)

                ZStack {
                    RoundedRectangle(cornerRadius: 30)
                        .fill(LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 300, height: 300)
                        .overlay(
                            Group {
                                if UIImage(named: "fire_mascot") != nil {
                                    Image("fire_mascot")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 250, height: 250)
                                        .shadow(color: .black.opacity(0.4), radius: 10, y: 10)
                                } else {
                                    Image(systemName: "flame.fill")
                                        .font(.system(size: 150))
                                        .foregroundStyle(.white)
                                }
                            }
                        )
                        .overlay(RoundedRectangle(cornerRadius: 30).stroke(.white.opacity(0.5), lineWidth: 2))

                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(LinearGradient(colors: [.red, .orange], startPoint: .top, endPoint: .bottom))
                            .frame(width: 100, height: 46)
                            .rotationEffect(.degrees(-3))
                            .shadow(color: .black.opacity(0.5), radius: 10)

                        Text("\(streakDays) Days")
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .rotationEffect(.degrees(-3))
                    }
                    .offset(x: -85, y: -94)
                }
                .shadow(color: Color.orange.opacity(isGlowing ? 1.0 : 0.6), radius: isGlowing ? 60 : 30, x: 0, y: isGlowing ? 0 : 15)
                .rotation3DEffect(
                    .degrees(isGlowing ? 25 : (isFloating ? 3 : -3)),
                    axis: isGlowing ? (x: -dragOffset.height, y: dragOffset.width, z: 0.0) : (x: 1, y: 0, z: 0),
                    perspective: 0.3
                )
                .scaleEffect(isGlowing ? 1.05 : 1.0)
                .offset(y: isFloating ? -8 : 8)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.6)) {
                                isGlowing = true
                                dragOffset = CGSize(width: (value.location.x - 160) / 4, height: (value.location.y - 160) / 4)
                            }
                        }
                        .onEnded { _ in
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                                isGlowing = false
                                dragOffset = .zero
                            }
                        }
                )
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    isFloating = true
                }
            }
        }
    }
}
struct FierySpeechBubble: View {
    var text: String
    var body: some View {
        VStack(spacing: 0) {
            Text(text)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing))
                )
                .shadow(color: Color.red.opacity(0.8), radius: 20, x: 0, y: 10)
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.4), lineWidth: 1))

            Path { path in
                path.move(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: 24, y: 0))
                path.addLine(to: CGPoint(x: 12, y: 16))
                path.closeSubpath()
            }
            .fill(Color.red)
            .frame(width: 24, height: 16)
            .offset(x: 20)
        }
    }
}

struct WorkoutHubEmptyStateView: View {
    @Environment(\.colorScheme) private var colorScheme
    let onExplore: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 80, height: 80)
                Image(systemName: "folder.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(Color.orange)
            }
            .padding(.top, 16)

            VStack(spacing: 8) {
                Text(LocalizedStringKey("No Templates Yet"))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(colorScheme == .dark ? .white : .black)

                Text(LocalizedStringKey("Browse Explore Database or create a new program to get started."))
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 40)
            }

            Button(action: onExplore) {
                HStack {
                    Image(systemName: "safari.fill")
                    Text(LocalizedStringKey("Explore Database"))
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(height: 50)
                .frame(maxWidth: .infinity)
                .background(Color.orange)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: Color.orange.opacity(0.3), radius: 10, y: 5)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity)
        .background(colorScheme == .dark ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.white))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }
}

struct LegendaryHubCardView: View {
    let routine: LegendaryRoutine
    @Environment(\.colorScheme) private var colorScheme
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "crown.fill").foregroundColor(.orange).font(.caption)
                    Text(LocalizedStringKey(routine.eraTitle))
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.5)
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.15))
                .cornerRadius(6)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "stopwatch").font(.caption)
                    Text(LocalizedStringKey("\(routine.estimatedMinutes) min"))
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundColor(.white.opacity(0.7))
            }

            Spacer()

            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey(routine.title))
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(LocalizedStringKey(routine.shortVibe))
                    .font(.system(size: 12))
                    .italic()
                    .foregroundColor(.cyan)
                    .lineLimit(1)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(20)
        .frame(width: 280, height: 180)
        .background(
            ZStack {
                LinearGradient(colors: routine.gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                
                // Dark overlay at the bottom for readability
                LinearGradient(colors: [.clear, .black.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                
                // Subtle texture/glow overlay
                RoundedRectangle(cornerRadius: 24)
                    .stroke(LinearGradient(colors: [.white.opacity(0.3), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
            }
        )
        .cornerRadius(24)
        .shadow(color: routine.gradientColors[0].opacity(0.3), radius: 10, x: 0, y: 5)
    }
}
