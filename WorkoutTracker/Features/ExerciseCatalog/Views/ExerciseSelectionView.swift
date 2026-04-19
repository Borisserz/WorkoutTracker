// ============================================================
// FILE: WorkoutTracker/Features/ExerciseCatalog/Views/ExerciseSelectionView.swift
// ============================================================

internal import SwiftUI

struct ExerciseSelectionView: View {
    
    // MARK: - Environment & Bindings
    @Environment(TutorialManager.self) var tutorialManager
    @Environment(\.dismiss) private var dismiss
    @Environment(CatalogViewModel.self) private var catalogViewModel
    @Environment(ThemeManager.self) private var themeManager
    
    /// Замыкание для добавления нового упражнения
    var onAdd: (Exercise) -> Void
    
    // MARK: - State
    @State private var filterState = ExerciseFilterState()
    @State private var showAdvancedFilters = false
    @State private var allItems: [ExerciseDBItem] = []
    
    private let availableGroups = ["Chest", "Back", "Legs", "Shoulders", "Arms", "Core", "Cardio"]
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                // Премиальный фон
                Color(red: 0.05, green: 0.05, blue: 0.07).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 1. Стеклянная строка поиска с кнопкой фильтров
                    PremiumExerciseSearchBar(filterState: filterState) {
                        showAdvancedFilters = true
                    }
                    
                    // 2. Горизонтальный фильтр по группам мышц
                    muscleGroupFilter
                    
                    // 3. Вычисляем отфильтрованные данные
                    let filteredItems = filterState.filter(exercises: allItems).sorted(by: { $0.name < $1.name })
                    
                    if filteredItems.isEmpty {
                        emptyStateView
                    } else {
                        ScrollView(.vertical, showsIndicators: false) {
                            LazyVStack(spacing: 12) {
                                ForEach(filteredItems, id: \.name) { item in
                                    let detectedType = detectType(name: item.name, group: item.primaryMuscles?.first ?? "Other")
                                    
                                    NavigationLink {
                                        ConfigureExerciseView(
                                            exerciseName: item.name,
                                            muscleGroup: item.primaryMuscles?.first ?? "Other",
                                            exerciseType: detectedType
                                        ) { newExercise in
                                            onAdd(newExercise)
                                            dismiss()
                                            if tutorialManager.currentStep == .addExercise {
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                                    tutorialManager.setStep(.finishExercise)
                                                }
                                            }
                                        }
                                    } label: {
                                        // Карточка в стиле дизайнера!
                                        ExerciseDBRowView(exercise: item, isSelectionMode: true)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .padding(.bottom, 40)
                        }
                    }
                }
            }
            .navigationTitle(LocalizedStringKey("Упражнения"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("Закрыть")) { dismiss() }
                        .foregroundStyle(.white.opacity(0.6))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("Готово")) { dismiss() }
                        .foregroundStyle(themeManager.current.primaryAccent)
                        .fontWeight(.bold)
                }
            }
            .task {
                await loadExercises()
            }
            .sheet(isPresented: $showAdvancedFilters) {
                AdvancedFiltersSheet(
                    filterState: filterState,
                    resultsCount: filterState.filter(exercises: allItems).count
                )
            }
            .preferredColorScheme(.dark)
        }
    }
    
    // MARK: - View Components
    
    private var muscleGroupFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                Spacer().frame(width: 8)
                
                filterButton(
                    title: LocalizedStringKey("Все"),
                    isSelected: filterState.selectedMuscles.isEmpty,
                    action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            filterState.selectedMuscles.removeAll()
                        }
                    }
                )
                
                ForEach(availableGroups, id: \.self) { group in
                    filterButton(
                        title: LocalizedStringKey(group),
                        isSelected: filterState.selectedMuscles.contains(group.lowercased()),
                        action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                filterState.toggle(item: group.lowercased(), in: &filterState.selectedMuscles)
                            }
                        }
                    )
                }
                
                Spacer().frame(width: 8)
            }
            .padding(.vertical, 12)
        }
    }
    
    private func filterButton(title: LocalizedStringKey, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            let gen = UISelectionFeedbackGenerator()
            gen.selectionChanged()
            action()
        } label: {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .bold : .medium)
                .foregroundColor(isSelected ? themeManager.current.primaryAccent : .white.opacity(0.8))
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(isSelected ? themeManager.current.primaryAccent.opacity(0.15) : Color.white.opacity(0.05))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? themeManager.current.primaryAccent : Color.white.opacity(0.1), lineWidth: 1)
                )
                .shadow(color: isSelected ? themeManager.current.primaryAccent.opacity(0.3) : .clear, radius: 8, x: 0, y: 0)
        }
        .buttonStyle(.plain)
    }
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(themeManager.current.secondaryAccent.opacity(0.4))
            
            Text(LocalizedStringKey("Упражнения не найдены"))
                .font(.headline)
                .foregroundColor(.white)
            
            Text(LocalizedStringKey("Попробуйте изменить запрос или очистить фильтры."))
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 60)
    }
    
    // MARK: - Logic
    private func loadExercises() async {
        if catalogViewModel.combinedCatalog.isEmpty {
            await catalogViewModel.loadDictionary()
        }
        
        var items = await ExerciseDatabaseService.shared.getAllExerciseItems()
        let hidden = catalogViewModel.deletedDefaultExercises
        items.removeAll { hidden.contains($0.name) }
        
        let customItems = catalogViewModel.customExercises.map { custom in
            ExerciseDBItem(
                id: custom.id.uuidString, name: custom.name, equipment: "bodyweight", force: "push",
                mechanic: "isolation", primaryMuscles: custom.targetedMuscles, secondaryMuscles: nil,
                instructions: nil, category: custom.category, level: "beginner"
            )
        }
        
        self.allItems = (items + customItems).sorted { $0.name < $1.name }
    }
    
    private func detectType(name: String, group: String) -> ExerciseType {
        if let custom = catalogViewModel.customExercises.first(where: { $0.name == name }) { return custom.type }
        if ["Running", "Cycling", "Rowing", "Jump Rope"].contains(name) { return .cardio }
        if ["Plank", "Stretching"].contains(name) { return .duration }
        if group.localizedCaseInsensitiveContains("Cardio") { return .cardio }
        return .strength
    }
}
