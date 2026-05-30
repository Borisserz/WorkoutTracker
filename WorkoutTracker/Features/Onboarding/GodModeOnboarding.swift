//
//  GodModeOnboarding.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 27.04.26.
//

internal import SwiftUI
import Combine
import AuthenticationServices
import GoogleSignIn

struct RootGodModeOnboarding: View {
    let onFinish: () -> Void
    @State private var currentStage = 0

    var body: some View {
        ZStack {
            if currentStage == 0 {
                NewOnboardingView(onNext: {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        currentStage = 1
                    }
                })
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            } else if currentStage == 1 {
                OnboardingGodMode(onNext: {
                    onFinish()
                })
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct NewOnboardingView: View {
    let onNext: () -> Void

    @State private var showGuestModal = false
    @State private var isAuthenticating = false
    @State private var authErrorMessage: String?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.18, green: 0.22, blue: 0.38),
                         Color(red: 0.35, green: 0.25, blue: 0.45)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            FloatingGlassShapes()

            WelcomeStepView(
                onAppleRequest: { request in
                    SocialAuthService.shared.prepareAppleRequest(request)
                },
                onAppleCompletion: { result in
                    Task { await authenticate { try await SocialAuthService.shared.handleAppleAuthorization(result) } }
                },
                onGoogleTap: {
                    Task { await authenticate { try await SocialAuthService.shared.signInWithGoogle() } }
                },
                onGuestTap: { showGuestModal = true },
                isAuthenticating: isAuthenticating
            )
        }
        .sheet(isPresented: $showGuestModal) {
            GuestWarningView(
                onStayGuest: { showGuestModal = false; onNext() },
                onSignIn: { showGuestModal = false }
            )
            .presentationDetents([.fraction(0.48), .medium])
            .presentationDragIndicator(.visible)
            .background(Color(red: 0.20, green: 0.22, blue: 0.30).ignoresSafeArea())
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
            onNext()
        } catch let error as ASAuthorizationError where error.code == .canceled {
        } catch let error as NSError where error.code == GIDSignInError.canceled.rawValue {
        } catch {
            authErrorMessage = error.localizedDescription
        }
    }
}

private struct WelcomeStepView: View {
    let onAppleRequest: (ASAuthorizationAppleIDRequest) -> Void
    let onAppleCompletion: (Result<ASAuthorization, Error>) -> Void
    let onGoogleTap: () -> Void
    let onGuestTap: () -> Void
    var isAuthenticating: Bool

    @State private var buttonPulse = false

    var body: some View {
        VStack(alignment: .center, spacing: 12) {
            Spacer(minLength: 8)
            VStack(alignment: .center, spacing: 10) {
                ZStack(alignment: .center) {
                    Text("Welcome 👋").font(.system(size: 28, weight: .bold, design: .rounded)).foregroundStyle(.white).blur(radius: 6).opacity(0.6)
                    Text("Welcome👋").font(.system(size: 28, weight: .bold, design: .rounded)).foregroundStyle(.white).shadow(color: .white.opacity(0.3), radius: 2)
                }.minimumScaleFactor(0.7).lineLimit(1)
                Text("Your body is a reflection of your discipline. Keep up the progress, beat your own records and reach a new level. Push your limits, no excuses.")
                    .font(.system(size: 14, weight: .medium)).lineSpacing(3).multilineTextAlignment(.center).foregroundStyle(.white.opacity(0.9)).padding(.horizontal)
            }
            Spacer()
            VStack(spacing: 12) {
                SignInWithAppleButton(.continue,
                                      onRequest: onAppleRequest,
                                      onCompletion: onAppleCompletion)
                    .signInWithAppleButtonStyle(.white)
                    .frame(maxWidth: 300)
                    .frame(height: 50)
                    .clipShape(Capsule())
                    .scaleEffect(buttonPulse ? 1.02 : 1.0)

                SignInButton(title: "Continue with Google", subtitle: "Log in via Google",
                             icon: "globe", accent: Color.white.opacity(0.15),
                             textColor: .white, action: onGoogleTap)

                Button(action: onGuestTap) {
                    Text("Stay a guest").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white.opacity(0.85)).frame(maxWidth: 300).padding(.vertical, 14)
                        .overlay(Capsule().stroke(LinearGradient(colors: [.white.opacity(0.4), .clear], startPoint: .top, endPoint: .bottom), lineWidth: 1))
                }
            }
            .disabled(isAuthenticating)
            .overlay { if isAuthenticating { ProgressView().tint(.white) } }
            .onAppear { withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) { buttonPulse = true } }
        }
        .padding(.horizontal, 20).padding(.vertical, 16)
    }
}

