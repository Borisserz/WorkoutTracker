//
//  EditExerciseView.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 24.12.25.
//
//  Экран редактирования параметров уже добавленного упражнения.
//  Использует локальные @State переменные как буфер, чтобы изменения
//  применялись к основной модели только при нажатии "Save".
//

internal import SwiftUI

struct EditExerciseView: View {
    
    // MARK: - Environment & Bindings
    
    @Environment(\.dismiss) var dismiss
    @StateObject private var unitsManager = UnitsManager.shared
    
    /// Ссылка на упражнение в родительском списке (основной источник истины)
    @Binding var exercise: Exercise
    
    // MARK: - Local State (Edit Buffer)
    
    @State private var sets: Int
    @State private var reps: Int
    @State private var weight: Double  // Хранится в кг
    @State private var effort: Int
    
    // Поля для кардио и времени
    @State private var distance: Double
    @State private var minutes: Int
    @State private var seconds: Int
    
    // Validation alerts
    @State private var showValidationAlert = false
    @State private var validationErrorMessage = ""
    
    // MARK: - Init
    
    init(exercise: Binding<Exercise>) {
        self._exercise = exercise
        
        // Инициализируем локальные State значениями из переданного упражнения.
        // Это позволяет редактировать данные, не меняя оригинал до нажатия Save.
        
        // Силовые параметры
        _sets = State(initialValue: exercise.wrappedValue.sets)
        _reps = State(initialValue: exercise.wrappedValue.reps)
        _weight = State(initialValue: exercise.wrappedValue.weight)
        _effort = State(initialValue: exercise.wrappedValue.effort)
        
        // Кардио параметры
        _distance = State(initialValue: exercise.wrappedValue.distance ?? 0.0)
        
        // Время (разбиваем секунды на минуты и секунды)
        let totalSeconds = exercise.wrappedValue.timeSeconds ?? 0
        _minutes = State(initialValue: totalSeconds / 60)
        _seconds = State(initialValue: totalSeconds % 60)
    }
    
    // MARK: - Computed Bindings
    
    private var weightBinding: Binding<Double> {
        Binding<Double>(
            get: {
                // Конвертируем из кг в выбранные единицы для отображения
                return UnitsManager.shared.convertFromKilograms(weight)
            },
            set: { newValue in
                // Конвертируем из выбранных единиц в кг для сохранения
                let kgValue = UnitsManager.shared.convertToKilograms(newValue)
                let validation = InputValidator.validateWeight(kgValue)
                if !validation.isValid {
                    weight = validation.clampedValue
                    validationErrorMessage = validation.errorMessage ?? "Invalid weight value"
                    showValidationAlert = true
                } else {
                    weight = kgValue
                }
            }
        )
    }
    
    // MARK: - Body
    
    var body: some View {
        Form {
            // 1. Основные настройки (Сеты, Вес, Время)
            configSection
            
            // 2. Настройка RPE (Усилия)
            effortSection
            
            // 3. Кнопка сохранения
            saveButton
        }
        .navigationTitle(LocalizedStringKey("Edit Exercise"))
        .alert(LocalizedStringKey("Invalid Input"), isPresented: $showValidationAlert) {
            Button(LocalizedStringKey("OK"), role: .cancel) { }
        } message: {
            Text(validationErrorMessage)
        }
    }
    
    // MARK: - View Components
    
    private var configSection: some View {
        Section(header: Text(LocalizedStringKey("Configuration"))) {
            // Заголовок
            HStack {
                Text(LocalizedStringKey("Exercise"))
                Spacer()
                Text(exercise.name).bold()
            }
            
            // Поля в зависимости от типа
            switch exercise.type {
            case .strength:
                strengthConfig
            case .cardio:
                cardioConfig
            case .duration:
                durationConfig
            }
        }
    }
    
