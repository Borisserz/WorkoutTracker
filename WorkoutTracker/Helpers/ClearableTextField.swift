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
                // Если пользователь стер все, сохраняем nil, иначе - число
                // Это нужно, чтобы placeholder снова появился, если поле пустое
                if isFocused && newValue == 0 {
                    // Пока пользователь печатает, 0 - это просто 0
                    value = 0
                } else if newValue == 0 {
                    value = nil
                } else {
                    value = newValue
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