private struct SignInButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let accent: Color
    let textColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(textColor.opacity(0.15)).frame(width: 32, height: 32)
                    Image(systemName: icon).font(.system(size: 15, weight: .semibold)).foregroundStyle(textColor)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 13, weight: .bold)).lineLimit(1).shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                    Text(subtitle).font(.system(size: 10, weight: .medium)).opacity(0.8).lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).opacity(0.5)
            }
            .foregroundStyle(textColor).padding(.horizontal, 20).padding(.vertical, 12).frame(maxWidth: 300)
            .background(.ultraThinMaterial).clipShape(Capsule())
            .overlay(Capsule().stroke(LinearGradient(colors: [.white.opacity(0.5), .white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5))
            .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 5)
        }
    }
}

private struct GuestWarningView: View {
    let onStayGuest: () -> Void; let onSignIn: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Log in as a guest?").font(.system(size: 24, weight: .bold, design: .rounded)).foregroundStyle(.white)
            Text("If you stay as a guest, your training data will not be saved in the cloud.").font(.system(size: 13)).foregroundStyle(.white.opacity(0.86))
            Text("Why is it better to register:").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 6) { bullet("Saving progress in the cloud"); bullet("Sync with iPad"); bullet("Smart Tips") }
            Spacer(minLength: 8)
            HStack(spacing: 12) {
                Button(action: onStayGuest) { Text("Guest").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 12).background(Color.white.opacity(0.15)).clipShape(RoundedRectangle(cornerRadius: 12)) }
                Button(action: onSignIn) { Text("Enter").font(.system(size: 14, weight: .bold)).foregroundStyle(.black).frame(maxWidth: .infinity).padding(.vertical, 12).background(LinearGradient(colors: [.white, Color(white: 0.9)], startPoint: .top, endPoint: .bottom)).clipShape(RoundedRectangle(cornerRadius: 12)) }
            }
        }.padding(24)
    }
    private func bullet(_ text: String) -> some View { HStack(alignment: .top, spacing: 8) { Circle().fill(Color.cyan).frame(width: 4, height: 4).padding(.top, 6); Text(text).font(.system(size: 13)).foregroundStyle(.white.opacity(0.92)) } }
}




