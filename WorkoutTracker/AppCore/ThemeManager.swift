//
//  ThemeManager.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 10.04.26.
//

internal import SwiftUI
import Observation

// MARK: - Color Extension (Hex Support)
extension Color {
    /// Creates a Color from hexadecimal string (e.g., "FF5733" or "#FF5733")
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

// MARK: - PROTOCOL: AppTheme (Semantic Colors)
/// Protocol-oriented theme definition with semantic color roles.
/// Enables dark/light mode support and custom theme implementations.
protocol AppTheme: Sendable {
    // MARK: Backgrounds & Surfaces
    /// Primary background color (entire screen, default state)
    var background: Color { get }
    /// Secondary/elevated surface color (cards, sheets)
    var surface: Color { get }
    /// Tertiary subtle surface
    var surfaceVariant: Color { get }
    
    // MARK: Text & Labels
    /// Primary text color (high contrast, main content)
    var primaryText: Color { get }
    /// Secondary text color (captions, hints, disabled)
    var secondaryText: Color { get }
    /// Tertiary text (very subtle)
    var tertiaryText: Color { get }
    /// Text color on bright accent backgrounds (for contrast/WCAG)
    var onAccentText: Color { get }
    
    // MARK: Accents & Interactive
    /// Primary brand accent (buttons, highlights)
    var primaryAccent: Color { get }
    /// Secondary accent (secondary buttons, borders)
    var secondaryAccent: Color { get }
    /// Mid-tone secondary color (for muscle group tags, secondary indicators)
    var secondaryMidTone: Color { get }
    /// Deep premium/dark accent (for contrast and emphasis)
    var deepPremiumAccent: Color { get }
    /// Light highlight color (subtle emphasis on active elements)
    var lightHighlight: Color { get }
    /// Success state (achievements, green indicators)
    var successColor: Color { get }
    /// Warning state (cautions, orange indicators)
    var warningColor: Color { get }
    /// Error state (destructive actions, red indicators)
    var errorColor: Color { get }
    
    // MARK: Gradients
    /// Premium/accent gradient for headers, hero sections
    var premiumGradient: LinearGradient { get }
    /// Subtle primary gradient for cards
    var primaryGradient: LinearGradient { get }
    /// Overlay gradient (dark fade, typically for images)
    var overlayGradient: LinearGradient { get }
}

// MARK: - THEME 1: ClassicTheme (Apple Default with Dark/Light Support)
/// Default Apple-style theme using system colors.
/// Automatically adapts to Dark/Light mode via UIColor system colors.
struct ClassicTheme: AppTheme {
    @Environment(\.colorScheme) private var colorScheme
    
    // MARK: Backgrounds & Surfaces
    var background: Color {
        Color(UIColor.systemBackground)
    }
    
    var surface: Color {
        Color(UIColor.secondarySystemBackground)
    }
    
    var surfaceVariant: Color {
        Color(UIColor.tertiarySystemBackground)
    }
    
    // MARK: Text & Labels
    var primaryText: Color {
        Color(UIColor.label)
    }
    
    var secondaryText: Color {
        Color(UIColor.secondaryLabel)
    }
    
    var tertiaryText: Color {
        Color(UIColor.tertiaryLabel)
    }
    
    var onAccentText: Color {
        Color(UIColor.systemBackground)  // Use background color for contrast on bright accents
    }
    
    // MARK: Accents & Interactive
    var primaryAccent: Color {
        Color(UIColor.systemBlue)
    }
    
    var secondaryAccent: Color {
        Color(UIColor.systemGray)
    }
    
    var secondaryMidTone: Color {
        Color(UIColor.systemOrange)  // Orange for secondary indicators
    }
    
    var deepPremiumAccent: Color {
        Color(UIColor.systemPurple)  // Purple for deep emphasis
    }
    
    var lightHighlight: Color {
        Color(UIColor.systemBlue).opacity(0.15)  // Light blue highlight for active elements
    }
    
    var successColor: Color {
        Color(UIColor.systemGreen)
    }
    
    var warningColor: Color {
        Color(UIColor.systemOrange)
    }
    
    var errorColor: Color {
        Color(UIColor.systemRed)
    }
    
