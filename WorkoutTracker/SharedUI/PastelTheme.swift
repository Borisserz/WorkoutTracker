internal import SwiftUI

/// Unified Calm Pastel & Warm Oat Design System for WorkoutTracker.
/// Implements Apple HIG, calm aesthetic, and zero visual noise.
enum PastelTheme {
    // MARK: - Canvas & Surfaces
    static let canvas = Color(hex: "141518")
    static let cardSurface = Color(hex: "1D1F24")
    static let cardSurfaceSubtle = Color(hex: "18191D")
    static let anatomyBackground = Color(hex: "17181C")
    
    // MARK: - Borders & Dividers
    static let cardBorder = Color(hex: "ECE6DE").opacity(0.07)
    static let cardBorderFocused = Color(hex: "ECE6DE").opacity(0.18)
    static let separator = Color(hex: "ECE6DE").opacity(0.06)

    // MARK: - Harmonious Pastel Accents
    /// Soft sage green for recovered muscles (80-100%), success and positive metrics.
    static let pastelSage = Color(hex: "9BB8A4")
    
    /// Gentle dusty peach / terracotta for fatigued muscles (<50%) and subtle streak fire.
    static let pastelPeach = Color(hex: "D8A68B")
    
    /// Soft warm amber for muscles in recovery transition (50-79%).
    static let pastelAmber = Color(hex: "DEC596")
    
    /// Noble warm oat cream for primary actions (e.g. Body Analysis button) & high contrast highlights.
    static let pastelOat = Color(hex: "ECE6DE")
    
    /// Muted powder blue / slate for toggles, sleep tracking and hydration sync.
    static let pastelSlate = Color(hex: "92A8BF")
    
    /// Dusty lavender for CNS autonomic readiness and HRV metrics.
    static let pastelLavender = Color(hex: "B8A9C9")

    // MARK: - Typography Colors
    static let textPrimary = Color(hex: "F5F5F7")
    static let textSecondary = Color(hex: "9E9EA7")
    static let textTertiary = Color(hex: "686873")
    static let textOnOat = Color(hex: "141518")

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
