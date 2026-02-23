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

// MARK: - Main Editor View

struct PresetEditorView: View {
    
    // MARK: - Environment & State
    
    @Environment(\.dismiss) private var dismiss
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
            .navigationTitle(preset == nil ? LocalizedStringKey("New Template") : LocalizedStringKey("Edit Template"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("Save")) {
                        savePreset()
                    }
                    .disabled(name.isEmpty || exercises.isEmpty)
                }
            }
            // Алерт удаления
            .alert(LocalizedStringKey("Delete Template?"), isPresented: $showDeleteAlert) {
                Button(LocalizedStringKey("Delete"), role: .destructive) {
                    if let p = preset {
                        viewModel.deletePreset(p)
                        dismiss()
                    }
                }
                Button(LocalizedStringKey("Cancel"), role: .cancel) { }
            } message: {
                Text(LocalizedStringKey("Are you sure you want to delete '\(name)'? This action cannot be undone."))
            }
            .alert(LocalizedStringKey("Delete Exercise?"), isPresented: $showDeleteExerciseAlert) {
                Button(LocalizedStringKey("Delete"), role: .destructive) {
                    if let indexSet = exercisesToDelete {
                        exercises.remove(atOffsets: indexSet)
                        exercisesToDelete = nil
                    }
                }
                Button(LocalizedStringKey("Cancel"), role: .cancel) {
                    exercisesToDelete = nil
                }
            } message: {
                if let indexSet = exercisesToDelete {
                    let count = indexSet.count
                    if count == 1, let firstIndex = indexSet.first, firstIndex < exercises.count {
                        Text(LocalizedStringKey("Are you sure you want to delete '\(exercises[firstIndex].name)'? This action cannot be undone."))
                    } else {
                        Text(LocalizedStringKey("Are you sure you want to delete \(count) exercises? This action cannot be undone."))
                    }
                } else {
                    Text(LocalizedStringKey("Are you sure you want to delete this exercise? This action cannot be undone."))
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
                ExerciseSelectionView(selectedExercises: $exercises)
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
        Section(header: Text(LocalizedStringKey("Template Info"))) {
            TextField(LocalizedStringKey("Template Name"), text: $name)
            
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
        Section(header: Text(LocalizedStringKey("Exercises"))) {
            if exercises.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    
                    Text(LocalizedStringKey("No exercises yet"))
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(LocalizedStringKey("Tap the button below to add your first exercise to this template"))
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
                                let unitsManager = UnitsManager.shared
                                let convertedWeight = unitsManager.convertFromKilograms(exercise.weight)
                                Text(LocalizedStringKey("\(exercise.sets) x \(exercise.reps) • \(Int(convertedWeight))\(unitsManager.weightUnitString())"))
                            case .cardio:
                                let dist = exercise.distance ?? 0
                                let time = exercise.timeSeconds ?? 0
                                Text(LocalizedStringKey("\(LocalizationHelper.shared.formatTwoDecimals(dist)) km • \(formatTime(time))"))
                            case .duration:
                                let time = exercise.timeSeconds ?? 0
                                Text(LocalizedStringKey("\(exercise.sets) sets • \(formatTime(time))"))
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
                Label(LocalizedStringKey("Add Exercise"), systemImage: "plus")
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
                    Text(LocalizedStringKey("Delete Template"))
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - Logic Helpers
    
    private func savePreset() {
        let newPreset = WorkoutPreset(
            id: preset?.id ?? UUID(),
            name: name,
            icon: selectedIcon,
            exercises: exercises
        )
        viewModel.updatePreset(newPreset)
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
    
    // Локальное время
    @State private var minutes: Int = 0
    @State private var seconds: Int = 0
    
    // Validation alerts
    @State private var showValidationAlert = false
    @State private var validationErrorMessage = ""
    
    // Binding адаптер для веса
    private var weightBindingAdapter: Binding<Double> {
        Binding<Double>(
            get: {
                // Конвертируем из кг в выбранные единицы для отображения
                return unitsManager.convertFromKilograms(exercise.weight)
            },
            set: { newValue in
                // Конвертируем из выбранных единиц в кг для сохранения
                let kgValue = unitsManager.convertToKilograms(newValue)
                let validation = InputValidator.validateWeight(kgValue)
                if !validation.isValid {
                    exercise.weight = validation.clampedValue
                    validationErrorMessage = validation.errorMessage ?? "Invalid weight value"
                    showValidationAlert = true
                } else {
                    exercise.weight = kgValue
                }
            }
        )
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(exercise.name)) {
                    switch exercise.type {
                    case .strength: strengthConfig
                    case .cardio: cardioConfig
                    case .duration: durationConfig
                    }
                }
                
                Button(LocalizedStringKey("Save Changes")) {
                    save()
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(.borderedProminent)
            }
            .navigationTitle(LocalizedStringKey("Configure Preset"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("Cancel")) { dismiss() }
                }
            }
            .onAppear {
                let total = exercise.timeSeconds ?? 0
                minutes = total / 60
                seconds = total % 60
            }
            .alert(LocalizedStringKey("Invalid Input"), isPresented: $showValidationAlert) {
                Button(LocalizedStringKey("OK"), role: .cancel) { }
            } message: {
                Text(validationErrorMessage)
            }
        }
    }
    
    // MARK: - Config Subviews
    
    @ViewBuilder
    private var strengthConfig: some View {
        Stepper(LocalizedStringKey("Sets: \(exercise.sets)"), value: $exercise.sets, in: 1...20)
        Stepper(LocalizedStringKey("Reps: \(exercise.reps)"), value: $exercise.reps, in: 0...100)
            .onChange(of: exercise.reps) { oldValue, newValue in
                let validation = InputValidator.validateReps(newValue)
                if !validation.isValid {
                    exercise.reps = validation.clampedValue
                    validationErrorMessage = validation.errorMessage ?? "Invalid reps value"
                    showValidationAlert = true
                }
            }
        HStack {
            Text(LocalizedStringKey("Weight (\(unitsManager.weightUnitString())):"))
            TextField(LocalizedStringKey("0"), value: weightBindingAdapter, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
        }
    }
    
    @ViewBuilder
    private var cardioConfig: some View {
        HStack {
            Text(LocalizedStringKey("Distance (km):"))
            TextField(LocalizedStringKey("0"), value: Binding(get: { exercise.distance ?? 0 }, set: { newValue in
                let validation = InputValidator.validateDistance(newValue)
                if !validation.isValid {
                    exercise.distance = validation.clampedValue
                    validationErrorMessage = validation.errorMessage ?? "Invalid distance value"
                    showValidationAlert = true
                } else {
                    exercise.distance = validation.clampedValue
                }
            }), format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
        }
        timePickerRow(label: LocalizedStringKey("Duration"))
    }
    
    @ViewBuilder
    private var durationConfig: some View {
        Stepper(LocalizedStringKey("Sets: \(exercise.sets)"), value: $exercise.sets, in: 1...10)
        timePickerRow(label: LocalizedStringKey("Time per set"))
    }
    
    private func timePickerRow(label: LocalizedStringKey) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField(LocalizedStringKey("0"), value: $minutes, format: .number)
                .frame(width: 40).multilineTextAlignment(.center)
                .keyboardType(.numberPad)
                .background(Color.gray.opacity(0.1)).cornerRadius(5)
                .onChange(of: minutes) { oldValue, newValue in
                    let totalSeconds = (newValue * 60) + seconds
                    let validation = InputValidator.validateTime(totalSeconds)
                    if !validation.isValid {
                        let validSeconds = validation.clampedValue
                        minutes = validSeconds / 60
                        seconds = validSeconds % 60
                        validationErrorMessage = validation.errorMessage ?? "Invalid time value"
                        showValidationAlert = true
                    }
                }
            Text(LocalizedStringKey("min"))
            TextField(LocalizedStringKey("0"), value: $seconds, format: .number)
                .frame(width: 40).multilineTextAlignment(.center)
                .keyboardType(.numberPad)
                .background(Color.gray.opacity(0.1)).cornerRadius(5)
                .onChange(of: seconds) { oldValue, newValue in
                    let clampedSeconds = max(0, min(newValue, 59))
                    if clampedSeconds != newValue {
                        seconds = clampedSeconds
                    }
                    let totalSeconds = (minutes * 60) + clampedSeconds
                    let validation = InputValidator.validateTime(totalSeconds)
                    if !validation.isValid {
                        let validSeconds = validation.clampedValue
                        minutes = validSeconds / 60
                        seconds = validSeconds % 60
                        validationErrorMessage = validation.errorMessage ?? "Invalid time value"
                        showValidationAlert = true
                    }
                }
            Text(LocalizedStringKey("sec"))
        }
    }
    
    // MARK: - Logic
    
    private func save() {
        // Final validation before saving
        var hasError = false
        var errorMessages: [String] = []
        
        if exercise.type == .strength {
            let weightValidation = InputValidator.validateWeight(exercise.weight)
            if !weightValidation.isValid {
                hasError = true
                if let error = weightValidation.errorMessage {
                    errorMessages.append(error)
                }
                exercise.weight = weightValidation.clampedValue
            }
            
            let repsValidation = InputValidator.validateReps(exercise.reps)
            if !repsValidation.isValid {
                hasError = true
                if let error = repsValidation.errorMessage {
                    errorMessages.append(error)
                }
                exercise.reps = repsValidation.clampedValue
            }
        }
        
        if exercise.type == .cardio, let distance = exercise.distance {
            let distanceValidation = InputValidator.validateDistance(distance)
            if !distanceValidation.isValid {
                hasError = true
                if let error = distanceValidation.errorMessage {
                    errorMessages.append(error)
                }
                exercise.distance = distanceValidation.clampedValue
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
        
        exercise.timeSeconds = total > 0 ? total : nil
        
        if exercise.type == .cardio { exercise.sets = 1 }
        
        if exercise.type != .strength {
            exercise.weight = 0
            exercise.reps = 0
        }
        
        // Перегенерируем setsList, чтобы шаблон был консистентным
        var newSets: [WorkoutSet] = []
        let setsCount = max(1, exercise.sets)
        
        for i in 1...setsCount {
            newSets.append(WorkoutSet(
                index: i,
                weight: exercise.type == .strength ? exercise.weight : nil,
                reps: exercise.type == .strength ? exercise.reps : nil,
                distance: exercise.type == .cardio ? exercise.distance : nil,
                time: exercise.timeSeconds,
                isCompleted: false,
                type: .normal
            ))
        }
        exercise.setsList = newSets
        
        onSave(exercise)
        dismiss()
    }
}