    // MARK: Gradients
    var premiumGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(UIColor.systemBlue),
                Color(UIColor.systemPurple)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    var primaryGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(UIColor.systemBlue),
                Color(UIColor.systemBlue).opacity(0.7)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    var overlayGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.black.opacity(0),
                Color.black.opacity(0.6)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - THEME 2: AmethystTheme (Purple/Lavender Custom Theme)
/// Custom theme using Amethyst purple palette.
/// HEX: #9C93E5, #C7A3D2, #BA8CBE, #7F4EA8
struct AmethystTheme: AppTheme {
    // MARK: Backgrounds & Surfaces
    var background: Color {
        Color(hex: "F8F7FC") // Very light lavender background
    }
    
    var surface: Color {
        Color(hex: "EFE9F7") // Soft lavender surface
    }
    
    var surfaceVariant: Color {
        Color(hex: "E6DFF0") // Slightly darker lavender
    }
    
    // MARK: Text & Labels
    var primaryText: Color {
        Color(hex: "2D1B4E") // Deep purple text
    }
    
    var secondaryText: Color {
        Color(hex: "6B5B7A") // Muted purple-gray
    }
    
    var tertiaryText: Color {
        Color(hex: "9B8FA8") // Light purple-gray
    }
    
    var onAccentText: Color {
        Color(hex: "2D1B4E")  // Deep purple (for contrast on #9C93E5 bright accent)
    }
    
    // MARK: Accents & Interactive
    var primaryAccent: Color {
        Color(hex: "9C93E5") // Soft Periwinkle
    }
    
    var secondaryAccent: Color {
        Color(hex: "BA8CBE") // Muted Mauve
    }
    
    var secondaryMidTone: Color {
        Color(hex: "D68A73")  // Warm terracotta-brown
    }
    
    var deepPremiumAccent: Color {
        Color(hex: "513E7F")  // Deep purple
    }
    
    var lightHighlight: Color {
        Color(hex: "9C93E5").opacity(0.15)  // Light purple highlight for active elements
    }
    
    var successColor: Color {
        Color(hex: "4CAF50") // Green
    }
    
    var warningColor: Color {
        Color(hex: "FF9800") // Orange
    }
    
    var errorColor: Color {
        Color(hex: "F44336") // Red
    }
    
    // MARK: Gradients
    var premiumGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(hex: "C7A3D2"),
                Color(hex: "7F4EA8")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    var primaryGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(hex: "9C93E5"),
                Color(hex: "C7A3D2")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    var overlayGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(hex: "7F4EA8").opacity(0),
                Color(hex: "7F4EA8").opacity(0.7)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - THEME 3: CoralTealTheme (Vibrant Red/Teal Custom Theme)
/// Custom theme using Coral-Teal palette for modern, vibrant UI.
/// HEX: #F5AD92, #ED717A, #734A8D, #00577F
struct CoralTealTheme: AppTheme {
    // MARK: Backgrounds & Surfaces
    var background: Color {
        Color(hex: "FAFBFC") // Near-white background
    }
    
    var surface: Color {
        Color(hex: "F3F4F6") // Light neutral surface
    }
    
    var surfaceVariant: Color {
        Color(hex: "E8EAED") // Slightly darker surface
    }
    
    // MARK: Text & Labels
    var primaryText: Color {
        Color(hex: "1A2835") // Deep navy text
    }
    
    var secondaryText: Color {
        Color(hex: "4A5568") // Neutral gray-blue
    }
    
    var tertiaryText: Color {
        Color(hex: "7A8594") // Light gray-blue
    }
    
    var onAccentText: Color {
        Color(hex: "1A2835")  // Deep navy (for contrast on #ED717A bright accents)
    }
    
    // MARK: Accents & Interactive
    var primaryAccent: Color {
        Color(hex: "ED717A") // Vibrant Coral-Red
    }
    
    var secondaryAccent: Color {
        Color(hex: "00577F") // Deep Teal
    }
    
    var secondaryMidTone: Color {
        Color(hex: "FF9966")  // Warm orange-coral
    }
    
