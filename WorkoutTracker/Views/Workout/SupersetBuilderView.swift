//
//  SupersetBuilderView.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 27.12.25.
//
//  Экран создания и редактирования Супер-сета (комбинации из нескольких упражнений).
//  Позволяет:
//  1. Добавить упражнения в суперсет.
//  2. Отредактировать параметры каждого упражнения (через EditSupersetItemView).
//  3. Сохранить или удалить суперсет.
//

internal import SwiftUI

// MARK: - Main Builder View

struct SupersetBuilderView: View {
    
    // MARK: - Environment & State
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: WorkoutViewModel
    
    // Если редактируем — передаем сюда существующий супер-сет
    @State var existingSuperset: Exercise?
    
    // Внутреннее состояние списка упражнений
    @State private var addedExercises: [Exercise] = []
    
    // Управление модальными окнами
    @State private var showExerciseSelector = false
    @State private var exerciseToEdit: Exercise?
    @State private var showDeleteAlert = false
    
    // MARK: - Callbacks
    
    var onSave: (Exercise) -> Void
    var onDelete: (() -> Void)? = nil
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Form {
                // 1. Список упражнений
                exercisesListSection
                
                // 2. Кнопка сохранения
                saveButton
                
                // 3. Кнопка удаления (только при редактировании)
                if existingSuperset != nil {
                    deleteButton
                }
            }
            .navigationTitle(existingSuperset == nil ? "New Superset" : "Edit Superset")
            .onAppear {
                // Загружаем данные при открытии
                if let ex = existingSuperset {
                    self.addedExercises = ex.subExercises
                }
            }
            // --- Modals & Alerts ---
            .alert("Delete Superset?", isPresented: $showDeleteAlert) {
                Button("Delete", role: .destructive) {
                    onDelete?()
                    dismiss()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This action cannot be undone.")
            }
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
    
    // MARK: - View Components
    
    private var exercisesListSection: some View {
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
                        // Превью параметров (берем из первого сета)
                        if let firstSet = ex.setsList.first {
                            Text("\(ex.setsList.count) sets • \(Int(firstSet.weight ?? 0))kg x \(firstSet.reps ?? 0) reps")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
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
    }
    
    private var saveButton: some View {
        Button(existingSuperset == nil ? "Create Superset" : "Save Changes") {
            saveSuperset()
        }
        .disabled(addedExercises.count < 2)
        .frame(maxWidth: .infinity)
        .buttonStyle(.borderedProminent)
    }
    
    private var deleteButton: some View {
        Button(role: .destructive) {
            showDeleteAlert = true
        } label: {
            Text("Delete Superset")
                .frame(maxWidth: .infinity)
        }
    }
    
    // MARK: - Logic
    
    private func saveSuperset() {
        // Создаем "контейнер"
        var superset = Exercise(
            name: "Superset",
            muscleGroup: "Mixed",
            effort: 5
        )
        
        // Вкладываем упражнения
        superset.subExercises = addedExercises
        
        // Генерируем имя (Ex1 + Ex2)
        let names = addedExercises.map { $0.name }.joined(separator: " + ")
        superset.name = names
        
        // Сохраняем ID при редактировании
        if let existing = existingSuperset {
            superset.id = existing.id
        }
        
        onSave(superset)
        dismiss()
    }
}

// MARK: - Inner Exercise Editor

struct EditSupersetItemView: View {
    
    @State var exercise: Exercise
    var onSave: (Exercise) -> Void
    @Environment(\.dismiss) var dismiss
    
    // MARK: - Bindings Adapters
    
    private var repsBinding: Binding<Double?> {
        Binding<Double?>(
            get: {
                guard !exercise.setsList.isEmpty, let reps = exercise.setsList[0].reps else { return nil }
                return Double(reps)
            },
            set: {
                guard !exercise.setsList.isEmpty else { return }
                exercise.setsList[0].reps = $0.map { Int($0) }
            }
        )
    }
    
    private var timeBinding: Binding<Double?> {
        Binding<Double?>(
            get: {
                guard !exercise.setsList.isEmpty, let time = exercise.setsList[0].time else { return nil }
                return Double(time)
            },
            set: {
                guard !exercise.setsList.isEmpty else { return }
                exercise.setsList[0].time = $0.map { Int($0) }
            }
        )
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(exercise.name)) {
                    if !exercise.setsList.isEmpty {
                        
                        Stepper("Sets: \(exercise.setsList.count)", onIncrement: addSet, onDecrement: removeSet)
                        
                        // Поля ввода в зависимости от типа
                        switch exercise.type {
                        case .strength:
                            inputRow(label: "Weight (kg):", placeholder: "kg", binding: $exercise.setsList[0].weight)
                            inputRow(label: "Reps:", placeholder: "reps", binding: repsBinding)
                            
                        case .cardio:
                            inputRow(label: "Distance (km):", placeholder: "km", binding: $exercise.setsList[0].distance)
                            inputRow(label: "Time (min):", placeholder: "min", binding: timeBinding)
                            
                        case .duration:
                            inputRow(label: "Time (sec):", placeholder: "sec", binding: timeBinding)
                        }
                    } else {
                        Button("Create First Set", action: addSet)
                    }
                }
                
                Button("Save") {
                    propagateFirstSetData()
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
    
    // MARK: - Helper Views
    
    private func inputRow(label: String, placeholder: String, binding: Binding<Double?>) -> some View {
        HStack {
            Text(label)
            Spacer()
            ClearableTextField(placeholder: placeholder, value: binding)
                .frame(width: 80)
        }
    }
    
    // MARK: - Logic
    
    private func addSet() {
        let newIndex = exercise.setsList.count + 1
        let lastSet = exercise.setsList.last
        let newSet = WorkoutSet(index: newIndex, weight: lastSet?.weight, reps: lastSet?.reps)
        exercise.setsList.append(newSet)
    }
    
    private func removeSet() {
        if exercise.setsList.count > 1 {
            exercise.setsList.removeLast()
        }
    }
    
    /// Копирует данные из первого сета во все остальные (для удобства)
    private func propagateFirstSetData() {
        guard exercise.setsList.count > 1, let firstSet = exercise.setsList.first else { return }
        for i in 1..<exercise.setsList.count {
            exercise.setsList[i].weight = firstSet.weight
            exercise.setsList[i].reps = firstSet.reps
            exercise.setsList[i].distance = firstSet.distance
            exercise.setsList[i].time = firstSet.time
        }
    }
}
