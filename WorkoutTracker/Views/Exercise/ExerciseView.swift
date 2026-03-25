//
//  ExerciseView.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 24.12.25.
//
//  Экран каталога упражнений.
//  Отображает полный список всех доступных упражнений (стандартных и пользовательских),
//  сгруппированных по мышцам/категориям.
//  Позволяет добавлять новые упражнения и удалять свои.
//

internal import SwiftUI
import SwiftData

struct ExerciseView: View {
    
    // MARK: - Environment & State
    
    @Environment(\.modelContext) private var context
    @EnvironmentObject var viewModel: WorkoutViewModel
    @State private var showAddSheet = false
    @State private var selectedGroups: Set<String>
    @State private var searchText: String
    @State private var showDeleteAlert = false
    @State private var exerciseToDelete: (name: String, category: String)?
    @State private var exercisesToDelete: [(name: String, category: String)] = []
    
    // Инициализатор, который позволяет задать заранее выбранную группу (фильтр)
    init(preselectedCategory: String? = nil) {
        if let category = preselectedCategory {
            _selectedGroups = State(initialValue: [category])
        } else {
            _selectedGroups = State(initialValue: [])
        }
        _searchText = State(initialValue: "")
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Строка поиска
                searchBar
                
                // Фильтр по группам мышц
                muscleGroupFilter
                
                if hasAnyFilteredExercises {
                    List {
                        // Проходим по всем категориям (Chest, Back...), сортируем по алфавиту
                        ForEach(filteredCategories, id: \.self) { group in
                            let exercises = filteredExercises(for: group)
                            
                            // Показываем секцию только если в ней есть упражнения
                            if !exercises.isEmpty {
                                Section(header: Text(LocalizedStringKey(group))) {
                                    
                                    ForEach(exercises, id: \.self) { exerciseName in
                                        // Убрали передачу массива
                                        NavigationLink(destination: ExerciseHistoryView(exerciseName: exerciseName)) {
                                            exerciseRow(name: exerciseName)
                                        }
                                    }
                                    // Подключаем удаление (свайп влево) - теперь работает для всех упражнений
                                    .onDelete { indexSet in
                                        let toDelete = indexSet.map { (name: exercises[$0], category: group) }
                                        exercisesToDelete = toDelete
                                        showDeleteAlert = true
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                } else {
                    // Пустое состояние когда нет упражнений после фильтрации
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 60))
                            .foregroundColor(.gray.opacity(0.5))
                        
                        Text(LocalizedStringKey("No exercises found"))
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if searchText.isEmpty {
                            Text(LocalizedStringKey("No exercises match the selected filters. Try selecting different muscle groups."))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        } else {
                            Text(LocalizedStringKey("No exercises match your search \"\(searchText)\". Try a different search term or clear the filters."))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }
            }
            .navigationTitle(LocalizedStringKey("Exercise Catalog"))
            .toolbar {
                // 1. Кнопка ПЛЮС — СЛЕВА
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .semibold))
                    }
                }
                
                // 2. Кнопка EDIT — СПРАВА (для массового удаления)
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddNewExerciseView()
            }
            .alert(LocalizedStringKey("Delete Exercise?"), isPresented: $showDeleteAlert) {
                Button(LocalizedStringKey("Delete"), role: .destructive) {
                    deleteExercises()
                }
                Button(LocalizedStringKey("Cancel"), role: .cancel) {
                    exercisesToDelete = []
                }
            } message: {
                if exercisesToDelete.count == 1 {
                    Text(LocalizedStringKey("Are you sure you want to delete '\(exercisesToDelete.first?.name ?? "")'? This action cannot be undone."))
                } else {
                    Text(LocalizedStringKey("Are you sure you want to delete \(exercisesToDelete.count) exercises? This action cannot be undone."))
                }
            }
        }
    }
    
    // MARK: - View Components
    
    private func exerciseRow(name: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(LocalizedStringKey(name))
                    .foregroundColor(.primary)
                    .font(.body)
                
                Spacer()
                
                // Если упражнение добавлено пользователем — показываем иконку
                if isCustom(name: name) {
                    Image(systemName: "person.crop.circle")
                        .foregroundColor(.blue)
                        .font(.caption)
                }
            }
            
            // Таргетные мускулы
            if let category = getCategory(for: name) {
                let targetMuscles = MuscleDisplayHelper.getTargetMuscleNames(for: name, muscleGroup: category)
                if !targetMuscles.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(targetMuscles.joined(separator: ", "))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
    }
    
    /// Получить категорию упражнения
    private func getCategory(for exerciseName: String) -> String? {
        for (category, exercises) in viewModel.combinedCatalog {
            if exercises.contains(exerciseName) {
                return category
            }
        }
        return nil
    }
    
    // MARK: - View Components
    
    /// Строка поиска
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField(LocalizedStringKey("Search exercises"), text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
            
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }
    
    /// Горизонтальная прокручиваемая панель фильтров по группам мышц
    private var muscleGroupFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // Кнопка "Все"
                filterButton(
                    title: NSLocalizedString("All", comment: ""),
                    isSelected: selectedGroups.isEmpty,
                    action: {
                        selectedGroups.removeAll()
                    }
                )
                
                // Кнопки для каждой группы мышц
                ForEach(sortedCategories, id: \.self) { group in
                    filterButton(
                        title: group,
                        isSelected: selectedGroups.contains(group),
                        action: {
                            if selectedGroups.contains(group) {
                                selectedGroups.remove(group)
                            } else {
                                selectedGroups.insert(group)
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground))
    }
    
    /// Кнопка фильтра
    private func filterButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(LocalizedStringKey(title))
                .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.accentColor : Color(.systemGray5))
                .cornerRadius(20)
        }
    }
    
    // MARK: - Helpers & Logic
    
    /// Список отсортированных категорий
    private var sortedCategories: [String] {
        viewModel.combinedCatalog.keys.sorted()
    }
    
    /// Отфильтрованные категории (если есть выбранные группы, показываем только их)
    private var filteredCategories: [String] {
        if selectedGroups.isEmpty {
            return sortedCategories
        } else {
            return sortedCategories.filter { selectedGroups.contains($0) }
        }
    }
    
    /// Получить отсортированный список упражнений для группы
    private func sortedExercises(for group: String) -> [String] {
        viewModel.combinedCatalog[group]?.sorted() ?? []
    }
    
    /// Получить отфильтрованный список упражнений для группы (с учетом поиска)
    private func filteredExercises(for group: String) -> [String] {
        let exercises = sortedExercises(for: group)
        
        if searchText.isEmpty {
            return exercises
        } else {
            return exercises.filter { exerciseName in
                exerciseName.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    /// Проверяет, есть ли хотя бы одно упражнение после фильтрации
    private var hasAnyFilteredExercises: Bool {
        for group in filteredCategories {
            if !filteredExercises(for: group).isEmpty {
                return true
            }
        }
        return false
    }
    
    /// Проверяет, является ли упражнение созданным пользователем
    private func isCustom(name: String) -> Bool {
        return viewModel.isCustomExercise(name: name)
    }
    
    /// Логика удаления (работает для всех упражнений - пользовательских и стандартных)
    private func deleteExercises() {
           withAnimation {
               for item in exercisesToDelete {
                   // ИСПРАВЛЕНИЕ: Передаем container вместо context
                   viewModel.deleteExercise(name: item.name, category: item.category, container: context.container)
               }
               exercisesToDelete = []
           }
       }
}

