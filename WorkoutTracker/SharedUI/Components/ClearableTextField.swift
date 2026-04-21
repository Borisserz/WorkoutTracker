

internal import SwiftUI

struct ClearableTextField: View {
    let placeholder: String
    @Binding var value: Double?
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme 

    @FocusState private var isFocused: Bool

    var body: some View {
        TextField(placeholder, value: $value, format: .number)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.center)
            .padding(.vertical, 8)

            .background(colorScheme == .dark ? themeManager.current.surfaceVariant : Color(UIColor.systemGray6))
            .foregroundColor(colorScheme == .dark ? .white : .black)
            .cornerRadius(8)
            .focused($isFocused)
            .onChange(of: isFocused) { oldValue, newValue in
                if newValue {
                    if value == 0 {
                        value = nil
                    }
                }
            }
    }
}
