//
//  SetRowView.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 24.12.25.
//
//  Строка одного сета в таблице упражнения.
//  Содержит:
//  1. Номер сета.
//  2. Поля ввода (Вес/Повторы/Время) с подсказками из прошлой тренировки.
//  3. Кнопку типа сета (Разминка/Обычный).
//  4. Чекбокс завершения.
//

internal import SwiftUI

struct SetRowView: View {
    
    // MARK: - Bindings & Properties
    
    @Binding var set: WorkoutSet
    @AppStorage("autoStartTimer") private var autoStartTimer: Bool = true
    @StateObject private var unitsManager = UnitsManager.shared
    let exerciseType: ExerciseType
    let isLastSet: Bool
    let isExerciseCompleted: Bool // Флаг завершения упражнения
    let isWorkoutCompleted: Bool // Флаг завершения тренировки
    
    /// Колбэк при завершении сета. Возвращает true, если нужно запустить таймер отдыха.
    var onCheck: (_ shouldStartTimer: Bool) -> Void
    
    // --- Данные прошлой тренировки (Ghost Data) ---
    var prevWeight: Double? = nil
    var prevReps: Int? = nil
    var prevDist: Double? = nil
    var prevTime: Int? = nil
    
    // Состояние для показа слайдера
    @State private var showSliderSheet: Bool = false
    @State private var activePlaceholder: String = ""
    @State private var activeValue: Double? = nil
    @State private var activeBindingType: BindingType = .weight
    
    enum BindingType {
        case weight
        case reps
        case distance
        case time
    }
    
    // MARK: - Computed Bindings (Type Adapters)
    
    // Адаптер Int? <-> Double? для поля повторов
    private var repsBinding: Binding<Double?> {
        Binding<Double?>(
            get: { set.reps.map { Double($0) } },
            set: { newValue in
                if let doubleValue = newValue {
                    let intValue = Int(doubleValue)
                    let validation = InputValidator.validateReps(intValue)
                    set.reps = validation.clampedValue
                } else {
                    set.reps = nil
                }
            }
        )
    }
    
    // Адаптер Int? <-> Double? для поля времени
    private var timeBinding: Binding<Double?> {
        Binding<Double?>(
            get: { set.time.map { Double($0) } },
            set: { newValue in
                if let doubleValue = newValue {
                    let intValue = Int(doubleValue)
                    let validation = InputValidator.validateTime(intValue)
                    set.time = validation.clampedValue
                } else {
                    set.time = nil
                }
            }
        )
    }
    
    // Validated binding for weight (конвертирует между кг и выбранными единицами)
    private var weightBinding: Binding<Double?> {
        Binding<Double?>(
            get: { 
                // Конвертируем из кг в выбранные единицы для отображения
                guard let kg = set.weight else { return nil }
                return unitsManager.convertFromKilograms(kg)
            },
            set: { newValue in
                if let value = newValue {
                    // Конвертируем из выбранных единиц в кг для сохранения
                    let kg = unitsManager.convertToKilograms(value)
                    let validation = InputValidator.validateWeight(kg)
                    set.weight = validation.clampedValue
                } else {
                    set.weight = nil
                }
            }
        )
    }
    
    // Validated binding for distance
    private var distanceBinding: Binding<Double?> {
        Binding<Double?>(
            get: { set.distance },
            set: { newValue in
                if let value = newValue {
                    let validation = InputValidator.validateDistance(value)
                    set.distance = validation.clampedValue
                } else {
                    set.distance = nil
                }
            }
        )
    }

    // MARK: - Body
    
    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            
            // 1. Номер сета
            indexLabel
            
            // 2. Поля ввода (в зависимости от типа)
            inputsSection
            
            // 3. Spacer для центрирования Type
            Spacer(minLength: 0)
            
            // 4. Кнопка типа сета (W/N) - по центру
            setTypeButton
            
            // 5. Spacer для центрирования Type
            Spacer(minLength: 0)
            
