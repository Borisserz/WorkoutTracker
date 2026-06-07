

internal import SwiftUI

class HapticManager {
    static let shared = HapticManager()
    private init() {}
    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
    func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}

struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 24
    var strokeColors: [Color] = [.white.opacity(0.4), .clear, .cyan.opacity(0.3)]

    func body(content: Content) -> some View {
        content
            .padding(20)
            .background(.ultraThinMaterial)
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(LinearGradient(colors: strokeColors, startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
            )
            .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 24, strokeColors: [Color] = [.white.opacity(0.4), .clear, .cyan.opacity(0.3)]) -> some View {
        self.modifier(GlassCardModifier(cornerRadius: cornerRadius, strokeColors: strokeColors))
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct ParallaxButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .rotation3DEffect(.degrees(configuration.isPressed ? 5 : 0), axis: (x: 1, y: 0, z: 0))
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.5), value: configuration.isPressed)
    }
}

struct PulseEffect: ViewModifier {
    @State private var isPulsing = false
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.2 : 0.8)
            .opacity(isPulsing ? 0.5 : 1.0)
            .onAppear {
                withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) { isPulsing = true }
            }
    }
}

struct HistoryBreathingBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var phase = false
    var cnsScore: Double
    var color3: Color { cnsScore > 50 ? .blue : .red }
    var color4: Color { cnsScore > 50 ? .indigo : .orange }

    var body: some View {
        ZStack {
            (colorScheme == .dark ? Color.black : Color(UIColor.systemGroupedBackground)).ignoresSafeArea()

            Circle().fill(Color.purple.opacity(colorScheme == .dark ? 0.15 : 0.08)).frame(width: 350, height: 350).blur(radius: 90).offset(x: phase ? -100 : 100, y: phase ? -150 : 50)
            Circle().fill(Color.cyan.opacity(colorScheme == .dark ? 0.12 : 0.05)).frame(width: 350, height: 350).blur(radius: 90).offset(x: phase ? 100 : -100, y: phase ? 150 : -50)
            Circle().fill(color3.opacity(colorScheme == .dark ? 0.1 : 0.05)).frame(width: 300, height: 300).blur(radius: 80).offset(x: phase ? 0 : 50, y: phase ? 50 : -100)
            Circle().fill(color4.opacity(colorScheme == .dark ? 0.08 : 0.04)).frame(width: 250, height: 250).blur(radius: 100).offset(x: phase ? 50 : -150, y: phase ? -50 : 150)
        }
        .rotationEffect(.degrees(phase ? 15 : -15)).scaleEffect(phase ? 1.05 : 0.95).drawingGroup()
        .onAppear { withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) { phase.toggle() } }
    }
}

struct DotGridBackground: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                for x in stride(from: 0, to: geometry.size.width, by: 20) {
                    for y in stride(from: 0, to: geometry.size.height, by: 20) {
                        path.addEllipse(in: CGRect(x: x, y: y, width: 1.5, height: 1.5))
                    }
                }
            }.fill(Color.gray.opacity(0.05)) 
        }.ignoresSafeArea().allowsHitTesting(false)
    }
}

struct FloatingParticles: View {
    @State private var animate = false
    var body: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { i in
                Circle()
                    .fill(Color.gray.opacity(Double.random(in: 0.1...0.3))) 
                    .frame(width: CGFloat.random(in: 2...4), height: CGFloat.random(in: 2...4))
                    .position(x: CGFloat.random(in: 0...400), y: animate ? -50 : CGFloat.random(in: 400...800))
                    .animation(.linear(duration: Double.random(in: 8...20)).repeatForever(autoreverses: false).delay(Double.random(in: 0...5)), value: animate)
            }
        }.onAppear { animate = true }.allowsHitTesting(false)
    }
}

struct CustomDonutChart: View {
    var data: [(value: Double, color: Color, id: UUID)]
    var thickness: CGFloat
    @Binding var activeId: UUID?