private struct FloatingGlassShapes: View {
    @State private var moveX = false; @State private var moveY = false; @State private var floatZ = false
    var body: some View {
        ZStack {
            Circle().fill(Color.purple.opacity(0.35)).frame(width: 300, height: 300).blur(radius: 60).offset(x: moveX ? 150 : -100, y: moveY ? -250 : 50)
            HyperRealisticBarbell(accentColor: .blue).scaleEffect(floatZ ? 0.4 : 0.55).blur(radius: floatZ ? 5 : 3).rotationEffect(.degrees(-25)).rotation3DEffect(.degrees(moveX ? 3 : -3), axis: (x: 1, y: 0.2, z: 0)).offset(x: moveX ? -120 : -50, y: moveY ? -240 : -160).opacity(0.7)
            HyperRealisticDumbbell(accentColor: .cyan).scaleEffect(floatZ ? 0.65 : 0.85).rotationEffect(.degrees(20)).rotation3DEffect(.degrees(moveY ? 4 : -4), axis: (x: 0.5, y: 0.5, z: 0)).offset(x: moveY ? 120 : 190, y: moveX ? -100 : -30).shadow(color: .black.opacity(0.4), radius: 20, x: -10, y: 15)
            HyperRealisticBarbell(accentColor: .purple).scaleEffect(floatZ ? 0.8 : 1.0).rotationEffect(.degrees(15)).rotation3DEffect(.degrees(moveX ? 5 : -5), axis: (x: 1, y: 0, z: 0)).offset(x: moveX ? 10 : 80, y: moveY ? 180 : 260).shadow(color: .black.opacity(0.5), radius: 30, x: -15, y: 25)
            HyperRealisticDumbbell(accentColor: .pink).scaleEffect(floatZ ? 1.0 : 1.25).rotationEffect(.degrees(70)).rotation3DEffect(.degrees(moveY ? -4 : 4), axis: (x: 1, y: 0.2, z: 0)).offset(x: moveY ? -140 : -220, y: moveX ? 40 : 120).shadow(color: .black.opacity(0.6), radius: 35, x: 15, y: 25)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 7.3).repeatForever(autoreverses: true)) { moveX = true }
            withAnimation(.easeInOut(duration: 9.7).repeatForever(autoreverses: true)) { moveY = true }
            withAnimation(.easeInOut(duration: 11.1).repeatForever(autoreverses: true)) { floatZ = true }
        }
    }
}
private struct MassivePlate3D: View {
    var width: CGFloat; var height: CGFloat; var color: Color; var isBarbell: Bool
    var body: some View {
        ZStack {
            Capsule().fill(Color.black.opacity(0.85)).frame(width: width, height: height).offset(x: -24, y: 4)
            Capsule().fill(LinearGradient(colors: [.black.opacity(0.9), color.opacity(0.3), .black.opacity(0.9)], startPoint: .top, endPoint: .bottom)).frame(width: width, height: height).offset(x: -12, y: 2)
            Capsule().fill(LinearGradient(colors: [color.opacity(0.6), color, color.opacity(0.7), .black.opacity(0.8)], startPoint: .top, endPoint: .bottom)).frame(width: width, height: height).overlay(Capsule().stroke(LinearGradient(colors: [.white.opacity(0.95), .clear, .black.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2))
            Capsule().fill(LinearGradient(colors: [.black.opacity(0.8), color.opacity(0.3), .white.opacity(0.3)], startPoint: .top, endPoint: .bottom)).frame(width: width * 0.75, height: height * 0.85)
            if isBarbell { ZStack { Capsule().fill(LinearGradient(colors: [.black, .white, .gray, .black], startPoint: .top, endPoint: .bottom)).frame(width: width * 0.5, height: height * 0.25).overlay(Capsule().stroke(Color.black, lineWidth: 1.5)); Capsule().fill(Color.black).frame(width: width * 0.25, height: height * 0.12) } }
        }
    }
}
private struct HyperRealisticDumbbell: View {
    var accentColor: Color
    var body: some View {
        ZStack {
            Capsule().fill(LinearGradient(colors: [.black, .white, .gray, .black, .black], startPoint: .top, endPoint: .bottom)).frame(width: 220, height: 32).overlay(Capsule().stroke(LinearGradient(colors: [.white.opacity(0.8), .clear, .black.opacity(0.9)], startPoint: .top, endPoint: .bottom), lineWidth: 2))
            Capsule().fill(Color.black.opacity(0.8)).frame(width: 14, height: 44).offset(x: -55)
            Capsule().fill(Color.black.opacity(0.8)).frame(width: 14, height: 44).offset(x: 55)
            HStack(spacing: 16) { MassivePlate3D(width: 44, height: 130, color: accentColor, isBarbell: false); MassivePlate3D(width: 48, height: 145, color: accentColor, isBarbell: false) }.offset(x: -90)
            HStack(spacing: 16) { MassivePlate3D(width: 48, height: 145, color: accentColor, isBarbell: false); MassivePlate3D(width: 44, height: 130, color: accentColor, isBarbell: false) }.offset(x: 90)
            Capsule().fill(LinearGradient(colors: [.white, .gray, .black], startPoint: .top, endPoint: .bottom)).frame(width: 18, height: 40).offset(x: -135)
            Capsule().fill(LinearGradient(colors: [.white, .gray, .black], startPoint: .top, endPoint: .bottom)).frame(width: 18, height: 40).offset(x: 135)
        }
    }
}
private struct HyperRealisticBarbell: View {
    var accentColor: Color
    var body: some View {
        ZStack {
            Capsule().fill(LinearGradient(colors: [.black, .gray, .white, .white, .gray, .black, .black], startPoint: .top, endPoint: .bottom)).frame(width: 480, height: 22).overlay(Capsule().stroke(Color.white.opacity(0.6), lineWidth: 1.5))
            Capsule().fill(LinearGradient(colors: [.black, .gray, .white, .gray, .black], startPoint: .top, endPoint: .bottom)).frame(width: 120, height: 28).offset(x: -170)
            Capsule().fill(LinearGradient(colors: [.black, .gray, .white, .gray, .black], startPoint: .top, endPoint: .bottom)).frame(width: 120, height: 28).offset(x: 170)
            HStack(spacing: 12) { Capsule().fill(LinearGradient(colors: [.white, .gray, .black], startPoint: .top, endPoint: .bottom)).frame(width: 18, height: 46); MassivePlate3D(width: 32, height: 180, color: accentColor, isBarbell: true); MassivePlate3D(width: 32, height: 180, color: Color.cyan, isBarbell: true); MassivePlate3D(width: 26, height: 120, color: Color.pink, isBarbell: true); Capsule().fill(LinearGradient(colors: [.white, .black], startPoint: .top, endPoint: .bottom)).frame(width: 20, height: 38) }.offset(x: -150)
            HStack(spacing: 12) { Capsule().fill(LinearGradient(colors: [.white, .black], startPoint: .top, endPoint: .bottom)).frame(width: 20, height: 38); MassivePlate3D(width: 26, height: 120, color: Color.pink, isBarbell: true); MassivePlate3D(width: 32, height: 180, color: Color.cyan, isBarbell: true); MassivePlate3D(width: 32, height: 180, color: accentColor, isBarbell: true); Capsule().fill(LinearGradient(colors: [.white, .gray, .black], startPoint: .top, endPoint: .bottom)).frame(width: 18, height: 46) }.offset(x: 150)
        }
    }
}

struct GodModeUserMetrics {
    var age: Int = 25
    var height: Int = 175
    var weight: Int = 75
    var activityLevel: GodModeActivityType = .none
}

enum GodModeActivityType: String, CaseIterable {
    case none = "Not selected yet"
    case office = "The office matrix"
    case light = "Light movement"
    case active = "A charged motor"
    case beast = "Cyborg Mode"
    
    var emoji: String {
        switch self {
        case .none: return "😶"; case .office: return "👨‍💻"; case .light: return "🚶‍♂️"; case .active: return "⚡️"; case .beast: return "🦍"
        }
    }
    var description: String {
        switch self {
        case .none: return ""; case .office: return "We sit at the table, minimum steps"; case .light: return "Warm-ups and 1-2 workouts"; case .active: return "Sports 3-4 times a week"; case .beast: return "Daily body loads"
        }
    }
}

struct OnboardingGodMode: View {
    let onNext: () -> Void
    enum Step { case welcome, metrics, activity, finish }

    @State private var step: Step = .welcome
    @State private var metrics = GodModeUserMetrics()

    
    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.08).ignoresSafeArea()
            
            if step == .welcome || step == .metrics || step == .activity {
                GodModeAnimatedBackground()
            }
            
            VStack {
                switch step {
                case .welcome:
                    GodModeWelcomeScreen(onNext: { navigate(to: .metrics) }).transition(pushTransition)
                case .metrics:
                    GodModeMetricsScreen(metrics: $metrics, onNext: { navigate(to: .activity) }).transition(pushTransition)
                case .activity:
                    GodModeActivityScreen(metrics: $metrics, onNext: { navigate(to: .finish) }).transition(pushTransition)
                case .finish:
                    GodModeFinishScreen(onWarpComplete: { onNext() }).transition(.opacity)
                }
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: step)
        }
    }
    
    private var pushTransition: AnyTransition {
        .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity))
    }
    private func navigate(to nextStep: Step) {
        HapticManager.playLightImpact()
        step = nextStep
    }
}