            // 6. Чекбокс выполнения
            checkButton
        }
        .padding(.vertical, 4)
        .background(set.isCompleted ? Color.green.opacity(0.05) : Color.clear)
        .cornerRadius(6)
        .disabled(set.isCompleted || isExerciseCompleted || isWorkoutCompleted) // Блокируем ввод, если сет выполнен, упражнение завершено или тренировка завершена
        .sheet(isPresented: $showSliderSheet) {
            SliderSheetView(
                placeholder: activePlaceholder,
                value: getActiveBinding(),
                isPresented: $showSliderSheet
            )
        }
    }
    
    // MARK: - Subviews (Components)
    
    private var indexLabel: some View {
        Text("\(set.index)")
            .font(.subheadline).bold()
            .foregroundColor(.secondary)
            .frame(width: 25)
    }
    
    @ViewBuilder
    private var inputsSection: some View {
        switch exerciseType {
        case .strength:
            // Вес + Повторы
            HStack(spacing: 4) {
                inputColumn(
                    placeholder: unitsManager.weightUnitString(),
                    binding: weightBinding,
                    ghostText: prevWeight.map { 
                        let converted = unitsManager.convertFromKilograms($0)
                        return LocalizationHelper.shared.formatFlexible(converted)
                    }
                )
                
                inputColumn(
                    placeholder: "reps",
                    binding: repsBinding,
                    ghostText: prevReps.map { "\($0)" }
                )
            }
            
        case .cardio:
            // Дистанция + Время
            inputColumn(
                placeholder: "km",
                binding: distanceBinding,
                ghostText: prevDist.map { LocalizationHelper.shared.formatDecimal($0) }
            )
            
            Spacer()
            
            inputColumn(
                placeholder: "min",
                binding: timeBinding,
                ghostText: prevTime.map { formatTime($0) }
            )
            
        case .duration:
            // Только время
            inputColumn(
                placeholder: "sec",
                binding: timeBinding,
                ghostText: prevTime.map { "\($0)s" }
            )
        }
    }
    
    /// Получает параметры слайдера в зависимости от типа поля
    private func getSliderParams(for placeholder: String) -> (min: Double, max: Double, step: Double) {
        switch placeholder {
        case "kg":
            return (0, 200, 0.5)
        case "reps":
            return (0, 50, 1)
        case "km":
            return (0, 50, 0.1)
        case "min", "sec":
            return (0, 300, 1)
        default:
            return (0, 100, 1)
        }
    }
    
    /// Получает активный binding в зависимости от типа
    private func getActiveBinding() -> Binding<Double?> {
        switch activeBindingType {
        case .weight:
            return weightBinding
        case .reps:
            return repsBinding
        case .distance:
            return distanceBinding
        case .time:
            return timeBinding
        }
    }
    
    /// Форматирует значение для отображения
    private func formatValue(_ value: Double?, placeholder: String) -> String {
        guard let value = value, value >= 0 else {
            return placeholder
        }
        
        // Проверяем, является ли placeholder единицей веса
        let weightUnitString = unitsManager.weightUnitString()
        if placeholder == weightUnitString || placeholder == "kg" || placeholder == "lbs" {
            return LocalizationHelper.shared.formatFlexible(value)
        }
        
        switch placeholder {
        case "reps":
            return LocalizationHelper.shared.formatInteger(value)
        case "km":
            return LocalizationHelper.shared.formatDecimal(value)
        case "min", "sec":
            return LocalizationHelper.shared.formatInteger(value)
        default:
            return LocalizationHelper.shared.formatFlexible(value)
        }
    }
    
    /// Универсальная колонка ввода с "призрачным" текстом снизу
    private func inputColumn(placeholder: String, binding: Binding<Double?>, ghostText: String?) -> some View {
        VStack(spacing: 2) {
            Button {
                activePlaceholder = placeholder
                // Определяем тип binding (проверяем и старые, и новые единицы)
                let weightUnitString = unitsManager.weightUnitString()
                if placeholder == weightUnitString || placeholder == "kg" || placeholder == "lbs" {
                    activeBindingType = .weight
                } else if placeholder == "reps" {
                    activeBindingType = .reps
                } else if placeholder == "km" {
                    activeBindingType = .distance
                } else if placeholder == "min" || placeholder == "sec" {
                    activeBindingType = .time
                } else {
                    activeBindingType = .weight
                }
                showSliderSheet = true
            } label: {
                Text(formatValue(binding.wrappedValue, placeholder: placeholder))
                    .font(.headline)
                    .foregroundColor(binding.wrappedValue != nil ? .primary : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }
            .buttonStyle(BorderlessButtonStyle())
            
            if let ghost = ghostText {
                Text(ghost)
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
            }
        }
        .frame(width: 100)
    }
    
    private var setTypeButton: some View {
        Button {
            // Запрещаем изменять тип сета, если упражнение или тренировка завершены
            guard !isExerciseCompleted && !isWorkoutCompleted else { return }
            // Переключение между Normal и Warmup
            set.type = (set.type == .normal) ? .warmup : .normal
        } label: {
            Text(set.type.rawValue)
                .font(.system(size: 12, weight: .bold))
                .frame(width: 32, height: 32)
                .background(set.type.color.opacity(0.8))
                .foregroundColor(set.type == .warmup ? .black : .white)
                .clipShape(Circle())
        }
        .buttonStyle(BorderlessButtonStyle())
        .disabled(isExerciseCompleted || isWorkoutCompleted) // Отключаем кнопку, если упражнение или тренировка завершены
    }
    
    private var checkButton: some View {
        Button(action: toggleComplete) {
            Image(systemName: set.isCompleted ? "checkmark.square.fill" : "square")
                .resizable()
                .frame(width: 32, height: 32)
                .foregroundColor(set.isCompleted ? .green : .gray.opacity(0.5))
        }
        .buttonStyle(BorderlessButtonStyle())
        .disabled(isExerciseCompleted || isWorkoutCompleted) // Отключаем кнопку, если упражнение или тренировка завершены
    }
    
    // MARK: - Logic & Actions
    
    func toggleComplete() {
        // Запрещаем отмечать сеты, если упражнение или тренировка завершены
        guard !isExerciseCompleted && !isWorkoutCompleted else { return }
        
        withAnimation { set.isCompleted.toggle() }
        
        if set.isCompleted {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            if autoStartTimer && !isLastSet {
                onCheck(true) // Запускаем
            } else {
                onCheck(false) // Не запускаем (только сохраняем прогресс)
            }
        }
    }
    
    private func formatTime(_ seconds: Int) -> String {
        return "\(seconds / 60):\(String(format: "%02d", seconds % 60))"
    }
}
