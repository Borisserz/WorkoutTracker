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
    
    // Параметры слайдера
    private var params: (min: Double, max: Double, step: Double) {
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
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                // Текущее значение
                VStack(spacing: 8) {
                    Text(placeholder.uppercased())
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(value.map { formatValue($0) } ?? "—")
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
                    
                    // Слайдер
                    VStack(spacing: 8) {
                        Slider(
                            value: sliderValue,
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
            .navigationTitle("Adjust \(placeholder)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    // Вычисляемое значение для слайдера
    private var sliderValue: Binding<Double> {
        Binding<Double>(
            get: { value ?? 0 },
            set: { newValue in
                value = newValue > 0 ? newValue : nil
            }
        )
    }
    
    private func increment() {
        let current = value ?? 0
        let newValue = min(current + params.step, params.max)
        value = newValue > 0 ? newValue : nil
    }
    
    private func decrement() {
        let current = value ?? 0
        let newValue = max(current - params.step, params.min)
        value = newValue > 0 ? newValue : nil
    }
    
    private func formatValue(_ val: Double) -> String {
        if params.step < 1 {
            return String(format: "%.1f", val)
        } else {
            return "\(Int(val))"
        }
    }
}

// MARK: - Slider Input View (Компактный компонент для встроенного использования)

struct SliderInputView: View {
    let placeholder: String
    @Binding var value: Double?
    
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
    
    // Вычисляемое значение для слайдера (не может быть nil)
    private var sliderValue: Binding<Double> {
        Binding<Double>(
            get: { value ?? 0 },
            set: { newValue in
                value = newValue > 0 ? newValue : nil
            }
        )
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
                        if let num = Double(newValue), num >= minValue && num <= maxValue {
                            value = num > 0 ? num : nil
                        } else if newValue.isEmpty {
                            value = nil
                        }
                    }
                    .onChange(of: value) { oldValue, newValue in
                        if let newValue = newValue {
                            textValue = formatValue(newValue)
                        } else {
                            textValue = ""
                        }
                    }
                    .onAppear {
                        if let val = value {
                            textValue = formatValue(val)
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
    }
    
    private func increment() {
        let current = value ?? 0
        let newValue = min(current + step, maxValue)
        value = newValue > 0 ? newValue : nil
        updateTextValue()
    }
    
    private func decrement() {
        let current = value ?? 0
        let newValue = max(current - step, minValue)
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
            return String(format: "%.1f", val)
        } else {
            return "\(Int(val))"
        }
    }
}

