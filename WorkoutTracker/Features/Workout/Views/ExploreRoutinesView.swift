// ============================================================
// FILE: WorkoutTracker/Views/Workout/ExploreRoutinesView.swift
// ============================================================

internal import SwiftUI
import SwiftData

struct ExploreRoutinesView: View {
    @Environment(DIContainer.self) private var di
    @Environment(\.modelContext) private var context
    @Environment(WorkoutService.self) var workoutService
    @Environment(PresetService.self) var presetService
    
    // Системные шаблоны
    @Query(filter: #Predicate<WorkoutPreset> { $0.isSystem == true }, sort: \WorkoutPreset.name)
    private var systemPresets: [WorkoutPreset]
    
    // Безопасный стейт для UI, чтобы избежать Infinite Loop при ленивой загрузке SwiftData
    @State private var displayedPresets: [WorkoutPreset] = []
    
    @State private var navigateToActiveWorkout: Workout? = nil
    @State private var isProcessing = false
    @State private var showSavedToast = false
    
    // Инструменты фильтрации
    @State private var searchDebouncer = SearchDebouncer()
    @State private var selectedFilter: String = "All"
    
    private let filters = ["All", "Chest", "Back", "Legs", "Shoulders", "Arms", "Core"]
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Color(UIColor.systemGroupedBackground).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Поиск и Фильтры (закреплены сверху)
                VStack(spacing: 12) {
                    DebouncedSearchBar(debouncer: searchDebouncer)
                        .padding(.horizontal)
                        .padding(.top, 8)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(filters, id: \.self) { filter in
                                Button {
                                    withAnimation(.snappy) { selectedFilter = filter }
                                    let generator = UIImpactFeedbackGenerator(style: .light)
                                    generator.impactOccurred()
                                } label: {
                                    Text(LocalizedStringKey(filter))
                                        .font(.subheadline)
                                        .fontWeight(selectedFilter == filter ? .semibold : .regular)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(selectedFilter == filter ? Color.accentColor : Color(UIColor.secondarySystemBackground))
                                        .foregroundColor(selectedFilter == filter ? .white : .primary)
                                        .cornerRadius(20)
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                    }
                }
                .background(Color(UIColor.systemGroupedBackground))
                .zIndex(1)
                
                // Контент программ
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        heroBanner
                        
                        Text(LocalizedStringKey("Curated Routines"))
                            .font(.title2)
                            .bold()
                            .padding(.horizontal)
                        
                        if displayedPresets.isEmpty {
                            EmptyStateView(
                                icon: "magnifyingglass",
                                title: LocalizedStringKey("No routines found"),
                                message: LocalizedStringKey("Try adjusting your search or filters.")
                            )
                        } else {
                            LazyVGrid(columns: [GridItem(.flexible(), spacing: 16)], spacing: 16) {
                                ForEach(displayedPresets) { preset in
                                    PremiumRoutineCard(
                                        preset: preset,
                                        onStart: { startWorkout(presetID: preset.persistentModelID) },
                                        onEdit: nil, // Системные редактировать нельзя
                                        onDuplicate: { duplicatePreset(preset) },
                                        onDelete: nil
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
            
            // Toast notification
            if showSavedToast {
                Text(LocalizedStringKey("Saved to My Routines"))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.green)
                    .clipShape(Capsule())
                    .shadow(radius: 5)
                    .padding(.bottom, 30)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(100)
            }
        }
        .navigationTitle(LocalizedStringKey("Explore"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $navigateToActiveWorkout) { workout in
            WorkoutDetailView(workout: workout, viewModel: di.makeWorkoutDetailViewModel())
        }
        // ✅ БЕЗОПАСНАЯ ФИЛЬТРАЦИЯ (Вне цикла рендеринга Body)
        .onAppear { applyFilters() }
        .onChange(of: systemPresets) { _, _ in applyFilters() }
        .onChange(of: searchDebouncer.debouncedText) { _, _ in applyFilters() }
        .onChange(of: selectedFilter) { _, _ in applyFilters() }
    }
    
    // MARK: - Safe Data Filtering
    
    private func applyFilters() {
        // Выполняем фильтрацию в изолированной задаче на MainActor
        // Это предотвращает Infinite Loop от ленивой загрузки связей (preset.exercises)
        Task { @MainActor in
            var results = systemPresets
            
            let searchText = searchDebouncer.debouncedText
            if !searchText.isEmpty {
                results = results.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
            }
            
            let filter = selectedFilter
            if filter != "All" {
                results = results.filter { preset in
                    // Обращение к `exercises` инициирует SwiftData faulting, но так как мы вне `body`, всё безопасно.
                    preset.exercises.contains { $0.muscleGroup == filter } ||
                    preset.name.localizedCaseInsensitiveContains(filter)
                }
            }
            
            withAnimation(.easeInOut(duration: 0.2)) {
                self.displayedPresets = results
            }
        }
    }
    
    // MARK: - Components & Logic
    
    private var heroBanner: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.yellow)
                    .font(.title2)
                Text(LocalizedStringKey("Discover"))
                    .font(.title3)
                    .bold()
                    .foregroundColor(.white)
            }
            
            Text(LocalizedStringKey("Find the perfect routine for your goals. AI-generated programs and pro splits are coming soon!"))
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(3)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [Color.purple, Color.blue], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .cornerRadius(16)
        .padding(.horizontal)
        .shadow(color: .purple.opacity(0.3), radius: 10, x: 0, y: 5)
    }
    
    private func duplicatePreset(_ preset: WorkoutPreset) {
        Task { @MainActor in
            let newName = preset.name + " (Copy)"
            let copiedExercises = preset.exercises.map { Exercise(from: $0.toDTO()) }
            
            await presetService.savePreset(preset: nil, name: newName, icon: preset.icon, exercises: copiedExercises)
            
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            
            withAnimation(.spring()) { showSavedToast = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation { showSavedToast = false }
            }
        }
    }
    
    private func startWorkout(presetID: PersistentIdentifier?) {
        guard !isProcessing else { return }
        isProcessing = true
        
        Task { @MainActor in
            if await workoutService.hasActiveWorkout() {
                di.appState.showError(title: "Active Workout Exists", message: "You already have an active workout in progress. Please finish or delete it before starting a new one.")
                isProcessing = false
                return
            }
            
            let title = systemPresets.first(where: { $0.persistentModelID == presetID })?.name ?? "Workout"
            
            if let _ = await workoutService.createWorkout(title: title, presetID: presetID, isAIGenerated: false) {
                di.liveActivityManager.startWorkoutActivity(title: title)
                var descriptor = FetchDescriptor<Workout>(sortBy: [SortDescriptor(\.date, order: .reverse)])
                descriptor.fetchLimit = 1
                if let newWorkout = try? context.fetch(descriptor).first {
                    self.navigateToActiveWorkout = newWorkout
                }
            }
            isProcessing = false
        }
    }
}
