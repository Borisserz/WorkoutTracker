//
//  FeatureDiscoveryCarouselView.swift
//  WorkoutTracker
//

internal import SwiftUI

struct FeatureDiscoveryCarouselView: View {
    let onFinish: () -> Void
    @State private var selectedTab = 0
    @AppStorage("hasSeenFeatureDiscovery") private var hasSeenFeatureDiscovery = false

    var body: some View {
        ZStack {
            PastelTheme.canvas.ignoresSafeArea()
            
            // Subtle ambient backdrop glow
            Circle()
                .fill(glowColor.opacity(0.12))
                .frame(width: 300, height: 300)
                .blur(radius: 80)
                .offset(y: -150)
                .animation(.easeInOut, value: selectedTab)

            VStack(spacing: 0) {
                TabView(selection: $selectedTab) {
                    FeatureSlide(
                        icon: "sparkles.tv",
                        title: "ИИ-тренер и камера",
                        description: "Умное отслеживание траектории движения и автоматический подсчет повторений в реальном времени.",
                        gradientColors: [PastelTheme.pastelLavender, PastelTheme.pastelLavender.opacity(0.7)]
                    )
                    .tag(0)

                    FeatureSlide(
                        icon: "chart.xyaxis.line",
                        title: "Глубокая аналитика",
                        description: "Наглядные графики прогресса, динамика силовых показателей и распределение нагрузки по мышцам.",
                        gradientColors: [PastelTheme.pastelSlate, PastelTheme.pastelSlate.opacity(0.7)]
                    )
                    .tag(1)
                    
                    FeatureSlide(
                        icon: "camera.viewfinder",
                        title: "Фото-прогресс",
                        description: "Фиксируйте трансформацию тела и сравнивайте фотографии до и после в едином ракурсе.",
                        gradientColors: [PastelTheme.pastelSage, PastelTheme.pastelSage.opacity(0.7)]
                    )
                    .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                Spacer().frame(height: 30)

                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    hasSeenFeatureDiscovery = true
                    onFinish()
                }) {
                    Text(selectedTab == 2 ? "Начать" : "Пропустить")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(PastelTheme.textOnOat)
                        .frame(maxWidth: .infinity)
                        .frame(height: PastelTheme.ButtonMetrics.heroHeight)
                        .background(PastelTheme.pastelOat)
                        .clipShape(RoundedRectangle(cornerRadius: PastelTheme.ButtonMetrics.heroRadius, style: .continuous))
                        .shadow(color: PastelTheme.pastelOat.opacity(0.15), radius: 10, y: 4)
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 50)
            }
        }
    }

    private var glowColor: Color {
        switch selectedTab {
        case 0: return PastelTheme.pastelLavender
        case 1: return PastelTheme.pastelSlate
        case 2: return PastelTheme.pastelSage
        default: return .clear
        }
    }
}

struct FeatureSlide: View {
    let icon: String
    let title: String
    let description: String
    let gradientColors: [Color]

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(PastelTheme.cardSurfaceSubtle)
                    .frame(width: 120, height: 120)
                    .overlay(
                        Circle().stroke(PastelTheme.cardBorder, lineWidth: 1)
                    )
                
                Image(systemName: icon)
                    .font(.system(size: 48, weight: .light))
                    .foregroundColor(gradientColors[0])
            }
            .padding(.bottom, 20)

            Text(title)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundColor(PastelTheme.textPrimary)
                .multilineTextAlignment(.center)

            Text(description)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(PastelTheme.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 40)

            Spacer()
        }
    }
}