    var body: some View {
        GeometryReader { geometry in
            let total = data.map { $0.value }.reduce(0, +)
            ZStack {
                ForEach(0..<data.count, id: \.self) { index in
                    let item = data[index]
                    let startValue = data[0..<index].map { $0.value }.reduce(0, +)
                    let startAngle = (startValue / total) * 360
                    let sweepAngle = (item.value / total) * 360
                    let isSelected = activeId == item.id

                    Circle()
                        .trim(from: startAngle / 360, to: (startAngle + sweepAngle) / 360)
                        .stroke(item.color, style: StrokeStyle(lineWidth: isSelected ? thickness + 4 : thickness, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .scaleEffect(isSelected ? 1.05 : 1.0)
                        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: isSelected)
                        .animation(.spring(response: 0.8, dampingFraction: 0.6), value: total)
                }
            }
        }.drawingGroup()
    }
}


struct ConfettiParticle: Identifiable {
    let id = UUID()
    var position: CGPoint
    var color: Color
    var size: CGFloat
    var rotation: Double
    var speed: Double
    var xSpeed: Double
}

struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []
    @State private var timer: Timer?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles) { particle in
                    Rectangle()
                        .fill(particle.color)
                        .frame(width: particle.size, height: particle.size * 0.6)
                        .rotationEffect(.degrees(particle.rotation))
                        .position(particle.position)
                }
            }
            .onAppear {
                createParticles(in: geometry.size)
                startAnimation(in: geometry.size)
            }
            .onDisappear {
                timer?.invalidate()
            }
        }
        .allowsHitTesting(false)
    }

    private func createParticles(in size: CGSize) {
        let colors: [Color] = [.red, .blue, .green, .yellow, .orange, .purple, .pink, .cyan]
        for _ in 0..<80 {
            let particle = ConfettiParticle(
                position: CGPoint(x: CGFloat.random(in: 0...size.width), y: CGFloat.random(in: -size.height...0)),
                color: colors.randomElement()!,
                size: CGFloat.random(in: 8...16),
                rotation: Double.random(in: 0...360),
                speed: Double.random(in: 2...6),
                xSpeed: Double.random(in: -2...2)
            )
            particles.append(particle)
        }
    }

    private func startAnimation(in size: CGSize) {
        timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            for i in particles.indices {
                particles[i].position.y += particles[i].speed
                particles[i].position.x += particles[i].xSpeed
                particles[i].rotation += particles[i].xSpeed * 2

                if particles[i].position.y > size.height + 50 {
                    particles[i].position.y = -50
                    particles[i].position.x = CGFloat.random(in: 0...size.width)
                }
            }
        }
    }
}

struct AchievementPopupView: View {
    let achievements: [Achievement]
    let onClose: () -> Void
    
    @State private var currentIndex = 0
    @State private var isAnimatingRing = false
    @State private var appearAnimation = false
    @State private var showConfetti = false
    
    private var currentAchievement: Achievement { achievements[currentIndex] }

