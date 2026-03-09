//
//  SliderInputView.swift
//  WorkoutTracker
//
//  Компонент для ввода числовых значений с помощью слайдера и кнопок +/-.
//  Используется для удобного изменения веса и повторений во время тренировки.
//

internal import SwiftUI

// MARK: - Types

/// Тип поля ввода для точной привязки логики без использования хардкод-строк (плейсхолдеров)
enum InputFieldType: Equatable {
    case weight
    case reps
    case distance
    case timeMin
    case timeSec
    
    /// Локализованный плейсхолдер для отображения в UI
    func title(unitsManager: UnitsManager) -> String {
        switch self {
        case .weight: return unitsManager.weightUnitString()
        case .reps: return String(localized: "reps")
        case .distance: return unitsManager.distanceUnitString()
        case .timeMin: return String(localized: "min")
        case .timeSec: return String(localized: "sec")
        }
    }
}

// MARK: - Slider Sheet View (Модальное окно со слайдером)

struct SliderSheetView: View {
    let fieldType: InputFieldType
    @Binding var value: Double?
    @Binding var isPresented: Bool
    
    @StateObject private var unitsManager = UnitsManager.shared
    
    // Локальное состояние для слайдера - обновляется мгновенно без валидации
    @State private var localValue: Double = 0
    @State private var textValue: String = ""
    @FocusState private var isBigTextFocused: Bool
    
    // Ошибки валидации
    @State private var errorMessage: String? = nil
    
    // Кэшированные параметры слайдера (вычисляются один раз)
    @State private var params: (min: Double, max: Double, step: Double) = (0, 100, 1)
    
