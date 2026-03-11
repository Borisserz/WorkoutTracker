//
//  PresetEditorView.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 27.12.25.
//
//  Редактор шаблона тренировки (Preset).
//  Позволяет:
//  1. Задать имя и иконку шаблона.
//  2. Добавить/удалить упражнения.
//  3. Настроить параметры упражнений (целевые сеты, повторы).
//

internal import SwiftUI
import SwiftData

// MARK: - Main Editor View

struct PresetEditorView: View {
    
    // MARK: - Environment & State
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var viewModel: WorkoutViewModel
    @StateObject private var unitsManager = UnitsManager.shared
    
    @State var preset: WorkoutPreset?
    
    // Локальный стейт формы
    @State private var name: String = ""
    @State private var selectedIcon: String = "img_default"
    @State private var exercises: [Exercise] = []
    
    // Управление модальными окнами
    @State private var showExerciseSelector = false
    @State private var exerciseToEdit: Exercise?
    @State private var showDeleteAlert = false
    @State private var showDeleteExerciseAlert = false
    @State private var exercisesToDelete: IndexSet?
    
    // Доступные иконки
    private let availableIcons = [
        "img_default", "img_chest", "img_chest2", "img_back", "img_back2",
        "img_legs", "img_legs2", "img_arms", "battle-rope", "dumbbell",
        "exercise-2", "gym-4"
    ]
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Form {
                // 1. Имя и Иконка
                headerSection
                
                // 2. Список упражнений
                exerciseListSection
                
                // 3. Удаление (только для существующих)
                if preset != nil {
                    deleteButtonSection
                }
            }
            .navigationTitle(preset == nil ? Text("New Template") : Text("Edit Template"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        savePreset()
                    }
                    .disabled(name.isEmpty || exercises.isEmpty)
                }
            }
            // Алерт удаления
            .alert("Delete Template?", isPresented: $showDeleteAlert) {
                Button("Delete", role: .destructive) {
                    if let p = preset {
                        context.delete(p)
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to delete '\(name)'? This action cannot be undone.")
            }
            .alert("Delete Exercise?", isPresented: $showDeleteExerciseAlert) {
                Button("Delete", role: .destructive) {
                    if let indexSet = exercisesToDelete {
                        exercises.remove(atOffsets: indexSet)
                        exercisesToDelete = nil
                    }
                }
                Button("Cancel", role: .cancel) {
                    exercisesToDelete = nil
                }
            } message: {
                if let indexSet = exercisesToDelete {
                    let count = indexSet.count
                    if count == 1, let firstIndex = indexSet.first, firstIndex < exercises.count {
                        Text("Are you sure you want to delete '\(exercises[firstIndex].name)'? This action cannot be undone.")
                    } else {
                        Text("Are you sure you want to delete \(count) exercises? This action cannot be undone.")
                    }
                } else {
                    Text("Are you sure you want to delete this exercise? This action cannot be undone.")
                }
            }
            // Инициализация
            .onAppear {
                if let p = preset {
                    name = p.name
                    selectedIcon = p.icon
                    exercises = p.exercises
                }
            }
            // Добавление упражнения
            .sheet(isPresented: $showExerciseSelector) {
                ExerciseSelectionView { newExercise in
                    exercises.append(newExercise)
                }
            }
            // Редактирование упражнения
            .sheet(item: $exerciseToEdit) { ex in
                PresetExerciseEditor(exercise: ex) { updatedEx in
                    if let index = exercises.firstIndex(where: { $0.id == ex.id }) {
                        exercises[index] = updatedEx
                    }
                    exerciseToEdit = nil
                }
                .presentationDetents([.medium])
            }
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        Section(header: Text("Template Info")) {
            TextField("Template Name", text: $name)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 15) {
                    ForEach(availableIcons, id: \.self) { iconName in
                        Image(iconName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 50, height: 50)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(selectedIcon == iconName ? Color.blue : Color.clear, lineWidth: 3)
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation { selectedIcon = iconName }
                            }
                    }
                }
                .padding(.vertical, 5)
            }
        }
    }
    
    private var exerciseListSection: some View {
        Section(header: Text("Exercises")) {
            if exercises.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    
                    Text("No exercises yet")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Tap the button below to add your first exercise to this template")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            }
            
            ForEach(exercises) { exercise in
                HStack {
                    VStack(alignment: .leading) {
                        Text(LocalizedStringKey(exercise.name)).font(.headline)
                        
                        Group {
                            switch exercise.type {
                            case .strength:
                                let convertedWeight = unitsManager.convertFromKilograms(exercise.weight)
                                Text("\(exercise.sets) x \(exercise.reps) • \(Int(convertedWeight))\(unitsManager.weightUnitString())")
                            case .cardio:
                                let dist = exercise.distance ?? 0
                                let convertedDist = unitsManager.convertFromMeters(dist)
                                let time = exercise.timeSeconds ?? 0
                                Text("\(LocalizationHelper.shared.formatTwoDecimals(convertedDist)) \(unitsManager.distanceUnitString()) • \(formatTime(time))")
                            case .duration:
                                let time = exercise.timeSeconds ?? 0
                                Text("\(exercise.sets) sets • \(formatTime(time))")
                            }
                        }
                        .font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                    
                    Button {
                        exerciseToEdit = exercise
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundColor(.secondary)
                            .font(.body)
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
                Label("Add Exercise", systemImage: "plus")
            }
        }
    }
    
    private var deleteButtonSection: some View {
        Section {
            Button(role: .destructive) {
                showDeleteAlert = true
            } label: {
                HStack {
                    Spacer()
                    Text("Delete Template")
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - Logic Helpers
    
    private func savePreset() {
        if let existingPreset = preset {
            // Обновляем существующий
            existingPreset.name = name
            existingPreset.icon = selectedIcon
            existingPreset.exercises = exercises
        } else {
            // Создаем новый
            let newPreset = WorkoutPreset(
                id: UUID(),
                name: name,
                icon: selectedIcon,
                exercises: exercises
            )
            context.insert(newPreset)
        }
        dismiss()
    }
    
    private func formatTime(_ totalSeconds: Int) -> String {
        let m = totalSeconds / 60
        let s = totalSeconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Inner Exercise Editor

struct PresetExerciseEditor: View {
    @State var exercise: Exercise
    var onSave: (Exercise) -> Void
    @Environment(\.dismiss) var dismiss
    @StateObject private var unitsManager = UnitsManager.shared
    
    // Локальное состояние (т.к. старые свойства Exercise теперь read-only)
    @State private var setsCount: Int = 1
    @State private var repsCount: Int = 0
    @State private var weightValue: Double = 0
    @State private var distanceValue: Double? = nil
    
    // Локальное время
    @State private var minutes: Int = 0
    @State private var seconds: Int = 0
    
    // Validation alerts (will only show on Save)
    @State private var showValidationAlert = false
    @State private var validationErrorMessage = ""
    
    // Binding адаптер для веса
    private var weightBindingAdapter: Binding<Double> {
        Binding<Double>(
            get: { unitsManager.convertFromKilograms(weightValue) },
            set: { newValue in
                weightValue = unitsManager.convertToKilograms(newValue)
            }
        )
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(LocalizedStringKey(exercise.name))) {
                    switch exercise.type {
                    case .strength: strengthConfig
                    case .cardio: cardioConfig
                    case .duration: durationConfig
                    }
                }
                
                Button("Save Changes") {
                    save()
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(.borderedProminent)
            }
            .navigationTitle("Configure Preset")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                // Инициализация локальных состояний при открытии
                setsCount = exercise.setsList.isEmpty ? 1 : exercise.setsList.count
                repsCount = exercise.setsList.first?.reps ?? 0
                weightValue = exercise.setsList.first?.weight ?? 0.0
                distanceValue = exercise.setsList.first?.distance
                
                let total = exercise.setsList.first?.time ?? 0
                minutes = total / 60
                seconds = total % 60
            }
            .alert("Invalid Input", isPresented: $showValidationAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(LocalizedStringKey(validationErrorMessage))
            }
        }
    }
    
    // MARK: - Config Subviews
    
    @ViewBuilder
    private var strengthConfig: some View {
        Stepper("Sets: \(setsCount)", value: $setsCount, in: 1...20)
        Stepper("Reps: \(repsCount)", value: $repsCount, in: 0...100)
        HStack {
            Text("Weight (\(unitsManager.weightUnitString())):")
            TextField("0", value: weightBindingAdapter, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
        }
    }
    
    @ViewBuilder
    private var cardioConfig: some View {
        HStack {
            Text("Distance (\(unitsManager.distanceUnitString())):")
            TextField("0", value: Binding(get: { 
                if let d = distanceValue { return unitsManager.convertFromMeters(d) }
                return 0
            }, set: { newValue in
                distanceValue = unitsManager.convertToMeters(newValue)
            }), format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
        }
        timePickerRow(label: "Duration")
    }
    
    @ViewBuilder
    private var durationConfig: some View {
        Stepper("Sets: \(setsCount)", value: $setsCount, in: 1...10)
        timePickerRow(label: "Time per set")
    }
    
    private func timePickerRow(label: LocalizedStringKey) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0", value: $minutes, format: .number)
                .frame(width: 40).multilineTextAlignment(.center)
                .keyboardType(.numberPad)
                .background(Color.gray.opacity(0.1)).cornerRadius(5)
            Text("min")
            TextField("0", value: $seconds, format: .number)
                .frame(width: 40).multilineTextAlignment(.center)
                .keyboardType(.numberPad)
                .background(Color.gray.opacity(0.1)).cornerRadius(5)
                .onChange(of: seconds) { oldValue, newValue in
                    let clampedSeconds = max(0, min(newValue, 59))
                    if clampedSeconds != newValue {
                        seconds = clampedSeconds
                    }
                }
            Text("sec")
        }
    }
    
    // MARK: - Logic
    
    private func save() {
        var hasError = false
        var errorMessages: [String] = []
        
        if exercise.type == .strength {
            if weightValue <= 0 {
                hasError = true
                errorMessages.append(String(localized: "Please enter a weight greater than 0."))
            } else {
                let weightValidation = InputValidator.validateWeight(weightValue)
                if !weightValidation.isValid {
                    hasError = true
                    if let error = weightValidation.errorMessage {
                        errorMessages.append(error)
                    }
                    weightValue = weightValidation.clampedValue
                }
            }
            
            let repsValidation = InputValidator.validateReps(repsCount)
            if !repsValidation.isValid {
                hasError = true
                if let error = repsValidation.errorMessage {
                    errorMessages.append(error)
                }
                repsCount = repsValidation.clampedValue
            }
        }
        
        if exercise.type == .cardio, let distance = distanceValue {
            let distanceValidation = InputValidator.validateDistance(distance)
            if !distanceValidation.isValid {
                hasError = true
                if let error = distanceValidation.errorMessage {
                    errorMessages.append(error)
                }
                distanceValue = distanceValidation.clampedValue
            }
        }
        
        let total = (minutes * 60) + seconds
        if total > 0 {
            let timeValidation = InputValidator.validateTime(total)
            if !timeValidation.isValid {
                hasError = true
                if let error = timeValidation.errorMessage {
                    errorMessages.append(error)
                }
                let validSeconds = timeValidation.clampedValue
                minutes = validSeconds / 60
                seconds = validSeconds % 60
            }
        }
        
        if hasError {
            validationErrorMessage = errorMessages.joined(separator: "\n")
            showValidationAlert = true
            return
        }
        
        // ИСПРАВЛЕНИЕ SwiftData: Удаляем старые сеты из контекста, чтобы не создавать сиротские объекты
        if let context = exercise.modelContext {
            for set in exercise.setsList {
                context.delete(set)
            }
        }
        
        // Генерация нового setsList
        var newSets: [WorkoutSet] = []
        let finalSetsCount = exercise.type == .cardio ? 1 : max(1, setsCount)
        
        for i in 1...finalSetsCount {
            let newSet = WorkoutSet(
                index: i,
                weight: exercise.type == .strength ? weightValue : nil,
                reps: exercise.type == .strength ? repsCount : nil,
                distance: exercise.type == .cardio ? distanceValue : nil,
                time: total > 0 ? total : nil,
                isCompleted: false,
                type: .normal
            )
            
            // ИСПРАВЛЕНИЕ SwiftData: Сначала вставляем в контекст (если он доступен)
            if let context = exercise.modelContext {
                context.insert(newSet)
            }
            
            newSets.append(newSet)
        }
        
        exercise.setsList = newSets
        onSave(exercise)
        dismiss()
    }
}