    @ViewBuilder
    private var strengthConfig: some View {
        Stepper(LocalizedStringKey("Sets: \(sets)"), value: $sets, in: 1...20)
        Stepper(LocalizedStringKey("Reps: \(reps)"), value: $reps, in: 0...100)
            .onChange(of: reps) { oldValue, newValue in
                let validation = InputValidator.validateReps(newValue)
                if !validation.isValid {
                    reps = validation.clampedValue
                    validationErrorMessage = validation.errorMessage ?? "Invalid reps value"
                    showValidationAlert = true
                }
            }
        HStack {
            Text(LocalizedStringKey("Weight (\(unitsManager.weightUnitString())):"))
            TextField(LocalizedStringKey("0"), value: weightBinding, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
        }
    }
    
    @ViewBuilder
    private var cardioConfig: some View {
        HStack {
            Text(LocalizedStringKey("Distance (km):"))
            TextField(LocalizedStringKey("0"), value: $distance, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .onChange(of: distance) { oldValue, newValue in
                    let validation = InputValidator.validateDistance(newValue)
                    if !validation.isValid {
                        distance = validation.clampedValue
                        validationErrorMessage = validation.errorMessage ?? "Invalid distance value"
                        showValidationAlert = true
                    }
                }
        }
        timePickerRow(label: LocalizedStringKey("Duration"))
    }
    
    @ViewBuilder
    private var durationConfig: some View {
        Stepper(LocalizedStringKey("Sets: \(sets)"), value: $sets, in: 1...10)
        timePickerRow(label: LocalizedStringKey("Time per set"))
    }
    
    private var effortSection: some View {
        Section(header: Text(LocalizedStringKey("Effort (RPE)"))) {
            HStack {
                Text("\(effort)/10")
                    .bold()
                    .foregroundColor(effortColor(effort))
                
                Slider(value: Binding(get: { Double(effort) }, set: { effort = Int($0) }), in: 1...10, step: 1)
                    .tint(effortColor(effort))
            }
            Text(LocalizedStringKey("1 = Easy, 10 = Failure"))
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var saveButton: some View {
        Button(LocalizedStringKey("Save Changes")) {
            save()
        }
        .frame(maxWidth: .infinity)
        .buttonStyle(.borderedProminent)
    }
    
    // Вспомогательная строка ввода времени
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
    
    // MARK: - Logic / Helpers
    
    private func save() {
        // Final validation before saving
        var hasError = false
        var errorMessages: [String] = []
        
        if exercise.type == .strength {
            let weightValidation = InputValidator.validateWeight(weight)
            if !weightValidation.isValid {
                hasError = true
                if let error = weightValidation.errorMessage {
                    errorMessages.append(error)
                }
                weight = weightValidation.clampedValue
            }
            
            let repsValidation = InputValidator.validateReps(reps)
            if !repsValidation.isValid {
                hasError = true
                if let error = repsValidation.errorMessage {
                    errorMessages.append(error)
                }
                reps = repsValidation.clampedValue
            }
        }
        
        if exercise.type == .cardio {
            let distanceValidation = InputValidator.validateDistance(distance)
            if !distanceValidation.isValid {
                hasError = true
                if let error = distanceValidation.errorMessage {
                    errorMessages.append(error)
                }
                distance = distanceValidation.clampedValue
            }
        }
        
        var totalSec = (minutes * 60) + seconds
        if totalSec > 0 {
            let timeValidation = InputValidator.validateTime(totalSec)
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
        
        // Применяем локальные изменения к основной модели
        exercise.sets = (exercise.type == .cardio) ? 1 : sets
        exercise.reps = (exercise.type == .strength) ? reps : 0
        exercise.weight = (exercise.type == .strength) ? weight : 0
        exercise.effort = effort
        
        exercise.distance = (exercise.type == .cardio) ? distance : nil
        
        // Recalculate totalSec in case minutes/seconds were modified during validation
        totalSec = (minutes * 60) + seconds
        exercise.timeSeconds = (totalSec > 0) ? totalSec : nil
        
        dismiss()
    }
    
    private func effortColor(_ value: Int) -> Color {
        switch value {
        case 1...4: return .green
        case 5...7: return .orange
        case 8...10: return .red
        default: return .blue
        }
    }
}
