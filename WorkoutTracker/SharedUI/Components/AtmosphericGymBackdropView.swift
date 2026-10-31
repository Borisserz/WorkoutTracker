internal import SwiftUI

/// Atmospheric luxury athletic background that gently displays cycling gym visuals
/// beneath a protective OLED Cashmere Charcoal vignette.
/// Ensures 100% contrast and readability for all metrics, cards, and typography.
struct AtmosphericGymBackdropView: View {
    @State private var activeIndex: Int = 0
    @State private var scale: CGFloat = 1.0
    @State private var timer: Timer? = nil

    private let bgImages = ["gym_ambient_bg_1", "gym_ambient_bg_2"]

    var body: some View {
        ZStack {
            // Base Solid OLED Canvas
            PastelTheme.canvas
                .ignoresSafeArea()

            // 1. Cycling Ambient Gym Imagery with Ken Burns subtle breathing
            GeometryReader { geo in
                ZStack {
                    ForEach(0..<bgImages.count, id: \.self) { index in
                        Image(bgImages[index])
                            .resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                            .scaleEffect(activeIndex == index ? scale : 1.0)
                            .opacity(activeIndex == index ? 0.20 : 0.0)
                            .blur(radius: 3.5)
                            .animation(.easeInOut(duration: 1.8), value: activeIndex)
                    }
                }
            }
            .ignoresSafeArea()

            // 2. Protective Vignette Gradient Layers
            LinearGradient(
                stops: [
                    .init(color: PastelTheme.canvas.opacity(0.85), location: 0.0),
                    .init(color: PastelTheme.canvas.opacity(0.70), location: 0.25),
                    .init(color: PastelTheme.canvas.opacity(0.82), location: 0.65),
                    .init(color: PastelTheme.canvas, location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // 3. Subtle Radial Focus for Center Reading Comfort
            RadialGradient(
                colors: [
                    Color.clear,
                    PastelTheme.canvas.opacity(0.60)
                ],
                center: .center,
                startRadius: 180,
                endRadius: 520
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
        .allowsHitTesting(false)
        .onAppear {
            startAmbientCycle()
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }

    private func startAmbientCycle() {
        withAnimation(.easeInOut(duration: 12.0).repeatForever(autoreverses: true)) {
            scale = 1.045
        }
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 14.0, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 1.6)) {
                activeIndex = (activeIndex + 1) % bgImages.count
            }
        }
    }
}
