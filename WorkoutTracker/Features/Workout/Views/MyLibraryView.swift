internal import SwiftUI
import SwiftData

enum LibraryFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case programs = "Programs"
    case saved = "Saved Workouts"
    case favorites = "Favorites"
    
    var id: String { self.rawValue }
    
    var icon: String {
        switch self {
        case .all: return "square.grid.2x2.fill"
        case .programs: return "folder.fill"
        case .saved: return "bookmark.fill"
        case .favorites: return "star.fill"
        }
    }
}

struct MyLibraryView: View {
    @Environment(\.modelContext) private var context
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    
    @Query(filter: #Predicate<WorkoutPreset> { $0.isSystem == false }, sort: \WorkoutPreset.createdAt, order: .reverse)
    private var userPresets: [WorkoutPreset]
    
    @Query(filter: #Predicate<Workout> { $0.isFavorite == true }, sort: \Workout.date, order: .reverse)
    private var favoriteWorkouts: [Workout]
    
    var onItemTapped: (CarouselItemType) -> Void
    var onEdit: ((WorkoutPreset) -> Void)?
    var onDuplicate: ((WorkoutPreset) -> Void)?
    var onDelete: ((CarouselItemType) -> Void)?
    var onLegendaryTapped: ((LegendaryRoutine) -> Void)?
    
    @State private var selectedFilter: LibraryFilter = .all
    @State private var appearAnimation = false
    
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    private var myRoutines: [WorkoutPreset] {
        userPresets.filter { ($0.folderName ?? "").isEmpty && $0.name != "Today's Plan" }
    }
    
    private var savedSingleRoutines: [WorkoutPreset] {
        userPresets.filter { $0.folderName == PresetService.savedRoutinesFolderName }
    }
    
    private var programFolders: [String: [WorkoutPreset]] {
        var dict = [String: [WorkoutPreset]]()
        let favStr = String(localized: "Favorites")
        for p in userPresets where !(p.folderName ?? "").isEmpty && p.folderName != PresetService.savedRoutinesFolderName && p.folderName != "HiddenFolder" && p.folderName != "Favorites" && p.folderName != favStr { 
            dict[p.folderName!, default: []].append(p)
        }
        return dict
    }

    var body: some View {
        ZStack {
            // Premium Adaptive Background
            if colorScheme == .dark {
                themeManager.current.background.ignoresSafeArea()
                
                GeometryReader { geo in
                    Circle()
                        .fill(Color.purple.opacity(0.15))
                        .blur(radius: 80)
                        .frame(width: geo.size.width)
                        .offset(x: -geo.size.width * 0.3, y: -geo.size.height * 0.1)
                        .scaleEffect(appearAnimation ? 1.1 : 0.9)
                        .animation(.easeInOut(duration: 4).repeatForever(autoreverses: true), value: appearAnimation)
                    
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .blur(radius: 80)
                        .frame(width: geo.size.width * 1.2)
                        .offset(x: geo.size.width * 0.3, y: geo.size.height * 0.5)
                        .scaleEffect(appearAnimation ? 0.9 : 1.1)
                        .animation(.easeInOut(duration: 5).repeatForever(autoreverses: true).delay(1), value: appearAnimation)
                }
                .ignoresSafeArea()
            } else {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
            }
            
            VStack(spacing: 0) {
                // Header & Stats
                libraryHeader
                
                // Custom Filter Tab Bar
                filterTabBar
                
                // Content ScrollView
                ScrollView(showsIndicators: false) {
                    if isLibraryEmpty {
                        emptyStateView
                    } else {
                        VStack(spacing: 32) {
                            if shouldShowSection(.programs) {
                                // Render standalone routines
                                if !myRoutines.isEmpty {
                                    LibraryGridSection(
                                        title: "My Routines",
                                        items: myRoutines.map { .preset($0) },
                                        columns: columns,
                                        onItemTapped: handleItemTapped,
                                        onEdit: onEdit,
                                        onDuplicate: onDuplicate,
                                        onDelete: onDelete
                                    )
                                }
                                
                                // Render folders
                                ForEach(programFolders.keys.sorted(), id: \.self) { folderName in
                                    if let programRoutines = programFolders[folderName] {
                                        LibraryGridSection(
                                            title: folderName,
                                            items: programRoutines.map { .preset($0) },
                                            columns: columns,
                                            onItemTapped: handleItemTapped,
                                            onEdit: onEdit,
                                            onDuplicate: onDuplicate,
                                            onDelete: onDelete
                                        )
                                    }
                                }
                            }
                            
                            if shouldShowSection(.saved) && !savedSingleRoutines.isEmpty {
                                LibraryGridSection(
                                    title: "Saved Workouts",
                                    items: savedSingleRoutines.map { .preset($0) },
                                    columns: columns,
                                    onItemTapped: handleItemTapped,
                                    onEdit: onEdit,
                                    onDuplicate: onDuplicate,
                                    onDelete: onDelete
                                )
                            }
                            
                            if shouldShowSection(.favorites) && !favoriteWorkouts.isEmpty {
                                LibraryGridSection(
                                    title: "Favorites",
                                    items: favoriteWorkouts.map { .favorite($0) },
                                    columns: columns,
                                    onItemTapped: handleItemTapped,
                                    onEdit: nil,
                                    onDuplicate: nil,
                                    onDelete: onDelete
                                )
                            }
                            
                            Spacer(minLength: 100) // Space for FAB
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    }
                }
            }
            
            // Floating Action Button
            VStack {
                Spacer()
                NavigationLink(destination: ProgramDiscoveryView()) {
                    HStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 18, weight: .bold))
                        Text("Browse Catalog")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 32)
                    .background(
                        LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .clipShape(Capsule())
                    .shadow(color: .blue.opacity(0.4), radius: 15, x: 0, y: 8)
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                }
                .padding(.bottom, 24)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            appearAnimation = true
        }
    }
    
    private func handleItemTapped(_ item: CarouselItemType) {
        if case .preset(let preset) = item,
           let legendary = FirestoreProgramService.shared.legendaryRoutines.first(where: { $0.title == preset.name }) {
            onLegendaryTapped?(legendary)
        } else {
            onItemTapped(item)
        }
    }
    
    private var isLibraryEmpty: Bool {
        myRoutines.isEmpty && savedSingleRoutines.isEmpty && programFolders.isEmpty && favoriteWorkouts.isEmpty
    }
    
    private func shouldShowSection(_ section: LibraryFilter) -> Bool {
        selectedFilter == .all || selectedFilter == section
    }
    
    private var libraryHeader: some View {
        HStack(alignment: .top, spacing: 16) {
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                    .padding(12)
                    .background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                    .clipShape(Circle())
            }
            .padding(.top, 4)

            VStack(alignment: .leading, spacing: 6) {
                Text("My Library")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                
                let totalItems = userPresets.count + favoriteWorkouts.count
                Text("\(totalItems) Items Saved")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(themeManager.current.primaryAccent)
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }
    
    private var filterTabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(LibraryFilter.allCases) { filter in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedFilter = filter
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: filter.icon)
                                .font(.system(size: 12, weight: .bold))
                            Text(LocalizedStringKey(filter.rawValue))
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            ZStack {
                                if selectedFilter == filter {
                                    themeManager.current.primaryAccent
                                } else {
                                    colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05)
                                }
                            }
                        )
                        .foregroundColor(selectedFilter == filter ? .white : (colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.7)))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 80)
            
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.purple.opacity(0.15), .blue.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
            }
            
            VStack(spacing: 8) {
                Text(LocalizedStringKey("Your Arsenal is Empty"))
                    .font(.title2).bold()
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                
                Text(LocalizedStringKey("Discover world-class programs or save your favorite workouts here."))
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            Spacer()
        }
    }
}

