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
            Color(red: 0.05, green: 0.05, blue: 0.08).ignoresSafeArea()
            
            // Background glow
            Circle()
                .fill(glowColor.opacity(0.15))
                .frame(width: 300, height: 300)
                .blur(radius: 80)
                .offset(y: -150)
                .animation(.easeInOut, value: selectedTab)

            VStack(spacing: 0) {
                TabView(selection: $selectedTab) {
                    FeatureSlide(
                        icon: "sparkles.tv",
                        title: "AI Coach Camera",
                        description: "Your personal trainer is watching. Get real-time form tracking and rep counting during your workouts.",
                        gradientColors: [.purple, .blue]
                    )
                    .tag(0)

                    FeatureSlide(
                        icon: "chart.xyaxis.line",
                        title: "Deep Analytics",
                        description: "Track your progress with advanced charts. Find your weak points and see your strength trends.",
                        gradientColors: [.blue, .cyan]
                    )
                    .tag(1)
                    
                    FeatureSlide(
                        icon: "camera.viewfinder",
                        title: "Photo Progress",
                        description: "The mirror doesn't lie. Take progress photos and compare them side-by-side to see your real transformation.",
                        gradientColors: [.cyan, .green]
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
                    Text(selectedTab == 2 ? "Let's Go" : "Skip")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(LinearGradient(colors: [.white, Color(white: 0.85)], startPoint: .top, endPoint: .bottom))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .white.opacity(0.3), radius: 10, y: 5)
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 50)
            }
        }
    }

    private var glowColor: Color {
        switch selectedTab {
        case 0: return .purple
        case 1: return .blue
        case 2: return .cyan
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
                    .fill(LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 120, height: 120)
                    .shadow(color: gradientColors[0].opacity(0.5), radius: 20, y: 10)
                
                Image(systemName: icon)
                    .font(.system(size: 50, weight: .light))
                    .foregroundColor(.white)
            }
            .padding(.bottom, 20)

            Text(title)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            Text(description)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 40)

            Spacer()
        }
    }
}