    private var navigationTitleText: LocalizedStringKey {
        switch fieldType {
        case .weight: return "Adjust Weight"
        case .reps: return "Adjust Reps"
        case .distance: return "Adjust Distance"
        case .timeMin, .timeSec: return "Adjust Time"
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                // Текущее значение
                VStack(spacing: 8) {
                    Text(fieldType.title(unitsManager: unitsManager).uppercased())
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // Заменили Text на TextField для быстрого ручного ввода
                    TextField("0", text: $textValue)
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(errorMessage != nil ? .red : .primary)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .focused($isBigTextFocused)
                        .onChange(of: isBigTextFocused) { _, focused in
                            if focused && localValue == 0 {
                                textValue = ""
                            } else if !focused {
                                textValue = formatValue(localValue)
                            }
                        }
                        .onChange(of: textValue) { _, newText in
                            if isBigTextFocused {
                                // Защита от запятых (в некоторых локалях они ломают конвертацию)
                                let cleanStr = newText.replacingOccurrences(of: ",", with: ".")
                                if let val = Double(cleanStr) {
                                    validateValue(val)
                                    localValue = val // Позволяем UI обновиться, даже если значение ошибочно
                                    
                                    // Динамически расширяем лимит слайдера, если ввели больше руками
                                    if errorMessage == nil && val > params.max {
                                        params.max = val
                                    }
                                } else if newText.isEmpty {
                                    localValue = 0
                                    errorMessage = nil
                                }
                            }
                        }
                        .onChange(of: localValue) { _, newVal in
                            if !isBigTextFocused {
                                textValue = formatValue(newVal)
                            }
                        }
                    
                    // Показ текста ошибки под полем
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .animation(.easeInOut, value: errorMessage)
                    }
                }
                .padding(.top, 40)
                
                // Кнопки +/- и слайдер
                VStack(spacing: 20) {
                    // Кнопки быстрого изменения
                    HStack(spacing: 30) {
                        // Кнопка уменьшения
                        Button(action: decrement) {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        
                        // Кнопка увеличения
                        Button(action: increment) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
                    
                    // Слайдер с оптимизированным обновлением (onEditingChanged)
                    VStack(spacing: 8) {
                        Slider(
                            value: $localValue,
                            in: params.min...params.max,
                            step: params.step
                        ) { editing in
                            // Когда пользователь ОТПУСКАЕТ палец (editing == false),
                            // мы передаем значение в модель (сохраняем)
                            if !editing {
                                validateValue(localValue)
                                updateBindingValue(localValue)
                            }
                        }
                        .tint(errorMessage != nil ? .red : .blue)
                        
                        HStack {
                            Text("\(Int(params.min))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(Int(params.max))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle(navigationTitleText)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    // Блокируем кнопку "Сохранить", если есть ошибка
                    Button(LocalizedStringKey("Done")) {
                        isBigTextFocused = false
                        // При закрытии сохраняем финальное значение
                        updateBindingValue(localValue)
                        isPresented = false
                    }
                    .disabled(errorMessage != nil)
                }
            }
        }
        .presentationDetents([.medium])
        .onAppear {
            // Инициализируем локальное значение при появлении
            localValue = value ?? 0
            
            // Кэшируем параметры слайдера один раз при появлении, основываясь на Enum
            switch fieldType {
            case .weight:
                // Для фунтов увеличиваем максимальный вес до 440 (примерно 200 кг)
                params = (0, unitsManager.weightUnit == .pounds ? 440 : 200, 0.5)
            case .reps:
                params = (0, 50, 1)
            case .distance:
                params = (0, unitsManager.distanceUnit == .miles ? 30 : 50, 0.1)
            case .timeMin, .timeSec:
                params = (0, 300, 1)
            }
            
            // Если в истории был сохранен больший вес, подстраиваем ползунок под него
            if localValue > params.max {
                params.max = localValue
            }
            
            textValue = formatValue(localValue)
        }
        .onDisappear {
            // На всякий случай сохраняем при скрытии шторки смахиванием вниз, только если нет ошибки
            updateBindingValue(localValue)
        }
    }
    
    // MARK: - Validation
    
    private func validateValue(_ val: Double) {
        let isValid: Bool
        let errMsg: String?
        
        switch fieldType {
        case .weight:
            let kg = unitsManager.convertToKilograms(val)
            let v = InputValidator.validateWeight(kg)
            isValid = v.isValid; errMsg = v.errorMessage
        case .reps:
            let v = InputValidator.validateReps(Int(val))
            isValid = v.isValid; errMsg = v.errorMessage
        case .distance:
            let km = unitsManager.convertToKilometers(val)
            let v = InputValidator.validateDistance(km)
            isValid = v.isValid; errMsg = v.errorMessage
        case .timeMin:
            let v = InputValidator.validateTime(Int(val) * 60)
            isValid = v.isValid; errMsg = v.errorMessage
        case .timeSec:
            let v = InputValidator.validateTime(Int(val))
            isValid = v.isValid; errMsg = v.errorMessage
        }
        
        self.errorMessage = errMsg
    }
    
    // Обновляет binding с валидацией
    private func updateBindingValue(_ newValue: Double) {
        guard errorMessage == nil else { return } // Не сохраняем невалидные значения!
        let validated = max(params.min, newValue)
        value = validated > 0 ? validated : nil
    }
    
    private func increment() {
        let newValue = localValue + params.step // Позволяем увеличивать без искусственного максимума от слайдера
        localValue = newValue
        validateValue(newValue)
        if errorMessage == nil && newValue > params.max {
            params.max = newValue
        }
    }
    
    private func decrement() {
        let newValue = max(localValue - params.step, params.min)
        localValue = newValue
        validateValue(newValue)
    }
    
    private func formatValue(_ val: Double) -> String {
        if val < 0 {
            return "—"
        }
        let step = params.step
        if step < 1 {
            return LocalizationHelper.shared.formatDecimal(val)
        } else {
            return LocalizationHelper.shared.formatInteger(val)
        }
    }
}

// MARK: - Slider Input View (Компактный компонент для встроенного использования)

struct SliderInputView: View {
    let fieldType: InputFieldType
    @Binding var value: Double?
    
    @StateObject private var unitsManager = UnitsManager.shared
    
    // Параметры слайдера
    let minValue: Double
    let maxValue: Double
    let step: Double
    
    @State private var dynamicMaxValue: Double
    @State private var errorMessage: String? = nil
    
    // Состояние для отслеживания фокуса текстового поля (для ручного ввода)
    @FocusState private var isFocused: Bool
    @State private var textValue: String = ""
    
    // Локальное, быстрое состояние для UI
    @State private var sliderDoubleValue: Double = 0
    @State private var updateTask: Task<Void, Never>? = nil
    
    init(
        fieldType: InputFieldType,
        value: Binding<Double?>,
        minValue: Double = 0,
        maxValue: Double = 200,
        step: Double = 1
    ) {
        self.fieldType = fieldType
        self._value = value
        self.minValue = minValue
        self.maxValue = maxValue
        self.step = step
        self._dynamicMaxValue = State(initialValue: maxValue)
    }
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Button(action: decrement) {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                .buttonStyle(BorderlessButtonStyle())
                
                TextField(fieldType.title(unitsManager: unitsManager), text: $textValue)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .font(.headline)
                    .frame(width: 50)
                    .foregroundColor(errorMessage != nil ? .red : .primary)
                    .focused($isFocused)
                    .onChange(of: isFocused) { _, focused in
                        if focused && sliderDoubleValue == 0 {
                            textValue = "" // Очищаем 0 при фокусе
                        } else if !focused {
                            updateTextValue() // Возвращаем форматированное значение при потере фокуса
                        }
                    }
                    .onChange(of: textValue) { oldValue, newValue in
                        let cleanStr = newValue.replacingOccurrences(of: ",", with: ".")
                        if let num = Double(cleanStr) {
                            sliderDoubleValue = num
                            validateAndCommit(num)
                            if errorMessage == nil && num > dynamicMaxValue {
                                dynamicMaxValue = num
                            }
                        } else if newValue.isEmpty {
                            sliderDoubleValue = 0
                            errorMessage = nil
                            commitValueWithDebounce(0)
                        }
                    }
                    .onChange(of: value) { oldValue, newValue in
                        // Внешнее изменение (например, загрузка из модели)
                        if let newValue = newValue {
                            if !isFocused {
                                textValue = formatValue(newValue)
                            }
                            sliderDoubleValue = newValue
                            if newValue > dynamicMaxValue {
                                dynamicMaxValue = newValue
                            }
                        } else {
                            if !isFocused {
                                textValue = ""
                            }
                            sliderDoubleValue = 0
                        }
                    }
                    .onAppear {
                        if let val = value {
                            textValue = formatValue(val)
                            sliderDoubleValue = val
                            if val > dynamicMaxValue {
                                dynamicMaxValue = val
                            }
                        } else {
                            sliderDoubleValue = 0
                        }
                    }
                
                Button(action: increment) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                    }
                .buttonStyle(BorderlessButtonStyle())
            }
            
            Slider(
                value: $sliderDoubleValue,
                in: minValue...dynamicMaxValue,
                step: step
            ) { editing in
                // Когда пользователь ОТПУСКАЕТ палец, передаем данные наверх
                if !editing {
                    validateAndCommit(sliderDoubleValue, immediate: true)
                    updateTextValue()
                } else {
                    // Пока тянет, просто обновляем текст без сохранения
                    textValue = formatValue(sliderDoubleValue)
                }
            }
            .tint(errorMessage != nil ? .red : .blue)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        .onDisappear {
            updateTask?.cancel()
            if errorMessage == nil {
                value = sliderDoubleValue > 0 ? sliderDoubleValue : nil
            }
        }
    }
    
    private func validateAndCommit(_ num: Double, immediate: Bool = false) {
        let isValid: Bool
        let errMsg: String?
        
        switch fieldType {
        case .weight:
            let kg = unitsManager.convertToKilograms(num)
            let v = InputValidator.validateWeight(kg)
            isValid = v.isValid; errMsg = v.errorMessage
        case .reps:
            let v = InputValidator.validateReps(Int(num))
            isValid = v.isValid; errMsg = v.errorMessage
        case .distance:
            let km = unitsManager.convertToKilometers(num)
            let v = InputValidator.validateDistance(km)
            isValid = v.isValid; errMsg = v.errorMessage
        case .timeMin:
            let v = InputValidator.validateTime(Int(num) * 60)
            isValid = v.isValid; errMsg = v.errorMessage
        case .timeSec:
            let v = InputValidator.validateTime(Int(num))
            isValid = v.isValid; errMsg = v.errorMessage
        }
        
        self.errorMessage = errMsg
        
        if isValid {
            commitValueWithDebounce(num, immediate: immediate)
        } else {
            updateTask?.cancel() // Отменяем сохранение невалидного значения
        }
    }
    
    // Сохранение с задержкой, чтобы не лагало при быстром кликаньи "плюсов"
    private func commitValueWithDebounce(_ newValue: Double, immediate: Bool = false) {
        updateTask?.cancel()
        
        if immediate {
            value = newValue > 0 ? newValue : nil
            return
        }
        
        updateTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // Ждем 0.3 секунды
            if !Task.isCancelled {
                await MainActor.run {
                    value = newValue > 0 ? newValue : nil
                }
            }
        }
    }
    
    private func increment() {
        let current = sliderDoubleValue
        let newValue = current + step
        sliderDoubleValue = newValue
        if newValue > dynamicMaxValue {
            dynamicMaxValue = newValue
        }
        updateTextValue()
        validateAndCommit(newValue)
    }
    
    private func decrement() {
        let current = sliderDoubleValue
        let newValue = max(current - step, minValue)
        sliderDoubleValue = newValue
        updateTextValue()
        validateAndCommit(newValue)
    }
    
    private func updateTextValue() {
        if sliderDoubleValue > 0 {
            textValue = formatValue(sliderDoubleValue)
        } else {
            textValue = ""
        }
    }
    
    private func formatValue(_ val: Double) -> String {
        if step < 1 {
            return LocalizationHelper.shared.formatDecimal(val)
        } else {
            return LocalizationHelper.shared.formatInteger(val)
        }
    }
}