fileprivate struct LibraryGridSection: View {
    let title: String
    let items: [CarouselItemType]
    let columns: [GridItem]
    
    let onItemTapped: (CarouselItemType) -> Void
    let onEdit: ((WorkoutPreset) -> Void)?
    let onDuplicate: ((WorkoutPreset) -> Void)?
    let onDelete: ((CarouselItemType) -> Void)?
    
    @Environment(\.colorScheme) private var colorScheme
    @Environment(ThemeManager.self) private var themeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(LocalizedStringKey(title))
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(colorScheme == .dark ? .white : .black)
            
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(items, id: \.id) { item in
                    LibraryGridCard(
                        item: item,
                        onTap: { onItemTapped(item) },
                        onEdit: onEdit,
                        onDuplicate: onDuplicate,
                        onDelete: onDelete
                    )
                }
            }
        }
    }
}

fileprivate struct LibraryGridCard: View {
    let item: CarouselItemType
    let onTap: () -> Void
    let onEdit: ((WorkoutPreset) -> Void)?
    let onDuplicate: ((WorkoutPreset) -> Void)?
    let onDelete: ((CarouselItemType) -> Void)?
    
    @Environment(\.colorScheme) private var colorScheme
    @Environment(ThemeManager.self) private var themeManager
    
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
        case .preset(let p): return p.icon.isEmpty ? "dumbbell.fill" : p.icon
        case .favorite(let w): return w.icon.isEmpty ? "star.fill" : w.icon
        }
    }
    
    private var isSystemIcon: Bool {
        switch item {
        case .preset(let p): return p.isSystem
        case .favorite: return true
        }
    }
    
    private var gradientColors: [Color] {
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
    
    private var extractPreset: WorkoutPreset? {
        if case .preset(let p) = item { return p }
        return nil
    }
    
    private var matchingLegendaryRoutine: LegendaryRoutine? {
        FirestoreProgramService.shared.legendaryRoutines.first { $0.title == title }
    }
    
    var body: some View {
        Button(action: onTap) {
            if let routine = matchingLegendaryRoutine {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top) {
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
                        
                        // Action Menu
                        Menu {
                            if let p = extractPreset, let onEdit = onEdit {
                                Button { onEdit(p) } label: { Label(LocalizedStringKey("Edit"), systemImage: "pencil") }
                            }
                            if let p = extractPreset, let onDuplicate = onDuplicate {
                                Button { onDuplicate(p) } label: { Label(LocalizedStringKey("Duplicate"), systemImage: "plus.square.on.square") }
                            }
                            if let onDelete = onDelete {
                                Button(role: .destructive) { onDelete(item) } label: { Label(LocalizedStringKey("Delete"), systemImage: "trash") }
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white.opacity(0.9))
                                .frame(width: 32, height: 32)
                                .background(Color.black.opacity(0.2))
                                .clipShape(Circle())
                        }
                        .highPriorityGesture(TapGesture().onEnded { })
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
                .frame(maxWidth: .infinity, alignment: .leading)
                .aspectRatio(0.85, contentMode: .fit)
                .background(
                    ZStack {
                        LinearGradient(colors: routine.gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                        LinearGradient(colors: [.clear, .black.opacity(0.8)], startPoint: .center, endPoint: .bottom)
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(LinearGradient(colors: [.white.opacity(0.3), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: routine.gradientColors.first?.opacity(0.3) ?? .black.opacity(0.1), radius: 10, x: 0, y: 5)
                
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top) {
                        // Icon Box
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing).opacity(0.2))
                                .frame(width: 40, height: 40)
                            
                            if isSystemIcon {
                                Image(systemName: iconName)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                            } else if UIImage(named: iconName) != nil {
                                Image(iconName)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 22, height: 22)
                            } else {
                                Image(systemName: "dumbbell.fill")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                            }
                        }
                        
                        Spacer()
                        
                        // Action Menu
                        Menu {
                            if let p = extractPreset, let onEdit = onEdit {
                                Button { onEdit(p) } label: { Label(LocalizedStringKey("Edit"), systemImage: "pencil") }
                            }
                            if let p = extractPreset, let onDuplicate = onDuplicate {
                                Button { onDuplicate(p) } label: { Label(LocalizedStringKey("Duplicate"), systemImage: "plus.square.on.square") }
                            }
                            if let onDelete = onDelete {
                                Button(role: .destructive) { onDelete(item) } label: { Label(LocalizedStringKey("Delete"), systemImage: "trash") }
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.4))
                                .frame(width: 32, height: 32)
                                .background(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
                                .clipShape(Circle())
                        }
                        .highPriorityGesture(TapGesture().onEnded { })
                    }
                    
                    Spacer()
                    
                    // Text Info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        
                        Text(subtitle)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.gray)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .aspectRatio(0.85, contentMode: .fit)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(colorScheme == .dark ? Color.white.opacity(0.03) : Color.white)
                        
                        if colorScheme == .dark {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(.ultraThinMaterial)
                                .opacity(0.5)
                        }
                        
                        GeometryReader { geo in
                            Circle()
                                .fill(gradientColors[0].opacity(0.15))
                                .blur(radius: 40)
                                .frame(width: geo.size.width)
                                .offset(x: -geo.size.width * 0.2, y: -geo.size.height * 0.2)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(
                            LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing).opacity(colorScheme == .dark ? 0.3 : 0.15),
                            lineWidth: 1
                        )
                )
                .shadow(color: gradientColors[0].opacity(colorScheme == .dark ? 0.1 : 0.05), radius: 10, x: 0, y: 5)
            }
        }
        .buttonStyle(.plain)
    }
}
