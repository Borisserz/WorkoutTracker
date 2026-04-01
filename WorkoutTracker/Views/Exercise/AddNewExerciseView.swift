//
//  AddNewExerciseView.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 27.12.25.
//
//  Экран создания нового (пользовательского) упражнения.
//  Позволяет задать имя, категорию, тип и отметить задействованные мышцы для Heatmap.
//

internal import SwiftUI
import SwiftData

struct AddNewExerciseView: View {
    
    // MARK: - Environment & State
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var catalogViewModel: CatalogViewModel
    // Данные формы
    @State private var name: String = ""
    @State private var selectedCategory: String = "Chest"
    @State private var selectedType: ExerciseType = .strength
    @State private var selectedMuscles: Set<String> = [] // Храним выбранные слоги (slugs)
    
    // MARK: - Constants / Data Source
    
    // Словарь: Отображаемое имя -> Технический слаг (slug)
    private let availableMuscles: [(name: String, slug: String)] = [
        ("Chest", "chest"),
        ("Upper Back", "upper-back"), ("Lats", "lats"), ("Traps", "trapezius"), ("Lower Back", "lower-back"),
        ("Shoulders (Delts)", "deltoids"),
        ("Biceps", "biceps"), ("Triceps", "triceps"), ("Forearms", "forearm"),
        ("Abs", "abs"), ("Obliques", "obliques"),
        ("Quads", "quadriceps"), ("Hamstrings", "hamstring"), ("Glutes", "gluteal"), ("Calves", "calves")
    ]
    
    private var categories: [String] {
        Exercise.catalog.keys.sorted()
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Form {
                // 1. Основная информация (Имя, Категория, Тип)
                basicInfoSection
                
                // 2. Выбор мышц (Список с галочками)
                muscleSelectionSection
            }
            .navigationTitle(LocalizedStringKey("New Exercise"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("Save")) {
                        saveExercise()
                    }
                    .disabled(name.isEmpty || selectedMuscles.isEmpty)
                }
            }
        }
    }
    
    // MARK: - View Components
    
    private var basicInfoSection: some View {
            Section(header: Text(LocalizedStringKey("Basic Info"))) {
                TextField(LocalizedStringKey("Exercise Name"), text: $name)
                
                Picker(LocalizedStringKey("Category"), selection: $selectedCategory) {
                    ForEach(categories, id: \.self) { cat in
                        Text(cat).tag(cat)
                    }
                }
                
                // На будущее: скрыли выбор типа упражнения по запросу,
                // но переменная $selectedType остается дефолтной (.strength)
                /*
                Picker(LocalizedStringKey("Exercise Type"), selection: $selectedType) {
                    ForEach(ExerciseType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                */
            }
        }
    
    private var muscleSelectionSection: some View {
        Section(header: Text(LocalizedStringKey("Affected Muscles (for Heatmap)"))) {
            // Используем ForEach вместо List, т.к. мы уже внутри Form
            ForEach(availableMuscles, id: \.slug) { muscle in
                HStack {
                    Text(LocalizedStringKey(muscle.name))
                    Spacer()
                    if selectedMuscles.contains(muscle.slug) {
                        Image(systemName: "checkmark")
                            .foregroundColor(.blue)
                    }
                }  .onTapGesture {
                    if selectedMuscles.contains(muscle.slug) {
                        selectedMuscles.remove(muscle.slug)
                    } else {
                        selectedMuscles.insert(muscle.slug)
                    }
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func toggleMuscle(_ slug: String) {
        if selectedMuscles.contains(slug) {
            selectedMuscles.remove(slug)
        } else {
            selectedMuscles.insert(slug)
        }
    }
    
    private func saveExercise() {
        catalogViewModel.addCustomExercise(name: name, category: selectedCategory, muscles: Array(selectedMuscles), type: selectedType)
        dismiss()
    }
    
}

