internal import SwiftUI
import SwiftData

enum LibraryFilter: String, CaseIterable, Identifiable {
    case all
    case programs
    case saved
    case favorites

    var id: String { rawValue }

    /// Catalog keys — never show English `rawValue` as chrome.
    var localizedTitleKey: LocalizedStringKey {
        switch self {
        case .all: return "All"
        case .programs: return "My Templates"
        case .saved: return "Saved Workouts"
        case .favorites: return "Favorites"
        }
    }

    var icon: String {
        switch self {
        case .all: return "square.grid.2x2.fill"
        case .programs: return "rectangle.stack.fill"
        case .saved: return "bookmark.fill"
        case .favorites: return "star.fill"
        }
    }
}

struct MyLibraryView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(DIContainer.self) private var di

    @Query private var userPresets: [WorkoutPreset]
    @Query private var favoriteWorkouts: [Workout]

    var onItemTapped: (CarouselItemType) -> Void
    var onStartNow: ((CarouselItemType) -> Void)? = nil
    var onCreate: (() -> Void)? = nil
    var onEdit: ((WorkoutPreset) -> Void)? = nil
    var onDuplicate: ((WorkoutPreset) -> Void)? = nil
    var onDelete: ((CarouselItemType) -> Void)? = nil
    var onLegendaryTapped: ((LegendaryRoutine) -> Void)? = nil
    var onBrowseCatalog: (() -> Void)? = nil

    init(
        onItemTapped: @escaping (CarouselItemType) -> Void,
        onStartNow: ((CarouselItemType) -> Void)? = nil,
        onCreate: (() -> Void)? = nil,
        onEdit: ((WorkoutPreset) -> Void)? = nil,
        onDuplicate: ((WorkoutPreset) -> Void)? = nil,
        onDelete: ((CarouselItemType) -> Void)? = nil,
        onLegendaryTapped: ((LegendaryRoutine) -> Void)? = nil,
        onBrowseCatalog: (() -> Void)? = nil
    ) {
        self.onItemTapped = onItemTapped
        self.onStartNow = onStartNow
        self.onCreate = onCreate
        self.onEdit = onEdit
        self.onDuplicate = onDuplicate
        self.onDelete = onDelete
        self.onLegendaryTapped = onLegendaryTapped
        self.onBrowseCatalog = onBrowseCatalog

        var presets = FetchDescriptor<WorkoutPreset>(
            predicate: #Predicate<WorkoutPreset> { $0.isSystem == false },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        presets.fetchLimit = 400
        _userPresets = Query(presets)

        var favorites = FetchDescriptor<Workout>(
            predicate: #Predicate<Workout> { $0.isFavorite == true },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        favorites.fetchLimit = 200
        _favoriteWorkouts = Query(favorites)
    }

    @State private var selectedFilter: LibraryFilter = .all
    @State private var searchText: String = ""
    @State private var showCatalogSheet = false

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private func matchesSearch(_ title: String, exercises: [Exercise]) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        if title.localizedCaseInsensitiveContains(query) { return true }
        return exercises.contains {
            $0.name.localizedCaseInsensitiveContains(query)
                || LocalizationHelper.shared.translateName($0.name).localizedCaseInsensitiveContains(query)
        }
    }

    private var myRoutines: [WorkoutPreset] {
        userPresets.filter {
            ($0.folderName ?? "").isEmpty
                && $0.name != "Today's Plan"
                && matchesSearch($0.name, exercises: $0.exercises)
        }
    }

    private var savedSingleRoutines: [WorkoutPreset] {
        userPresets.filter {
            $0.folderName == PresetService.savedRoutinesFolderName
                && matchesSearch($0.name, exercises: $0.exercises)
        }
    }

    private var programFolders: [String: [WorkoutPreset]] {
        var dict = [String: [WorkoutPreset]]()
        let favStr = String(localized: "Favorites")
        for p in userPresets where !(p.folderName ?? "").isEmpty
            && p.folderName != PresetService.savedRoutinesFolderName
            && p.folderName != "HiddenFolder"
            && p.folderName != "Favorites"
            && p.folderName != favStr
            && matchesSearch(p.name, exercises: p.exercises) {
            dict[p.folderName!, default: []].append(p)
        }
        return dict
    }

    private var filteredFavorites: [Workout] {
        favoriteWorkouts.filter { matchesSearch($0.title, exercises: $0.exercises) }
    }

    private var totalSavedCount: Int {
        let validPresets = userPresets.filter {
            $0.name != "Today's Plan" && $0.folderName != "HiddenFolder"
        }
        return validPresets.count + favoriteWorkouts.count
    }

    private var isLibraryEmpty: Bool {
        myRoutines.isEmpty
            && savedSingleRoutines.isEmpty
            && programFolders.isEmpty
            && filteredFavorites.isEmpty
    }

    private func shouldShowSection(_ section: LibraryFilter) -> Bool {
        selectedFilter == .all || selectedFilter == section
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            PastelTheme.canvas.ignoresSafeArea()
            AtmosphericGymBackdropView(style: .overview)

            VStack(spacing: 0) {
                libraryHeader
                searchBar
                filterTabBar

                ScrollView(showsIndicators: false) {
                    if isLibraryEmpty {
                        emptyStateView
                    } else {
                        VStack(spacing: 24) {
                            if shouldShowSection(.programs) {
                                if !myRoutines.isEmpty {
                                    LibraryGridSection(
                                        title: String(localized: "Custom Templates"),
                                        items: myRoutines.map { .preset($0) },
                                        columns: columns,
                                        onItemTapped: handleItemTapped,
                                        onStartNow: handleStartNow,
                                        onEdit: onEdit,
                                        onDuplicate: onDuplicate,
                                        onDelete: onDelete
                                    )
                                }

                                ForEach(programFolders.keys.sorted(), id: \.self) { folderName in
                                    if let programRoutines = programFolders[folderName] {
                                        LibraryGridSection(
                                            title: folderName,
                                            items: programRoutines.map { .preset($0) },
                                            columns: columns,
                                            onItemTapped: handleItemTapped,
                                            onStartNow: handleStartNow,
                                            onEdit: onEdit,
                                            onDuplicate: onDuplicate,
                                            onDelete: onDelete
                                        )
                                    }
                                }
                            }

                            if shouldShowSection(.saved) && !savedSingleRoutines.isEmpty {
                                LibraryGridSection(
                                    title: String(localized: "Saved Workouts"),
                                    items: savedSingleRoutines.map { .preset($0) },
                                    columns: columns,
                                    onItemTapped: handleItemTapped,
                                    onStartNow: handleStartNow,
                                    onEdit: onEdit,
                                    onDuplicate: onDuplicate,
                                    onDelete: onDelete
                                )
                            }

                            if shouldShowSection(.favorites) && !filteredFavorites.isEmpty {
                                LibraryGridSection(
                                    title: String(localized: "Favorites"),
                                    items: filteredFavorites.map { .favorite($0) },
                                    columns: columns,
                                    onItemTapped: handleItemTapped,
                                    onStartNow: handleStartNow,
                                    onEdit: nil,
                                    onDuplicate: nil,
                                    onDelete: onDelete
                                )
                            }

                            Spacer(minLength: 96)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                    }
                }
            }

            if !isLibraryEmpty {
                browseCatalogFAB
            }
        }
        .navigationBarHidden(true)
        .accessibilityIdentifier("wt.templates.root")
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showCatalogSheet) {
            NavigationStack {
                ProgramDiscoveryView()
            }
        }
        .onChange(of: di.appState.returnToActiveWorkoutId) { _, newValue in
            if newValue != nil && showCatalogSheet {
                showCatalogSheet = false
            }
        }
        .onChange(of: di.appState.selectedTab) { _, newTab in
            if newTab == 2 && showCatalogSheet {
                showCatalogSheet = false
            }
        }
    }

    // MARK: - Header
    private var libraryHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            Button {
                HapticManager.shared.impact(.light)
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(PastelTheme.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(PastelTheme.cardSurface)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(PastelTheme.cardBorder, lineWidth: 1))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text("My Templates")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(PastelTheme.textPrimary)

                Text("\(totalSavedCount) saved")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PastelTheme.pastelOat)
            }

            Spacer()

            if let onCreate {
                Button {
                    HapticManager.shared.impact(.medium)
                    onCreate()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                        Text("New")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(PastelTheme.textOnOat)
                    .padding(.horizontal, 14)
                    .frame(height: PastelTheme.ButtonMetrics.pillHeight)
                    .background(PastelTheme.pastelOat)
                    .clipShape(Capsule())
                }
                .buttonStyle(PressScaleButtonStyle())
                .accessibilityIdentifier("wt.templates.new")
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 10)
    }

    // MARK: - Search Bar
    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(PastelTheme.textTertiary)

            TextField("Search templates or exercises...", text: $searchText)
                .font(.subheadline)
                .foregroundStyle(PastelTheme.textPrimary)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    ChromeDismissMark()
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(PastelTheme.cardSurfaceSubtle)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(PastelTheme.cardBorder, lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Filter Bar
    private var filterTabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(LibraryFilter.allCases) { filter in
                    let isSelected = selectedFilter == filter
                    Button {
                        HapticManager.shared.impact(.soft)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            selectedFilter = filter
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: filter.icon)
                                .font(.system(size: 11, weight: .bold))
                            Text(filter.localizedTitleKey)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                        }
                        .padding(.horizontal, 14)
                        .frame(height: PastelTheme.ButtonMetrics.pillHeight)
                        .background(isSelected ? PastelTheme.pastelOat : PastelTheme.cardSurfaceSubtle)
                        .foregroundStyle(isSelected ? PastelTheme.textOnOat : PastelTheme.textSecondary)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(isSelected ? PastelTheme.pastelOat : PastelTheme.cardBorder, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        let isFiltering = !searchText.isEmpty || selectedFilter != .all
        return VStack(spacing: 18) {
            Spacer().frame(height: 44)

            ZStack {
                Circle()
                    .fill(PastelTheme.pastelOat.opacity(0.12))
                    .frame(width: 84, height: 84)
                    .overlay(Circle().stroke(PastelTheme.cardBorder, lineWidth: 1))

                Image(systemName: isFiltering ? "magnifyingglass" : "rectangle.stack.badge.plus")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(PastelTheme.pastelOat)
            }

            VStack(spacing: 6) {
                Text(isFiltering ? String(localized: "No templates match") : String(localized: "No templates yet"))
                    .font(.title3.bold())
                    .foregroundStyle(PastelTheme.textPrimary)

                Text(
                    isFiltering
                        ? String(localized: "Try clearing search or picking another filter.")
                        : String(localized: "Create your own split or explore ready-made programs.")
                )
                .font(.subheadline)
                .foregroundStyle(PastelTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
            }

            VStack(spacing: 10) {
                if isFiltering {
                    Button {
                        searchText = ""
                        selectedFilter = .all
                    } label: {
                        Text("Clear filters")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(PastelTheme.textOnOat)
                            .frame(maxWidth: .infinity)
                            .frame(height: PastelTheme.ButtonMetrics.heroHeight)
                            .background(PastelTheme.pastelOat)
                            .clipShape(RoundedRectangle(cornerRadius: PastelTheme.ButtonMetrics.heroRadius, style: .continuous))
                    }
                    .buttonStyle(.plain)
                } else {
                    if let onCreate {
                        Button {
                            HapticManager.shared.impact(.medium)
                            onCreate()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "plus.circle.fill")
                                Text("Create template")
                            }
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(PastelTheme.textOnOat)
                            .frame(maxWidth: .infinity)
                            .frame(height: PastelTheme.ButtonMetrics.heroHeight)
                            .background(PastelTheme.pastelOat)
                            .clipShape(RoundedRectangle(cornerRadius: PastelTheme.ButtonMetrics.heroRadius, style: .continuous))
                        }
                        .buttonStyle(PressScaleButtonStyle())
                    }

                    Button {
                        openBrowseCatalog()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                            Text("Browse Catalog")
                        }
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(PastelTheme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: PastelTheme.ButtonMetrics.heroHeight)
                        .background(PastelTheme.cardSurface)
                        .clipShape(RoundedRectangle(cornerRadius: PastelTheme.ButtonMetrics.heroRadius, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: PastelTheme.ButtonMetrics.heroRadius, style: .continuous)
                                .stroke(PastelTheme.cardBorder, lineWidth: 1)
                        )
                    }
                    .buttonStyle(PressScaleButtonStyle())
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 4)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Bottom Catalog CTA
    private var browseCatalogFAB: some View {
        Button {
            openBrowseCatalog()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .bold))
                Text("Browse Catalog")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
            }
            .foregroundStyle(PastelTheme.textOnOat)
            .padding(.vertical, 13)
            .padding(.horizontal, 24)
            .background(PastelTheme.pastelOat)
            .clipShape(Capsule())
            .shadow(color: PastelTheme.pastelOat.opacity(0.28), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(PressScaleButtonStyle())
        .padding(.bottom, 18)
    }

    private func openBrowseCatalog() {
        HapticManager.shared.impact(.medium)
        if let onBrowseCatalog {
            onBrowseCatalog()
        } else {
            showCatalogSheet = true
        }
    }

    // MARK: - Routing Helpers
    private func handleItemTapped(_ item: CarouselItemType) {
        if case .preset(let preset) = item,
           let legendary = FirestoreProgramService.shared.legendaryRoutines.first(where: { $0.title == preset.name }) {
            onLegendaryTapped?(legendary)
        } else {
            onItemTapped(item)
        }
    }

    private func handleStartNow(_ item: CarouselItemType) {
        if let onStartNow {
            onStartNow(item)
        } else {
            handleItemTapped(item)
        }
    }
}

