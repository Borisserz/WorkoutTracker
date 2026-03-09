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
                        .foregroundColor(.primary)
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
                                    let validated = min(max(val, params.min), params.max)
                                    localValue = validated
                                } else if newText.isEmpty {
                                    localValue = 0
                                }
                            }
                        }
                        .onChange(of: localValue) { _, newVal in
                            if !isBigTextFocused {
                                textValue = formatValue(newVal)
                            }
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
                                updateBindingValue(localValue)
                            }
                        }
                        .tint(.blue)
                        
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
                    Button(LocalizedStringKey("Done")) {
                        isBigTextFocused = false
                        // При закрытии сохраняем финальное значение
                        updateBindingValue(localValue)
                        isPresented = false
                    }
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
            
            textValue = formatValue(localValue)
        }
        .onDisappear {
            // На всякий случай сохраняем при скрытии шторки смахиванием вниз
            updateBindingValue(localValue)
        }
    }
    
    // Обновляет binding с валидацией
    private func updateBindingValue(_ newValue: Double) {
        let validated = max(params.min, min(newValue, params.max))
        value = validated > 0 ? validated : nil
    }
    
    private func increment() {
        let newValue = min(localValue + params.step, params.max)
        localValue = newValue
    }
    
    private func decrement() {
        let newValue = max(localValue - params.step, params.min)
        localValue = newValue
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
                            let validated = max(minValue, min(num, maxValue))
                            sliderDoubleValue = validated
                            commitValueWithDebounce(validated)
                        } else if newValue.isEmpty {
                            sliderDoubleValue = 0
                            commitValueWithDebounce(0)
                        }
                    }
                    .onChange(of: value) { oldValue, newValue in
                        // Внешнее изменение (например, загрузка из модели)
                        if let newValue = newValue {
                            // Чтобы избежать зацикливания, обновляем только если текст не в фокусе
                            if !isFocused {
                                textValue = formatValue(newValue)
                            }
                            sliderDoubleValue = newValue
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
                in: minValue...maxValue,
                step: step
            ) { editing in
                // Когда пользователь ОТПУСКАЕТ палец, передаем данные наверх
                if !editing {
                    commitValueWithDebounce(sliderDoubleValue, immediate: true)
                    updateTextValue()
                } else {
                    // Пока тянет, просто обновляем текст без сохранения
                    textValue = formatValue(sliderDoubleValue)
                }
            }
            .tint(.blue)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        .onDisappear {
            updateTask?.cancel()
            value = sliderDoubleValue > 0 ? sliderDoubleValue : nil
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
        let newValue = min(current + step, maxValue)
        sliderDoubleValue = newValue
        updateTextValue()
        commitValueWithDebounce(newValue) // Сохраняем с задержкой
    }
    
    private func decrement() {
        let current = sliderDoubleValue
        let newValue = max(current - step, minValue)
        sliderDoubleValue = newValue
        updateTextValue()
        commitValueWithDebounce(newValue) // Сохраняем с задержкой
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

