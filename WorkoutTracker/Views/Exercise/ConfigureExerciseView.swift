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
@EnvironmentObject var unitsManager: UnitsManager
    
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
    @State private var weight: Double? = nil
    @State private var distance: Double? = nil
    
    // Время разбито на минуты и секунды для удобства ввода
    @State private var minutes: Int? = 0
    @State private var seconds: Int? = 0
    
    // Validation alerts
    @State private var showValidationAlert = false
    @State private var validationErrorMessage = ""
    
    // НОВОЕ: Для Progressive Overload
    @State private var hasAutoFilled = false
    @State private var showOverloadBanner = false
    @State private var recommendedWeight: Double = 0.0
    
    // MARK: - Binding Adapters
    // Эти вычисляемые свойства нужны для адаптации @State к Binding<Double?>,
    // который требуется компонентом ClearableTextField.
    
    private var weightBinding: Binding<Double?> {
        Binding<Double?>(get: {
            if let w = weight {
                return unitsManager.convertFromKilograms(w)
            }
            return nil
        }, set: { newValue in
            if let value = newValue {
                let kgValue = unitsManager.convertToKilograms(value)
                let validation = InputValidator.validateWeight(kgValue)
                weight = validation.clampedValue
                if !validation.isValid, let error = validation.errorMessage {
                    validationErrorMessage = error
                    showValidationAlert = true
                }
            } else {
                weight = nil
            }
        })
    }
    
    private var distanceBinding: Binding<Double?> {
        Binding<Double?>(get: {
            if let d = distance {
                return unitsManager.convertFromMeters(d)
            }
            return nil
        }, set: { newValue in
            if let value = newValue {
                let mValue = unitsManager.convertToMeters(value)
                let validation = InputValidator.validateDistance(mValue)
                distance = validation.clampedValue
                if !validation.isValid, let error = validation.errorMessage {
                    validationErrorMessage = error
                    showValidationAlert = true
                }
            } else {
                distance = nil
            }
        })
    }
    
    private var minutesBinding: Binding<Double?> {
        Binding<Double?>(get: {
            if let m = minutes { return Double(m) }
            return nil
        }, set: { newValue in
            if let val = newValue {
                let value = Int(val)
                let validation = InputValidator.validateTime(value * 60)
                minutes = max(0, min(value, validation.clampedValue / 60))
                if !validation.isValid, let error = validation.errorMessage {
                    validationErrorMessage = error
                    showValidationAlert = true
                }
            } else {
                minutes = nil
            }
        })
    }
    
    private var secondsBinding: Binding<Double?> {
        Binding<Double?>(get: {
            if let s = seconds { return Double(s) }
            return nil
        }, set: { newValue in
            if let val = newValue {
                let value = Int(val)
                seconds = max(0, min(value, 59))
            } else {
                seconds = nil
            }
        })
    }

    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Form {
                
                // ПРОАКТИВНАЯ РЕКОМЕНДАЦИЯ OVERLOAD
                if showOverloadBanner {
                    overloadBannerSection
                }
                
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
            .onAppear {
                if !hasAutoFilled {
                    loadLastPerformance()
                    hasAutoFilled = true
                }
            }
        }
    }
    
    // MARK: - View Components
    
    private var overloadBannerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundColor(.green)
                    Text("Progressive Overload")
                        .font(.headline)
                        .foregroundColor(.green)
                }
                
                let convertedWeight = unitsManager.convertFromKilograms(recommendedWeight)
                let weightStr = convertedWeight.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", convertedWeight) : String(format: "%.1f", convertedWeight)
                
                Text("Your forecast allows it! Try **\(weightStr) \(unitsManager.weightUnitString())** today for better results.")
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                HStack(spacing: 12) {
                    Button("Discard") {
                        withAnimation {
                            showOverloadBanner = false
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(.gray)
                    .frame(maxWidth: .infinity)
                    
                    Button("Apply") {
                        withAnimation {
                            weight = recommendedWeight
                            showOverloadBanner = false
                        }
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .frame(maxWidth: .infinity)
                }
                .padding(.top, 4)
            }
            .padding(.vertical, 4)
        }
    }
    
    // 1. Силовая конфигурация
    @ViewBuilder
    private var strengthConfig: some View {
        Stepper("Sets: \(sets)", value: $sets, in: 1...20)
        // ИСПРАВЛЕНИЕ: Количество повторений не может быть меньше 1
        Stepper("Reps: \(reps)", value: $reps, in: 1...100)
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
            Text("Distance (\(unitsManager.distanceUnitString())):")
            Spacer()
            ClearableTextField(placeholder: unitsManager.distanceUnitString(), value: distanceBinding)
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
                // Bind directly to the state variables. Let the user type freely.
                ClearableTextField(placeholder: "0", value: Binding(
                    get: { minutes == 0 ? nil : Double(minutes ?? 0) },
                    set: { minutes = Int($0 ?? 0) }
                ))
                .frame(width: 50)
                Text("min")
                
                ClearableTextField(placeholder: "0", value: Binding(
                    get: { seconds == 0 ? nil : Double(seconds ?? 0) },
                    set: { seconds = Int($0 ?? 0) }
                ))
                .frame(width: 50)
                Text("sec")
            }
        }
    }
    
    // MARK: - Logic
    
    private func loadLastPerformance() {
        guard let lastPerf = viewModel.lastPerformancesCache[exerciseName] else { return }
        let lastSets = lastPerf.sortedSets.filter { $0.type != .warmup && $0.isCompleted }
        guard !lastSets.isEmpty else { return }
        
        // Автозаполнение
        if exerciseType == .strength {
            self.sets = lastSets.count
            self.reps = lastSets.first?.reps ?? 10
            
            let lastMax = lastSets.compactMap { $0.weight }.max() ?? 0.0
            self.weight = lastMax > 0 ? lastMax : nil
            
            // Если есть что рекомендовать, показываем баннер
            if lastMax > 0 {
                self.recommendedWeight = lastMax + 2.5
                withAnimation {
                    self.showOverloadBanner = true
                }
            }
            
        } else if exerciseType == .cardio {
            if let firstSet = lastSets.first {
                self.distance = firstSet.distance
                let t = firstSet.time ?? 0
                self.minutes = t / 60
                self.seconds = t % 60
            }
        } else if exerciseType == .duration {
            self.sets = lastSets.count
            if let firstSet = lastSets.first {
                let t = firstSet.time ?? 0
                self.minutes = t / 60
                self.seconds = t % 60
            }
        }
    }
    
    private func handleSave() {
        // Final validation before saving
        var hasError = false
        var errorMessages: [String] = []
        
        let actualWeight = weight ?? 0.0
        let actualDistance = distance ?? 0.0
        let actualMinutes = minutes ?? 0
        let actualSeconds = seconds ?? 0
        
        if exerciseType == .strength {
            // ИСПРАВЛЕНИЕ: Допускаем вес 0 (работа с собственным весом)
            if actualWeight < 0 {
                hasError = true
                errorMessages.append(String(localized: "Weight cannot be negative."))
            } else {
                let weightValidation = InputValidator.validateWeight(actualWeight)
                if !weightValidation.isValid {
                    hasError = true
                    if let error = weightValidation.errorMessage {
                        errorMessages.append(error)
                    }
                    weight = weightValidation.clampedValue
                }
            }
            
            // ИСПРАВЛЕНИЕ: Строгая валидация повторений (должны быть строго больше 0)
            if reps <= 0 {
                hasError = true
                errorMessages.append(String(localized: "Reps must be greater than 0"))
                reps = 1 // Безопасный фоллбэк
            } else {
                let repsValidation = InputValidator.validateReps(reps)
                if !repsValidation.isValid {
                    hasError = true
                    if let error = repsValidation.errorMessage {
                        errorMessages.append(error)
                    }
                    reps = repsValidation.clampedValue
                }
            }
        }
        
        if exerciseType == .cardio {
            let distanceValidation = InputValidator.validateDistance(actualDistance)
            if !distanceValidation.isValid {
                hasError = true
                if let error = distanceValidation.errorMessage {
                    errorMessages.append(error)
                }
                distance = distanceValidation.clampedValue
            }
        }
        
        let totalSeconds = (actualMinutes * 60) + actualSeconds
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
                weight: (exerciseType == .strength) ? actualWeight : nil,
                reps: (exerciseType == .strength) ? reps : nil,
                distance: (exerciseType == .cardio) ? actualDistance : nil,
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
            weight: actualWeight,
            distance: (exerciseType == .cardio) ? actualDistance : nil,
            timeSeconds: (totalSeconds > 0) ? totalSeconds : nil,
            effort: 5,
            setsList: generatedSets // <-- Передаем сгенерированный список
        )
        
        // ИСПРАВЛЕНИЕ: Легкая вибрация, подтверждающая успешное добавление упражнения в тренировку
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        onAdd(newExercise)
        dismiss()
    }
}
