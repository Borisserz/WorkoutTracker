// ============================================================
// FILE: WorkoutTracker/Features/ExerciseCatalog/Views/ExerciseSelectionView.swift
// ============================================================

internal import SwiftUI

struct ExerciseSelectionView: View {
    
    // MARK: - Environment & Bindings
    @Environment(TutorialManager.self) var tutorialManager
    @Environment(\.dismiss) private var dismiss
    @Environment(CatalogViewModel.self) private var catalogViewModel
    
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
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 1. Строка поиска с кнопкой фильтров
                    PremiumExerciseSearchBar(filterState: filterState) {
                        showAdvancedFilters = true
                    }
                    
                    // 2. Горизонтальный фильтр по группам мышц
                    muscleGroupFilter
                    
                    Divider().opacity(0.5)
                    
                    // 3. Вычисляем отфильтрованные данные
                    let filteredItems = filterState.filter(exercises: allItems).sorted(by: { $0.name < $1.name })
                                       
                                       if filteredItems.isEmpty {
                                           emptyStateView
                                       } else {
                                           ScrollView(.vertical, showsIndicators: false) {
                                               LazyVStack(spacing: 12) { // Уменьшили spacing, так как нет заголовков групп
                                                   ForEach(filteredItems, id: \.name) { item in
                                                       let detectedType = detectType(name: item.name, group: item.primaryMuscles?.first ?? "Other")
                                                       
                                                       NavigationLink {
                                                           ConfigureExerciseView(
                                                               exerciseName: item.name,
                                                               muscleGroup: item.primaryMuscles?.first ?? "Other", // Берем мышцу из JSON
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
                                                           ExerciseDBRowView(exercise: item)
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
            .navigationTitle(LocalizedStringKey("Select Exercise"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("Close")) { dismiss() }
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
        }
    }
    
    // MARK: - View Components
    
    private var muscleGroupFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                Spacer().frame(width: 8) // Отступ слева
                
                filterButton(
                    title: LocalizedStringKey("All"),
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
                
                Spacer().frame(width: 8) // Отступ справа
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
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(isSelected ? Color.blue : Color(UIColor.secondarySystemBackground))
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isSelected ? Color.blue : Color.gray.opacity(0.2), lineWidth: 1)
                )
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.4))
            
            Text(LocalizedStringKey("No exercises found"))
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(LocalizedStringKey("Try adjusting your search or clear advanced filters."))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 60)
    }
    
    // MARK: - Logic
    private func loadExercises() async {
            // 1. Убеждаемся, что словарь каталога загружен
            if catalogViewModel.combinedCatalog.isEmpty {
                await catalogViewModel.loadDictionary()
            }
            
            // 2. Получаем все упражнения из JSON
            var items = await ExerciseDatabaseService.shared.getAllExerciseItems()
            
            // 3. Удаляем те, которые пользователь скрыл
            let hidden = catalogViewModel.deletedDefaultExercises
            items.removeAll { hidden.contains($0.name) }
            
            // 4. Добавляем кастомные упражнения пользователя, преобразуя их в ExerciseDBItem
            // ✅ ИСПРАВЛЕНО: Добавлены недостающие аргументы force, mechanic, level
            let customItems = catalogViewModel.customExercises.map { custom in
                ExerciseDBItem(
                    id: custom.id.uuidString,
                    name: custom.name,
                    equipment: "bodyweight",
                    force: "push",        // Значение по умолчанию для кастомных
                    mechanic: "isolation", // Значение по умолчанию для кастомных
                    primaryMuscles: custom.targetedMuscles,
                    secondaryMuscles: nil,
                    instructions: nil,
                    category: custom.category,
                    level: "beginner"      // Значение по умолчанию для кастомных
                )
            }
            
            // 5. Сортируем и сохраняем
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
