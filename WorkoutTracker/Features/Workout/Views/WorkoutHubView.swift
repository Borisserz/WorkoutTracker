// ============================================================
// FILE: WorkoutTracker/Views/Workout/WorkoutHubView.swift
// ============================================================

internal import SwiftUI
import SwiftData
internal import UniformTypeIdentifiers

struct WorkoutHubView: View {
    @Environment(DIContainer.self) private var di
    @Environment(\.modelContext) private var context
    @Environment(WorkoutService.self) var workoutService
    @Environment(PresetService.self) var presetService
    
    // Пользовательские шаблоны
    @Query(filter: #Predicate<WorkoutPreset> { $0.isSystem == false }, sort: \WorkoutPreset.name)
    private var myPresets: [WorkoutPreset]
    
    // Системные/Сохраненные программы
    @Query(filter: #Predicate<WorkoutPreset> { $0.isSystem == true }, sort: \WorkoutPreset.name)
    private var systemPresets: [WorkoutPreset]
    
    // Управление папками (Храним имена папок в строке через разделитель)
    @AppStorage("customPresetFolders") private var customFoldersString: String = ""
    @State private var showNewFolderAlert = false
    @State private var newFolderName = ""
    @State private var expandedFolders: [String: Bool] = [:] // Состояние развертывания папок
    
    // ✅ ИСПРАВЛЕНИЕ: Сделано Read-Only для защиты от 'self is immutable'
    var customFolders: [String] {
        customFoldersString.isEmpty ? [] : customFoldersString.components(separatedBy: "|")
    }
    
    @State private var navigateToActiveWorkout: Workout? = nil
    @State private var navigateToExplore = false
    
    @State private var showPresetEditor = false
    @State private var presetToEdit: WorkoutPreset? = nil
    @State private var presetToDelete: WorkoutPreset? = nil
    @State private var showDeleteAlert = false
    
    @State private var showActiveWorkoutAlert = false
    @State private var isProcessing = false
    
    // Состояния сворачивания системных списков
    @State private var isMyRoutinesExpanded: Bool = true
    @State private var isSystemRoutinesExpanded: Bool = false
    
    private let columns = [GridItem(.flexible(), spacing: 16)]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        quickStartButton
                        routinesActionRow
                        
                        // Списки программ (с поддержкой папок и Drag & Drop)
                        VStack(spacing: 20) {
                            foldersAndMyRoutinesSection
                            systemRoutinesSection
                        }
                    }
                    .padding(.vertical, 20)
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        newFolderName = ""
                        showNewFolderAlert = true
                    } label: {
                        Image(systemName: "folder.badge.plus")
                            .font(.body)
                    }
                }
            }
            .alert(LocalizedStringKey("New Folder"), isPresented: $showNewFolderAlert) {
                TextField("Folder Name", text: $newFolderName)
                Button("Create") {
                    let name = newFolderName.trimmingCharacters(in: .whitespaces)
                    if !name.isEmpty && !customFolders.contains(name) {
                        var folders = customFolders
                        folders.append(name)
                        // ✅ ИСПРАВЛЕНИЕ: Обновляем напрямую @AppStorage переменную
                        customFoldersString = folders.joined(separator: "|")
                        expandedFolders[name] = true // Сразу открываем новую папку
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Enter a name for your new routine group.")
            }
            .alert(LocalizedStringKey("Active Workout Exists"), isPresented: $showActiveWorkoutAlert) {
                Button(LocalizedStringKey("OK"), role: .cancel) { }
            } message: {
                Text(LocalizedStringKey("You already have an active workout in progress. Please finish or delete it before starting a new one."))
            }
            .alert(LocalizedStringKey("Delete Template?"), isPresented: $showDeleteAlert) {
                Button(LocalizedStringKey("Delete"), role: .destructive) {
                    if let p = presetToDelete {
                        Task { await presetService.deletePreset(p); presetToDelete = nil }
                    }
                }
                Button(LocalizedStringKey("Cancel"), role: .cancel) { presetToDelete = nil }
            } message: {
                if let p = presetToDelete {
                    Text(String(localized: "Are you sure you want to delete '\(p.name)'? This action cannot be undone."))
                }
            }
            .onChange(of: di.appState.returnToActiveWorkoutId) { _, newId in
                            if let id = newId {
                                // Ищем тренировку в кэше по ID и делаем Push
                                let desc = FetchDescriptor<Workout>(predicate: #Predicate { $0.endTime == nil })
                                if let active = try? context.fetch(desc).first(where: { $0.persistentModelID == id }) {
                                    self.navigateToActiveWorkout = active
                                }
                                // Сбрасываем триггер
                                di.appState.returnToActiveWorkoutId = nil
                            }
                        }
                    } // <- Закрывающая скобка NavigationStack
                }
      
    
    // MARK: - Sections
    
    private var quickStartButton: some View {
        Button { startWorkout(presetID: nil) } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus").font(.headline).fontWeight(.semibold)
                Text(LocalizedStringKey("Start an Empty Workout")).font(.headline).fontWeight(.semibold)
            }
            .foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 14)
            .background(Color.blue).cornerRadius(12)
        }
        .padding(.horizontal).disabled(isProcessing)
    }
    
    private var routinesActionRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(LocalizedStringKey("Routines")).font(.title2).bold()
                Spacer()
                Button {
                    presetToEdit = nil
                    showPresetEditor = true
                } label: { Image(systemName: "plus.square").font(.title2).foregroundColor(.primary) }
            }
            .padding(.horizontal)
            
            HStack(spacing: 12) {
                Button { presetToEdit = nil; showPresetEditor = true } label: {
                    HStack { Image(systemName: "clipboard.fill").foregroundColor(.primary); Text(LocalizedStringKey("New Routine")).font(.subheadline).fontWeight(.medium).foregroundColor(.primary) }
                    .frame(maxWidth: .infinity).padding(.vertical, 14).background(Color(UIColor.systemBackground)).cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                }
                
                Button { navigateToExplore = true } label: {
                    HStack { Image(systemName: "magnifyingglass").foregroundColor(.primary); Text(LocalizedStringKey("Explore")).font(.subheadline).fontWeight(.medium).foregroundColor(.primary) }
                    .frame(maxWidth: .infinity).padding(.vertical, 14).background(Color(UIColor.systemBackground)).cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Folders & My Routines
    
    private var foldersAndMyRoutinesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            // 1. Некатегоризированные (Корневые) тренировки
            let uncategorized = myPresets.filter { $0.folderName == nil || $0.folderName!.isEmpty }
            
            VStack(spacing: 8) {
                folderDropHeader(
                    title: "My Routines",
                    count: uncategorized.count,
                    isExpanded: $isMyRoutinesExpanded,
                    icon: "tray.full.fill",
                    targetFolder: nil
                )
                
                if isMyRoutinesExpanded {
                    if uncategorized.isEmpty && customFolders.isEmpty {
                        emptyRoutinesState
                    } else {
                        renderPresetsGrid(uncategorized)
                    }
                }
            }
            
            // 2. Кастомные папки
            ForEach(customFolders, id: \.self) { folder in
                let folderPresets = myPresets.filter { $0.folderName == folder }
                let isExp = Binding(
                    get: { expandedFolders[folder] ?? false },
                    set: { expandedFolders[folder] = $0 }
                )
                
                VStack(spacing: 8) {
                    folderDropHeader(
                        title: folder,
                        count: folderPresets.count,
                        isExpanded: isExp,
                        icon: "folder.fill",
                        targetFolder: folder
                    )
                    .contextMenu {
                        Button(role: .destructive) { deleteFolder(folder) } label: {
                            Label(LocalizedStringKey("Delete Folder"), systemImage: "trash")
                        }
                    }
                    
                    if isExp.wrappedValue {
                        if folderPresets.isEmpty {
                            Text(LocalizedStringKey("Drag routines here"))
                                .font(.caption).foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, minHeight: 60)
                                .background(Color.gray.opacity(0.05))
                                .cornerRadius(12)
                                .padding(.horizontal)
                                // Пустая зона тоже принимает Drop
                                .onDrop(of: [.text], delegate: RoutineDropDelegate(folderName: folder, presets: myPresets, onMove: moveRoutine))
                        } else {
                            renderPresetsGrid(folderPresets)
                        }
                    }
                }
            }
        }
    }
    
    private func renderPresetsGrid(_ presets: [WorkoutPreset]) -> some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(presets) { preset in
                PremiumRoutineCard(
                    preset: preset,
                    onStart: { startWorkout(presetID: preset.persistentModelID) },
                    onEdit: { presetToEdit = preset; showPresetEditor = true },
                    onDuplicate: { duplicatePreset(preset) },
                    onDelete: { presetToDelete = preset; showDeleteAlert = true }
                )
                // ✅ Поддержка Drag (начинаем перетаскивание)
                .onDrag {
                    NSItemProvider(object: preset.id.uuidString as NSString)
                }
            }
        }
        .padding(.horizontal)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
    
    private func folderDropHeader(title: String, count: Int, isExpanded: Binding<Bool>, icon: String, targetFolder: String?) -> some View {
        Button {
            withAnimation(.snappy) { isExpanded.wrappedValue.toggle() }
        } label: {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(targetFolder == nil ? .purple : .blue)
                    .frame(width: 24)
                Text(LocalizedStringKey("\(title) (\(count))"))
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: isExpanded.wrappedValue ? "chevron.down" : "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // ✅ Поддержка Drop (бросаем карточку на заголовок папки)
        .onDrop(of: [.text], delegate: RoutineDropDelegate(folderName: targetFolder, presets: myPresets, onMove: moveRoutine))
    }
    
    // MARK: - System Routines
    
    private var systemRoutinesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.snappy) { isSystemRoutinesExpanded.toggle() }
            } label: {
                HStack {
                    Image(systemName: "star.square.on.square.fill")
                        .foregroundColor(.yellow)
                        .frame(width: 24)
                    Text(LocalizedStringKey("Saved Programs (\(systemPresets.count))"))
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: isSystemRoutinesExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption).foregroundColor(.gray)
                }
                .padding(.horizontal).padding(.vertical, 8).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            if isSystemRoutinesExpanded {
                if systemPresets.isEmpty {
                    Text(LocalizedStringKey("Explore and save programs to see them here."))
                        .font(.subheadline).foregroundColor(.secondary).padding(.horizontal)
                } else {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(systemPresets) { preset in
                            PremiumRoutineCard(
                                preset: preset,
                                onStart: { startWorkout(presetID: preset.persistentModelID) },
                                onEdit: nil,
                                onDuplicate: { duplicatePreset(preset) },
                                onDelete: nil
                            )
                        }
                    }
                    .padding(.horizontal).transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }
    
    private var emptyRoutinesState: some View {
        Button {
            presetToEdit = nil
            showPresetEditor = true
        } label: {
            VStack(spacing: 12) {
                Image(systemName: "doc.badge.plus").font(.system(size: 40))
                Text(LocalizedStringKey("Tap to Add\nNew Template")).font(.headline).multilineTextAlignment(.center)
            }
            .foregroundColor(.blue).frame(maxWidth: .infinity, minHeight: 160).background(Color.blue.opacity(0.05)).cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8])).foregroundColor(.blue.opacity(0.3)))
        }
        .padding(.horizontal)
    }
    
    // MARK: - Logic
    
    private func startWorkout(presetID: PersistentIdentifier?) {
        guard !isProcessing else { return }
        isProcessing = true
        Task { @MainActor in
            if await workoutService.hasActiveWorkout() {
                showActiveWorkoutAlert = true; isProcessing = false; return
            }
            let allPresets = myPresets + systemPresets
            let title = presetID == nil ? LocalizationHelper.shared.formatWorkoutDateName() : (allPresets.first(where: { $0.persistentModelID == presetID })?.name ?? "Workout")
            
            if let _ = await workoutService.createWorkout(title: title, presetID: presetID, isAIGenerated: false) {
                di.liveActivityManager.startWorkoutActivity(title: title)
                var descriptor = FetchDescriptor<Workout>(sortBy: [SortDescriptor(\.date, order: .reverse)]); descriptor.fetchLimit = 1
                if let newWorkout = try? context.fetch(descriptor).first { self.navigateToActiveWorkout = newWorkout }
            }
            isProcessing = false
        }
    }
    
    private func duplicatePreset(_ preset: WorkoutPreset) {
        Task { @MainActor in
            let newName = preset.name + " (Copy)"
            let copiedExercises = preset.exercises.map { Exercise(from: $0.toDTO()) }
            await presetService.savePreset(preset: nil, name: newName, icon: preset.icon, exercises: copiedExercises)
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            withAnimation { isMyRoutinesExpanded = true }
        }
    }
    
    // MARK: - Folders Logic
    
    private func moveRoutine(preset: WorkoutPreset, to folder: String?) {
        withAnimation(.snappy) {
            preset.folderName = folder
            try? context.save()
            
            // Если перенесли в папку, автоматически открываем её
            if let f = folder {
                expandedFolders[f] = true
            }
        }
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    private func deleteFolder(_ folder: String) {
        withAnimation(.snappy) {
            // Возвращаем все тренировки в корень
            let presetsInFolder = myPresets.filter { $0.folderName == folder }
            for p in presetsInFolder {
                p.folderName = nil
            }
            try? context.save()
            
            // Удаляем папку из настроек
            var folders = customFolders
            folders.removeAll { $0 == folder }
            // ✅ ИСПРАВЛЕНИЕ: Обновляем напрямую @AppStorage переменную
            customFoldersString = folders.joined(separator: "|")
        }
    }
}

// MARK: - Drop Delegate for Routines

struct RoutineDropDelegate: DropDelegate {
    let folderName: String?
    let presets: [WorkoutPreset]
    let onMove: (WorkoutPreset, String?) -> Void
    
    func performDrop(info: DropInfo) -> Bool {
        guard let itemProvider = info.itemProviders(for: [.text]).first else { return false }
        
        // Безопасное чтение перетаскиваемого объекта
        itemProvider.loadObject(ofClass: NSString.self) { (string, error) in
            if let str = string as? String, let id = UUID(uuidString: str) {
                // Возвращаемся в Main Thread для изменения состояния UI и БД
                DispatchQueue.main.async {
                    if let preset = presets.first(where: { $0.id == id }) {
                        // Не делаем перемещение, если папка и так целевая
                        if preset.folderName != folderName {
                            onMove(preset, folderName)
                        }
                    }
                }
            }
        }
        return true
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
}