    var deepPremiumAccent: Color {
        Color(hex: "003D5C")  // Deep navy-teal
    }
    
    var lightHighlight: Color {
        Color(hex: "ED717A").opacity(0.15)  // Light coral highlight for active elements
    }
    
    var successColor: Color {
        Color(hex: "00AA66") // Teal-Green
    }
    
    var warningColor: Color {
        Color(hex: "FF9900") // Amber
    }
    
    var errorColor: Color {
        Color(hex: "E31C1C") // Bright Red
    }
    
    // MARK: Gradients
    var premiumGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(hex: "F5AD92"),
                Color(hex: "ED717A")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    var primaryGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(hex: "ED717A"),
                Color(hex: "734A8D")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    var overlayGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(hex: "00577F").opacity(0),
                Color(hex: "00577F").opacity(0.7)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Enum: AppThemeType
/// Theme selection enum with persistence support
enum AppThemeType: String, CaseIterable, Identifiable, Codable {
    case classic = "Classic"
    case amethyst = "Amethyst"
    case coralTeal = "Coral Teal"
    
    var id: String { self.rawValue }
    
    /// Returns a theme instance for this type
    var theme: AppTheme {
        switch self {
        case .classic:
            return ClassicTheme()
        case .amethyst:
            return AmethystTheme()
        case .coralTeal:
            return CoralTealTheme()
        }
    }
}

// MARK: - THEME MANAGER (@Observable)
/// Central theme management with @Observable for SwiftUI reactivity.
/// Persists theme selection to UserDefaults.
@Observable
final class ThemeManager: Sendable {
    static let shared = ThemeManager()
    
    private(set) var activeThemeType: AppThemeType {
        didSet {
            UserDefaults.standard.set(activeThemeType.rawValue, forKey: "selectedAppTheme")
        }
    }
    
    /// Current active theme instance
    var current: AppTheme {
        activeThemeType.theme
    }
    
    private init() {
        if let saved = UserDefaults.standard.string(forKey: "selectedAppTheme"),
           let type = AppThemeType(rawValue: saved) {
            self.activeThemeType = type
        } else {
            self.activeThemeType = .classic // Default to Apple Classic
        }
    }
    
    /// Switch to a different theme
    func setTheme(_ type: AppThemeType) {
        self.activeThemeType = type
    }
}

// MARK: - VIEW MODIFIER: withThemeTransition
/// Smooth color transition animation when theme changes
extension View {
    func withThemeTransition() -> some View {
        self
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.3), value: ThemeManager.shared.activeThemeType)
    }
}

// MARK: - EXAMPLE: SampleCardView (Before & After Refactoring)
/// Example showing how to refactor from hard-coded colors to theme system
struct SampleCardView: View {
    @State private var themeManager = ThemeManager.shared
    
    var body: some View {
        VStack(spacing: 16) {
            // BEFORE: themeManager.current.surface, .black, .blue
            // NOW: Semantic colors from theme
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Workout Card")
                        .font(.headline)
                        .foregroundColor(themeManager.current.primaryText) // Was: .black
                    Spacer()
                    Text("Active")
                        .font(.caption)
                        .foregroundColor(themeManager.current.successColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(themeManager.current.successColor.opacity(0.2))
                        .cornerRadius(4)
                }
                
                Text("Upper Body • 45 min")
                    .font(.subheadline)
                    .foregroundColor(themeManager.current.secondaryText) // Was: .gray
                
                Divider()
                    .background(themeManager.current.secondaryAccent.opacity(0.3))
                
                HStack {
                    Label("8 exercises", systemImage: "figure.strengthtraining")
                        .foregroundColor(themeManager.current.primaryText)
                    Spacer()
                    Button(action: {}) {
                        Text("Resume")
                            .font(.callout)
                            .fontWeight(.semibold)
                            .foregroundColor(themeManager.current.background)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(themeManager.current.primaryAccent) // Was: .blue
                            .cornerRadius(8)
                    }
                }
            }
            .padding(16)
            .background(themeManager.current.surface) // Was: themeManager.current.surface
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
        .padding(16)
        .background(themeManager.current.background) // Was: themeManager.current.background
        .withThemeTransition()
    }
}
