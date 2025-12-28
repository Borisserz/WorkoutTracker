//
//  SupersetBuilderView.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 27.12.25.
//

internal import SwiftUI

struct SupersetBuilderView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var viewModel: WorkoutViewModel
    
    // Если редактируем — передаем сюда существующий супер-сет
    @State var existingSuperset: Exercise?
    
    // Callback для сохранения назад в WorkoutDetailView
    var onSave: (Exercise) -> Void
    var onDelete: (() -> Void)? = nil
    // Состояние: список упражнений внутри этого супер-сета
    @State private var addedExercises: [Exercise] = []
    
    // Общая усталость
    @State private var overallEffort: Int = 5
    
    // Управление окнами
    @State private var showExerciseSelector = false
    @State private var exerciseToEdit: Exercise? // Только для редактирования уже добавленных
    @State private var showDeleteAlert = false
    var body: some View {
        NavigationStack {
            Form {
                // Секция 1: Список
                Section(header: Text("Exercises in Superset")) {
                    if addedExercises.isEmpty {
                        Text("Add at least 2 exercises")
                            .foregroundColor(.secondary)
                            .italic()
                    }
                    
                    ForEach(addedExercises) { ex in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(ex.name).bold()
                                Text("\(ex.sets) sets x \(ex.reps) reps • \(Int(ex.weight))kg")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button {
                                exerciseToEdit = ex
                            } label: {
                                Image(systemName: "slider.horizontal.3")
                                    .foregroundColor(.blue)
                            }
                            .buttonStyle(BorderlessButtonStyle())
                        }
                    }
                    .onDelete { indexSet in
                        addedExercises.remove(atOffsets: indexSet)
                    }
                    
                    Button {
                        showExerciseSelector = true
                    } label: {
                        Label("Add Exercise", systemImage: "plus")
                    }
                }
                
                // Секция 2: Усталость
                Section(header: Text("Overall Effort (RPE)")) {
                    HStack {
                        Text("\(overallEffort)/10")
                            .bold()
                            .foregroundColor(effortColor(overallEffort))
                        Slider(value: Binding(get: { Double(overallEffort) }, set: { overallEffort = Int($0) }), in: 1...10, step: 1)
                            .tint(effortColor(overallEffort))
                    }
                    Text("Rate the effort for the whole superset")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Кнопка Сохранить
                Button(existingSuperset == nil ? "Create Superset" : "Save Changes") {
                    saveSuperset()
                }
                .disabled(addedExercises.count < 2)
                .frame(maxWidth: .infinity)
                .buttonStyle(.borderedProminent)
                
                // НОВОЕ: Кнопка Удалить (только если редактируем существующий)
                if existingSuperset != nil {
                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Text("Delete Superset")
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle(existingSuperset == nil ? "New Superset" : "Edit Superset")
            .onAppear {
                if let ex = existingSuperset {
                    self.addedExercises = ex.subExercises
                    self.overallEffort = ex.effort
                }
            }
            // Alert подтверждения удаления
            .alert("Delete Superset?", isPresented: $showDeleteAlert) {
                Button("Delete", role: .destructive) {
                    onDelete?() // Вызываем удаление в родителе
                    dismiss()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This action cannot be undone.")
            }
            // Sheets
            .sheet(isPresented: $showExerciseSelector) {
                ExerciseSelectionView(selectedExercises: $addedExercises)
            }
            .sheet(item: $exerciseToEdit) { ex in
                EditSupersetItemView(exercise: ex) { updatedEx in
                    if let index = addedExercises.firstIndex(where: { $0.id == ex.id }) {
                        addedExercises[index] = updatedEx
                    }
                    exerciseToEdit = nil
                }
                .presentationDetents([.medium])
            }
        }
    }
    
    
    func saveSuperset() {
        // Создаем "контейнер"
        var superset = Exercise(
            name: "Superset", // Временное имя
            muscleGroup: "Mixed",
            sets: 1, // Условно 1 подход суперсета
            reps: 0,
            weight: 0,
            effort: overallEffort
        )
        // ВАЖНО: Кладем реальные упражнения внутрь
        superset.subExercises = addedExercises
        
        // Генерируем красивое имя (Жим + Присед)
        let names = addedExercises.map { $0.name }.joined(separator: " + ")
        superset.name = names
        
        // Сохраняем ID, если это редактирование (чтобы не создался дубликат)
        if let existing = existingSuperset {
            superset.id = existing.id
        }
        
        onSave(superset)
        dismiss()
    }
    
    func effortColor(_ value: Int) -> Color {
        switch value {
        case 1...4: return .green
        case 5...7: return .orange
        case 8...10: return .red
        default: return .blue
        }
    }
}

// Вспомогательный View для быстрой правки веса/повторов внутри списка
struct EditSupersetItemView: View {
    @State var exercise: Exercise
    var onSave: (Exercise) -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(exercise.name)) {
                    Stepper("Sets: \(exercise.sets)", value: $exercise.sets, in: 1...20)
                    Stepper("Reps: \(exercise.reps)", value: $exercise.reps, in: 1...100)
                    HStack {
                        Text("Weight (kg):")
                        TextField("0", value: $exercise.weight, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                Button("Save") {
                    onSave(exercise)
                    dismiss()
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(.borderedProminent)
            }
            .navigationTitle("Edit Details")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
