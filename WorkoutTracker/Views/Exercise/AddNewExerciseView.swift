//
//  AddNewExerciseView.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 27.12.25.
//

internal import SwiftUI

struct AddNewExerciseView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var viewModel: WorkoutViewModel
    
    @State private var name: String = ""
    @State private var selectedCategory: String = "Chest"
    
    // Для выбора мышц (Heatmap)
    // Словарь: Отображаемое имя -> Технический слаг (slug)
    let availableMuscles: [(name: String, slug: String)] = [
        ("Chest", "chest"),
        ("Upper Back", "upper-back"), ("Lats", "lats"), ("Traps", "trapezius"), ("Lower Back", "lower-back"),
        ("Shoulders (Delts)", "deltoids"),
        ("Biceps", "biceps"), ("Triceps", "triceps"), ("Forearms", "forearm"),
        ("Abs", "abs"), ("Obliques", "obliques"),
        ("Quads", "quadriceps"), ("Hamstrings", "hamstring"), ("Glutes", "gluteal"), ("Calves", "calves")
    ]
    
    @State private var selectedMuscles: Set<String> = [] // Храним выбранные слоги
    
    let categories = Exercise.catalog.keys.sorted()
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Basic Info")) {
                    TextField("Exercise Name", text: $name)
                    
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(categories, id: \.self) { cat in
                            Text(cat).tag(cat)
                        }
                    }
                }
                
                Section(header: Text("Affected Muscles (for Heatmap)")) {
                    List {
                        ForEach(availableMuscles, id: \.slug) { muscle in
                            HStack {
                                Text(LocalizedStringKey(muscle.name))
                                Spacer()
                                if selectedMuscles.contains(muscle.slug) {
                                    Image(systemName: "checkmark").foregroundColor(.blue)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if selectedMuscles.contains(muscle.slug) {
                                    selectedMuscles.remove(muscle.slug)
                                } else {
                                    selectedMuscles.insert(muscle.slug)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("New Exercise")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveExercise()
                    }
                    .disabled(name.isEmpty || selectedMuscles.isEmpty)
                }
            }
        }
    }
    
    func saveExercise() {
        // Сохраняем через ViewModel
        viewModel.addCustomExercise(
            name: name,
            category: selectedCategory,
            muscles: Array(selectedMuscles)
        )
        dismiss()
    }
}
#Preview {
    AddNewExerciseView()
}
