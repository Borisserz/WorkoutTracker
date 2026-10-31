internal import SwiftUI

/// Visual theme style for atmospheric gym backdrop per tab.
enum TabBackdropStyle: Sendable {
    case overview   // Nordic Athletic Sage + Warm Amber
    case history    // Warm Oat + Subtle Graphite
    case workout    // Warm Amber + Athletic Sage
    case aiHub      // Dusty Lavender + Glacier Slate
    case progress   // Golden Amber + Warm Beige

    var topColor: Color {
        switch self {
        case .overview: return PastelTheme.pastelSage
        case .history: return PastelTheme.pastelOat
        case .workout: return PastelTheme.pastelAmber
        case .aiHub: return PastelTheme.pastelLavender
        case .progress: return PastelTheme.pastelAmber
        }
    }

    var bottomColor: Color {
        switch self {
        case .overview: return PastelTheme.pastelAmber
        case .history: return PastelTheme.warmBeige
        case .workout: return PastelTheme.pastelSage
        case .aiHub: return PastelTheme.pastelSlate
        case .progress: return PastelTheme.pastelOat
        }
    }

    var topOpacity: Double {
        switch self {
        case .overview: return 0.08
        case .history: return 0.06
        case .workout: return 0.09
        case .aiHub: return 0.09
        case .progress: return 0.08
        }
    }

    var bottomOpacity: Double {
        switch self {
        case .overview: return 0.05
        case .history: return 0.04
        case .workout: return 0.06
        case .aiHub: return 0.06
        case .progress: return 0.06
        }
    }
}

/// Atmospheric luxury athletic background that gently displays cycling gym visuals
/// beneath a protective OLED Cashmere Charcoal vignette and tab-specific pastel mist.
/// Ensures 100% contrast and readability for all metrics, cards, and typography.
struct AtmosphericGymBackdropView: View {
    var style: TabBackdropStyle? = nil
    var selectedTab: Int? = nil

    @State private var activeIndex: Int = 0
    @State private var scale: CGFloat = 1.0
    @State private var timer: Timer? = nil

    private let bgImages = ["gym_ambient_bg_1", "gym_ambient_bg_2"]

    private var currentStyle: TabBackdropStyle {
        if let style { return style }
        if let selectedTab {
            switch selectedTab {
            case 0: return .overview
            case 1: return .history
            case 2: return .workout
            case 3: return .aiHub
            case 4: return .progress
            default: return .overview
            }
        }
        return .overview
    }

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
                            .opacity(activeIndex == index ? 0.18 : 0.0)
                            .blur(radius: 4.0)
                            .animation(.easeInOut(duration: 1.8), value: activeIndex)
                    }
                }
            }
            .ignoresSafeArea()

            // 1.5. Tab-Specific Organic Pastel Mist (Zero neon, pure ambient depth)
            GeometryReader { geo in
                let width = geo.size.width
                let height = geo.size.height

                ZStack {
                    // Top ambient light sphere
                    Circle()
                        .fill(currentStyle.topColor.opacity(currentStyle.topOpacity))
                        .frame(width: width * 0.85, height: width * 0.85)
                        .blur(radius: 95)
                        .offset(x: -width * 0.15, y: -height * 0.12)

                    // Bottom ambient light sphere
                    Circle()
                        .fill(currentStyle.bottomColor.opacity(currentStyle.bottomOpacity))
                        .frame(width: width * 0.75, height: width * 0.75)
                        .blur(radius: 90)
                        .offset(x: width * 0.20, y: height * 0.18)
                }
                .animation(.easeInOut(duration: 0.6), value: currentStyle.topOpacity)
            }
            .ignoresSafeArea()

            // 2. Protective Vignette Gradient Layers
            LinearGradient(
                stops: [
                    .init(color: PastelTheme.canvas.opacity(0.85), location: 0.0),
                    .init(color: PastelTheme.canvas.opacity(0.68), location: 0.25),
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
