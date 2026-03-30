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
import SwiftData

// MARK: - Main Builder View

struct SupersetBuilderView: View {
    
    // MARK: - Environment & State
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: WorkoutViewModel
@EnvironmentObject var unitsManager: UnitsManager
    
    // Если редактируем — передаем сюда существующий супер-сет
    @State var existingSuperset: Exercise?
    
    // Внутреннее состояние списка упражнений
    @State private var addedExercises: [Exercise] = []
    
    // Управление модальными окнами
    @State private var showExerciseSelector = false
    @State private var exerciseToEdit: Exercise?
    @State private var showDeleteAlert = false
    @State private var showDeleteExerciseAlert = false
    @State private var exercisesToDelete: IndexSet?
    
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
            .navigationTitle(existingSuperset == nil ? LocalizedStringKey("New Superset") : LocalizedStringKey("Edit Superset"))
            .onAppear {
                // Загружаем данные при открытии
                if let ex = existingSuperset {
                    self.addedExercises = ex.subExercises
                }
            }
            // --- Modals & Alerts ---
            .alert(LocalizedStringKey("Delete Superset?"), isPresented: $showDeleteAlert) {
                Button(LocalizedStringKey("Delete"), role: .destructive) {
                    onDelete?()
                    dismiss()
                }
                Button(LocalizedStringKey("Cancel"), role: .cancel) { }
            } message: {
                Text(LocalizedStringKey("This action cannot be undone."))
            }
            .alert(LocalizedStringKey("Delete Exercise?"), isPresented: $showDeleteExerciseAlert) {
                Button(LocalizedStringKey("Delete"), role: .destructive) {
                    if let indexSet = exercisesToDelete {
                        addedExercises.remove(atOffsets: indexSet)
                        exercisesToDelete = nil
                    }
                }
                Button(LocalizedStringKey("Cancel"), role: .cancel) {
                    exercisesToDelete = nil
                }
            } message: {
                if let indexSet = exercisesToDelete {
                    let count = indexSet.count
                    if count == 1, let firstIndex = indexSet.first, firstIndex < addedExercises.count {
                        Text(LocalizedStringKey("Are you sure you want to delete '\(addedExercises[firstIndex].name)'? This action cannot be undone."))
                    } else {
                        Text(LocalizedStringKey("Are you sure you want to delete \(count) exercises? This action cannot be undone."))
                    }
                } else {
                    Text(LocalizedStringKey("Are you sure you want to delete this exercise? This action cannot be undone."))
                }
            }
            .sheet(isPresented: $showExerciseSelector) {
                ExerciseSelectionView { newExercise in
                    addedExercises.append(newExercise)
                }
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
        Section(header: Text(LocalizedStringKey("Exercises in Superset"))) {
            if addedExercises.isEmpty {
                Text(LocalizedStringKey("Add at least 2 exercises"))
                    .foregroundColor(.secondary)
                    .italic()
            }
            
            ForEach(addedExercises) { ex in
                HStack {
                    VStack(alignment: .leading) {
                        Text(ex.name).bold()
                        // Превью параметров (берем из первого сета)
                        if let firstSet = ex.setsList.sorted(by: { $0.index < $1.index }).first, let weight = firstSet.weight {
                            let convertedWeight = unitsManager.convertFromKilograms(weight)
                            Text(LocalizedStringKey("\(ex.setsList.count) sets • \(Int(convertedWeight))\(unitsManager.weightUnitString()) x \(firstSet.reps ?? 0) reps"))
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
                exercisesToDelete = indexSet
                showDeleteExerciseAlert = true
            }
            
            Button {
                showExerciseSelector = true
            } label: {
                Label(LocalizedStringKey("Add Exercise"), systemImage: "plus")
            }
        }
    }
    
    private var saveButton: some View {
        Button(existingSuperset == nil ? LocalizedStringKey("Create Superset") : LocalizedStringKey("Save Changes")) {
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
            Text(LocalizedStringKey("Delete Superset"))
                .frame(maxWidth: .infinity)
        }
    }
    
    // MARK: - Logic
    
    private func saveSuperset() {
        // Создаем "контейнер"
        let superset = Exercise(
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
    
    @Bindable var exercise: Exercise // ДОБАВЛЕНО: SwiftData Bindable
    var onSave: (Exercise) -> Void
    @Environment(\.dismiss) var dismiss
@EnvironmentObject var unitsManager: UnitsManager
    
    // Валидация
    @State private var showValidationAlert = false
    @State private var validationErrorMessage = ""
    
    // Сортированные сеты
    private var sortedSets: [WorkoutSet] {
        exercise.setsList.sorted(by: { $0.index < $1.index })
    }
    
    // MARK: - Bindings Adapters
    
    private var repsBinding: Binding<Double?> {
        Binding<Double?>(
            get: {
                guard let first = sortedSets.first, let reps = first.reps else { return nil }
                return Double(reps)
            },
            set: { newValue in
                guard let first = sortedSets.first else { return }
                if let value = newValue {
                    let intValue = Int(value)
                    let validation = InputValidator.validateReps(intValue)
                    first.reps = validation.clampedValue
                    if !validation.isValid, let error = validation.errorMessage {
                        validationErrorMessage = error
                        showValidationAlert = true
                    }
                } else {
                    first.reps = nil
                }
            }
        )
    }
    
    private var timeBinding: Binding<Double?> {
        Binding<Double?>(
            get: {
                guard let first = sortedSets.first, let time = first.time else { return nil }
                return Double(time)
            },
            set: { newValue in
                guard let first = sortedSets.first else { return }
                if let value = newValue {
                    let intValue = Int(value)
                    let validation = InputValidator.validateTime(intValue)
                    first.time = validation.clampedValue
                    if !validation.isValid, let error = validation.errorMessage {
                        validationErrorMessage = error
                        showValidationAlert = true
                    }
                } else {
                    first.time = nil
                }
            }
        )
    }
    
    private var weightBindingAdapter: Binding<Double?> {
        Binding<Double?>(
            get: {
                guard let first = sortedSets.first, let weight = first.weight else { return nil }
                return unitsManager.convertFromKilograms(weight)
            },
            set: { newValue in
                guard let first = sortedSets.first else { return }
                if let value = newValue {
                    let kgValue = unitsManager.convertToKilograms(value)
                    let validation = InputValidator.validateWeight(kgValue)
                    first.weight = validation.clampedValue
                    if !validation.isValid, let error = validation.errorMessage {
                        validationErrorMessage = error
                        showValidationAlert = true
                    }
                } else {
                    first.weight = nil
                }
            }
        )
    }
    
    private var distanceBindingAdapter: Binding<Double?> {
        Binding<Double?>(
            get: {
                guard let first = sortedSets.first, let dist = first.distance else { return nil }
                return unitsManager.convertFromMeters(dist)
            },
            set: { newValue in
                guard let first = sortedSets.first else { return }
                if let value = newValue {
                    let mValue = unitsManager.convertToMeters(value)
                    let validation = InputValidator.validateDistance(mValue)
                    first.distance = validation.clampedValue
                    if !validation.isValid, let error = validation.errorMessage {
                        validationErrorMessage = error
                        showValidationAlert = true
                    }
                } else {
                    first.distance = nil
                }
            }
        )
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(exercise.name)) {
                    if !exercise.setsList.isEmpty {
                        
                        Stepper(LocalizedStringKey("Sets: \(exercise.setsList.count)"), onIncrement: addSet, onDecrement: removeSet)
                        
                        // Поля ввода в зависимости от типа
                        switch exercise.type {
                        case .strength:
                            inputRow(label: LocalizedStringKey("Weight (\(unitsManager.weightUnitString())):"), placeholder: unitsManager.weightUnitString(), binding: weightBindingAdapter)
                            inputRow(label: LocalizedStringKey("Reps:"), placeholder: "reps", binding: repsBinding)
                            
                        case .cardio:
                            inputRow(label: LocalizedStringKey("Distance (\(unitsManager.distanceUnitString())):"), placeholder: unitsManager.distanceUnitString(), binding: distanceBindingAdapter)
                            inputRow(label: LocalizedStringKey("Time (min):"), placeholder: "min", binding: timeBinding)
                            
                        case .duration:
                            inputRow(label: LocalizedStringKey("Time (sec):"), placeholder: "sec", binding: timeBinding)
                        }
                    } else {
                        Button(LocalizedStringKey("Create First Set"), action: addSet)
                    }
                }
                
                Button(LocalizedStringKey("Save")) {
                    let weight = sortedSets.first?.weight ?? 0.0
                    if exercise.type == .strength && weight <= 0 {
                        validationErrorMessage = String(localized: "Please enter a weight greater than 0.")
                        showValidationAlert = true
                    } else {
                        propagateFirstSetData()
                        onSave(exercise)
                        dismiss()
                    }
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(.borderedProminent)
            }
            .navigationTitle(LocalizedStringKey("Edit Details"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("Cancel")) { dismiss() }
                }
            }
            .alert(LocalizedStringKey("Invalid Input"), isPresented: $showValidationAlert) {
                Button(LocalizedStringKey("OK"), role: .cancel) { }
            } message: {
                Text(validationErrorMessage)
            }
        }
    }
    
    // MARK: - Helper Views
    
    private func inputRow(label: LocalizedStringKey, placeholder: String, binding: Binding<Double?>) -> some View {
        HStack {
            Text(label)
            Spacer()
            ClearableTextField(placeholder: placeholder, value: binding)
                .frame(width: 80)
        }
    }
    
    // MARK: - Logic
    
    private func addSet() {
        let lastSet = sortedSets.last
        let newIndex = (lastSet?.index ?? 0) + 1
        let newSet = WorkoutSet(index: newIndex, weight: lastSet?.weight, reps: lastSet?.reps)
        
        // ИСПРАВЛЕНИЕ SwiftData: Вставляем в контекст ДО добавления в массив для избежания дублирования
        if let context = exercise.modelContext {
            context.insert(newSet)
        }
        
        exercise.setsList.append(newSet)
    }
    
    private func removeSet() {
        if exercise.setsList.count > 1, let last = sortedSets.last {
            if let index = exercise.setsList.firstIndex(where: { $0.id == last.id }) {
                let setToDelete = exercise.setsList[index]
                
                // ИСПРАВЛЕНИЕ SwiftData: Явно удаляем объект
                if let context = exercise.modelContext {
                    context.delete(setToDelete)
                }
                
                exercise.setsList.remove(at: index)
            }
        }
    }
    
    /// Копирует данные из первого сета во все остальные (для удобства)
    private func propagateFirstSetData() {
        guard let firstSet = sortedSets.first else { return }
        for set in exercise.setsList where set.id != firstSet.id {
            set.weight = firstSet.weight
            set.reps = firstSet.reps
            set.distance = firstSet.distance
            set.time = firstSet.time
        }
    }
}
