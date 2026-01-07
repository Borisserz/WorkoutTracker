//
//  SliderInputView.swift
//  WorkoutTracker
//
//  Компонент для ввода числовых значений с помощью слайдера и кнопок +/-.
//  Используется для удобного изменения веса и повторений во время тренировки.
//

internal import SwiftUI

// MARK: - Slider Sheet View (Модальное окно со слайдером)

struct SliderSheetView: View {
    let placeholder: String
    @Binding var value: Double?
    @Binding var isPresented: Bool
    
    @StateObject private var unitsManager = UnitsManager.shared
    
    // Локальное состояние для слайдера - обновляется мгновенно без валидации
    @State private var localValue: Double = 0
    @State private var updateTask: Task<Void, Never>?
    @State private var isDragging: Bool = false
    
    // Кэшированные параметры слайдера (вычисляются один раз)
    @State private var params: (min: Double, max: Double, step: Double) = (0, 100, 1)
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                // Текущее значение
                VStack(spacing: 8) {
                    Text(placeholder.uppercased())
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(formatValue(localValue))
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.primary)
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
                    
                    // Слайдер с оптимизированным обновлением
                    VStack(spacing: 8) {
                        Slider(
                            value: Binding(
                                get: { localValue },
                                set: { newValue in
                                    localValue = newValue
                                    handleSliderValueChange(newValue)
                                }
                            ),
                            in: params.min...params.max,
                            step: params.step
                        )
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
            .navigationTitle(LocalizedStringKey("Adjust \(placeholder)"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("Done")) {
                        // Отменяем любые ожидающие задачи
                        updateTask?.cancel()
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
            
            // Кэшируем параметры слайдера один раз при появлении
            let weightUnitString = unitsManager.weightUnitString()
            if placeholder == weightUnitString || placeholder == "kg" || placeholder == "lbs" {
                // Для фунтов увеличиваем максимальный вес до 440 (примерно 200 кг)
                params = (0, unitsManager.weightUnit == .pounds ? 440 : 200, 0.5)
            } else {
                switch placeholder {
                case "reps":
                    params = (0, 50, 1)
                case "km":
                    params = (0, 50, 0.1)
                case "min", "sec":
                    params = (0, 300, 1)
                default:
                    params = (0, 100, 1)
                }
            }
        }
        .onDisappear {
            // Отменяем задачу обновления при закрытии
            updateTask?.cancel()
            // Сохраняем финальное значение при закрытии
            if isDragging {
                updateBindingValue(localValue)
            }
        }
    }
    
    // Обрабатывает изменение значения слайдера с оптимизацией производительности
    private func handleSliderValueChange(_ newValue: Double) {
        // Отменяем предыдущую задачу обновления
        updateTask?.cancel()
        
        // Отмечаем, что началось перетаскивание
        if !isDragging {
            isDragging = true
        }
        
        // Сбрасываем флаг перетаскивания через небольшую задержку после последнего изменения
        // Это позволяет определять, когда пользователь перестал активно перетаскивать
        updateTask = Task {
            try? await Task.sleep(nanoseconds: 200_000_000) // 200ms после последнего изменения
            if !Task.isCancelled {
                await MainActor.run {
                    // Используем актуальное значение localValue на момент выполнения задачи
                    isDragging = false
                    updateBindingValue(localValue)
                }
            }
        }
    }
    
    // Обновляет binding с валидацией (вызывается с debounce или при закрытии)
    private func updateBindingValue(_ newValue: Double) {
        // Быстрая валидация без лишних вычислений
        let validated = max(params.min, min(newValue, params.max))
        
        // Для km нужна дополнительная валидация через InputValidator
        let finalValue: Double
        if placeholder.lowercased() == "km" {
            let validation = InputValidator.validateDistance(validated)
            finalValue = validation.clampedValue
        } else {
            finalValue = validated
        }
        
        value = finalValue >= 0 ? finalValue : nil
    }
    
    private func increment() {
        let newValue = min(localValue + params.step, params.max)
        localValue = newValue
        updateBindingValue(newValue)
    }
    
    private func decrement() {
        let newValue = max(localValue - params.step, params.min)
        localValue = newValue
        updateBindingValue(newValue)
    }
    
    private func formatValue(_ val: Double) -> String {
        if val < 0 {
            return "—"
        }
        // Используем кэшированный step из params
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
    let placeholder: String
    @Binding var value: Double?
    
    @StateObject private var unitsManager = UnitsManager.shared
    
    // Параметры слайдера
    let minValue: Double
    let maxValue: Double
    let step: Double
    
    // Состояние для отслеживания фокуса текстового поля (для ручного ввода)
    @FocusState private var isFocused: Bool
    @State private var textValue: String = ""
    
    init(
        placeholder: String,
        value: Binding<Double?>,
        minValue: Double = 0,
        maxValue: Double = 200,
        step: Double = 1
    ) {
        self.placeholder = placeholder
        self._value = value
        self.minValue = minValue
        self.maxValue = maxValue
        self.step = step
    }
    
    // Кэшированное значение для слайдера (оптимизация производительности)
    @State private var sliderDoubleValue: Double = 0
    @State private var sliderUpdateTask: Task<Void, Never>?
    @State private var isSliderDragging: Bool = false
    
    // Вычисляемое значение для слайдера (не может быть nil)
    private var sliderValue: Binding<Double> {
        Binding<Double>(
            get: { sliderDoubleValue },
            set: { newValue in
                sliderDoubleValue = newValue
                handleSliderValueChange(newValue)
            }
        )
    }
    
    // Обрабатывает изменение значения слайдера с debounce
    private func handleSliderValueChange(_ newValue: Double) {
        // Отменяем предыдущую задачу
        sliderUpdateTask?.cancel()
        
        // Отмечаем, что происходит перетаскивание
        if !isSliderDragging {
            isSliderDragging = true
        }
        
        // Обновляем значение с задержкой после последнего изменения
        sliderUpdateTask = Task {
            try? await Task.sleep(nanoseconds: 150_000_000) // 150ms debounce
            if !Task.isCancelled {
                await MainActor.run {
                    // Используем актуальное значение sliderDoubleValue на момент выполнения
                    isSliderDragging = false
                    value = sliderDoubleValue > 0 ? sliderDoubleValue : nil
                }
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 4) {
            // Верхняя часть: кнопки +/- и значение
            HStack(spacing: 4) {
                // Кнопка уменьшения
                Button(action: decrement) {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                .buttonStyle(BorderlessButtonStyle())
                
                // Текущее значение (можно тапнуть для ручного ввода)
                TextField(placeholder, text: $textValue)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .font(.headline)
                    .frame(width: 50)
                    .focused($isFocused)
                    .onChange(of: textValue) { oldValue, newValue in
                        if let num = Double(newValue) {
                            // Validate based on placeholder type
                            let validated: Double
                            let weightUnitString = unitsManager.weightUnitString().lowercased()
                            if placeholder.lowercased() == weightUnitString || placeholder.lowercased() == "kg" || placeholder.lowercased() == "lbs" {
                                // Для веса валидация будет в weightBinding
                                validated = max(minValue, min(num, maxValue))
                            } else if placeholder.lowercased() == "km" {
                                let validation = InputValidator.validateDistance(num)
                                validated = validation.clampedValue
                            } else {
                                validated = max(minValue, min(num, maxValue))
                            }
                            sliderDoubleValue = validated
                            value = validated >= 0 ? validated : nil
                        } else if newValue.isEmpty {
                            sliderDoubleValue = 0
                            value = nil
                        }
                    }
                    .onChange(of: value) { oldValue, newValue in
                        if let newValue = newValue {
                            textValue = formatValue(newValue)
                            sliderDoubleValue = newValue
                        } else {
                            textValue = ""
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
                
                // Кнопка увеличения
                Button(action: increment) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                .buttonStyle(BorderlessButtonStyle())
            }
            
            // Компактный слайдер
            Slider(
                value: sliderValue,
                in: minValue...maxValue,
                step: step
            )
            .tint(.blue)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        .onDisappear {
            // Отменяем задачу обновления при исчезновении вида
            sliderUpdateTask?.cancel()
            // Сохраняем финальное значение
            if isSliderDragging {
                value = sliderDoubleValue > 0 ? sliderDoubleValue : nil
            }
        }
    }
    
    private func increment() {
        // Отменяем любые ожидающие задачи обновления слайдера
        sliderUpdateTask?.cancel()
        isSliderDragging = false
        
        let current = sliderDoubleValue
        let newValue = min(current + step, maxValue)
        sliderDoubleValue = newValue
        value = newValue > 0 ? newValue : nil
        updateTextValue()
    }
    
    private func decrement() {
        // Отменяем любые ожидающие задачи обновления слайдера
        sliderUpdateTask?.cancel()
        isSliderDragging = false
        
        let current = sliderDoubleValue
        let newValue = max(current - step, minValue)
        sliderDoubleValue = newValue
        value = newValue > 0 ? newValue : nil
        updateTextValue()
    }
    
    private func updateTextValue() {
        if let val = value {
            textValue = formatValue(val)
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

