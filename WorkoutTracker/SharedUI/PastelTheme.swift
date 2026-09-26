internal import SwiftUI

/// Unified Warm Oat & High-Contrast Pastel Design System for WorkoutTracker.
/// Features luminous warm beiges, crystal-clear white typography, and motivating workout tones.
enum PastelTheme {
    // MARK: - Canvas & Surfaces
    static let canvas = Color(hex: "121316")
    static let cardSurface = Color(hex: "1B1D22")
    static let cardSurfaceSubtle = Color(hex: "16171B")
    static let anatomyBackground = Color(hex: "15161A")
    
    // MARK: - Borders & Dividers
    static let cardBorder = Color(hex: "FAF5EE").opacity(0.12)
    static let cardBorderFocused = Color(hex: "FAF5EE").opacity(0.28)
    static let separator = Color(hex: "FAF5EE").opacity(0.10)

    // MARK: - Harmonious Warm & Motivational Accents
    /// Luminous warm oat/ivory cream for primary actions, badges, and high-contrast highlights.
    static let pastelOat = Color(hex: "FAF5EE")
    
    /// Rich warm beige for frames, highlights, and secondary accents.
    static let warmBeige = Color(hex: "F4ECE2")

    /// Fresh energetic sage green for recovered muscles (80-100%), readiness, and PR achievements.
    static let pastelSage = Color(hex: "9DD6AF")
    
    /// Gentle dusty peach / terracotta for fatigued muscles (<50%) and workout streak fire.
    static let pastelPeach = Color(hex: "E4A891")
    
    /// Warm golden amber for active workouts, favorites, and transition recovery (50-79%).
    static let pastelAmber = Color(hex: "F2CB7E")
    
    /// Muted powder blue / slate for toggles, time metrics, and hydration sync.
    static let pastelSlate = Color(hex: "A3BCD6")
    
    /// Dusty lavender for CNS autonomic readiness and HRV metrics.
    static let pastelLavender = Color(hex: "C6B8D8")

    // MARK: - Crystal-Clear High-Contrast Typography
    /// Pure crisp white for primary headers, titles, and main figures.
    static let textPrimary = Color(hex: "FFFFFF")
    
    /// Warm light beige / cream for high-contrast subtitles, descriptions, and values.
    static let textSecondary = Color(hex: "E8E2D8")
    
    /// Soft warm ivory-gray for clear micro-labels, icons, and captions.
    static let textTertiary = Color(hex: "C4BCB2")
    
    /// Deep charcoal for text displayed on bright oat / beige buttons and chips.
    static let textOnOat = Color(hex: "121316")

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
