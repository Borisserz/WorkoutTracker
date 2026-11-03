internal import SwiftUI

/// Premium Apple HIG Athletic Living Flame Border Effect.
/// Replaces flat, generic AI gold with an organic, dynamic fiery ember contour.
/// Dual-layer bloom: Outer heat haze glow + sharp inner molten ridge with continuous flowing phase rotation.
struct FlameBorderModifier: ViewModifier {
    var cornerRadius: CGFloat = 24
    var lineWidth: CGFloat = 1.6
    var isBurning: Bool = true

    @State private var rotationAngle: Double = 0
    @State private var pulseIntensity: Double = 0.85
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Living Athletic Flame Palette (Ember Crimson -> Molten Blaze -> Solar Flame -> White-hot Spark)
    private static let flameStops: [Gradient.Stop] = [
        .init(color: Color(red: 0.88, green: 0.11, blue: 0.28), location: 0.0),   // Ember Crimson #E11D48
        .init(color: Color(red: 0.98, green: 0.45, blue: 0.09), location: 0.28),  // Molten Blaze #F97316
        .init(color: Color(red: 0.98, green: 0.75, blue: 0.14), location: 0.55),  // Solar Flame #FBBF24
        .init(color: Color(red: 1.00, green: 0.95, blue: 0.60), location: 0.75),  // White-hot Spark #FEF08A
        .init(color: Color(red: 0.98, green: 0.45, blue: 0.09), location: 0.90),  // Deep Ember
        .init(color: Color(red: 0.88, green: 0.11, blue: 0.28), location: 1.0)    // Return to Crimson
    ]

    private var flameGradient: AngularGradient {
        AngularGradient(
            gradient: Gradient(stops: Self.flameStops),
            center: .center,
            startAngle: .degrees(rotationAngle),
            endAngle: .degrees(rotationAngle + 360)
        )
    }

    func body(content: Content) -> some View {
        content
            .overlay(
                ZStack {
                    if isBurning {
                        // Layer 1: Outer Heat Haze (Atmospheric Bloom Glow)
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(flameGradient, lineWidth: lineWidth + 2.5)
                            .blur(radius: 7.0)
                            .opacity(pulseIntensity * 0.72)
                            .allowsHitTesting(false)

                        // Layer 2: Core Molten Ridge (Sharp, crisp contour)
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(flameGradient, lineWidth: lineWidth)
                            .opacity(0.95)
                            .allowsHitTesting(false)
                    }
                }
            )
            .onAppear {
                guard isBurning, !reduceMotion else { return }
                withAnimation(
                    .linear(duration: 6.5)
                    .repeatForever(autoreverses: false)
                ) {
                    rotationAngle = 360
                }
                withAnimation(
                    .easeInOut(duration: 2.2)
                    .repeatForever(autoreverses: true)
                ) {
                    pulseIntensity = 1.0
                }
            }
    }
}

extension View {
    /// Applies a luxury athletic living flame border around the view contour.
    func flameBorder(cornerRadius: CGFloat = 24, lineWidth: CGFloat = 1.6, isBurning: Bool = true) -> some View {
        modifier(FlameBorderModifier(cornerRadius: cornerRadius, lineWidth: lineWidth, isBurning: isBurning))
    }
}
