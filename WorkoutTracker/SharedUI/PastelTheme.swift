internal import SwiftUI

/// Luxury Athletic Design System for WorkoutTracker.
/// Harmonizes deep warm charcoal, pure white typography, rich visible premium beige, and athletic emerald green.
enum PastelTheme {
    // MARK: - Canvas & Surfaces (Warm Cashmere Charcoal)
    static let canvas = Color(hex: "0E0F12")
    static let cardSurface = Color(hex: "17181D")
    static let cardSurfaceSubtle = Color(hex: "121317")
    static let anatomyBackground = Color(hex: "101114")
    
    // MARK: - Rich Visible Warm Beige Borders & Dividers
    /// Visible premium warm beige border for all cards and interactive containers.
    static let cardBorder = Color(hex: "EFE3D3").opacity(0.18)
    /// Highlighted focused border with glowing warm beige outline.
    static let cardBorderFocused = Color(hex: "EFE3D3").opacity(0.42)
    static let separator = Color(hex: "EFE3D3").opacity(0.12)

    // MARK: - Harmonious Warm & Motivational Accents
    /// Rich visible premium warm beige / oat cream for primary action buttons, active tabs, and highlights.
    static let pastelOat = Color(hex: "EFE3D3")
    
    /// Deep warm beige for borders, accent frames, and secondary badges.
    static let warmBeige = Color(hex: "E5D5C0")

    /// Athletic vivid emerald green for recovered muscles (80-100%), readiness, and PR achievements.
    static let pastelSage = Color(hex: "10B981")
    
    /// Gentle energetic peach / coral for fatigued muscles (<50%) and workout streak fire.
    static let pastelPeach = Color(hex: "F87171")
    
    /// Warm golden amber for active workouts, favorites, and transition recovery (50-79%).
    static let pastelAmber = Color(hex: "FBBF24")
    
    /// Muted powder blue / slate for toggles, time metrics, and hydration sync.
    static let pastelSlate = Color(hex: "60A5FA")
    
    /// Dusty lavender for CNS autonomic readiness and HRV metrics.
    static let pastelLavender = Color(hex: "A78BFA")

    // MARK: - Crystal-Clear High-Contrast Typography
    /// Pure crisp white for primary headers, titles, and main figures.
    static let textPrimary = Color(hex: "FFFFFF")
    
    /// Warm light beige / cream for high-contrast subtitles, descriptions, and values.
    static let textSecondary = Color(hex: "EAE3D8")
    
    /// Soft warm ivory-gray for clear micro-labels, icons, and captions.
    static let textTertiary = Color(hex: "BDB5A9")
    
    /// Deep charcoal for text displayed on bright oat / beige buttons and chips.
    static let textOnOat = Color(hex: "0E0F12")

    // MARK: - Corner Radii
    static let cardRadius: CGFloat = 20
    static let buttonRadius: CGFloat = 14
    static let chipRadius: CGFloat = 10
}

// MARK: - View Modifiers
struct PastelCardModifier: ViewModifier {
    var padding: CGFloat = 18

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(PastelTheme.cardSurface)
            .clipShape(RoundedRectangle(cornerRadius: PastelTheme.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: PastelTheme.cardRadius, style: .continuous)
                    .stroke(PastelTheme.cardBorder, lineWidth: 1)
            )
    }
}

extension View {
    func pastelCard(padding: CGFloat = 18) -> some View {
        self.modifier(PastelCardModifier(padding: padding))
    }
}
