

internal import SwiftUI

enum ExploreTabType: Int {
    case programs = 0
    case singles = 1
}

@Observable
@MainActor
final class ExploreViewModel {
    var allPrograms: [WorkoutProgramDefinition] = []
        var searchDebouncer = SearchDebouncer()

    var selectedTab: ExploreTabType = .programs
    var selectedLevel: ProgramLevel? = nil
    var selectedGoal: ProgramGoal? = nil
    var selectedEquipment: ProgramEquipment? = nil
    var usingOfflineSamples = false

    var filteredPrograms: [WorkoutProgramDefinition] {
        allPrograms.filter { program in

            let matchesTab = (selectedTab == .singles) ? program.isSingleRoutine : !program.isSingleRoutine

            let matchesSearch = searchDebouncer.debouncedText.isEmpty || program.title.localizedCaseInsensitiveContains(searchDebouncer.debouncedText)

            let matchesLevel = selectedLevel == nil || program.level == selectedLevel
            let matchesGoal = selectedGoal == nil || program.goal == selectedGoal
            let matchesEquip = selectedEquipment == nil || program.equipment == selectedEquipment

            return matchesTab && matchesSearch && matchesLevel && matchesGoal && matchesEquip
        }
    }

    var activeFilterCount: Int {
        var count = 0
        if selectedLevel != nil { count += 1 }
        if selectedGoal != nil { count += 1 }
        if selectedEquipment != nil { count += 1 }
        return count
    }

    func clearFilters() {
        selectedLevel = nil
        selectedGoal = nil
        selectedEquipment = nil
    }
}

struct ExploreRoutinesView: View {
    @State private var viewModel = ExploreViewModel()
    @State private var showFilters = false
    @State private var showAIBuilder = false

    @Environment(ThemeManager.self) private var themeManager
    @Environment(DIContainer.self) private var di

    var body: some View {
        ZStack {

            themeManager.current.background
                .ignoresSafeArea()

            VStack(spacing: 0) {

                VStack(spacing: 12) {

                    Picker(LocalizedStringKey("Workout Type"), selection: $viewModel.selectedTab) {
                        Text(LocalizedStringKey("Programs")).tag(ExploreTabType.programs)
                        Text(LocalizedStringKey("Single programs")).tag(ExploreTabType.singles)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.top, 8)

                    HStack(spacing: 12) {
                        DebouncedSearchBar(debouncer: viewModel.searchDebouncer)
                            .padding()
                            .background(themeManager.current.surface)
                            .cornerRadius(16)
                            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)

                        Button {
                            HapticManager.shared.impact(.light)
                            showFilters = true
                        } label: {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "line.3.horizontal.decrease.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(themeManager.current.primaryAccent)

                                if viewModel.activeFilterCount > 0 {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 14, height: 14)
                                        .overlay(
                                            Text("\(viewModel.activeFilterCount)")
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundColor(.white)
                                        )
                                        .offset(x: 2, y: -2)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
                .background(themeManager.current.background)
                .zIndex(1)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {

                        NavigationLink(destination: LegendaryRoutinesView()) {
                            HallOfFameBanner()
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                        .padding(.top, 16)

                        Button {
                            HapticManager.shared.impact(.medium)
                            showAIBuilder = true
                        } label: {
                            PremiumAIBannerView()
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)

                        if viewModel.usingOfflineSamples {
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
                            .padding(.horizontal)
                        }

                        Text(viewModel.selectedTab == .programs ? "All Programs" : "Single Routines")
                            .font(.headline)
                            .foregroundColor(themeManager.current.secondaryText)
                            .padding(.horizontal)
                            .padding(.top, 10)

                        if viewModel.filteredPrograms.isEmpty {
                            EmptyStateView(
                                icon: viewModel.allPrograms.isEmpty ? "wifi.exclamationmark" : "magnifyingglass",
                                title: viewModel.allPrograms.isEmpty
                                    ? "Programs unavailable"
                                    : "No routines found",
                                message: viewModel.allPrograms.isEmpty
                                    ? "Could not load programs from the server. Check your connection and try again."
                                    : "Try adjusting your search or clearing your filters.",
                                iconColor: PastelTheme.pastelLavender,
                                actionTitle: viewModel.allPrograms.isEmpty
                                    ? "Retry"
                                    : "Clear Filters"
                            ) {
                                if viewModel.allPrograms.isEmpty {
                                    Task { await reloadExploreCatalog() }
                                } else {
                                    viewModel.searchDebouncer.inputText = ""
                                    viewModel.selectedLevel = nil
                                    viewModel.selectedGoal = nil
                                    viewModel.selectedEquipment = nil
                                }
                            }
                            .padding(.top, 40)
                        } else {
                            LazyVStack(spacing: 20) {
                                ForEach(viewModel.filteredPrograms) { program in
                                    NavigationLink(destination: ProgramDetailView(program: program)) {
                                        PremiumProgramCardView(program: program)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .navigationTitle("Explore")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showFilters) {
            ExploreFiltersSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $showAIBuilder) {
            AIProgramBuilderSheet(aiLogicService: di.aiLogicService)
        }
        .task { await reloadExploreCatalog() }
    }

    private func reloadExploreCatalog() async {
        if FirestoreProgramService.shared.explorePrograms.isEmpty {
            await FirestoreProgramService.shared.fetchAllPrograms()
        }
        let remote = FirestoreProgramService.shared.explorePrograms
        viewModel.usingOfflineSamples = ExploreCatalogSource.isOffline(remoteCount: remote.count)
        viewModel.allPrograms = ExploreCatalogSource.programs(
            remote: remote,
            offline: MockProgramCatalog.shared.featuredPrograms
        )
    }
}

struct HallOfFameBanner: View {
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.yellow.opacity(0.2))
                    .frame(width: 48, height: 48)

                Image(systemName: "star.fill")
                    .font(.title2)
                    .foregroundColor(.yellow)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Hall of Fame")
                    .font(.headline)
                    .fontWeight(.heavy)
                    .foregroundColor(.white)

                Text("Train with legendary workout protocols.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.body.bold())
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color(hex: "0F2027"), Color(hex: "203A43")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 15, x: 0, y: 8)
    }
}

struct PremiumAIBannerView: View {
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 48, height: 48)

                Image(systemName: "wand.and.stars")
                    .font(.title2)
                    .foregroundColor(themeManager.current.background)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("AI Program Architect")
                    .font(.headline)
                    .fontWeight(.heavy)
                    .foregroundColor(themeManager.current.background)

                Text("Design your perfect weekly split.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.body.bold())
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(20)
        .background(themeManager.current.premiumGradient)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: themeManager.current.deepPremiumAccent.opacity(0.4), radius: 15, x: 0, y: 8)
    }
}
