internal import SwiftUI

struct ClearableTextField: View {
    let placeholder: String
    @Binding var value: Double? // Работаем с опциональным Double
    
    // Состояние для отслеживания фокуса
    @FocusState private var isFocused: Bool
    
    var body: some View {
        // Напрямую привязываем опциональное значение. Если nil — поле будет пустым.
        TextField(placeholder, value: $value, format: .number)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.center)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            .focused($isFocused) // Привязываем фокус
            .onChange(of: isFocused) { oldValue, newValue in
                if newValue { // Поле получило фокус
                    // Если текущее значение 0, очищаем его, чтобы можно было сразу вводить новое
                    if value == 0 {
                        value = nil
                    }
                }
            }
    }
}
