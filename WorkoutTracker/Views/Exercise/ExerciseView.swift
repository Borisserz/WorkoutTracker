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

struct ExerciseView: View {
    
    // MARK: - Environment & State
    
    @EnvironmentObject var viewModel: WorkoutViewModel
    @State private var showAddSheet = false
    @State private var selectedGroups: Set<String> = []
    @State private var searchText: String = ""
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Строка поиска
                searchBar
                
                // Фильтр по группам мышц
                muscleGroupFilter
                
                List {
                    // Проходим по всем категориям (Chest, Back...), сортируем по алфавиту
                    ForEach(filteredCategories, id: \.self) { group in
                        let exercises = filteredExercises(for: group)
                        
                        // Показываем секцию только если в ней есть упражнения
                        if !exercises.isEmpty {
                            Section(header: Text(LocalizedStringKey(group))) {
                                
                                ForEach(exercises, id: \.self) { exerciseName in
                                NavigationLink(destination: ExerciseHistoryView(exerciseName: exerciseName, allWorkouts: viewModel.workouts)) {
                                    exerciseRow(name: exerciseName)
                                }
                            }
                                // Подключаем удаление (свайп влево) - теперь работает для всех упражнений
                                .onDelete { indexSet in
                                    deleteExercise(at: indexSet, in: group, exercises: exercises)
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Exercise Catalog")
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
        }
    }
    
    // MARK: - View Components
    
    private func exerciseRow(name: String) -> some View {
        HStack {
            Text(LocalizedStringKey(name))
                .foregroundColor(.primary)
            
            Spacer()
            
            // Если упражнение добавлено пользователем — показываем иконку
            if isCustom(name: name) {
                Image(systemName: "person.crop.circle")
                    .foregroundColor(.blue)
                    .font(.caption)
            }
        }
    }
    
    // MARK: - View Components
    
    /// Строка поиска
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search exercises", text: $searchText)
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
                    title: "All",
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
    
    /// Проверяет, является ли упражнение созданным пользователем
    private func isCustom(name: String) -> Bool {
        return viewModel.isCustomExercise(name: name)
    }
    
    /// Логика удаления (работает для всех упражнений - пользовательских и стандартных)
    private func deleteExercise(at offsets: IndexSet, in group: String, exercises: [String]) {
        withAnimation {
            offsets.forEach { index in
                let nameToDelete = exercises[index]
                viewModel.deleteExercise(name: nameToDelete, category: group)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ExerciseView()
        .environmentObject(WorkoutViewModel())
}
