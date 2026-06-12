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
                                Text(LocalizedStringKey("Start Session"))
                                    .font(.system(size: 28, weight: .black, design: .rounded))
                                    .foregroundColor(colorScheme == .dark ? .white : .black)
                                
                                Text(LocalizedStringKey("Select how you want to train today"))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
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
                                        title: "Quick Session",
                                        subtitle: "Freestyle Mode",
                                        icon: "play.circle.fill",
                                        colors: [.blue, .cyan],
                                        accentColor: .blue
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
                                        title: "My Routines",
                                        subtitle: "Saved Templates",
                                        icon: "list.bullet.clipboard.fill",
                                        colors: [.green, .mint],
                                        accentColor: .green
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
                    .fill(LinearGradient(colors: [.purple.opacity(0.3), .indigo.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 64, height: 64)
                
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(LinearGradient(colors: [.purple, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(LocalizedStringKey("AI Smart Generator"))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                    
                    Text("NEW")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.purple)
                        .cornerRadius(6)
                }
                
                Text(LocalizedStringKey("Generate custom personalized routine tailored for you instantly"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.footnote)
        }
        .padding(20)
        .background(colorScheme == .dark ? themeManager.current.surface : Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    LinearGradient(colors: [.purple.opacity(0.4), .indigo.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1.5
                )
        )
        .shadow(color: .purple.opacity(colorScheme == .dark ? 0.12 : 0.04), radius: 12, x: 0, y: 6)
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
                    .fill(LinearGradient(colors: [colors[0].opacity(0.2), colors[1].opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 48, height: 48)
                
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(title))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                
                Text(LocalizedStringKey(subtitle))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(colorScheme == .dark ? themeManager.current.surface : Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    LinearGradient(colors: [colors[0].opacity(0.4), colors[1].opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1.2
                )
        )
        .shadow(color: accentColor.opacity(colorScheme == .dark ? 0.08 : 0.02), radius: 10, x: 0, y: 5)
    }

    private var legendaryBentoBanner: some View {
        HStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.orange.opacity(0.3), .red.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 56, height: 56)
                
                Image(systemName: "crown.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey("Legendary Programs"))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text(LocalizedStringKey("Train with protocols from bodybuilding icons of Golden Era"))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(.white.opacity(0.7))
                .font(.footnote)
        }
        .padding(20)
        .background(
            ZStack {
                LinearGradient(colors: [Color(hex: "1f1c2c"), Color(hex: "928dab").opacity(0.9)], startPoint: .topLeading, endPoint: .bottomTrailing)
                
                // Tech glowing grid lines overlay
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.orange.opacity(0.05))
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    LinearGradient(colors: [.orange.opacity(0.5), .red.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1.5
                )
        )
        .shadow(color: .orange.opacity(0.2), radius: 12, x: 0, y: 6)
    }
}

struct BentoBackgroundGlowView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var animateGlow = false

    var body: some View {
        ZStack {
            (colorScheme == .dark ? themeManager.current.background : Color(UIColor.systemGroupedBackground))

            if colorScheme == .dark {
                // Radial soft glows for dark mode
                Circle()
                    .fill(Color.purple.opacity(0.08))
                    .frame(width: 280, height: 280)
                    .blur(radius: 60)
                    .offset(x: animateGlow ? -90 : -130, y: animateGlow ? -200 : -160)
                    .scaleEffect(animateGlow ? 1.15 : 0.9)

                Circle()
                    .fill(Color.blue.opacity(0.08))
                    .frame(width: 250, height: 250)
                    .blur(radius: 60)
                    .offset(x: animateGlow ? 140 : 100, y: animateGlow ? 60 : 100)
                    .scaleEffect(animateGlow ? 0.9 : 1.1)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 5.0).repeatForever(autoreverses: true)) {
                animateGlow = true
            }
        }
    }
}
