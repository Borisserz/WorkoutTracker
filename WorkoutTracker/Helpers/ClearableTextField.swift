internal import SwiftUI

struct ClearableTextField: View {
    let placeholder: String
    @Binding var value: Double? // Работаем с опциональным Double
    
    // Состояние для отслеживания фокуса
    @FocusState private var isFocused: Bool
    
    // Вспомогательный Binding для преобразования nil <-> 0
    private var textBinding: Binding<Double> {
        Binding<Double>(
            get: { value ?? 0 },
            set: { newValue in
                // Validate and clamp negative values
                let validatedValue = max(0, newValue)
                
                // Если пользователь стер все, сохраняем nil, иначе - число
                // Это нужно, чтобы placeholder снова появился, если поле пустое
                if isFocused && validatedValue == 0 {
                    // Пока пользователь печатает, 0 - это просто 0
                    value = 0
                } else if validatedValue == 0 {
                    value = nil
                } else {
                    value = validatedValue
                }
            }
        )
    }
    
    var body: some View {
        TextField(placeholder, value: textBinding, format: .number)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.center)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            .focused($isFocused) // Привязываем фокус
            .onChange(of: isFocused) { oldValue, newValue in
                if newValue { // Поле получило фокус
                    // Если текущее значение 0, очищаем его
                    if value == 0 {
                        value = nil
                    }
                }
            }
    }
}
