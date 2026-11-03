internal import SwiftUI
import SwiftData

/// Browse Catalog — Legendary Protocols, Multi-Week Programs & Solo Workouts.
/// Architectural mechanical pressure plates grid adhering strictly to PastelTheme (Strict Dark Mode #0E0F12),
/// featuring corner micro-screws, specular rim bevels, physical spring depression, and tactile haptic feedback.
struct ProgramDiscoveryView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(WorkoutService.self) private var workoutService
    @Environment(DIContainer.self) private var di
    
    @State private var selectedLegendaryRoutine: LegendaryRoutine?
    @State private var showActiveWorkoutAlert = false
    @State private var isProcessing = false
    @State private var selectedFilter: CatalogFilter = .all
    @State private var hasPavedScreen = false
    @State private var selectedProgram: WorkoutProgramDefinition?
    
    private var usingOfflineCatalog: Bool {
        FirestoreProgramService.shared.legendaryRoutines.isEmpty
            || FirestoreProgramService.shared.explorePrograms.isEmpty
    }

    private var legendaryPrograms: [LegendaryRoutine] {
        let routines = FirestoreProgramService.shared.legendaryRoutines
        // Single source of truth — trademark-safe offline samples.
        return routines.isEmpty ? LegendaryFallbackCatalog.routines : routines
    }
    
    private var featuredPrograms: [WorkoutProgramDefinition] {
        let progs = FirestoreProgramService.shared.explorePrograms
        return progs.isEmpty ? MockProgramCatalog.shared.featuredPrograms : progs
    }

    private var filteredFeatured: [WorkoutProgramDefinition] {
        featuredPrograms.filter { program in
            switch selectedFilter {
            case .all: return true
            case .beginner: return program.level == .beginner
            case .intermediate: return program.level == .intermediate
            case .advanced: return program.level == .advanced
            case .buildMuscle: return program.goal == .buildMuscle
            case .getStronger: return program.goal == .getStronger
            case .loseWeight: return program.goal == .loseWeight
            case .fullGym: return program.equipment == .fullGym
            case .dumbbells: return program.equipment == .dumbbells
            case .bodyweight: return program.equipment == .bodyweight
            }
        }
    }

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        ZStack {
            PastelTheme.canvas.ignoresSafeArea()
            AtmosphericGymBackdropView(style: .overview)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    if usingOfflineCatalog {
                        offlineBanner
                    }

                    // 1. Legendary Section (Top, Architectural Pressure Plates)
                    if !legendaryPrograms.isEmpty {
                        legendarySection
                    }
                    
                    // 2. All Catalog Section (Programs & Solo Workouts)
                    if !featuredPrograms.isEmpty {
                        allCatalogSection
                    }
                    
                    Spacer(minLength: 80)
                }
            }
        }
        .navigationTitle(LocalizedStringKey("Browse Catalog"))
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .accessibilityIdentifier("wt.explore.root")
        .sheet(item: $selectedLegendaryRoutine) { routine in
            LegendaryTemplatePreviewSheet(routine: routine) {
                startLegendaryRoutine(routine)
            }
        }
        .navigationDestination(isPresented: Binding(
            get: { selectedProgram != nil },
            set: { if !$0 { selectedProgram = nil } }
        )) {
            if let selectedProgram {
                ProgramDetailView(program: selectedProgram)
            }
        }
        .alert(LocalizedStringKey("Active Workout Exists"), isPresented: $showActiveWorkoutAlert) {
            Button(LocalizedStringKey("OK"), role: .cancel) { }
        } message: {
            Text(LocalizedStringKey("You already have an active workout in progress. Please finish or delete it before starting a new one."))
        }
        .onAppear {
            withAnimation(.spring(response: 0.48, dampingFraction: 0.78)) {
                hasPavedScreen = true
            }
        }
    }

    // MARK: - Offline Banner
    private var offlineBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "icloud.slash")
                .foregroundStyle(PastelTheme.pastelAmber)
            Text("Showing bundled sample programs (generic names only). Connect to refresh the live catalog.")
                .font(.footnote)
                .foregroundStyle(PastelTheme.textSecondary)
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(PastelTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(PastelTheme.cardBorder, lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Legendary Section
    private var legendarySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(PastelTheme.pastelAmber)

                Text(LocalizedStringKey("Legendary Programs"))
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(PastelTheme.textPrimary)

                Spacer()

                Text("\(legendaryPrograms.count)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(PastelTheme.pastelAmber)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2.5)
                    .background(PastelTheme.cardSurfaceSubtle)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(PastelTheme.cardBorder, lineWidth: 1))
            }
            .padding(.horizontal, 16)
            
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(Array(legendaryPrograms.enumerated()), id: \.element.id) { index, routine in
                    LegendaryPressurePlate(
                        routine: routine,
                        isSelected: selectedLegendaryRoutine?.id == routine.id,
                        delay: min(0.3, Double(index) * 0.035),
                        hasPavedScreen: hasPavedScreen
                    ) {
                        HapticManager.shared.impact(.light)
                        selectedLegendaryRoutine = routine
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 16)
    }

    // MARK: - All Catalog Section
    private var allCatalogSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header Telemetry Row
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(LocalizedStringKey("All Catalog"))
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundStyle(PastelTheme.textPrimary)

                    Text(LocalizedStringKey("Explore programs and solo workouts"))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(PastelTheme.textSecondary)
                }

                Spacer()

                Text(String(localized: "\(filteredFeatured.count) available"))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(PastelTheme.pastelSage)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(PastelTheme.cardSurfaceSubtle)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(PastelTheme.cardBorder, lineWidth: 1))
            }
            .padding(.horizontal, 16)
            
            // Filter Pills Bar
            FilterBarView(selectedFilter: $selectedFilter)
            
            let programs = filteredFeatured.filter { !$0.isSingleRoutine }
            let soloWorkouts = filteredFeatured.filter { $0.isSingleRoutine }
            
            // Programs Subsection
            if !programs.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.stack.3d.up.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(PastelTheme.pastelSage)

                        Text(LocalizedStringKey("Programs"))
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                            .foregroundStyle(PastelTheme.textPrimary)

                        Spacer()

                        Text("\(programs.count)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(PastelTheme.pastelSage)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2.5)
                            .background(PastelTheme.cardSurfaceSubtle)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(PastelTheme.cardBorder, lineWidth: 1))
                    }
                    .padding(.horizontal, 16)
                    
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(Array(programs.enumerated()), id: \.element.id) { index, program in
                            programCard(program, index: index)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.top, 4)
            }
            
            // Solo Workouts Subsection
            if !soloWorkouts.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 6) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(PastelTheme.pastelAmber)

                        Text(LocalizedStringKey("Solo Workouts"))
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                            .foregroundStyle(PastelTheme.textPrimary)

                        Spacer()

                        Text("\(soloWorkouts.count)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(PastelTheme.pastelAmber)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2.5)
                            .background(PastelTheme.cardSurfaceSubtle)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(PastelTheme.cardBorder, lineWidth: 1))
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(Array(soloWorkouts.enumerated()), id: \.element.id) { index, program in
                            programCard(program, index: index)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }
    
    private func programCard(_ program: WorkoutProgramDefinition, index: Int) -> some View {
        Button {
            HapticManager.shared.impact(.light)
            selectedProgram = program
        } label: {
            ProgramPressurePlate(
                program: program,
                delay: min(0.3, Double(index) * 0.03),
                hasPavedScreen: hasPavedScreen
            )
        }
        .buttonStyle(.plain)
    }

    private func startLegendaryRoutine(_ routine: LegendaryRoutine) {
        guard !isProcessing else { return }
        isProcessing = true
        
        Task { @MainActor in
            if await workoutService.hasActiveWorkout() {
                showActiveWorkoutAlert = true
                isProcessing = false
                return
            }
            
            let generatedDTO = GeneratedWorkoutDTO(
                title: routine.title,
                aiMessage: routine.loreDescription,
                exercises: routine.exercises
            )
            
            if let id = await workoutService.startGeneratedWorkout(generatedDTO, source: "legendary") {
                di.appState.returnToActiveWorkoutId = id
                di.appState.selectedTab = 2
            }
            selectedLegendaryRoutine = nil
            isProcessing = false
        }
    }
}

