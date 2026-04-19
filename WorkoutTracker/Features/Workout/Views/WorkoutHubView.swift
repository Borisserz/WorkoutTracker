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
    @Environment(DashboardViewModel.self) var dashboardViewModel // Для получения Стрика
    @Environment(ThemeManager.self) private var themeManager
    
    // 1. Все пользовательские шаблоны (Созданные юзером + Скачанные из Explore)
    @Query(filter: #Predicate<WorkoutPreset> { $0.isSystem == false }, sort: \WorkoutPreset.name)
    private var userPresets: [WorkoutPreset]
    
    // 2. Избранные тренировки (из Истории)
    @Query(filter: #Predicate<Workout> { $0.isFavorite == true }, sort: \Workout.date, order: .reverse)
    private var favoriteWorkouts: [Workout]
    
    // MARK: - Динамическая сортировка по папкам
    private var myRoutines: [WorkoutPreset] {
            userPresets.filter { ($0.folderName ?? "").isEmpty && $0.name != "План на сегодня" }
        }
    
    private var savedSingleRoutines: [WorkoutPreset] {
        userPresets.filter { $0.folderName == PresetService.savedRoutinesFolderName }
    }
    
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
    
    @State private var showSmartBuilder = false
    @State private var showPresetEditor = false
    @State private var presetToEdit: WorkoutPreset? = nil
    @State private var showStreakPopup = false // Новый стейт для 3D Маскота
    
    @State private var itemToDelete: CarouselItemType? = nil
    @State private var showDeleteAlert = false
    @State private var showActiveWorkoutAlert = false
    @State private var isProcessing = false
    @State private var selectedPreview: PreviewItem? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                // Premium Dark Background
                themeManager.current.background.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 32) {
                        
                        // 1. ЗАГОЛОВОК И СТРИК (Интегрировано с дизайном)
                        headerSection
                        
                        // 2. КНОПКИ ДЕЙСТВИЙ (Dribbble Style)
                        topActionsSection
                        
                        // 3. КАРУСЕЛИ СОХРАНЕННЫХ ТРЕНИРОВОК
                        carouselsSection
                        
                        Spacer(minLength: 120)
                    }
                    .padding(.top, 20)
                }
                
                // 4. МАСКОТ-ПОПАП (Поверх всего контента)
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
            .navigationBarHidden(true) // Скрываем стандартный бар
            
            // Навигация и Модалки
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
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        HStack {
            Text(LocalizedStringKey("Тренировка"))
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            
            Spacer()
            
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { showStreakPopup = true }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill").foregroundStyle(Color.orange)
                    Text("\(dashboardViewModel.streakCount) \(String(localized: "дня"))")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 1))
                .shadow(color: Color.orange.opacity(0.4), radius: 10, x: 0, y: 4)
            }.buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
    }
    
    private var topActionsSection: some View {
        VStack(alignment: .leading, spacing: 32) {
            VStack(spacing: 16) {
                PremiumHubGlassButton(
                    title: "Начать пустую тренировку",
                    subtitle: "Свободный режим",
                    icon: "play.circle.fill",
                    colorTint: .blue
                ) { startEmptyWorkout() }
                
                PremiumHubGlassButton(
                    title: "Умный конструктор",
                    subtitle: "Сгенерировано под вас",
                    icon: "wand.and.stars",
                    colorTint: .purple
                ) {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    showSmartBuilder = true
                }
            }
            .padding(.horizontal, 20)
            
            VStack(alignment: .leading, spacing: 16) {
                Text(LocalizedStringKey("Программы"))
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                
                HStack(spacing: 16) {
                    PremiumHubGlassButton(
                        title: "Новая\nпрограмма",
                        icon: "plus.app.fill",
                        colorTint: .green,
                        isSmall: true
                    ) {
                        presetToEdit = nil
                        showPresetEditor = true
                    }
                    
                    PremiumHubGlassButton(
                        title: "Исследовать\nбазу",
                        icon: "safari.fill",
                        colorTint: .orange,
                        isSmall: true
                    ) {
                        navigateToExplore = true
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    private var carouselsSection: some View {
            VStack(alignment: .leading, spacing: 32) {
                
                // ВСТАВЛЯЕМ БЛОК ПЛАНА НА СЕГОДНЯ
                if let dailyPlan = userPresets.first(where: { $0.name == "План на сегодня" }), !dailyPlan.exercises.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("План на сегодня")
                            .font(.title3).bold()
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                        
                        // Широкая премиальная карточка
                        PremiumRoutineCard(
                            preset: dailyPlan,
                            onStart: { startWorkoutFromPreview(item: .preset(dailyPlan)) },
                            onEdit: { presetToEdit = dailyPlan; showPresetEditor = true },
                            onDuplicate: nil, // План на сегодня не дублируем
                            onDelete: {
                                Task { @MainActor in
                                    await presetService.deletePreset(dailyPlan)
                                }
                            }
                        )
                        .padding(.horizontal, 20)
                    }
                }
                // --- КОНЕЦ ВСТАВКИ ---

                CarouselSectionView(
                title: "Мои программы", folderName: nil, items: myRoutines.map { .preset($0) },
                onItemTapped: handleItemStart, onEdit: { presetToEdit = $0; showPresetEditor = true },
                onDuplicate: duplicatePreset, onDelete: promptDelete
            )
            
            if !savedSingleRoutines.isEmpty {
                CarouselSectionView(
                    title: "Сохраненные тренировки", folderName: PresetService.savedRoutinesFolderName, items: savedSingleRoutines.map { .preset($0) },
                    onItemTapped: handleItemStart, onEdit: { presetToEdit = $0; showPresetEditor = true },
                    onDuplicate: duplicatePreset, onDelete: promptDelete
                )
            }
            
            ForEach(programFolders.keys.sorted(), id: \.self) { folderName in
                if let programRoutines = programFolders[folderName] {
                    CarouselSectionView(
                        title: LocalizedStringKey(folderName), folderName: folderName, items: programRoutines.map { .preset($0) },
                        onItemTapped: handleItemStart, onEdit: { presetToEdit = $0; showPresetEditor = true },
                        onDuplicate: duplicatePreset, onDelete: promptDelete
                    )
                }
            }
            
            if !favoriteWorkouts.isEmpty {
                CarouselSectionView(
                    title: "Избранное", folderName: nil, items: favoriteWorkouts.map { .favorite($0) },
                    onItemTapped: handleItemStart, onEdit: nil, onDuplicate: nil, onDelete: promptDelete
                )
            }
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
    
    // ИСПРАВЛЕНО: Преобразование типов для Preview
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
    
    private func routeToLatestWorkout() {
        var descriptor = FetchDescriptor<Workout>(sortBy: [SortDescriptor(\.date, order: .reverse)]); descriptor.fetchLimit = 1
        if let newWorkout = try? context.fetch(descriptor).first { self.navigateToActiveWorkout = newWorkout }
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

// MARK: - ВОССТАНОВЛЕННЫЕ КОМПОНЕНТЫ КАРУСЕЛЕЙ (ОНИ БЫЛИ ПОТЕРЯНЫ)

struct CarouselSectionView: View {
    let title: LocalizedStringKey
    let folderName: String? // Used to identify the folder for deletion logic
    let items: [CarouselItemType]
    
    let onItemTapped: (CarouselItemType) -> Void
    let onEdit: ((WorkoutPreset) -> Void)?
    let onDuplicate: ((WorkoutPreset) -> Void)?
    let onDelete: ((CarouselItemType) -> Void)?
    
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                
                // Header with "See All"
                HStack(alignment: .bottom) {
                    Text(title)
                        .font(.title3).bold()
                        .foregroundColor(.white)
                    
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
                        Text(LocalizedStringKey("Смотреть все"))
                            .font(.subheadline)
                            .foregroundColor(themeManager.current.primaryAccent)
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
            ZStack(alignment: .topLeading) {
                // Background Base
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(UIColor.secondarySystemGroupedBackground))
                
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
                                .foregroundColor(.white.opacity(0.8))
                                .frame(width: 30, height: 30)
                                .background(Color.white.opacity(0.1))
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
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                }
                .padding(16)
            }
            .frame(width: 160, height: 200)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
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
        case .preset(let p): return LocalizedStringKey("\(p.exercises.count) упражнений")
        case .favorite(let w): return LocalizedStringKey("\(w.exercises.count) упражнений")
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

// MARK: - Premium Glass Button (Dribbble Style)
struct PremiumHubGlassButton: View {
    let title: LocalizedStringKey
    var subtitle: LocalizedStringKey? = nil
    let icon: String
    let colorTint: Color
    var isSmall: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            if isSmall {
                // Вертикальная маленькая кнопка
                VStack(alignment: .leading, spacing: 12) {
                    ZStack {
                        Circle().fill(colorTint.opacity(0.2)).frame(width: 44, height: 44)
                        Image(systemName: icon).font(.title3).foregroundColor(colorTint)
                    }
                    Text(title)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(LinearGradient(colors: [colorTint.opacity(0.5), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
                .shadow(color: colorTint.opacity(0.15), radius: 15, x: 0, y: 8)
            } else {
                // Горизонтальная большая кнопка
                HStack(spacing: 16) {
                    ZStack {
                        Circle().fill(colorTint.opacity(0.2)).frame(width: 48, height: 48)
                        Image(systemName: icon).font(.title2).foregroundColor(colorTint)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).font(.headline).fontWeight(.bold).foregroundColor(.white)
                        if let sub = subtitle {
                            Text(sub).font(.caption).foregroundColor(.white.opacity(0.7))
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundColor(.white.opacity(0.5))
                }
                .padding(16)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(LinearGradient(colors: [colorTint.opacity(0.5), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
                .shadow(color: colorTint.opacity(0.15), radius: 15, x: 0, y: 8)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 3D Маскот и Пузырь
struct StreakMascotPopup: View {
    var streakDays: Int
    @Binding var isShowing: Bool
    @State private var dragOffset: CGSize = .zero
    @State private var isGlowing: Bool = false
    @State private var isFloating: Bool = false
    
    var body: some View {
        ZStack {
            // Размытый темный фон
            Color.black.opacity(0.6)
                .background(.ultraThinMaterial)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring()) { isShowing = false }
                }
            
            VStack(spacing: 5) {
                // Пузырь с текстом
                FierySpeechBubble(text: String(localized: "Так держать!\nТы в огне! 🔥"))
                    .offset(y: 15)
                    .zIndex(1)
                    .rotation3DEffect(.degrees(isGlowing ? 10 : 0), axis: (x: -dragOffset.height, y: dragOffset.width, z: 0.0), perspective: 0.3)
                    .offset(y: isFloating ? -5 : 5)
                
                // Карточка Маскота
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
                    
                    // Плашка со стриком
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(LinearGradient(colors: [.red, .orange], startPoint: .top, endPoint: .bottom))
                            .frame(width: 100, height: 46)
                            .rotationEffect(.degrees(-3))
                            .shadow(color: .black.opacity(0.5), radius: 10)
                        
                        Text("\(streakDays) ДНЯ")
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
                .font(.system(size: 18, weight: .heavy, design: .rounded))
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
