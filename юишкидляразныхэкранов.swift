import SwiftUI

// MARK: - 7. ВЫПАДАЮЩЕЕ МЕНЮ НАСТРОЕК
struct SettingsDropdownMenu: View {
    @Binding var isShowing: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingRow(icon: "moon.fill", title: "Темная тема", color: .indigo)
            SettingRow(icon: "bell.fill", title: "Уведомления", color: .orange)
            SettingRow(icon: "waveform.path", title: "Вибрация", color: .pink)
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
        .background(Color.black.opacity(0.4), in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(LinearGradient(colors: [.white.opacity(0.5), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5))
        .shadow(color: .black.opacity(0.5), radius: 30, x: 0, y: 15)
        .frame(width: 210)
    }
}

struct SettingRow: View {
    let icon: String; let title: String; let color: Color
    @State private var isOn = true
    var body: some View {
        HStack {
            Image(systemName: icon).foregroundStyle(color).frame(width: 20)
            Text(title).font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white)
            Spacer()
            Toggle("", isOn: $isOn).labelsHidden().scaleEffect(0.7).tint(Color.neonBlue)
        }
    }
}

// MARK: - 10. ДОРОГИЕ ЗЕРКАЛЬНЫЕ UI КОМПОНЕНТЫ
struct PremiumGlassButton: View {
    let title: String
    var subtitle: String? = nil
    let icon: String
    let colorTint: Color
    var isSmall: Bool = false
    let action: () -> Void
    
    @State private var isPressed: Bool = false
    
    var body: some View {
        Button(action: {
            action()
        }) {
            HStack(alignment: .top, spacing: 16) {
                ZStack {
                    Circle().fill(colorTint.opacity(0.2)).frame(width: isSmall ? 40 : 50, height: isSmall ? 40 : 50)
                    Image(systemName: icon).font(.system(size: isSmall ? 20 : 24, weight: .bold))
                        .foregroundStyle(colorTint)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.system(size: isSmall ? 16 : 18, weight: .bold, design: .rounded)).foregroundStyle(.white).lineLimit(2)
                    if let subtitle = subtitle { Text(subtitle).font(.system(size: 13, weight: .medium, design: .rounded)).foregroundStyle(.white.opacity(0.6)) }
                }
                if !isSmall { Spacer() }
            }
            .padding(isSmall ? 16 : 20)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.2), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// ДОРОГОЙ ТЕМНЫЙ ФОН
struct PremiumDarkBackground: View {
    var body: some View {
        ZStack {
            Color.premiumBackground.ignoresSafeArea()
            
            // Статичные сферы (без сложных условий, чтобы не было ошибок)
            Circle()
                .fill(Color.neonBlue.opacity(0.15))
                .frame(width: 350)
                .blur(radius: 120)
                .offset(x: -100, y: -150)
            
            Circle()
                .fill(Color.neonPurple.opacity(0.12))
                .frame(width: 400)
                .blur(radius: 130)
                .offset(x: 100, y: 100)
        }
    }
}
