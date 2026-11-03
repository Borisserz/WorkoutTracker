internal import SwiftUI
import SwiftData

/// Hall of Fame — Legendary Routines Showcase
/// Architectural mechanical pressure plates grid styled after the awards & trophies in ProgressView.
/// Features high-precision dossier header HUD, era filter pills with tactile haptics,
/// 2-column spring cascade pressure plates, and zero neon/living flame slop.
struct LegendaryRoutinesView: View {
    @Environment(DIContainer.self) private var di
    @Environment(WorkoutService.self) private var workoutService
    @Environment(\.dismiss) private var dismiss

    @State private var routines: [LegendaryRoutine] = []
    @State private var selectedFilter: String = "All"
    @State private var selectedRoutineForPreview: LegendaryRoutine? = nil
    @State private var hasPavedScreen: Bool = false
    @State private var isStartingWorkout: Bool = false
    @State private var showActiveWorkoutAlert: Bool = false
    /// True when Firestore was empty and we fell back to `LegendaryFallbackCatalog`.
    @State private var usingSampleCatalog: Bool = false

    private var availableEras: [String] {
        var eras = ["All"]
        let rawEras = routines.map { $0.eraTitle }
        for era in rawEras {
            let trimmed = era.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty && !eras.contains(trimmed) {
                eras.append(trimmed)
            }
        }
        return eras
    }

    private var filteredRoutines: [LegendaryRoutine] {
        if selectedFilter == "All" {
            return routines
        }
        return routines.filter { routine in
            routine.eraTitle.localizedCaseInsensitiveContains(selectedFilter)
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
                VStack(alignment: .leading, spacing: 18) {
                    if usingSampleCatalog {
                        sampleCatalogBanner
                    }

                    // 1. Header Telemetry Card
                    headerTelemetryCard

                    // 2. Filter Pills Row
                    if availableEras.count > 1 {
                        eraFilterPills
                    }

                    // 3. Staggered 2-Column Mechanical Pressure Plates Grid
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(Array(filteredRoutines.enumerated()), id: \.element.id) { index, routine in
                            LegendaryPressurePlate(
                                routine: routine,
                                isSelected: selectedRoutineForPreview?.id == routine.id,
                                delay: min(0.35, Double(index) * 0.03),
                                hasPavedScreen: hasPavedScreen
                            ) {
                                HapticManager.shared.impact(.light)
                                selectedRoutineForPreview = routine
                            }
                        }
                    }
                    .padding(.horizontal, 16)

                    Spacer(minLength: 60)
                }
                .padding(.top, 14)
            }

            if isStartingWorkout {
                ZStack {
                    Color.black.opacity(0.45).ignoresSafeArea()
                    ProgressView().tint(PastelTheme.pastelOat).scaleEffect(1.4)
                }
            }
        }
        .navigationTitle("Hall of Fame")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            if FirestoreProgramService.shared.legendaryRoutines.isEmpty {
                await FirestoreProgramService.shared.fetchAllPrograms()
            }
            let remote = FirestoreProgramService.shared.legendaryRoutines
            let offline = remote.isEmpty
            self.usingSampleCatalog = offline
            self.routines = offline ? LegendaryFallbackCatalog.routines : remote
            withAnimation(.spring(response: 0.48, dampingFraction: 0.78)) {
                hasPavedScreen = true
            }
        }
        .sheet(item: $selectedRoutineForPreview) { routine in
            LegendaryTemplatePreviewSheet(routine: routine) {
                startRoutine(routine)
            }
        }
        .alert(LocalizedStringKey("Active Workout Exists"), isPresented: $showActiveWorkoutAlert) {
            Button(LocalizedStringKey("OK"), role: .cancel) { }
        } message: {
            Text(LocalizedStringKey("You already have an active workout in progress. Please finish or delete it before starting a new one."))
        }
    }

    // MARK: - Header Telemetry Card
    private var headerTelemetryCard: some View {
        HStack(spacing: 16) {
            // Crown / Trophy Seal Socket
            ZStack {
                Circle()
                    .fill(PastelTheme.cardSurfaceSubtle)
                    .frame(width: 54, height: 54)
                    .overlay(Circle().stroke(PastelTheme.pastelAmber.opacity(0.35), lineWidth: 1.5))

                Image(systemName: "crown.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(PastelTheme.pastelAmber)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Hall of Fame")
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(PastelTheme.textPrimary)

                Text(
                    usingSampleCatalog
                        ? String(localized: "Sample sessions inspired by classic training styles")
                        : String(localized: "Train like the legends of every era")
                )
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(PastelTheme.textSecondary)

                Text(
                    usingSampleCatalog
                        ? String(localized: "\(routines.count) bundled sample protocols")
                        : String(localized: "\(routines.count) master protocols archived")
                )
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(PastelTheme.pastelAmber)
            }

            Spacer()
        }
        .padding(14)
        .background(PastelTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(PastelTheme.cardBorder, lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }

    private var sampleCatalogBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "icloud.slash")
                .foregroundStyle(PastelTheme.pastelAmber)
            Text("Showing bundled sample programs (generic names only). Connect to refresh the live catalog.")
                .font(.footnote)
                .foregroundStyle(PastelTheme.textSecondary)
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(PastelTheme.cardSurfaceSubtle)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(PastelTheme.pastelAmber.opacity(0.35), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .accessibilityIdentifier("wt.halloffame.sampleBanner")
    }

    // MARK: - Era Filter Pills
    private var eraFilterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(availableEras, id: \.self) { era in
                    let isSelected = selectedFilter == era
                    Button {
                        HapticManager.playSelection()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.76)) {
                            selectedFilter = era
                        }
                    } label: {
                        Text(era)
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

    // MARK: - Workout Execution
    private func startRoutine(_ routine: LegendaryRoutine) {
        guard !isStartingWorkout else { return }
        isStartingWorkout = true

        Task { @MainActor in
            if await workoutService.hasActiveWorkout() {
                showActiveWorkoutAlert = true
                isStartingWorkout = false
                return
            }

            let generatedDTO = GeneratedWorkoutDTO(
                title: routine.title,
                aiMessage: "Entering \(routine.eraTitle). \(routine.loreDescription)",
                exercises: routine.exercises
            )

            if let id = await workoutService.startGeneratedWorkout(generatedDTO, source: "legendary") {
                di.appState.returnToActiveWorkoutId = id
                di.appState.selectedTab = 2
                isStartingWorkout = false
                dismiss()
            } else {
                isStartingWorkout = false
            }
        }
    }
}

// MARK: - Backward-Compatible Views
struct LegendaryCardView: View {
    let routine: LegendaryRoutine
    let onStart: () -> Void

    var body: some View {
        LegendaryPressurePlate(routine: routine, onSelect: onStart)
    }
}

struct MorphingBackgroundView: View {
    var colors: [Color] = []

    var body: some View {
        PastelTheme.canvas.ignoresSafeArea()
    }
}
