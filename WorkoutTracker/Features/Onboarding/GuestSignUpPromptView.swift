internal import SwiftUI
import AuthenticationServices
import GoogleSignIn

struct GuestSignUpPromptView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(AppStateManager.self) private var appState

    @State private var isAuthenticating = false
    @State private var authErrorMessage: String?

    private let controlWidth: CGFloat = 320
    private let controlHeight: CGFloat = 54
    private let corner: CGFloat = 16

    var body: some View {
        ZStack {
            AuroraPromptBackground()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .padding()
                }

                Spacer()

                VStack(spacing: 16) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 56, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(colors: [.white, .green],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .shadow(color: .green.opacity(0.4), radius: 20, y: 8)

                    Text("Workout Complete! 🎉")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text("You're doing great! Create an account to permanently save your workouts, unlock smart analytics, and sync across devices.")
                        .font(.system(size: 15, weight: .medium))
                        .lineSpacing(3)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.horizontal, 28)
                }

                Spacer()

                VStack(alignment: .leading, spacing: 12) {
                    FeatureRow(icon: "cloud.fill", text: "Never lose your data")
                    FeatureRow(icon: "arrow.triangle.2.circlepath", text: "Sync with your iPad & Watch")
                    FeatureRow(icon: "chart.xyaxis.line", text: "Advanced AI insights")
                }
                .padding(.bottom, 40)

                VStack(spacing: 12) {
                    SignInWithAppleButton(.continue) { request in
                        SocialAuthService.shared.prepareAppleRequest(request)
                    } onCompletion: { result in
                        Task { await authenticate { try await SocialAuthService.shared.handleAppleAuthorization(result) } }
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(maxWidth: controlWidth)
                    .frame(height: controlHeight)
                    .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))

                    Button(action: {
                        Task { await authenticate { try await SocialAuthService.shared.signInWithGoogle() } }
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: "globe")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Continue with Google")
                        }
                    }
                    .buttonStyle(PromptGlassAuthButtonStyle(width: controlWidth, height: controlHeight, corner: corner))

                    Button("Not now", action: {
                        TrackingManager.shared.track(.guestModeChosen)
                        dismiss()
                    })
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.top, 8)
                }
                .disabled(isAuthenticating)
                .opacity(isAuthenticating ? 0.6 : 1)
                .overlay { if isAuthenticating { ProgressView().tint(.white) } }
                .padding(.bottom, 24)
            }
        }
        .alert("Couldn't log in",
               isPresented: Binding(get: { authErrorMessage != nil },
                                    set: { if !$0 { authErrorMessage = nil } })) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(authErrorMessage ?? "")
        }
    }

    @MainActor
    private func authenticate(_ action: @escaping () async throws -> Void) async {
        isAuthenticating = true
        defer { isAuthenticating = false }
        do {
            try await action()
            dismiss()
        } catch let error as ASAuthorizationError where error.code == .canceled {
        } catch let error as NSError where error.code == GIDSignInError.canceled.rawValue {
        } catch {
            authErrorMessage = error.localizedDescription
        }
    }
}

private struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.cyan)
                .frame(width: 24)
            Text(text)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
    }
}

private struct PromptGlassAuthButtonStyle: ButtonStyle {
    var width: CGFloat
    var height: CGFloat
    var corner: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .frame(maxWidth: width)
            .frame(height: height)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: corner, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .strokeBorder(.white.opacity(0.18), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

private struct AuroraPromptBackground: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.10, green: 0.11, blue: 0.20),
                         Color(red: 0.15, green: 0.25, blue: 0.22)],
                startPoint: .top, endPoint: .bottom
            )
            Circle()
                .fill(Color.green.opacity(0.35))
                .frame(width: 320, height: 320)
                .blur(radius: 90)
                .offset(x: animate ? -60 : -120, y: animate ? -200 : -260)
            
            Circle()
                .fill(Color.cyan.opacity(0.25))
                .frame(width: 280, height: 280)
                .blur(radius: 90)
                .offset(x: animate ? 90 : 140, y: animate ? 100 : 50)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) { animate = true }
        }
    }
}
