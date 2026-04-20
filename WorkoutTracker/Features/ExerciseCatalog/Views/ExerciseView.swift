// ============================================================
// FILE: WorkoutTracker/Features/ExerciseCatalog/Views/ExerciseView.swift
// ============================================================

internal import SwiftUI
import SwiftData

struct ExerciseView: View {
    @Environment(\.modelContext) private var context
    @Environment(CatalogViewModel.self) var catalogViewModel
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme // 👈 ДОБАВЛЕНО ДЛЯ АДАПТАЦИИ
    
    @State private var showAddSheet = false
    @State private var showDeleteAlert = false
    @State private var exercisesToDelete: [(name: String, category: String)] = []
    
    // MARK: - State
    @State private var filterState = ExerciseFilterState()
    @State private var showAdvancedFilters = false
    @State private var allItems: [ExerciseDBItem] = []
    
    private let availableGroups = ["Chest", "Back", "Legs", "Shoulders", "Arms", "Core", "Cardio"]
    
    init(preselectedCategory: String? = nil) {
        if let category = preselectedCategory {
            let state = ExerciseFilterState()
            state.selectedMuscles = [category.lowercased()]
            _filterState = State(initialValue: state)
        }
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            // Адаптивный премиальный фон
            (colorScheme == .dark ? Color(UIColor.systemGroupedBackground) : Color(UIColor.secondarySystemBackground)).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 1. Строка поиска с кнопкой фильтров
                PremiumExerciseSearchBar(filterState: filterState) {
                    showAdvancedFilters = true
                }
                
                // 2. Горизонтальный фильтр мышц
                muscleGroupFilter
                
                Divider().opacity(0.5)
                
                // 3. Вычисляем отфильтрованные элементы
                let filteredItems = filterState.filter(exercises: allItems).sorted(by: { $0.name < $1.name })
                
                if filteredItems.isEmpty {
                    emptyStateView
                } else {
                    // Используем List для встроенной поддержки свайпов (onDelete)
                    List {
                        ForEach(filteredItems, id: \.name) { item in
                            ZStack(alignment: .leading) {
                                // Карточка упражнения
                                ExerciseDBRowView(exercise: item)
                                
                                // Невидимый NavigationLink
                                NavigationLink(destination: ExerciseHistoryView(exerciseName: item.name)) {
                                    EmptyView()
                                }
                                .opacity(0)
                            }
                            .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }
                        .onDelete { indexSet in
                            exercisesToDelete = indexSet.map { (name: filteredItems[$0].name, category: filteredItems[$0].category ?? "") }
                            showDeleteAlert = true
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .navigationTitle(LocalizedStringKey("Exercise Catalog"))
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    let gen = UIImpactFeedbackGenerator(style: .medium)
                    gen.impactOccurred()
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus").font(.system(size: 18, weight: .semibold))
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) { EditButton() }
        }
        .task {
            await loadExercises()
        }
        .sheet(isPresented: $showAddSheet) {
            AddNewExerciseView()
        }
        .sheet(isPresented: $showAdvancedFilters) {
            AdvancedFiltersSheet(
                filterState: filterState,
                resultsCount: filterState.filter(exercises: allItems).count
            )
        }
        .alert(LocalizedStringKey("Delete Exercise?"), isPresented: $showDeleteAlert) {
            Button(LocalizedStringKey("Delete"), role: .destructive) { deleteExercises() }
            Button(LocalizedStringKey("Cancel"), role: .cancel) { exercisesToDelete = [] }
        } message: {
            Text(LocalizedStringKey("This action cannot be undone."))
        }
    }
    
    // MARK: - View Components
    
    private var muscleGroupFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                Spacer().frame(width: 8)
                
                filterButton(title: "All", isSelected: filterState.selectedMuscles.isEmpty) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        filterState.selectedMuscles.removeAll()
                    }
                }
                
                ForEach(availableGroups, id: \.self) { group in
                    filterButton(title: group, isSelected: filterState.selectedMuscles.contains(group.lowercased())) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            filterState.toggle(item: group.lowercased(), in: &filterState.selectedMuscles)
                        }
                    }
                }
                
                Spacer().frame(width: 8)
            }
            .padding(.vertical, 12)
        }
    }
    
    // 👈 ИСПРАВЛЕНИЕ: Адаптивные цвета для чипсов
    private func filterButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            let gen = UISelectionFeedbackGenerator()
            gen.selectionChanged()
            action()
        } label: {
            Text(LocalizedStringKey(title))
                .font(.subheadline)
                .fontWeight(isSelected ? .bold : .medium)
                .foregroundColor(isSelected ? .white : (colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.8)))
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(isSelected ? themeManager.current.primaryAccent : (colorScheme == .dark ? themeManager.current.surface : Color.white))
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isSelected ? themeManager.current.primaryAccent : (colorScheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.1)), lineWidth: 1)
                )
                .shadow(color: isSelected ? themeManager.current.primaryAccent.opacity(0.2) : .clear, radius: 5, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(themeManager.current.secondaryAccent.opacity(0.4))
            
            Text(LocalizedStringKey("No exercises found"))
                .font(.headline)
                .foregroundColor(colorScheme == .dark ? themeManager.current.primaryText : .black)
            
            Text(LocalizedStringKey("Try adjusting search or clear advanced filters."))
                .font(.subheadline)
                .foregroundColor(colorScheme == .dark ? themeManager.current.secondaryText : .gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 60)
    }
    
    // MARK: - Logic Helpers
    
    private func loadExercises() async {
        if catalogViewModel.combinedCatalog.isEmpty {
            await catalogViewModel.loadDictionary()
        }
        
        var items = await ExerciseDatabaseService.shared.getAllExerciseItems()
        let hidden = catalogViewModel.deletedDefaultExercises
        items.removeAll { hidden.contains($0.name) }
        
        let customItems = catalogViewModel.customExercises.map { custom in
            ExerciseDBItem(
                id: custom.id.uuidString,
                name: custom.name,
                equipment: "bodyweight",
                force: "push",
                mechanic: "isolation",
                primaryMuscles: custom.targetedMuscles,
                secondaryMuscles: nil,
                instructions: nil,
                category: custom.category,
                level: "beginner"
            )
        }
        
        self.allItems = (items + customItems).sorted { $0.name < $1.name }
    }
    
    private func deleteExercises() {
        let items = exercisesToDelete
        exercisesToDelete = []
        Task {
            for item in items {
                await catalogViewModel.deleteExercise(name: item.name, category: item.category)
            }
            await loadExercises()
        }
    }
}
