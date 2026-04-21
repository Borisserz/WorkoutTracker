internal import SwiftUI

struct ImbalanceCard: View {
    @Environment(ThemeManager.self) private var themeManager
    let title: String
    let message: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 15) {

            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 20))
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(LocalizedStringKey(title))
                    .font(.headline)
                    .foregroundColor(themeManager.current.primaryText)

                Text(message)
                    .font(.caption)
                    .foregroundColor(themeManager.current.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding()
        .background(themeManager.current.surface)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal)
        .padding(.vertical, 5)
    }
}