struct GodModeWelcomeScreen: View {
    let onNext: () -> Void
    @State private var isVisible = false
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Spacer()
            Text("Your\nNew\nEra.").font(.system(size: 56, weight: .black, design: .rounded)).foregroundStyle(LinearGradient(colors: [.white, .cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)).lineSpacing(-5)
                .offset(y: isVisible ? 0 : 20).opacity(isVisible ? 1 : 0)
            Text("You is a personal architect of the body. No garbage, just a pure focus on the result.\n\nHow to break the limits?").font(.system(size: 16, weight: .medium)).foregroundStyle(.white.opacity(0.7)).offset(y: isVisible ? 0 : 20).opacity(isVisible ? 1 : 0)
            Spacer()
            GodModeButton(title: "To begin", action: onNext).offset(y: isVisible ? 0 : 30).opacity(isVisible ? 1 : 0)
        }
        .padding(30).onAppear { withAnimation(.easeOut(duration: 0.8).delay(0.2)) { isVisible = true } }
    }
}

struct GodModeMetricsScreen: View {
    @Binding var metrics: GodModeUserMetrics
    let onNext: () -> Void
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Text("Digitize yourself").font(.system(size: 32, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Text("Basic parameters for the start").font(.system(size: 15)).foregroundStyle(.white.opacity(0.6))
            }.padding(.top, 60)
            Spacer()
            HStack(spacing: 0) {
                GodModeWheelColumn(title: "Age", range: 14...100, suffix: "years", selection: $metrics.age)
                GodModeWheelColumn(title: "Height", range: 140...230, suffix: "sm", selection: $metrics.height)
                GodModeWheelColumn(title: "Weight", range: 40...200, suffix: "kg", selection: $metrics.weight)
            }
            .frame(height: 220).background(RoundedRectangle(cornerRadius: 24).fill(Color.white.opacity(0.05)).overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.1), lineWidth: 1))).padding(.horizontal, 20)
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "cpu").font(.system(size: 24, weight: .light)).foregroundStyle(.cyan)
                Text("The algorithm uses this data to accurately calculate BMR and adapt loads. No magic, just science.").font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.7))
            }
            .padding(16).background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 16)).padding(.horizontal, 20).padding(.top, 30)
            Spacer()
            GodModeButton(title: "Continue", action: onNext).padding(.horizontal, 30).padding(.bottom, 30)
        }
    }
}

