internal import SwiftUI
import Observation

extension Color {

    static let premiumBackground = Color(red: 0.05, green: 0.05, blue: 0.08)

    static let neonBlue = Color(red: 0.20, green: 0.60, blue: 1.0)
    static let neonPurple = Color(red: 0.60, green: 0.20, blue: 1.0)
    static let neonOrange = Color(red: 1.0, green: 0.40, blue: 0.10)
    static let neonGreen = Color(red: 0.10, green: 0.85, blue: 0.40)
    static let neonRed = Color(red: 1.0, green: 0.15, blue: 0.30)
    static let neonYellow = Color(red: 1.0, green: 0.85, blue: 0.10)
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

struct CyberNeonTheme: AppTheme {
    var background: Color { .premiumBackground }
    var surface: Color { Color(red: 0.10, green: 0.10, blue: 0.14) }
    var surfaceVariant: Color { Color(red: 0.15, green: 0.15, blue: 0.20) }

    var primaryText: Color { .white }
    var secondaryText: Color { Color(white: 0.6) }
    var tertiaryText: Color { Color(white: 0.4) }
    var onAccentText: Color { .white }

    var primaryAccent: Color { .neonBlue }
    var secondaryAccent: Color { .neonPurple }
    var secondaryMidTone: Color { .neonOrange }
    var deepPremiumAccent: Color { .neonPurple }
    var lightHighlight: Color { .neonBlue.opacity(0.15) }

    var successColor: Color { .neonGreen }
    var warningColor: Color { .neonYellow }
    var errorColor: Color { .neonRed }

    var premiumGradient: LinearGradient {
        LinearGradient(colors: [.neonBlue, .neonPurple], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var primaryGradient: LinearGradient {
        LinearGradient(colors: [.neonPurple, .neonOrange], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var overlayGradient: LinearGradient {
        LinearGradient(colors: [.premiumBackground.opacity(0), .premiumBackground.opacity(0.8)], startPoint: .top, endPoint: .bottom)
    }
}

@Observable
final class ThemeManager: Sendable {
    static let shared = ThemeManager()

    let current: AppTheme = CyberNeonTheme()

    private init() {}
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
