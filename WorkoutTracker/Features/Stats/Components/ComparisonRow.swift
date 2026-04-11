internal import SwiftUI

struct ComparisonRow: View {
    let title: String
    let icon: String
    let color: Color
    let currentValue: Int
    let previousValue: Int
    
    var percentageChange: Double {
        if previousValue == 0 {
            return currentValue > 0 ? 100.0 : 0.0
        }
        return (Double(currentValue - previousValue) / Double(previousValue)) * 100.0
    }
    
        @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)
            
            Text(LocalizedStringKey(title))
                .foregroundColor(themeManager.current.background)
            
            Spacer()
            
            Text("\(currentValue)")
                .foregroundColor(themeManager.current.background)
            Image(systemName: "arrow.right")
                .font(.caption)
                .foregroundColor(themeManager.current.secondaryAccent)
            Text("\(previousValue)")
                .foregroundColor(themeManager.current.secondaryAccent)
            
            Spacer()
            
            Text("\(percentageChange, specifier: "%.0f")%")
                .font(.caption)
                .bold()
                .foregroundColor(percentageChange >= 0 ? .green : .red)
                .frame(width: 50, alignment: .trailing)
        }
        .padding(.vertical, 8)
    }
}