// MARK: - Grid Section
fileprivate struct LibraryGridSection: View {
    let title: String
    let items: [CarouselItemType]
    let columns: [GridItem]

    let onItemTapped: (CarouselItemType) -> Void
    let onStartNow: (CarouselItemType) -> Void
    let onEdit: ((WorkoutPreset) -> Void)?
    let onDuplicate: ((WorkoutPreset) -> Void)?
    let onDelete: ((CarouselItemType) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(LocalizedStringKey(title))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(PastelTheme.textPrimary)

                Spacer()

                Text("\(items.count)")
                    .font(.system(size: 12, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(PastelTheme.textTertiary)
            }

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(items, id: \.id) { item in
                    LibraryGridCard(
                        item: item,
                        onTap: { onItemTapped(item) },
                        onStart: { onStartNow(item) },
                        onEdit: onEdit,
                        onDuplicate: onDuplicate,
                        onDelete: onDelete
                    )
                }
            }
        }
    }
}

// MARK: - Luxury Pastel Template Card
fileprivate struct LibraryGridCard: View {
    let item: CarouselItemType
    let onTap: () -> Void
    let onStart: () -> Void
    let onEdit: ((WorkoutPreset) -> Void)?
    let onDuplicate: ((WorkoutPreset) -> Void)?
    let onDelete: ((CarouselItemType) -> Void)?

    private var title: String {
        switch item {
        case .preset(let p): return p.name
        case .favorite(let w): return w.title.isEmpty ? String(localized: "Workout") : w.title
        }
    }

    private var exercises: [Exercise] {
        switch item {
        case .preset(let p): return p.exercises
        case .favorite(let w): return w.exercises
        }
    }

    private var exercisePreviewText: String {
        let names = exercises.prefix(2).map { LocalizationHelper.shared.translateName($0.name) }
        return names.joined(separator: " · ")
    }

    private var iconName: String {
        switch item {
        case .preset(let p): return p.icon.isEmpty ? "dumbbell.fill" : p.icon
        case .favorite: return "star.fill"
        }
    }

    private var isFavorite: Bool {
        if case .favorite = item { return true }
        return false
    }

    private var accentColor: Color {
        if isFavorite { return PastelTheme.pastelAmber }
        if matchingLegendaryRoutine != nil { return PastelTheme.pastelAmber }
        return PastelTheme.pastelOat
    }

    private var extractPreset: WorkoutPreset? {
        if case .preset(let p) = item { return p }
        return nil
    }

    private var matchingLegendaryRoutine: LegendaryRoutine? {
        FirestoreProgramService.shared.legendaryRoutines.first { $0.title == title }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                TemplateIconBadge(
                    iconName: isFavorite ? "star.fill" : iconName,
                    tint: accentColor,
                    boxSize: 38,
                    glyphSize: 15,
                    assetSize: 21,
                    cornerRadius: 11
                )

                Spacer()

                Menu {
                    Button {
                        onStart()
                    } label: {
                        Label(LocalizedStringKey("Start now"), systemImage: "play.fill")
                    }

                    if let p = extractPreset, let onEdit {
                        Button { onEdit(p) } label: {
                            Label(LocalizedStringKey("Edit"), systemImage: "pencil")
                        }
                    }

                    if let p = extractPreset, let onDuplicate {
                        Button { onDuplicate(p) } label: {
                            Label(LocalizedStringKey("Duplicate"), systemImage: "plus.square.on.square")
                        }
                    }

                    if let onDelete {
                        Button(role: .destructive) { onDelete(item) } label: {
                            Label(LocalizedStringKey("Delete"), systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(PastelTheme.textSecondary)
                        .frame(width: 30, height: 30)
                        .background(PastelTheme.cardSurfaceSubtle)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(PastelTheme.cardBorder, lineWidth: 1))
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(PastelTheme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text("\(exercises.count) exercises")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(PastelTheme.pastelSage)

                if !exercisePreviewText.isEmpty {
                    Text(exercisePreviewText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(PastelTheme.textTertiary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            Button {
                HapticManager.shared.impact(.medium)
                onStart()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 10, weight: .bold))
                    Text("Start")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }
                .foregroundStyle(PastelTheme.textOnOat)
                .frame(maxWidth: .infinity)
                .frame(height: PastelTheme.ButtonMetrics.inCardHeight)
                .background(PastelTheme.pastelSage)
                .clipShape(Capsule())
            }
            .buttonStyle(PressScaleButtonStyle())
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 176, alignment: .leading)
        .background(PastelTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(PastelTheme.cardBorder, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onTapGesture {
            HapticManager.shared.impact(.light)
            onTap()
        }
    }
}
