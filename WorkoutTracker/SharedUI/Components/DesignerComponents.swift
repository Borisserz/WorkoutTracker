//
//  DesignerComponents.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 18.04.26.
//

internal import SwiftUI

// MARK: - Haptic Manager
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

// MARK: - Glass Card Modifier
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

// MARK: - Button Styles & Effects
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

// MARK: - Backgrounds
struct HistoryBreathingBackground: View {
    @State private var phase = false
    var cnsScore: Double
    var color3: Color { cnsScore > 50 ? .blue : .red }
    var color4: Color { cnsScore > 50 ? .indigo : .orange }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Circle().fill(Color.purple.opacity(0.15)).frame(width: 350, height: 350).blur(radius: 90).offset(x: phase ? -100 : 100, y: phase ? -150 : 50)
            Circle().fill(Color.cyan.opacity(0.12)).frame(width: 350, height: 350).blur(radius: 90).offset(x: phase ? 100 : -100, y: phase ? 150 : -50)
            Circle().fill(color3.opacity(0.1)).frame(width: 300, height: 300).blur(radius: 80).offset(x: phase ? 0 : 50, y: phase ? 50 : -100)
            Circle().fill(color4.opacity(0.08)).frame(width: 250, height: 250).blur(radius: 100).offset(x: phase ? 50 : -150, y: phase ? -50 : 150)
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
            }.fill(Color.white.opacity(0.03))
        }.ignoresSafeArea().allowsHitTesting(false)
    }
}

struct FloatingParticles: View {
    @State private var animate = false
    var body: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { i in
                Circle()
                    .fill(Color.white.opacity(Double.random(in: 0.1...0.3)))
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
// MARK: - Всплывающее окно получения достижения (Achievement Popup)
struct AchievementPopupView: View {
    let achievement: Achievement
    let onClose: () -> Void
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Темный фон с размытием
            Color.black.opacity(0.85).ignoresSafeArea()
            
            VStack(spacing: 24) {
                ZStack {
                    if achievement.isUnlocked {
                        Circle()
                            .fill(tierColor(achievement.tier).opacity(0.2))
                            .frame(width: 160, height: 160)
                            .scaleEffect(isAnimating ? 1.2 : 0.9)
                            .opacity(isAnimating ? 0 : 1)
                            .animation(.easeOut(duration: 1.5).repeatForever(autoreverses: false), value: isAnimating)
                    }
                    
                    Image(systemName: achievement.isUnlocked ? achievement.icon : "lock.fill")
                        .font(.system(size: 80))
                        .foregroundColor(achievement.isUnlocked ? tierColor(achievement.tier) : .gray)
                        .shadow(color: achievement.isUnlocked ? tierColor(achievement.tier).opacity(0.8) : .clear, radius: 20, x: 0, y: 0)
                }
                .padding(.bottom, 10)
                
                if achievement.isUnlocked {
                    Text("🏆").font(.largeTitle)
                    Text(LocalizedStringKey("Achievement Unlocked!"))
                        .font(.headline)
                        .foregroundColor(.yellow)
                        .textCase(.uppercase)
                        .tracking(2)
                } else {
                    Text(LocalizedStringKey("Locked"))
                        .font(.headline)
                        .foregroundColor(.gray)
                        .textCase(.uppercase)
                        .tracking(2)
                }
                
                Text(achievement.title)
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text(achievement.description)
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                
                if achievement.isUnlocked {
                    HStack(spacing: 6) {
                        Text(LocalizedStringKey("Level:"))
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.7))
                        Text(achievement.tier.name)
                            .font(.headline)
                            .foregroundColor(tierColor(achievement.tier))
                    }
                    .padding(.top, 10)
                } else if !achievement.progress.isEmpty {
                    Text(achievement.progress)
                        .font(.headline)
                        .foregroundColor(.cyan)
                        .padding(.top, 10)
                }
                
                Button(action: onClose) {
                    Text(LocalizedStringKey("Close"))
                        .font(.headline)
                        .foregroundColor(.black)
                        .frame(width: 200)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(16)
                }
                .padding(.top, 20)
            }
            .padding(30)
            .background(.ultraThinMaterial)
            .environment(\.colorScheme, .dark) // Фиксируем темную тему для поп-апа
            .cornerRadius(32)
            .overlay(
                RoundedRectangle(cornerRadius: 32)
                    .stroke(achievement.isUnlocked ? tierColor(achievement.tier).opacity(0.5) : Color.gray.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.3), radius: 30, x: 0, y: 15)
            .padding(.horizontal, 20)
        }
        .onAppear {
            if achievement.isUnlocked {
                isAnimating = true
                HapticManager.shared.impact(.heavy) // Вызываем тактильный отклик
            }
        }
    }
    
    private func tierColor(_ tier: AchievementTier) -> Color {
        switch tier {
        case .none: return .clear
        case .bronze: return .brown
        case .silver: return .gray
        case .gold: return .yellow
        case .diamond: return .cyan
        }
    }
}
// MARK: - ДОРОГОЙ ТЕМНЫЙ ФОН
struct PremiumDarkBackground: View {
    var body: some View {
        ZStack {
            Color.premiumBackground.ignoresSafeArea()
            
            // Статичные сферы
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

// MARK: - ДОРОГИЕ ЗЕРКАЛЬНЫЕ UI КОМПОНЕНТЫ
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

// MARK: - СТРОКА НАСТРОЕК
struct SettingRow: View {
    let icon: String
    let title: String
    let color: Color
    @Binding var isOn: Bool // Сделали Binding, чтобы управлять реальными данными
    
    var body: some View {
        HStack {
            Image(systemName: icon).foregroundStyle(color).frame(width: 20)
            Text(title).font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white)
            Spacer()
            Toggle("", isOn: $isOn).labelsHidden().scaleEffect(0.7).tint(Color.neonBlue)
        }
    }
}
// MARK: - ВЫПАДАЮЩЕЕ МЕНЮ НАСТРОЕК
struct SettingsDropdownMenu: View {
    @Binding var isShowing: Bool
    var onOpenFullSettings: () -> Void // Коллбэк для полного экрана
    
    // Подключаемся к реальным настройкам приложения
    @AppStorage(Constants.UserDefaultsKeys.appearanceMode.rawValue) private var appearanceMode: String = "dark"
    @AppStorage("hapticsEnabled") private var hapticsEnabled: Bool = true
    @State private var notificationsEnabled: Bool = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            // Темная тема (включает/выключает)
            SettingRow(icon: "moon.fill", title: "Темная тема", color: .indigo, isOn: Binding(
                get: { appearanceMode == "dark" },
                set: { appearanceMode = $0 ? "dark" : "light" }
            ))
            
            SettingRow(icon: "bell.fill", title: "Уведомления", color: .orange, isOn: $notificationsEnabled)
            SettingRow(icon: "waveform.path", title: "Вибрация", color: .pink, isOn: $hapticsEnabled)
            
            Divider().background(Color.white.opacity(0.2))
            
            // Кнопка для перехода к полным настройкам (как было раньше)
            Button(action: {
                withAnimation { isShowing = false }
                onOpenFullSettings()
            }) {
                HStack {
                    Text("Все настройки")
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