    var body: some View {
        ZStack {
            // Background blur and dim
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture { handleClose() }
                .overlay(.ultraThinMaterial)

            if showConfetti && currentAchievement.isUnlocked {
                FloatingParticles()
                    .transition(.opacity)
                    .zIndex(0.5)
                ConfettiView()
                    .transition(.opacity)
                    .zIndex(1)
            }

            // Glow behind card
            if currentAchievement.isUnlocked {
                Circle()
                    .fill(tierColor(currentAchievement.tier).opacity(0.3))
                    .frame(width: 300, height: 300)
                    .blur(radius: 80)
                    .scaleEffect(isAnimatingRing ? 1.2 : 0.8)
                    .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: isAnimatingRing)
            }

            VStack(spacing: 0) {
                // Header / Icon area
                ZStack {
                    if currentAchievement.isUnlocked {
                        // Premium spinning rays / rings
                        Circle()
                            .strokeBorder(
                                LinearGradient(colors: [tierColor(currentAchievement.tier).opacity(0.8), .clear], startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: 4
                            )
                            .frame(width: 140, height: 140)
                            .rotationEffect(.degrees(isAnimatingRing ? 360 : 0))
                            .animation(.linear(duration: 8).repeatForever(autoreverses: false), value: isAnimatingRing)
                        
                        Circle()
                            .fill(tierColor(currentAchievement.tier).opacity(0.15))
                            .frame(width: 120, height: 120)
                            .scaleEffect(isAnimatingRing ? 1.1 : 0.9)
                            .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isAnimatingRing)
                    }

                    Image(systemName: currentAchievement.isUnlocked ? currentAchievement.icon : "lock.fill")
                        .font(.system(size: 60, weight: .semibold))
                        .foregroundColor(currentAchievement.isUnlocked ? tierColor(currentAchievement.tier) : .gray)
                        .shadow(color: currentAchievement.isUnlocked ? tierColor(currentAchievement.tier).opacity(0.8) : .clear, radius: 15, x: 0, y: 0)
                }
                .padding(.top, 40)
                .padding(.bottom, 24)

                // Text Content
                VStack(spacing: 12) {
                    if currentAchievement.isUnlocked {
                        Text(LocalizedStringKey("Achievement Unlocked!"))
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(tierColor(currentAchievement.tier))
                            .textCase(.uppercase)
                            .tracking(2)
                    } else {
                        Text(LocalizedStringKey("Locked"))
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.gray)
                            .textCase(.uppercase)
                            .tracking(2)
                    }

                    Text(currentAchievement.title)
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)

                    Text(currentAchievement.description)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.top, 4)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Tier Info / Progress
                VStack(spacing: 8) {
                    if currentAchievement.isUnlocked {
                        HStack(spacing: 8) {
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundColor(tierColor(currentAchievement.tier))
                            Text(currentAchievement.tier.name)
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundColor(tierColor(currentAchievement.tier))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(tierColor(currentAchievement.tier).opacity(0.15))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(tierColor(currentAchievement.tier).opacity(0.3), lineWidth: 1))
                    } else if !currentAchievement.progress.isEmpty {
                        Text(currentAchievement.progress)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.cyan)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.cyan.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
                .padding(.top, 24)
                .padding(.bottom, 32)

                // Button
                Button(action: handleClose) {
                    HStack {
                        Text(currentIndex < achievements.count - 1 ? LocalizedStringKey("Next") : LocalizedStringKey("Awesome"))
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                        if currentIndex < achievements.count - 1 {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 16, weight: .bold))
                        }
                    }
                    .foregroundColor(currentAchievement.isUnlocked ? .black : .white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        currentAchievement.isUnlocked 
                        ? AnyView(LinearGradient(colors: [.white, Color(white: 0.9)], startPoint: .top, endPoint: .bottom))
                        : AnyView(Color.white.opacity(0.2))
                    )
                }
                .buttonStyle(ScaleButtonStyle())
                .clipShape(RoundedRectangle(cornerRadius: 0)) 
            }
            .background(
                RoundedRectangle(cornerRadius: 32)
                    .fill(Color(red: 0.1, green: 0.1, blue: 0.15).opacity(0.8))
            )
            .background(
                RoundedRectangle(cornerRadius: 32)
                    .fill(.ultraThinMaterial)
            )
            .clipShape(RoundedRectangle(cornerRadius: 32))
            .overlay(
                RoundedRectangle(cornerRadius: 32)
                    .stroke(
                        LinearGradient(
                            colors: [
                                currentAchievement.isUnlocked ? tierColor(currentAchievement.tier).opacity(0.8) : .white.opacity(0.3),
                                .clear,
                                currentAchievement.isUnlocked ? tierColor(currentAchievement.tier).opacity(0.4) : .clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .overlay(
                // Holographic Shimmer Effect
                GeometryReader { geo in
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.2), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: geo.size.width * 2, height: geo.size.height * 2)
                    .offset(x: appearAnimation ? geo.size.width : -geo.size.width * 2,
                            y: appearAnimation ? geo.size.height : -geo.size.height * 2)
                    .animation(.linear(duration: 2.5).delay(0.5).repeatForever(autoreverses: false), value: appearAnimation)
                    .mask(RoundedRectangle(cornerRadius: 32))
                }
            )
            .shadow(color: .black.opacity(0.5), radius: 40, x: 0, y: 20)
            .padding(.horizontal, 24)
            .rotation3DEffect(
                .degrees(appearAnimation ? 0 : 15),
                axis: (x: 1, y: 0, z: 0)
            )
            .scaleEffect(appearAnimation ? 1.0 : 0.8)
            .opacity(appearAnimation ? 1.0 : 0.0)
            .id(currentIndex)
            .onTapGesture { handleClose() }
            .zIndex(2)
        }
        .onAppear { setupAnimation() }
        .onChange(of: currentIndex) { _ in setupAnimation() }
    }
    
    private func setupAnimation() {
        showConfetti = false
        if currentAchievement.isUnlocked {
            isAnimatingRing = true
            HapticManager.shared.impact(.heavy)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation { showConfetti = true }
            }
        } else {
            isAnimatingRing = false
        }
        
        appearAnimation = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                appearAnimation = true
            }
        }
    }

    private func handleClose() {
        HapticManager.shared.impact(.light)
        if currentIndex < achievements.count - 1 {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentIndex += 1
            }
        } else {
            withAnimation(.easeIn(duration: 0.2)) {
                appearAnimation = false
                showConfetti = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                onClose()
            }
        }
    }

    private func tierColor(_ tier: AchievementTier) -> Color {
        switch tier {
        case .none: return .clear
        case .bronze: return .orange.opacity(0.8)
        case .silver: return .gray
        case .gold: return .yellow
        case .diamond: return .cyan
        }
    }
}

