internal import SwiftUI
import Observation

extension Color {
    static let premiumBackground = Color(red: 0.05, green: 0.05, blue: 0.08)
}

protocol AppTheme: Sendable {
    var background: Color { get }
    var surface: Color { get }
    var surfaceVariant: Color { get }
    var primaryText: Color { get }
    var secondaryText: Color { get }
    var tertiaryText: Color { get }
    var onAccentText: Color { get }
    var primaryAccent: Color { get }
    var secondaryAccent: Color { get }
    var secondaryMidTone: Color { get }
    var deepPremiumAccent: Color { get }
    var lightHighlight: Color { get }
    var successColor: Color { get }
    var warningColor: Color { get }
    var errorColor: Color { get }
    var premiumGradient: LinearGradient { get }
    var primaryGradient: LinearGradient { get }
    var overlayGradient: LinearGradient { get }
}

struct LuxuryPastelTheme: AppTheme {
    var background: Color { PastelTheme.canvas }
    var surface: Color { PastelTheme.cardSurface }
    var surfaceVariant: Color { PastelTheme.cardSurfaceSubtle }

    var primaryText: Color { PastelTheme.textPrimary }
    var secondaryText: Color { PastelTheme.textSecondary }
    var tertiaryText: Color { PastelTheme.textTertiary }
    var onAccentText: Color { PastelTheme.textOnOat }

    var primaryAccent: Color { PastelTheme.pastelOat }
    var secondaryAccent: Color { PastelTheme.warmBeige }
    var secondaryMidTone: Color { PastelTheme.pastelAmber }
    var deepPremiumAccent: Color { PastelTheme.cardSurface }
    var lightHighlight: Color { PastelTheme.cardBorder }

    var successColor: Color { PastelTheme.pastelEmerald }
    var warningColor: Color { PastelTheme.pastelAmber }
    var errorColor: Color { PastelTheme.pastelPeach }

    var premiumGradient: LinearGradient {
        LinearGradient(colors: [PastelTheme.cardSurface, PastelTheme.cardSurfaceSubtle], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var primaryGradient: LinearGradient {
        LinearGradient(colors: [PastelTheme.cardSurfaceSubtle, PastelTheme.canvas], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var overlayGradient: LinearGradient {
        LinearGradient(colors: [PastelTheme.canvas.opacity(0), PastelTheme.canvas.opacity(0.85)], startPoint: .top, endPoint: .bottom)
    }
}

@Observable
@MainActor
final class ThemeManager {
    static let shared = ThemeManager()

    var current: AppTheme = LuxuryPastelTheme()
    var accentColor: Color = PastelTheme.pastelOat

    private init() {}
    
    func setAccentColor(_ color: Color) {
        accentColor = color
    }
}

extension View {
    func withThemeTransition() -> some View { self }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)
        let red = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let green = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let blue = Double(rgbValue & 0x0000FF) / 255.0
        self.init(red: red, green: green, blue: blue)
    }
}
