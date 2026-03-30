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
@EnvironmentObject var unitsManager: UnitsManager
    
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
            .navigationTitle(preset == nil ? String(localized: "New Template") : String(localized: "Edit Template"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Save")) {
                        savePreset()
                    }
                    .disabled(name.isEmpty || exercises.isEmpty)
                }
            }
            // Алерт удаления шаблона
            .alert(String(localized: "Delete Template?"), isPresented: $showDeleteAlert) {
                Button(String(localized: "Delete"), role: .destructive) {
                    if let p = preset {
                        context.delete(p)
                        dismiss()
                    }
                }
                Button(String(localized: "Cancel"), role: .cancel) { }
            } message: {
                Text(String(localized: "Are you sure you want to delete '\(name)'? This action cannot be undone."))
            }
            // Алерт удаления упражнения
            .alert(String(localized: "Delete Exercise?"), isPresented: $showDeleteExerciseAlert) {
                Button(String(localized: "Delete"), role: .destructive) {
                    if let indexSet = exercisesToDelete {
                        exercises.remove(atOffsets: indexSet)
                        exercisesToDelete = nil
                    }
                }
                Button(String(localized: "Cancel"), role: .cancel) {
                    exercisesToDelete = nil
                }
            } message: {
                if let indexSet = exercisesToDelete {
                    let count = indexSet.count
                    if count == 1, let firstIndex = indexSet.first, firstIndex < exercises.count {
                        let exName = exercises[firstIndex].name
                        Text(String(localized: "Are you sure you want to delete '\(exName)'? This action cannot be undone."))
                    } else {
                        Text(String(localized: "Are you sure you want to delete \(count) exercises? This action cannot be undone."))
                    }
                } else {
                    Text(String(localized: "Are you sure you want to delete this exercise? This action cannot be undone."))
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
        Section(header: Text(String(localized: "Template Info"))) {
            TextField(String(localized: "Template Name"), text: $name)
            
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
        Section(header: Text(String(localized: "Exercises"))) {
            if exercises.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    
                    Text(String(localized: "No exercises yet"))
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(String(localized: "Tap the button below to add your first exercise to this template"))
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
                        Text(exercise.name).font(.headline)
                        
                        Group {
                            switch exercise.type {
                            case .strength:
                                let convertedWeight = unitsManager.convertFromKilograms(exercise.firstSetWeight)
                                Text("\(exercise.setsCount) x \(exercise.firstSetReps) • \(Int(convertedWeight))\(unitsManager.weightUnitString())")
                            case .cardio:
                                let dist = exercise.firstSetDistance ?? 0
                                let convertedDist = unitsManager.convertFromMeters(dist)
                                let time = exercise.firstSetTimeSeconds ?? 0
                                Text("\(LocalizationHelper.shared.formatTwoDecimals(convertedDist)) \(unitsManager.distanceUnitString()) • \(formatTime(time))")
                            case .duration:
                                let time = exercise.firstSetTimeSeconds ?? 0
                                Text("\(exercise.setsCount) sets • \(formatTime(time))")
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
                Label(String(localized: "Add Exercise"), systemImage: "plus")
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
                    Text(String(localized: "Delete Template"))
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
                
                // Очищаем старые и добавляем новые, чтобы SwiftData понял изменения
                existingPreset.exercises.removeAll()
                for ex in exercises {
                    if ex.modelContext == nil { context.insert(ex) }
                    ex.preset = existingPreset
                    existingPreset.exercises.append(ex)
                }
            } else {
                // Создаем новый
                let newPreset = WorkoutPreset(
                    id: UUID(),
                    name: name,
                    icon: selectedIcon,
                    exercises: []
                )
                context.insert(newPreset)
                
                for ex in exercises {
                    context.insert(ex)
                    ex.preset = newPreset
                    newPreset.exercises.append(ex)
                }
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
    // ИСПРАВЛЕНИЕ: Используем let для объекта SwiftData, чтобы избежать конфликтов Binding.
    let exercise: Exercise
    var onSave: (Exercise) -> Void
    @Environment(\.dismiss) var dismiss
@EnvironmentObject var unitsManager: UnitsManager
    
    // Локальное состояние для редактирования
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
                Section(header: Text(exercise.name)) {
                    switch exercise.type {
                    case .strength: strengthConfig
                    case .cardio: cardioConfig
                    case .duration: durationConfig
                    }
                }
                
                Button(String(localized: "Save Changes")) {
                    save()
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(.borderedProminent)
            }
            .navigationTitle(String(localized: "Configure Preset"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) { dismiss() }
                }
            }
            .onAppear {
                // Инициализация локальных состояний при открытии из новых агрегатов
                setsCount = exercise.setsCount > 0 ? exercise.setsCount : 1
                repsCount = exercise.firstSetReps
                weightValue = exercise.firstSetWeight
                distanceValue = exercise.firstSetDistance
                
                let total = exercise.firstSetTimeSeconds ?? 0
                minutes = total / 60
                seconds = total % 60
            }
            .alert(String(localized: "Invalid Input"), isPresented: $showValidationAlert) {
                Button(String(localized: "OK"), role: .cancel) { }
            } message: {
                Text(validationErrorMessage)
            }
        }
    }
    
    // MARK: - Config Subviews
    
    @ViewBuilder
    private var strengthConfig: some View {
        Stepper(String(localized: "Sets: \(setsCount)"), value: $setsCount, in: 1...20)
        Stepper(String(localized: "Reps: \(repsCount)"), value: $repsCount, in: 0...100)
        HStack {
            Text(String(localized: "Weight (\(unitsManager.weightUnitString())):"))
            TextField("0", value: weightBindingAdapter, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
        }
    }
    
    @ViewBuilder
    private var cardioConfig: some View {
        HStack {
            Text(String(localized: "Distance (\(unitsManager.distanceUnitString())):"))
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
        Stepper(String(localized: "Sets: \(setsCount)"), value: $setsCount, in: 1...10)
        timePickerRow(label: "Time per set")
    }
    
    private func timePickerRow(label: String) -> some View {
        HStack {
            Text(String(localized: String.LocalizationValue(label)))
            Spacer()
            TextField("0", value: $minutes, format: .number)
                .frame(width: 40).multilineTextAlignment(.center)
                .keyboardType(.numberPad)
                .background(Color.gray.opacity(0.1)).cornerRadius(5)
            Text(String(localized: "min"))
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
            Text(String(localized: "sec"))
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
        exercise.updateAggregates() // Обновляем агрегаты сразу, чтобы UI отрисовал изменения
        onSave(exercise)
        dismiss()
    }
}
