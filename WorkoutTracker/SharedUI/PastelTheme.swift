internal import SwiftUI

/// High-Performance Athletic Contrast Design System for WorkoutTracker.
/// Features deep OLED blacks, pure white typography, and vibrant athletic emerald green accents.
enum PastelTheme {
    // MARK: - Canvas & Surfaces
    static let canvas = Color(hex: "08090B")
    static let cardSurface = Color(hex: "121418")
    static let cardSurfaceSubtle = Color(hex: "0D0E12")
    static let anatomyBackground = Color(hex: "0B0C0F")
    
    // MARK: - Borders & Dividers
    static let cardBorder = Color(hex: "FFFFFF").opacity(0.10)
    static let cardBorderFocused = Color(hex: "10B981").opacity(0.40)
    static let separator = Color(hex: "FFFFFF").opacity(0.08)

    // MARK: - Harmonious Warm & Motivational Accents
    /// Luminous warm oat/ivory cream for primary actions, badges, and high-contrast highlights.
    static let pastelOat = Color(hex: "FAF5EE")
    
    /// Rich warm beige for frames, highlights, and secondary accents.
    static let warmBeige = Color(hex: "F4ECE2")

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
    static let textSecondary = Color(hex: "E6E1D8")
    
    /// Soft warm ivory-gray for clear micro-labels, icons, and captions.
    static let textTertiary = Color(hex: "A8A29E")
    
    /// Deep charcoal for text displayed on bright oat / beige buttons and chips.
    static let textOnOat = Color(hex: "08090B")

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
