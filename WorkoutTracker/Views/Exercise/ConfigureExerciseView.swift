//
//  ConfigureExerciseView.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 24.12.25.
//
//  Экран первоначальной настройки упражнения перед добавлением в тренировку.
//  Позволяет задать количество подходов, повторений, вес или время/дистанцию.
//  На основе этих данных генерируется начальный список сетов.
//

internal import SwiftUI

struct ConfigureExerciseView: View {
    
    // MARK: - Environment
    
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var viewModel: WorkoutViewModel
    @StateObject private var unitsManager = UnitsManager.shared
    
    // MARK: - Input Parameters
    
    let exerciseName: String
    let muscleGroup: String
    var exerciseType: ExerciseType = .strength
    
    /// Замыкание для возврата созданного упражнения
    var onAdd: (Exercise) -> Void
    
    // MARK: - Local State
    
    // Значения по умолчанию
    @State private var sets = 3
    @State private var reps = 10
    @State private var weight = 0.0
    @State private var distance = 0.0
    
    // Время разбито на минуты и секунды для удобства ввода
    @State private var minutes = 0
    @State private var seconds = 0
    
    // Validation alerts
    @State private var showValidationAlert = false
    @State private var validationErrorMessage = ""
    
    // MARK: - Binding Adapters
    // Эти вычисляемые свойства нужны для адаптации @State (non-optional)
    // к Binding<Double?>, который требуется компонентом ClearableTextField.
    
    private var weightBinding: Binding<Double?> {
        Binding<Double?>(get: { 
            // Конвертируем из кг в выбранные единицы для отображения
            return unitsManager.convertFromKilograms(weight)
        }, set: { newValue in
            let value = newValue ?? 0
            // Конвертируем из выбранных единиц в кг для сохранения
            let kgValue = unitsManager.convertToKilograms(value)
            let validation = InputValidator.validateWeight(kgValue)
            weight = validation.clampedValue
            if !validation.isValid, let error = validation.errorMessage {
                validationErrorMessage = error
                showValidationAlert = true
            }
        })
    }
    
    private var distanceBinding: Binding<Double?> {
        Binding<Double?>(get: { distance }, set: { newValue in
            let value = newValue ?? 0
            let validation = InputValidator.validateDistance(value)
            distance = validation.clampedValue
            if !validation.isValid, let error = validation.errorMessage {
                validationErrorMessage = error
                showValidationAlert = true
            }
        })
    }
    
    private var minutesBinding: Binding<Double?> {
        Binding<Double?>(get: { Double(minutes) }, set: { newValue in
            let value = Int(newValue ?? 0)
            let validation = InputValidator.validateTime(value * 60)
            minutes = max(0, min(value, validation.clampedValue / 60))
            if !validation.isValid, let error = validation.errorMessage {
                validationErrorMessage = error
                showValidationAlert = true
            }
        })
    }
    
    private var secondsBinding: Binding<Double?> {
        Binding<Double?>(get: { Double(seconds) }, set: { newValue in
            let value = Int(newValue ?? 0)
            seconds = max(0, min(value, 59))
        })
    }

    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Form {
                // Основная секция настроек
                Section(header: Text("Configuration")) {
                    // Заголовок с именем упражнения
                    HStack {
                        Text("Exercise")
                        Spacer()
                        Text(exerciseName).bold()
                    }
                    
                    // Контент в зависимости от типа упражнения
                    switch exerciseType {
                    case .strength:
                        strengthConfig
                    case .cardio:
                        cardioConfig
                    case .duration:
                        durationConfig
                    }
                }
                
                // Кнопка действия
                Button("Add Exercise") {
                    handleSave()
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(.borderedProminent)
            }
            .navigationTitle("Configure")
            .alert("Invalid Input", isPresented: $showValidationAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(validationErrorMessage)
            }
        }
    }
    
    // MARK: - View Components
    
    // 1. Силовая конфигурация
    @ViewBuilder
    private var strengthConfig: some View {
        Stepper("Sets: \(sets)", value: $sets, in: 1...20)
        Stepper("Reps: \(reps)", value: $reps, in: 0...100)
            .onChange(of: reps) { oldValue, newValue in
                let validation = InputValidator.validateReps(newValue)
                if !validation.isValid {
                    reps = validation.clampedValue
                    validationErrorMessage = validation.errorMessage ?? String(localized: "Invalid reps value")
                    showValidationAlert = true
                }
            }
        
        HStack {
            Text("Weight (\(unitsManager.weightUnitString())):")
            Spacer()
            ClearableTextField(placeholder: unitsManager.weightUnitString(), value: weightBinding)
                .frame(width: 80)
        }
    }
    
    // 2. Кардио конфигурация
    @ViewBuilder
    private var cardioConfig: some View {
        HStack {
            Text("Distance (km):")
            Spacer()
            ClearableTextField(placeholder: "km", value: distanceBinding)
                .frame(width: 80)
        }
        timePickerRow(label: "Duration")
    }
    
    // 3. Конфигурация на время
    @ViewBuilder
    private var durationConfig: some View {
        Stepper("Sets: \(sets)", value: $sets, in: 1...10)
        timePickerRow(label: "Time per set")
    }
    
    // Вспомогательная строка для ввода времени (Мин : Сек)
    private func timePickerRow(label: String) -> some View {
        HStack {
            Text(LocalizedStringKey(label))
            Spacer()
            HStack(spacing: 5) {
                ClearableTextField(placeholder: "0", value: minutesBinding)
                    .frame(width: 50)
                Text("min")
                
                ClearableTextField(placeholder: "0", value: secondsBinding)
                    .frame(width: 50)
                Text("sec")
            }
        }
    }
    
    // MARK: - Logic
    
    private func handleSave() {
        // Final validation before saving
        var hasError = false
        var errorMessages: [String] = []
        
        if exerciseType == .strength {
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
        
        if exerciseType == .cardio {
            let distanceValidation = InputValidator.validateDistance(distance)
            if !distanceValidation.isValid {
                hasError = true
                if let error = distanceValidation.errorMessage {
                    errorMessages.append(error)
                }
                distance = distanceValidation.clampedValue
            }
        }
        
        let totalSeconds = (minutes * 60) + seconds
        if totalSeconds > 0 {
            let timeValidation = InputValidator.validateTime(totalSeconds)
            if !timeValidation.isValid {
                hasError = true
                if let error = timeValidation.errorMessage {
                    errorMessages.append(error)
                }
                // Adjust minutes and seconds to valid range
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
        
        // Для кардио всегда считаем как 1 подход, для остальных берем из степпера
        let setsCount = (exerciseType == .cardio) ? 1 : sets
        
        // Генерация начальных сетов на основе введенных данных
        var generatedSets: [WorkoutSet] = []
        for i in 1...setsCount {
            generatedSets.append(WorkoutSet(
                index: i,
                weight: (exerciseType == .strength) ? weight : nil,
                reps: (exerciseType == .strength) ? reps : nil,
                distance: (exerciseType == .cardio) ? distance : nil,
                time: (totalSeconds > 0) ? totalSeconds : nil,
                isCompleted: false,
                type: .normal
            ))
        }
        
        // Создаем объект упражнения
        let newExercise = Exercise(
            name: exerciseName,
            muscleGroup: muscleGroup,
            type: exerciseType,
            sets: setsCount,
            reps: reps,
            weight: weight,
            distance: (exerciseType == .cardio) ? distance : nil,
            timeSeconds: (totalSeconds > 0) ? totalSeconds : nil,
            effort: 5,
            setsList: generatedSets // <-- Передаем сгенерированный список
        )
        
        onAdd(newExercise)
        dismiss()
    }
}
