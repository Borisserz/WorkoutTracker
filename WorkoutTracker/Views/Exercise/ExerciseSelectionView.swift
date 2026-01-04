//
//  ExerciseSelectionView.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 24.12.25.
//
//  Экран выбора упражнения из каталога.
//  Отображает список, сгруппированный по частям тела, с иконками типов.
//  При выборе открывает экран конфигурации (ConfigureExerciseView).
//

internal import SwiftUI

struct ExerciseSelectionView: View {
    
    // MARK: - Environment & Bindings
    @EnvironmentObject var tutorialManager: TutorialManager
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: WorkoutViewModel
    
    /// Сюда добавится новое упражнение после конфигурации
    @Binding var selectedExercises: [Exercise]
    
    // MARK: - State
    @State private var searchText: String = ""
    @State private var selectedGroups: Set<String> = []
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Строка поиска
                searchBar
                
                // Фильтр по группам мышц
                muscleGroupFilter
                
                List {
                    // Проходим по всем группам мышц (ключам словаря)
                    ForEach(filteredGroups, id: \.self) { group in
                        let exercisesInGroup = getFilteredExercises(for: group)
                        
                        // Показываем секцию только если в ней есть упражнения
                        if !exercisesInGroup.isEmpty {
                            Section(header: Text(LocalizedStringKey(group))) {
                                
                                ForEach(exercisesInGroup, id: \.self) { exerciseName in
                                    
                                    // Определяем тип (Силовое/Кардио/Время)
                                    let detectedType = detectType(name: exerciseName, group: group)
                                    
                                    NavigationLink {
                                        // Экран настройки параметров (Сеты/Повторы)
                                        ConfigureExerciseView(
                                            exerciseName: exerciseName,
                                            muscleGroup: group,
                                            exerciseType: detectedType
                                        ) { newExercise in
                                            selectedExercises.append(newExercise)
                                            dismiss()
                                            if tutorialManager.currentStep == .addExercise {
                                                // Небольшая задержка, чтобы экран успел закрыться
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                                    tutorialManager.setStep(.finishExercise)
                                                }
                                            }
                                        }
                                    } label: {
                                        // Внешний вид строки
                                        exerciseRowView(name: exerciseName, type: detectedType)
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Select Exercise")
            .toolbar {
                Button("Close") { dismiss() }
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
                ForEach(sortedGroups, id: \.self) { group in
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
    
    /// Внешний вид строки списка упражнений
    private func exerciseRowView(name: String, type: ExerciseType) -> some View {
        HStack(spacing: 12) {
            // 1. Иконка типа (Слева)
            Image(systemName: getIcon(for: type))
                .foregroundColor(getColor(for: type))
                .frame(width: 20) // Фиксированная ширина для выравнивания
            
            // 2. Название
            Text(LocalizedStringKey(name))
                .foregroundColor(.primary)
            
            Spacer()
            
            // 3. Бейдж "Пользовательское" (Справа)
            if isCustom(name: name) {
                Image(systemName: "person.crop.circle")
                    .foregroundColor(.gray.opacity(0.5))
                    .font(.caption)
            }
        }
    }
    
    // MARK: - Helpers (Logic)
    
    private var sortedGroups: [String] {
        viewModel.combinedCatalog.keys.sorted()
    }
    
    /// Отфильтрованные группы (если есть выбранные группы, показываем только их)
    private var filteredGroups: [String] {
        if selectedGroups.isEmpty {
            return sortedGroups
        } else {
            return sortedGroups.filter { selectedGroups.contains($0) }
        }
    }
    
    private func getSortedExercises(for group: String) -> [String] {
        viewModel.combinedCatalog[group]?.sorted() ?? []
    }
    
    /// Получить отфильтрованный список упражнений для группы (с учетом поиска)
    private func getFilteredExercises(for group: String) -> [String] {
        let exercises = getSortedExercises(for: group)
        
        if searchText.isEmpty {
            return exercises
        } else {
            return exercises.filter { exerciseName in
                exerciseName.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    private func isCustom(name: String) -> Bool {
        return viewModel.isCustomExercise(name: name)
    }
    
    /// Логика автоматического определения типа упражнения
    private func detectType(name: String, group: String) -> ExerciseType {
        // 1. Проверяем пользовательские (там тип задан явно)
        if let custom = viewModel.customExercises.first(where: { $0.name == name }) {
            return custom.type
        }
        
        // 2. Проверяем по спискам стандартных исключений
        if ["Running", "Cycling", "Rowing", "Jump Rope"].contains(name) { return .cardio }
        if ["Plank", "Stretching"].contains(name) { return .duration }
        if group == "Cardio" { return .cardio }
        
        // 3. По умолчанию считаем силовым
        return .strength
    }
    
    // MARK: - Helpers (UI)
    
    private func getIcon(for type: ExerciseType) -> String {
        switch type {
        case .strength: return "dumbbell.fill"    // Гантелька
        case .cardio: return "figure.run"         // Бегущий
        case .duration: return "stopwatch.fill"   // Таймер
        }
    }
    
    private func getColor(for type: ExerciseType) -> Color {
        switch type {
        case .strength: return .blue
        case .cardio: return .orange
        case .duration: return .purple
        }
    }
}
