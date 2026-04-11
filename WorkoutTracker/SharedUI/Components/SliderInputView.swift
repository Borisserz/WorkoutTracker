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
    @Environment(ThemeManager.self) private var themeManager
    @Environment(UnitsManager.self) var unitsManager
    
    // Локальное состояние
    @State private var localValue: Double = 0
    @State private var textValue: String = ""
    @FocusState private var isBigTextFocused: Bool
    
    // Ошибки валидации
    @State private var errorMessage: String? = nil
    
    private var navigationTitleText: LocalizedStringKey {
        switch fieldType {
        case .weight: return "Adjust Weight"
        case .reps: return "Adjust Reps"
        case .distance: return "Adjust Distance"
        case .timeMin, .timeSec: return "Adjust Time"
        }
    }
    
    // Умные шаги в зависимости от контекста
    private var quickSteps: [Double] {
        switch fieldType {
        case .weight:
            return unitsManager.weightUnit == .pounds ? [2.5, 5.0, 10.0, 25.0] : [1, 2.5, 5.0, 10.0]
        case .reps:
            return [1.0, 2.0, 5.0, 10.0]
        case .distance:
            return unitsManager.distanceUnit == .miles ? [0.1, 0.5, 1.0, 5.0] : [100.0, 500.0, 1000.0, 5000.0]
        case .timeMin:
            return [1.0, 5.0, 10.0, 15.0]
        case .timeSec:
            return [5.0, 10.0, 15.0, 30.0]
        }
    }
    
    // Базовый шаг для больших круглых кнопок +/-
    private var mainStep: Double {
        switch fieldType {
        case .weight: return unitsManager.weightUnit == .pounds ? 2.5 : 1.0
        case .reps, .timeMin: return 1.0
        case .timeSec: return 5.0
        case .distance: return unitsManager.distanceUnit == .miles ? 0.1 : 100.0
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                // Текущее значение
                VStack(spacing: 8) {
                    Text(fieldType.title(unitsManager: unitsManager).uppercased())
                        .font(.caption)
                        .foregroundColor(themeManager.current.secondaryText)
                        .tracking(1.5)
                    
                    TextField("0", text: $textValue)
                        .font(.system(size: 64, weight: .heavy, design: .rounded))
                        .foregroundColor(errorMessage != nil ? .red : .primary)
                        .keyboardType(fieldType == .reps ? .numberPad : .decimalPad) // Reps только целые
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
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
                                let cleanStr = newText.replacingOccurrences(of: ",", with: ".")
                                if let val = Double(cleanStr) {
                                    let sanitizedVal = fieldType == .reps ? Double(Int(val)) : val
                                    validateValue(sanitizedVal)
                                    localValue = sanitizedVal
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
                    
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .animation(.easeInOut, value: errorMessage)
                    }
                }
                .padding(.top, 40)
                
                // Элементы управления
                VStack(spacing: 24) {
                    // Главные кнопки +/- (Точная подстройка)
                    HStack(spacing: 40) {
                        Button { adjustValue(by: -mainStep) } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(themeManager.current.primaryAccent)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        
                        Button { adjustValue(by: mainStep) } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(themeManager.current.primaryAccent)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
                    
                    Divider().padding(.horizontal, 40).opacity(0.5)
                    
                    // Кнопки быстрого добавления (Quick Adjust)
                    VStack(spacing: 12) {
                        // Плюс строка
                        HStack(spacing: 10) {
                            ForEach(quickSteps, id: \.self) { step in
                                quickAdjustButton(amount: step, isPositive: true)
                            }
                        }
                        
                        // Минус строка
                        HStack(spacing: 10) {
                            ForEach(quickSteps, id: \.self) { step in
                                quickAdjustButton(amount: step, isPositive: false)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                Spacer()
            }
            .navigationTitle(navigationTitleText)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("Done")) {
                        isBigTextFocused = false
                        updateBindingValue(localValue)
                        isPresented = false
                    }
                    .disabled(errorMessage != nil)
                    .fontWeight(.bold)
                }
            }
        }
        .presentationDetents([.fraction(0.6)]) // Делаем шторку чуть выше половины для комфорта
        .presentationDragIndicator(.visible)
        .onAppear {
            localValue = value ?? 0
            textValue = formatValue(localValue)
        }
        .onDisappear {
            updateBindingValue(localValue)
        }
    }
    
    // MARK: - Quick Adjust Button
    
    private func quickAdjustButton(amount: Double, isPositive: Bool) -> some View {
        let sign = isPositive ? "+" : "-"
        let valueStr = fieldType == .reps ? "\(Int(amount))" : LocalizationHelper.shared.formatFlexible(amount)
        let actualAmount = isPositive ? amount : -amount
        
        return Button {
            adjustValue(by: actualAmount)
        } label: {
            Text("\(sign)\(valueStr)")
                .font(.subheadline)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(isPositive ? themeManager.current.primaryAccent.opacity(0.15) : Color.red.opacity(0.1))
                .foregroundColor(isPositive ? themeManager.current.primaryAccent : .red)
                .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Validation & Logic
    
    private func adjustValue(by amount: Double) {
        isBigTextFocused = false
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        
        var newValue = localValue + amount
        if newValue < 0 { newValue = 0 } // Запрещаем отрицательные значения
        
        if fieldType == .reps {
            newValue = Double(Int(newValue)) // Защита от дробей в повторениях
        }
        
        localValue = newValue
        validateValue(newValue)
    }
    
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
            let m = unitsManager.convertToMeters(val)
            let v = InputValidator.validateDistance(m)
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
    
    private func updateBindingValue(_ newValue: Double) {
        guard errorMessage == nil else { return }
        value = newValue > 0 ? newValue : nil
    }
    
    private func formatValue(_ val: Double) -> String {
        if val < 0 { return "—" }
        
        // ЖЕСТКАЯ ПРОВЕРКА: Если это повторения, минуты или секунды — ТОЛЬКО целые числа
        if fieldType == .reps || fieldType == .timeMin || fieldType == .timeSec {
            return LocalizationHelper.shared.formatInteger(val)
        }
        
        // Для веса и дистанции используем гибкое форматирование (убираем .0)
        return LocalizationHelper.shared.formatFlexible(val)
    }
}

// MARK: - Slider Input View (Компактный компонент для встроенного использования)

struct SliderInputView: View {
    @Environment(ThemeManager.self) private var themeManager
    let fieldType: InputFieldType
    @Binding var value: Double?
    
@Environment(UnitsManager.self) var unitsManager
    
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
        maxValue: Double = 500, // ИЗМЕНЕНО: По умолчанию до 500
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
                        .foregroundColor(themeManager.current.primaryAccent)
                }
                .buttonStyle(BorderlessButtonStyle())
                
                TextField(fieldType.title(unitsManager: unitsManager), text: $textValue)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .frame(width: 60) // Сделали чуть шире (было 50) для надежности
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
                        .foregroundColor(themeManager.current.primaryAccent)
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
        .background(themeManager.current.surfaceVariant)
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
        let clampedValue: Double
        
        switch fieldType {
        case .weight:
            let kg = unitsManager.convertToKilograms(num)
            let v = InputValidator.validateWeight(kg)
            isValid = v.isValid; errMsg = v.errorMessage; clampedValue = unitsManager.convertFromKilograms(v.clampedValue)
        case .reps:
            let v = InputValidator.validateReps(Int(num))
            isValid = v.isValid; errMsg = v.errorMessage; clampedValue = Double(v.clampedValue)
        case .distance:
            let m = unitsManager.convertToMeters(num)
            let v = InputValidator.validateDistance(m)
            isValid = v.isValid; errMsg = v.errorMessage; clampedValue = unitsManager.convertFromMeters(v.clampedValue)
        case .timeMin:
            let v = InputValidator.validateTime(Int(num) * 60)
            isValid = v.isValid; errMsg = v.errorMessage; clampedValue = Double(v.clampedValue / 60)
        case .timeSec:
            let v = InputValidator.validateTime(Int(num))
            isValid = v.isValid; errMsg = v.errorMessage; clampedValue = Double(v.clampedValue)
        }
        
        self.errorMessage = errMsg
        
        // Auto-correct the UI state to the clamped value if invalid
        if !isValid {
            self.sliderDoubleValue = clampedValue
            self.textValue = formatValue(clampedValue)
        }
        
        // ALWAYS commit the clamped/valid value
        commitValueWithDebounce(clampedValue, immediate: immediate)
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

