// MARK: - FILE: WorkoutTracker/Features/Workout/Views/WorkoutHubView.swift

internal import SwiftUI
import SwiftData

// MARK: - Wrapper Type for Universal Carousel
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

// MARK: - Main View
struct WorkoutHubView: View {
    @Environment(DIContainer.self) private var di
    @Environment(\.modelContext) private var context
    @Environment(WorkoutService.self) var workoutService
    @Environment(PresetService.self) var presetService
    
    // 1. Все пользовательские шаблоны (Созданные юзером + Скачанные из Explore)
    @Query(filter: #Predicate<WorkoutPreset> { $0.isSystem == false }, sort: \WorkoutPreset.name)
    private var userPresets: [WorkoutPreset]
    
    @State private var showSmartBuilder = false
    
    // 2. Избранные тренировки (из Истории)
    @Query(filter: #Predicate<Workout> { $0.isFavorite == true }, sort: \Workout.date, order: .reverse)
    private var favoriteWorkouts: [Workout]
    
    // MARK: - Динамическая сортировка по папкам
    
    // Личные тренировки юзера (без папки)
    private var myRoutines: [WorkoutPreset] {
        userPresets.filter { ($0.folderName ?? "").isEmpty }
    }
    
    // Одиночные скачанные тренировки из магазина
    private var savedSingleRoutines: [WorkoutPreset] {
        userPresets.filter { $0.folderName == PresetService.savedRoutinesFolderName }
    }
    
    // Многодневные программы (Группируются по названию программы)
    private var programFolders: [String: [WorkoutPreset]] {
        var dict = [String: [WorkoutPreset]]()
        for p in userPresets where !(p.folderName ?? "").isEmpty && p.folderName != PresetService.savedRoutinesFolderName {
            dict[p.folderName!, default: []].append(p)
        }
        return dict
    }
    
    // MARK: - State & Navigation
    @State private var navigateToActiveWorkout: Workout? = nil
    @State private var navigateToExplore = false
    
    @State private var showPresetEditor = false
    @State private var presetToEdit: WorkoutPreset? = nil
    
    @State private var itemToDelete: CarouselItemType? = nil
    @State private var showDeleteAlert = false
    @State private var showActiveWorkoutAlert = false
    @State private var isProcessing = false
    @State private var selectedPreview: PreviewItem? = nil
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Premium Dark Background
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        // Top Action Rows
                        VStack(spacing: 24) {
                            quickStartButton
                            smartBuilderButton
                            routinesActionRow
                        }
                        .padding(.top, 20)
                        
                        // My Routines (user-created)
                        CarouselSectionView(
                            title: "My Routines",
                            folderName: nil,
                            items: myRoutines.map { .preset($0) },
                            onItemTapped: handleItemStart,
                            onEdit: { presetToEdit = $0; showPresetEditor = true },
                            onDuplicate: duplicatePreset,
                            onDelete: promptDelete
                        )
                        
                        // Saved Single Routines
                        if !savedSingleRoutines.isEmpty {
                            CarouselSectionView(
                                title: "Saved Routines",
                                folderName: PresetService.savedRoutinesFolderName,
                                items: savedSingleRoutines.map { .preset($0) },
                                onItemTapped: handleItemStart,
                                onEdit: { presetToEdit = $0; showPresetEditor = true },
                                onDuplicate: duplicatePreset,
                                onDelete: promptDelete
                            )
                        }
                        
                        // Dynamic Program Carousels
                        ForEach(programFolders.keys.sorted(), id: \.self) { folderName in
                            if let programRoutines = programFolders[folderName] {
                                CarouselSectionView(
                                    title: LocalizedStringKey(folderName),
                                    folderName: folderName,
                                    items: programRoutines.map { .preset($0) },
                                    onItemTapped: handleItemStart,
                                    onEdit: { presetToEdit = $0; showPresetEditor = true },
                                    onDuplicate: duplicatePreset,
                                    onDelete: promptDelete
                                )
                            }
                        }
                        
                        // Favorites
                        if !favoriteWorkouts.isEmpty {
                            CarouselSectionView(
                                title: "Favorites",
                                folderName: nil,
                                items: favoriteWorkouts.map { .favorite($0) },
                                onItemTapped: handleItemStart,
                                onEdit: nil,
                                onDuplicate: nil,
                                onDelete: promptDelete
                            )
                        }
                        
                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationTitle(LocalizedStringKey("Workout"))
            .navigationDestination(item: $navigateToActiveWorkout) { workout in
                WorkoutDetailView(workout: workout, viewModel: di.makeWorkoutDetailViewModel())
            }
            .navigationDestination(isPresented: $navigateToExplore) {
                ExploreRoutinesView()
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
                            aiMessage: "Generated by Smart Builder",
                            exercises: exerciseDTOs.map { dto in
                                let safeSetsList = dto.setsList ?? []
                                return GeneratedExerciseDTO(
                                    name: dto.name,
                                    muscleGroup: dto.muscleGroup,
                                    type: dto.type.rawValue,
                                    sets: safeSetsList.count,
                                    reps: safeSetsList.first?.reps ?? 10,
                                    recommendedWeightKg: safeSetsList.first?.weight,
                                    restSeconds: nil
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
            .alert(LocalizedStringKey("Active Workout Exists"), isPresented: $showActiveWorkoutAlert) {
                Button(LocalizedStringKey("OK"), role: .cancel) { }
            } message: {
                Text(LocalizedStringKey("You already have an active workout in progress. Please finish or delete it before starting a new one."))
            }
            .alert(LocalizedStringKey("Delete Item?"), isPresented: $showDeleteAlert) {
                Button(LocalizedStringKey("Delete"), role: .destructive) {
                    confirmDelete()
                }
                Button(LocalizedStringKey("Cancel"), role: .cancel) { itemToDelete = nil }
            } message: {
                Text(LocalizedStringKey("This action cannot be undone."))
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
        }
    }
    
    // MARK: - Top Actions
    private var quickStartButton: some View {
        Button { startEmptyWorkout() } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.headline).fontWeight(.bold)
                Text(LocalizedStringKey("Start an Empty Workout"))
                    .font(.headline).fontWeight(.bold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .cornerRadius(16)
            .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
        }
        .padding(.horizontal)
        .disabled(isProcessing)
    }
    
    private var smartBuilderButton: some View {
        Button {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            showSmartBuilder = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "wand.and.stars")
                    .font(.headline).fontWeight(.bold)
                Text("Smart Workout Builder")
                    .font(.headline).fontWeight(.bold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .cornerRadius(16)
            .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
        }
        .padding(.horizontal)
        .disabled(isProcessing)
    }
    
    private var routinesActionRow: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(LocalizedStringKey("Routines")).font(.title2).bold()
                Spacer()
            }
            .padding(.horizontal)
            
            HStack(spacing: 12) {
                Button { presetToEdit = nil; showPresetEditor = true } label: {
                    HStack {
                        Image(systemName: "clipboard.fill").foregroundColor(.blue)
                        Text(LocalizedStringKey("New Routine")).font(.subheadline).fontWeight(.semibold).foregroundColor(.primary)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                }
                
                Button { navigateToExplore = true } label: {
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundColor(.purple)
                        Text(LocalizedStringKey("Explore")).font(.subheadline).fontWeight(.semibold).foregroundColor(.primary)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                }
            }
            .padding(.horizontal)
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
                    di.liveActivityManager.startWorkoutActivity(title: preset.name)
                    routeToLatestWorkout()
                }
            case .favorite(let workout):
                if let _ = await workoutService.createWorkout(title: workout.title, presetID: nil, isAIGenerated: false) {
                    di.liveActivityManager.startWorkoutActivity(title: workout.title)
                    
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
    
    // MARK: - Logic
    private func startEmptyWorkout() {
        guard !isProcessing else { return }
        isProcessing = true
        Task { @MainActor in
            if await workoutService.hasActiveWorkout() {
                showActiveWorkoutAlert = true; isProcessing = false; return
            }
            let title = LocalizationHelper.shared.formatWorkoutDateName()
            if let _ = await workoutService.createWorkout(title: title, presetID: nil, isAIGenerated: false) {
                di.liveActivityManager.startWorkoutActivity(title: title)
                var descriptor = FetchDescriptor<Workout>(sortBy: [SortDescriptor(\.date, order: .reverse)]); descriptor.fetchLimit = 1
                if let newWorkout = try? context.fetch(descriptor).first { self.navigateToActiveWorkout = newWorkout }
            }
            isProcessing = false
        }
    }
    
    private func handleItemStart(item: CarouselItemType) {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        switch item {
        case .preset(let preset):
            selectedPreview = .preset(preset)
        case .favorite(let workout):
            selectedPreview = .favorite(workout)
        }
    }
    
    private func routeToLatestWorkout() {
        var descriptor = FetchDescriptor<Workout>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = 1
        if let newWorkout = try? context.fetch(descriptor).first {
            self.navigateToActiveWorkout = newWorkout
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

// MARK: - Carousel Section View

struct CarouselSectionView: View {
    let title: LocalizedStringKey
    let folderName: String? // Used to identify the folder for deletion logic
    let items: [CarouselItemType]
    
    let onItemTapped: (CarouselItemType) -> Void
    let onEdit: ((WorkoutPreset) -> Void)?
    let onDuplicate: ((WorkoutPreset) -> Void)?
    let onDelete: ((CarouselItemType) -> Void)?
    
    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                
                // Header with "See All"
                HStack(alignment: .bottom) {
                    Text(title)
                        .font(.title3).bold()
                        .foregroundColor(.primary)
                    
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
                        Text(LocalizedStringKey("See all"))
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal)
                
                // Horizontal Carousel
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

// MARK: - Premium Carousel Card
struct PremiumCarouselCardView: View {
    @Environment(\.colorScheme) private var colorScheme
    let item: CarouselItemType
    
    let onTap: () -> Void
    let onEdit: ((WorkoutPreset) -> Void)?
    let onDuplicate: ((WorkoutPreset) -> Void)?
    let onDelete: ((CarouselItemType) -> Void)?
    
    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topLeading) {
                // Background Base
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : .white)
                
                // Subtle Accent Glow
                GeometryReader { geo in
                    Circle()
                        .fill(accentColor.opacity(0.15))
                        .blur(radius: 30)
                        .frame(width: geo.size.width * 1.5)
                        .offset(x: -geo.size.width * 0.2, y: -geo.size.height * 0.2)
                }
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                
                VStack(alignment: .leading, spacing: 0) {
                    // Top Row: Icon & Menu
                    HStack(alignment: .top) {
                        // Icon
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 44, height: 44)
                            
                            if isSystemIcon {
                                Image(systemName: iconName)
                                    .font(.title3)
                                    .foregroundColor(accentColor)
                            } else if UIImage(named: iconName) != nil {
                                Image(iconName)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 24, height: 24)
                            } else {
                                Image(systemName: "dumbbell.fill")
                                    .font(.title3)
                                    .foregroundColor(accentColor)
                            }
                        }
                        
                        Spacer()
                        
                        // Action Menu
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
                                .foregroundColor(.gray)
                                .frame(width: 30, height: 30)
                                .background(Color.gray.opacity(0.1))
                                .clipShape(Circle())
                        }
                        .highPriorityGesture(TapGesture().onEnded { }) // Prevent triggering card tap
                    }
                    
                    Spacer()
                    
                    // Bottom Row: Text
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(16)
            }
            .frame(width: 160, height: 200)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(colorScheme == .dark ? 0.1 : 0.4), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.15), radius: 15, x: 0, y: 8)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: Card Data Extraction Helpers
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
        case .favorite: return true // Workouts generally use SF Symbols
        }
    }
    
    private var accentColor: Color {
        switch item {
        case .preset(let p): return p.isSystem ? .purple : .blue
        case .favorite: return .orange
        }
    }
    
    private func extractPreset() -> WorkoutPreset? {
        if case .preset(let p) = item { return p }
        return nil
    }
}

// MARK: - "See All" Grid View
struct PresetListView: View {
    let title: LocalizedStringKey
    let items: [CarouselItemType]
    
    let onItemTapped: (CarouselItemType) -> Void
    let onEdit: ((WorkoutPreset) -> Void)?
    let onDuplicate: ((WorkoutPreset) -> Void)?
    let onDelete: ((CarouselItemType) -> Void)?
    
    let columns = [GridItem(.adaptive(minimum: 160), spacing: 16)]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(items, id: \.id) { item in
                    PremiumCarouselCardView(
                        item: item,
                        onTap: { onItemTapped(item) },
                        onEdit: onEdit,
                        onDuplicate: onDuplicate,
                        onDelete: onDelete
                    )
                }
            }
            .padding()
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