struct GodModeWheelColumn: View {
    let title: String; let range: ClosedRange<Int>; let suffix: String
    @Binding var selection: Int
    var body: some View {
        VStack(spacing: -10) {
            Text(title).font(.system(size: 14, weight: .bold)).foregroundStyle(.white.opacity(0.5)).padding(.bottom, 10)
            Picker(title, selection: $selection) {
                ForEach(range, id: \.self) { value in Text("\(value) \(suffix)").font(.system(size: 20, weight: .semibold, design: .rounded)).foregroundStyle(.white).tag(value) }
            }.pickerStyle(.wheel)
        }.frame(maxWidth: .infinity)
    }
}

struct GodModeActivityScreen: View {
    @Binding var metrics: GodModeUserMetrics
    let onNext: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Your rhythm").font(.system(size: 32, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Text("How is your usual day going?").font(.system(size: 15)).foregroundStyle(.white.opacity(0.6))
            }.padding(.horizontal, 30).padding(.top, 60).padding(.bottom, 30)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    ForEach([GodModeActivityType.office, .light, .active, .beast], id: \.self) { type in
                        Button(action: { withAnimation { metrics.activityLevel = type; HapticManager.playSelection() } }) {
                            HStack(spacing: 16) {
                                Text(type.emoji).font(.system(size: 28)).frame(width: 46, height: 46).background(metrics.activityLevel == type ? Color.white.opacity(0.2) : Color.white.opacity(0.05)).clipShape(Circle())
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(type.rawValue).font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                                    Text(type.description).font(.system(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.6))
                                }
                                Spacer()
                                if metrics.activityLevel == type { Image(systemName: "checkmark.circle.fill").font(.system(size: 20)).foregroundStyle(.cyan).transition(.scale) }
                            }
                            .padding(14).background(metrics.activityLevel == type ? Color.cyan.opacity(0.15) : Color.white.opacity(0.03)).clipShape(RoundedRectangle(cornerRadius: 18)).overlay(RoundedRectangle(cornerRadius: 18).stroke(metrics.activityLevel == type ? Color.cyan : Color.white.opacity(0.1), lineWidth: metrics.activityLevel == type ? 2 : 1))
                        }.buttonStyle(.plain)
                    }
                }.padding(.horizontal, 30)
            }
            Spacer()
            GodModeButton(title: "Create a profile", action: onNext, isDisabled: metrics.activityLevel == .none).padding(.horizontal, 30).padding(.bottom, 30)
        }
    }
}

struct GodModeFinishScreen: View {
    let onWarpComplete: () -> Void
    @State private var animateUI = false; @State private var isWarping = false; @State private var flashWhite = false
    @State private var engine = WarpEngine()
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            TimelineView(.animation) { timeline in Canvas { context, size in engine.update(time: timeline.date.timeIntervalSinceReferenceDate); engine.draw(context: &context, size: size) } }.ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer()
                ZStack { Circle().fill(Color.cyan.opacity(0.2)).frame(width: 100, height: 100).blur(radius: 20); Image(systemName: "bolt.shield.fill").font(.system(size: 50)).foregroundStyle(LinearGradient(colors: [.cyan, .blue], startPoint: .top, endPoint: .bottom)) }
                VStack(spacing: 8) {
                    Text("The profile is ready").font(.system(size: 32, weight: .black, design: .rounded)).foregroundStyle(.white)
                    Text("Your data is securely stored.Have a good workout, bro.").font(.system(size: 15, weight: .medium)).foregroundStyle(.white.opacity(0.6)).multilineTextAlignment(.center).padding(.horizontal, 30)
                }
                Spacer()
                GodModeButton(title: "Log in to the system") { startExtendedHyperspaceJump() }.padding(.horizontal, 30).padding(.bottom, 30)
            }.scaleEffect(isWarping ? 0.3 : (animateUI ? 1 : 0.9)).opacity(isWarping ? 0 : (animateUI ? 1 : 0))
            Color.white.ignoresSafeArea().opacity(flashWhite ? 1 : 0)
        }.onAppear { HapticManager.playSuccess(); withAnimation(.spring()) { animateUI = true } }
    }
    private func startExtendedHyperspaceJump() {
        HapticManager.playLightImpact()
        withAnimation(.easeIn(duration: 3.5)) { isWarping = true }
        engine.startWarp()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { HapticManager.playLightImpact() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) { HapticManager.playMediumImpact() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.5) { HapticManager.playHeavyImpact() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 7.8) {
            HapticManager.playHeavyImpact()
            withAnimation(.easeIn(duration: 0.2)) { flashWhite = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 8.2) { onWarpComplete() }
    }
}

