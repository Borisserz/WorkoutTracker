//
//  ForceUpdateView.swift
//  WorkoutTracker
//

internal import SwiftUI

struct ForceUpdateView: View {
    @Environment(ThemeManager.self) private var themeManager
    @State private var appear = false
    @State private var pulse = false

    var body: some View {
        ZStack {
            // Animated Background
            themeManager.current.background.ignoresSafeArea()
            
            GeometryReader { proxy in
                let width = proxy.size.width
                let height = proxy.size.height
                
                Circle()
                    .fill(LinearGradient(colors: [PastelTheme.pastelSlate.opacity(0.25), PastelTheme.pastelLavender.opacity(0.25)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: width * 0.8, height: width * 0.8)
                    .blur(radius: 60)
                    .offset(x: appear ? width * 0.1 : -width * 0.1, y: appear ? -height * 0.1 : -height * 0.2)
                
                Circle()
                    .fill(LinearGradient(colors: [PastelTheme.pastelLavender.opacity(0.2), PastelTheme.pastelOat.opacity(0.2)], startPoint: .bottomLeading, endPoint: .topTrailing))
                    .frame(width: width * 0.6, height: width * 0.6)
                    .blur(radius: 50)
                    .offset(x: appear ? -width * 0.2 : width * 0.2, y: appear ? height * 0.1 : height * 0.3)
            }
            .animation(.easeInOut(duration: 8).repeatForever(autoreverses: true), value: appear)
            
            VStack(spacing: 40) {
                Spacer()
                
                // Animated Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [PastelTheme.pastelOat.opacity(0.2), PastelTheme.pastelSlate.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 160, height: 160)
                        .scaleEffect(pulse ? 1.05 : 0.95)
                        .blur(radius: pulse ? 10 : 20)
                        .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: pulse)
                        
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 140, height: 140)
                        .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                        .shadow(color: themeManager.current.primaryAccent.opacity(0.3), radius: 20, x: 0, y: 10)
                    
                    Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 70, height: 70)
                        .foregroundStyle(PastelTheme.pastelSlate)
                        .rotationEffect(.degrees(appear ? 360 : 0))
                        .animation(.linear(duration: 20).repeatForever(autoreverses: false), value: appear)
                }
                .offset(y: appear ? 0 : 30)
                .opacity(appear ? 1 : 0)
                
                // Content Card
                VStack(spacing: 16) {
                    Text("Время обновиться")
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(PastelTheme.textPrimary)
                        .multilineTextAlignment(.center)
                        .lineLimit(1).minimumScaleFactor(0.8)
                    
                    Text("Мы добавили новые функции, улучшили ИИ-тренера и повысили стабильность работы приложения. Пожалуйста, обновитесь до актуальной версии.")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(PastelTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                }
                .padding(32)
                .background(PastelTheme.cardSurface)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(PastelTheme.cardBorder, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
                .padding(.horizontal, 24)
                .offset(y: appear ? 0 : 40)
                .opacity(appear ? 1 : 0)
                
                Spacer()
                
                // Action Button
                Button {
                    let generator = UIImpactFeedbackGenerator(style: .heavy)
                    generator.impactOccurred()
                    AppReviewManager.openAppStoreReview()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "icloud.and.arrow.down.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Обновить приложение")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(PastelTheme.textOnOat)
                    .frame(maxWidth: .infinity)
                    .frame(height: PastelTheme.ButtonMetrics.heroHeight)
                    .background(PastelTheme.pastelOat)
                    .clipShape(RoundedRectangle(cornerRadius: PastelTheme.ButtonMetrics.heroRadius, style: .continuous))
                    .shadow(color: PastelTheme.pastelOat.opacity(0.16), radius: 10, y: 3)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 50)
                .offset(y: appear ? 0 : 50)
                .opacity(appear ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                appear = true
            }
            pulse = true
        }
    }
}
