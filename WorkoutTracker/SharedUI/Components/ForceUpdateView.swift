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
                    .fill(LinearGradient(colors: [.blue.opacity(0.3), .purple.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: width * 0.8, height: width * 0.8)
                    .blur(radius: 60)
                    .offset(x: appear ? width * 0.1 : -width * 0.1, y: appear ? -height * 0.1 : -height * 0.2)
                
                Circle()
                    .fill(LinearGradient(colors: [.cyan.opacity(0.2), .indigo.opacity(0.3)], startPoint: .bottomLeading, endPoint: .topTrailing))
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
                                colors: [themeManager.current.primaryAccent.opacity(0.2), .cyan.opacity(0.2)],
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
                        .foregroundStyle(
                            LinearGradient(
                                colors: [themeManager.current.primaryAccent, .cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .rotationEffect(.degrees(appear ? 360 : 0))
                        .animation(.linear(duration: 20).repeatForever(autoreverses: false), value: appear)
                }
                .offset(y: appear ? 0 : 30)
                .opacity(appear ? 1 : 0)
                
                // Content Card
                VStack(spacing: 16) {
                    Text(LocalizedStringKey("Time to Update!"))
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [themeManager.current.primaryText, themeManager.current.primaryAccent],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .multilineTextAlignment(.center)
                        .lineLimit(1).minimumScaleFactor(0.8)
                    
                    Text(LocalizedStringKey("We've added powerful new features, AI enhancements, and critical fixes. Please update to the latest version to continue crushing your goals."))
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(themeManager.current.secondaryText)
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                }
                .padding(32)
                .background(Color(UIColor.secondarySystemBackground).opacity(0.5))
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
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
                    HStack(spacing: 12) {
                        Image(systemName: "icloud.and.arrow.down.fill")
                            .font(.title3)
                        Text(LocalizedStringKey("Update Now"))
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(
                        LinearGradient(
                            colors: [themeManager.current.primaryAccent, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: themeManager.current.primaryAccent.opacity(0.5), radius: 15, x: 0, y: 8)
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