class WarpEngine {
    struct Star { var x, y, z, pz: Double; var color: Color }
    var stars: [Star] = []; var lastTime: TimeInterval = 0; var speed: Double = 0.2; var isWarping = false
    init() {
        let colors: [Color] = [.white, .cyan, .blue, .white.opacity(0.8)]
        for _ in 0..<500 { stars.append(Star(x: Double.random(in: -2000...2000), y: Double.random(in: -2000...2000), z: Double.random(in: 10...2000), pz: 0, color: colors.randomElement()!)) }
    }
    func startWarp() { isWarping = true }
    func update(time: TimeInterval) {
        if lastTime == 0 { lastTime = time }; let dt = time - lastTime; lastTime = time
        if isWarping { speed = min(speed * 1.01, 220.0) }
        for i in 0..<stars.count {
            stars[i].pz = stars[i].z; stars[i].z -= speed * dt * 60
            if stars[i].z <= 1 { stars[i].x = Double.random(in: -2000...2000); stars[i].y = Double.random(in: -2000...2000); stars[i].z = 2000; stars[i].pz = 2000 }
        }
    }
    func draw(context: inout GraphicsContext, size: CGSize) {
        let cx = size.width / 2, cy = size.height / 2, fov: Double = 300
        for star in stars {
            let px = cx + (star.x / star.pz) * fov, py = cy + (star.y / star.pz) * fov
            let nx = cx + (star.x / star.z) * fov, ny = cy + (star.y / star.z) * fov
            if star.pz == 2000 { continue }
            var path = Path(); path.move(to: CGPoint(x: px, y: py)); path.addLine(to: CGPoint(x: nx, y: ny))
            let depthFactor = 1.0 - (star.z / 2000.0)
            context.stroke(path, with: .color(star.color.opacity(depthFactor)), lineWidth: CGFloat(max(0.5, 3.0 * depthFactor)))
        }
    }
}

struct GodModeButton: View {
    let title: String; let action: () -> Void; var isDisabled: Bool = false
    var body: some View { Button(action: action) { Text(title).font(.system(size: 17, weight: .bold)).foregroundStyle(isDisabled ? Color.white.opacity(0.3) : .black).frame(maxWidth: .infinity).padding(.vertical, 16).background(isDisabled ? AnyShapeStyle(Color.white.opacity(0.1)) : AnyShapeStyle(LinearGradient(colors: [.white, Color(white: 0.85)], startPoint: .top, endPoint: .bottom))).clipShape(RoundedRectangle(cornerRadius: 16)).shadow(color: isDisabled ? .clear : .white.opacity(0.3), radius: 10, y: 5) }.disabled(isDisabled).buttonStyle(BouncyButtonStyle()) }
}
struct BouncyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { configuration.label.scaleEffect(configuration.isPressed ? 0.95 : 1.0).opacity(configuration.isPressed ? 0.9 : 1.0).animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed) }
}
struct GodModeAnimatedBackground: View {
    @State private var move1 = false; @State private var move2 = false
    var body: some View { ZStack { Circle().fill(Color.cyan.opacity(0.15)).frame(width: 300, height: 300).blur(radius: 80).offset(x: move1 ? 100 : -100, y: move1 ? -150 : 0); Circle().fill(Color.purple.opacity(0.15)).frame(width: 350, height: 350).blur(radius: 100).offset(x: move2 ? -150 : 150, y: move2 ? 200 : 50) }.onAppear { withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) { move1 = true }; withAnimation(.easeInOut(duration: 10).repeatForever(autoreverses: true)) { move2 = true } } }
}
