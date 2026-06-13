internal import SwiftUI
import SwiftData

struct ProgramDiscoveryView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(WorkoutService.self) private var workoutService
    
    @State private var selectedLegendaryRoutine: LegendaryRoutine?
    @State private var showActiveWorkoutAlert = false
    @State private var isProcessing = false
    @State private var selectedFilter: CatalogFilter = .all
    
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
    
    private var featuredPrograms: [WorkoutProgramDefinition] {
        let progs = FirestoreProgramService.shared.explorePrograms
        if progs.isEmpty {
            return MockProgramCatalog.shared.featuredPrograms
        }
        return progs
    }
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 32) {
                // Legendary Section (Top, Wide Cards)
                if !legendaryPrograms.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(LocalizedStringKey("Legendary Programs"))
                            .font(.title2).bold()
                        let legendColumns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 2)
                        
                        LazyVGrid(columns: legendColumns, spacing: 16) {
                            ForEach(legendaryPrograms) { routine in
                                Button {
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    selectedLegendaryRoutine = routine
                                } label: {
                                    LegendaryGridCardView(routine: routine)
                                }
                                .buttonStyle(PremiumScaleButtonStyle())
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.top, 24)
                }
                
                // All Catalog Section
                if !featuredPrograms.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(LocalizedStringKey("All Catalog"))
                            .font(.title2).bold()
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                            .padding(.horizontal, 20)
                        
                        FilterBarView(selectedFilter: $selectedFilter)
                            .padding(.bottom, 8)
                        
                        let filteredFeatured = featuredPrograms.filter { program in
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
                        
                        let programs = filteredFeatured.filter { !$0.isSingleRoutine }
                        let soloWorkouts = filteredFeatured.filter { $0.isSingleRoutine }
                        let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)
                        
                        if !programs.isEmpty {
                            Text(LocalizedStringKey("Programs"))
                                .font(.title3).bold()
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 20)
                            
                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(programs) { program in
                                    NavigationLink(destination: ProgramDetailView(program: program)) {
                                        CompactProgramCardView(program: program)
                                    }
                                    .buttonStyle(PremiumScaleButtonStyle())
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        if !soloWorkouts.isEmpty {
                            Text(LocalizedStringKey("Solo Workouts"))
                                .font(.title3).bold()
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 20)
                                .padding(.top, 16)
                            
                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(soloWorkouts) { program in
                                    NavigationLink(destination: ProgramDetailView(program: program)) {
                                        CompactProgramCardView(program: program)
                                    }
                                    .buttonStyle(PremiumScaleButtonStyle())
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                }
                
                Spacer(minLength: 80)
            }
        }
        .navigationTitle(LocalizedStringKey("Browse Catalog"))
        .navigationBarTitleDisplayMode(.large)
        .background(colorScheme == .dark ? themeManager.current.background : Color(UIColor.systemGroupedBackground))
        .sheet(item: $selectedLegendaryRoutine) { routine in
            LegendaryTemplatePreviewSheet(routine: routine) {
                startLegendaryRoutine(routine)
            }
        }
        .alert(LocalizedStringKey("Active Workout Exists"), isPresented: $showActiveWorkoutAlert) {
            Button(LocalizedStringKey("OK"), role: .cancel) { }
        } message: { Text(LocalizedStringKey("You already have an active workout in progress. Please finish or delete it before starting a new one.")) }
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
            
            await workoutService.startGeneratedWorkout(generatedDTO)
            selectedLegendaryRoutine = nil
            isProcessing = false
        }
    }
}

// A highly compact card suitable for 4 columns
struct CompactProgramCardView: View {
    let program: WorkoutProgramDefinition
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: program.gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ).opacity(0.15)
                    )
                    .aspectRatio(1, contentMode: .fill)
                
                Image(systemName: program.equipment.icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: program.gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            
            Text(LocalizedStringKey(program.title))
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(colorScheme == .dark ? .white : .black)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.8)
        }
    }
}

// A compact square card for Legendary Programs in a 2-column grid
struct LegendaryGridCardView: View {
    let routine: LegendaryRoutine
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "crown.fill").foregroundColor(.orange).font(.system(size: 10))
                    Text(LocalizedStringKey(routine.eraTitle))
                        .font(.system(size: 8, weight: .bold))
                        .tracking(1.0)
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.15))
                .cornerRadius(4)
                
                Spacer()
            }
            
            Spacer()
            
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(routine.title))
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                HStack(spacing: 4) {
                    Image(systemName: "stopwatch").font(.system(size: 10))
                    Text(LocalizedStringKey("\(routine.estimatedMinutes) min"))
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundColor(.white.opacity(0.7))
                .padding(.top, 4)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fill)
        .background(
            ZStack {
                LinearGradient(colors: routine.gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                LinearGradient(colors: [.clear, .black.opacity(0.8)], startPoint: .center, endPoint: .bottom)
                RoundedRectangle(cornerRadius: 16)
                    .stroke(LinearGradient(colors: [.white.opacity(0.3), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
            }
        )
        .cornerRadius(16)
        .shadow(color: routine.gradientColors[0].opacity(0.3), radius: 8, x: 0, y: 4)
    }
}

struct FilterBarView: View {
    @Binding var selectedFilter: CatalogFilter
    @Environment(\.colorScheme) private var colorScheme
    @Environment(ThemeManager.self) private var themeManager
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(CatalogFilter.allCases, id: \.self) { filter in
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedFilter = filter
                        }
                    }) {
                        Text(LocalizedStringKey(filter.rawValue))
                            .font(.system(size: 14, weight: .semibold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(selectedFilter == filter ? themeManager.current.primaryAccent : (colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05)))
                            )
                            .foregroundColor(selectedFilter == filter ? .white : (colorScheme == .dark ? .white : .black))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
    }
}