// MARK: - Program Pressure Plate
/// Luxury architectural mechanical pressure plate for multi-week programs and solo workouts.
/// Features bevel lighting, corner micro-screws, physical spring depression, and tactile rigid haptic feedback.
struct ProgramPressurePlate: View {
    let program: WorkoutProgramDefinition
    var delay: Double = 0.0
    var hasPavedScreen: Bool = true

    var levelColor: Color {
        switch program.level {
        case .beginner: return PastelTheme.pastelSage
        case .intermediate: return PastelTheme.pastelAmber
        case .advanced: return PastelTheme.pastelPeach
        }
    }

    var body: some View {
        ZStack {
            // 1. Slab Surface Background with Specular Rim Highlight
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(PastelTheme.cardSurface)
                .overlay(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.09),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .center
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                )

            // 2. Corner Micro-Screws (Craftsmanship detail)
            VStack {
                HStack {
                    Circle().fill(PastelTheme.cardBorder.opacity(0.38)).frame(width: 3, height: 3)
                    Spacer()
                    Circle().fill(PastelTheme.cardBorder.opacity(0.38)).frame(width: 3, height: 3)
                }
                Spacer()
                HStack {
                    Circle().fill(PastelTheme.cardBorder.opacity(0.38)).frame(width: 3, height: 3)
                    Spacer()
                    Circle().fill(PastelTheme.cardBorder.opacity(0.38)).frame(width: 3, height: 3)
                }
            }
            .padding(6)

            // 3. Plate Content
            VStack(alignment: .leading, spacing: 8) {
                // Top Row: Level Pill & Equipment Icon
                HStack(spacing: 4) {
                    Text(program.level.rawValue)
                        .font(.system(size: 8.5, weight: .heavy, design: .rounded))
                        .foregroundStyle(levelColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .background(levelColor.opacity(0.14))
                        .clipShape(Capsule())

                    Spacer(minLength: 4)

                    Image(systemName: program.equipment.icon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(PastelTheme.textSecondary)
                }

                Spacer(minLength: 2)

                // Center: Illuminated Emblem Socket
                HStack {
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(PastelTheme.cardSurfaceSubtle)
                            .frame(width: 44, height: 44)
                            .overlay(
                                Circle().stroke(levelColor.opacity(0.35), lineWidth: 1)
                            )

                        Image(systemName: program.equipment.icon)
                            .font(.system(size: 19, weight: .bold))
                            .foregroundStyle(levelColor)
                    }
                    Spacer()
                }

                Spacer(minLength: 2)

                // Bottom: Title & Routine/Exercise Count Badge
                VStack(alignment: .leading, spacing: 3) {
                    Text(LocalizedStringKey(program.title))
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(PastelTheme.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .frame(height: 32, alignment: .leading)

                    HStack(spacing: 4) {
                        if program.isSingleRoutine {
                            let exerciseCount = program.routines.first?.exercises.count ?? 0
                            Image(systemName: "list.bullet")
                                .font(.system(size: 9))
                            Text(String(localized: "\(exerciseCount) exercises"))
                                .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                        } else {
                            Image(systemName: "square.stack.3d.up.fill")
                                .font(.system(size: 9))
                            Text(String(localized: "\(program.routines.count) routines"))
                                .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                        }
                    }
                    .foregroundStyle(PastelTheme.textTertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(PastelTheme.cardSurfaceSubtle)
                    .clipShape(Capsule())
                }
            }
            .padding(12)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 168)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(PastelTheme.cardBorder, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.45), radius: 6, y: 4)
        .offset(y: hasPavedScreen ? 0 : 24)
        .scaleEffect(hasPavedScreen ? 1.0 : 0.88)
        .opacity(hasPavedScreen ? 1.0 : 0.0)
        .animation(.spring(response: 0.42, dampingFraction: 0.76).delay(delay), value: hasPavedScreen)
    }
}

// MARK: - Backward Compatibility Wrappers
struct CompactProgramCardView: View {
    let program: WorkoutProgramDefinition
    
    var body: some View {
        ProgramPressurePlate(program: program)
    }
}

struct LegendaryGridCardView: View {
    let routine: LegendaryRoutine
    
    var body: some View {
        LegendaryPressurePlate(routine: routine, onSelect: {})
    }
}

// MARK: - Upgraded Filter Bar View
struct FilterBarView: View {
    @Binding var selectedFilter: CatalogFilter

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(CatalogFilter.allCases, id: \.self) { filter in
                    let isSelected = selectedFilter == filter
                    Button {
                        HapticManager.playSelection()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.76)) {
                            selectedFilter = filter
                        }
                    } label: {
                        Text(LocalizedStringKey(filter.rawValue))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(isSelected ? PastelTheme.textOnOat : PastelTheme.textSecondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(isSelected ? PastelTheme.pastelOat : PastelTheme.cardSurface)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(isSelected ? PastelTheme.pastelOat : PastelTheme.cardBorder, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }
}