struct PremiumDarkBackground: View {
    var body: some View {
        ZStack {
            Color.premiumBackground.ignoresSafeArea()

            Circle()
                .fill(Color.neonBlue.opacity(0.15))
                .frame(width: 350)
                .blur(radius: 120)
                .offset(x: -100, y: -150)

            Circle()
                .fill(Color.neonPurple.opacity(0.12))
                .frame(width: 400)
                .blur(radius: 130)
                .offset(x: 100, y: 100)
        }
    }
}

struct PremiumGlassButton: View {
    let title: String
    var subtitle: String? = nil
    let icon: String
    let colorTint: Color
    var isSmall: Bool = false
    let action: () -> Void

    @State private var isPressed: Bool = false

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            HStack(alignment: .top, spacing: 16) {
                ZStack {
                    Circle().fill(colorTint.opacity(0.2)).frame(width: isSmall ? 40 : 50, height: isSmall ? 40 : 50)
                    Image(systemName: icon).font(.system(size: isSmall ? 20 : 24, weight: .bold))
                        .foregroundStyle(colorTint)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.system(size: isSmall ? 16 : 18, weight: .bold, design: .rounded)).foregroundStyle(.white).lineLimit(2)
                    if let subtitle = subtitle { Text(subtitle).font(.system(size: 13, weight: .medium, design: .rounded)).foregroundStyle(.white.opacity(0.6)) }
                }
                if !isSmall { Spacer() }
            }
            .padding(isSmall ? 16 : 20)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.2), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

struct SettingRow: View {
    let icon: String
    let title: String
    let color: Color
    @Binding var isOn: Bool 

    var body: some View {
        HStack {
            Image(systemName: icon).foregroundStyle(color).frame(width: 20)
            Text(title).font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white)
            Spacer()
            Toggle("", isOn: $isOn).labelsHidden().scaleEffect(0.7).tint(Color.neonBlue)
        }
    }
}

struct SettingsDropdownMenu: View {
    @Binding var isShowing: Bool
    var onOpenFullSettings: () -> Void 

    @AppStorage(Constants.UserDefaultsKeys.appearanceMode.rawValue) private var appearanceMode: String = "dark"
    @AppStorage("hapticsEnabled") private var hapticsEnabled: Bool = true
    @State private var notificationsEnabled: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            SettingRow(icon: "moon.fill", title: "Dark Theme", color: .indigo, isOn: Binding(
                get: { appearanceMode == "dark" },
                set: { appearanceMode = $0 ? "dark" : "light" }
            ))

            SettingRow(icon: "bell.fill", title: "Notifications", color: .orange, isOn: $notificationsEnabled)
            SettingRow(icon: "waveform.path", title: "Vibration", color: .pink, isOn: $hapticsEnabled)

            Divider().background(Color.white.opacity(0.2))

            Button(action: {
                withAnimation { isShowing = false }
                onOpenFullSettings()
            }) {
                HStack {
                    Text("All Settings")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .foregroundStyle(.white.opacity(0.8))
                .padding(.vertical, 4)
            }
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
        .background(Color.black.opacity(0.4), in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(LinearGradient(colors: [.white.opacity(0.5), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5))
        .shadow(color: .black.opacity(0.5), radius: 30, x: 0, y: 15)
        .frame(width: 230)
    }
}
extension HapticManager {
    static func playLightImpact() { shared.impact(.light) }
    static func playMediumImpact() { shared.impact(.medium) }
    static func playHeavyImpact() { shared.impact(.heavy) }
    static func playSelection() { shared.selection() }
    static func playSuccess() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
