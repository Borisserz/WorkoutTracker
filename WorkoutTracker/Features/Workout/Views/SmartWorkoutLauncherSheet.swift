internal import SwiftUI
import SwiftData

struct PremiumScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct SmartWorkoutLauncherSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme

    var onStartEmptySession: () -> Void
    var onSmartWorkoutTap: () -> Void
    var onPresetTap: (WorkoutPreset) -> Void
    var onExploreTap: () -> Void
    var onNewProgramTap: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                // Background with premium tech-minimalism radial glows
                BentoBackgroundGlowView()
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Custom top bar with close button
                    HStack {
                        Spacer()
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.3) : Color.black.opacity(0.15))
                        }
                        .buttonStyle(PremiumScaleButtonStyle())
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 8)

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 20) {
                            // Header
                            VStack(spacing: 6) {
                                Text("Начать тренировку")
                                    .font(.system(size: 28, weight: .black, design: .rounded))
                                    .foregroundColor(colorScheme == .dark ? PastelTheme.textPrimary : .black)
                                
                                Text("Выберите формат сегодняшней сессии")
                                    .font(.subheadline)
                                    .foregroundColor(PastelTheme.textSecondary)
                            }
                            .padding(.bottom, 12)

                            // 1. AI Smart Workout Card (Featured Bento - Full Width)
                            Button {
                                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                                dismiss()
                                onSmartWorkoutTap()
                            } label: {
                                aiBentoCard
                            }
                            .buttonStyle(PremiumScaleButtonStyle())

                            // 2. Secondary Row (HStack Grid: Quick Session & My Routines)
                            HStack(spacing: 16) {
                                // Quick Session
                                Button {
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    dismiss()
                                    onStartEmptySession()
                                } label: {
                                    squareBentoCard(
                                        title: "Быстрый старт",
                                        subtitle: "Свободный режим",
                                        icon: "play.circle.fill",
                                        colors: [PastelTheme.pastelSlate, PastelTheme.pastelSlate.opacity(0.7)],
                                        accentColor: PastelTheme.pastelSlate
                                    )
                                }
                                .buttonStyle(PremiumScaleButtonStyle())

                                // My Routines (Navigates to separate screen)
                                NavigationLink {
                                    SmartWorkoutRoutinesListView(
                                        onPresetTap: onPresetTap,
                                        onNewProgramTap: onNewProgramTap,
                                        onExploreTap: onExploreTap
                                    )
                                } label: {
                                    squareBentoCard(
                                        title: "Мои шаблоны",
                                        subtitle: "Сохраненные программы",
                                        icon: "list.bullet.clipboard.fill",
                                        colors: [PastelTheme.pastelSage, PastelTheme.pastelSage.opacity(0.7)],
                                        accentColor: PastelTheme.pastelSage
                                    )
                                }
                                .buttonStyle(PremiumScaleButtonStyle())
                            }

                            // 3. Legendary Programs Banner (Gold/Orange Neon - Full Width)
                            NavigationLink {
                                LegendaryRoutinesView()
                            } label: {
                                legendaryBentoBanner
                            }
                            .buttonStyle(PremiumScaleButtonStyle())
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 30)
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }

    // MARK: - Bento Cards UI Components

    private var aiBentoCard: some View {
        HStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(PastelTheme.cardSurfaceSubtle)
                    .frame(width: 60, height: 60)
                
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(PastelTheme.pastelLavender)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("ИИ-генератор")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(colorScheme == .dark ? PastelTheme.textPrimary : .black)
                    
                    Text("ИИ")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(PastelTheme.textOnOat)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(PastelTheme.pastelLavender)
                        .cornerRadius(6)
                }
                
                Text("Персональная программа тренировки за пару секунд")
                    .font(.caption)
                    .foregroundColor(PastelTheme.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(PastelTheme.textMuted)
                .font(.footnote)
        }
        .padding(20)
        .background(colorScheme == .dark ? PastelTheme.cardSurface : Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(PastelTheme.cardBorder, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func squareBentoCard(
        title: String,
        subtitle: String,
        icon: String,
        colors: [Color],
        accentColor: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack(alignment: .center) {
                Circle()
                    .fill(PastelTheme.cardSurfaceSubtle)
                    .frame(width: 48, height: 48)
                
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(accentColor)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(colorScheme == .dark ? PastelTheme.textPrimary : .black)
                
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(PastelTheme.textSecondary)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(colorScheme == .dark ? PastelTheme.cardSurface : Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(PastelTheme.cardBorder, lineWidth: 1)
        )
    }

    private var legendaryBentoBanner: some View {
        HStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(PastelTheme.cardSurfaceSubtle)
                    .frame(width: 56, height: 56)
                
                Image(systemName: "crown.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(PastelTheme.pastelAmber)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Золотая эра")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(colorScheme == .dark ? PastelTheme.textPrimary : .black)
                
                Text("Классические программы легенд бодибилдинга")
                    .font(.caption)
                    .foregroundColor(PastelTheme.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(PastelTheme.textMuted)
                .font(.footnote)
        }
        .padding(20)
        .background(colorScheme == .dark ? PastelTheme.cardSurface : Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(PastelTheme.cardBorder, lineWidth: 1)
        )
    }
}

struct BentoBackgroundGlowView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var animateGlow = false

    var body: some View {
        ZStack {
            (colorScheme == .dark ? PastelTheme.canvas : Color(UIColor.systemGroupedBackground))

            if colorScheme == .dark {
                // Subtle warm ambient breathing for dark mode
                Circle()
                    .fill(PastelTheme.pastelAmber.opacity(0.03))
                    .frame(width: 320, height: 320)
                    .blur(radius: 80)
                    .offset(x: animateGlow ? -60 : -100, y: animateGlow ? -160 : -120)
                    .scaleEffect(animateGlow ? 1.1 : 0.95)

                Circle()
                    .fill(PastelTheme.pastelOat.opacity(0.02))
                    .frame(width: 280, height: 280)
                    .blur(radius: 80)
                    .offset(x: animateGlow ? 100 : 70, y: animateGlow ? 40 : 80)
                    .scaleEffect(animateGlow ? 0.95 : 1.1)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 5.0).repeatForever(autoreverses: true)) {
                animateGlow = true
            }
        }
    }
}
