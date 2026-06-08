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
import PhotosUI

struct RootGodModeOnboarding: View {
    let onFinish: (Int?) -> Void
    @State private var currentStage = 0
    @AppStorage("hasSeenFeatureDiscovery") private var hasSeenFeatureDiscovery = false
    @State private var savedTargetTab: Int? = nil

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
                    if hasSeenFeatureDiscovery {
                        onFinish(nil)
                    } else {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            currentStage = 2
                        }
                    }
                })
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            } else if currentStage == 2 {
                OnboardingIntroView(onNext: { targetTab in
                    hasSeenFeatureDiscovery = true
                    onFinish(targetTab)
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
            AuroraBackground()

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

// MARK: - Welcome step (чистый заголовок + единые кнопки)

private struct WelcomeStepView: View {
    let onAppleRequest: (ASAuthorizationAppleIDRequest) -> Void
    let onAppleCompletion: (Result<ASAuthorization, Error>) -> Void
    let onGoogleTap: () -> Void
    let onGuestTap: () -> Void
    var isAuthenticating: Bool

    private let controlWidth: CGFloat = 320
    private let controlHeight: CGFloat = 54
    private let corner: CGFloat = 16

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 52, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(colors: [.white, .cyan],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .shadow(color: .cyan.opacity(0.4), radius: 20, y: 8)

                Text("Welcome 👋")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Your body is a reflection of your discipline. Keep pushing your limits — no excuses.")
                    .font(.system(size: 15, weight: .medium))
                    .lineSpacing(3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(.horizontal, 28)
            }

            Spacer()

            VStack(spacing: 12) {
                SignInWithAppleButton(.continue,
                                      onRequest: onAppleRequest,
                                      onCompletion: onAppleCompletion)
                    .signInWithAppleButtonStyle(.white)
                    .frame(maxWidth: controlWidth)
                    .frame(height: controlHeight)
                    .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))

                Button(action: onGoogleTap) {
                    HStack(spacing: 10) {
                        Image(systemName: "globe")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Continue with Google")
                    }
                }
                .buttonStyle(GlassAuthButtonStyle(width: controlWidth, height: controlHeight, corner: corner))

                Button("Stay a guest", action: onGuestTap)
                    .buttonStyle(GhostAuthButtonStyle(width: controlWidth, height: controlHeight, corner: corner))
            }
            .disabled(isAuthenticating)
            .opacity(isAuthenticating ? 0.6 : 1)
            .overlay { if isAuthenticating { ProgressView().tint(.white) } }
            .padding(.bottom, 24)
        }
        .padding(.horizontal, 24)
    }
}

private struct GlassAuthButtonStyle: ButtonStyle {
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

private struct GhostAuthButtonStyle: ButtonStyle {
    var width: CGFloat
    var height: CGFloat
    var corner: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.85))
            .frame(maxWidth: width)
            .frame(height: height)
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .strokeBorder(.white.opacity(0.22), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Премиальный фон вместо 3D-гантелей

private struct AuroraBackground: View {
    @State private var animate = false

    private struct Orb: Identifiable {
        let id = UUID()
        let color: Color
        let size: CGFloat
        let from: CGSize
        let to: CGSize
    }

    private let orbs: [Orb] = [
        .init(color: .purple, size: 320, from: .init(width: -120, height: -260), to: .init(width: -60,  height: -200)),
        .init(color: .blue,   size: 300, from: .init(width:  140, height: -110), to: .init(width:  90,  height:  -50)),
        .init(color: .cyan,   size: 280, from: .init(width:  -80, height:  260), to: .init(width: -140, height:  200))
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.10, green: 0.11, blue: 0.20),
                         Color(red: 0.20, green: 0.16, blue: 0.34)],
                startPoint: .top, endPoint: .bottom
            )
            ForEach(orbs) { orb in
                Circle()
                    .fill(orb.color.opacity(0.35))
                    .frame(width: orb.size, height: orb.size)
                    .blur(radius: 90)
                    .offset(animate ? orb.to : orb.from)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true)) { animate = true }
        }
    }
}

private struct GuestWarningView: View {
    let onStayGuest: () -> Void
    let onSignIn: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Continue as a guest?").font(.system(size: 24, weight: .bold, design: .rounded)).foregroundStyle(.white)
            Text("If you stay as a guest, your training data will not be saved in the cloud.").font(.system(size: 13)).foregroundStyle(.white.opacity(0.86))
            Text("Why you should register:").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 6) {
                bullet("Saving progress in the cloud")
                bullet("Sync with iPad")
                bullet("Smart Tips")
            }
            Spacer(minLength: 8)
            HStack(spacing: 12) {
                Button(action: onStayGuest) {
                    Text("Guest").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 12).background(Color.white.opacity(0.15)).clipShape(RoundedRectangle(cornerRadius: 12))
                }
                Button(action: onSignIn) {
                    Text("Enter").font(.system(size: 14, weight: .bold)).foregroundStyle(.black).frame(maxWidth: .infinity).padding(.vertical, 12).background(LinearGradient(colors: [.white, Color(white: 0.9)], startPoint: .top, endPoint: .bottom)).clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(24)
    }

    private func bullet(_ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle().fill(Color.cyan).frame(width: 4, height: 4).padding(.top, 6)
            Text(text).font(.system(size: 13)).foregroundStyle(.white.opacity(0.92))
        }
    }
}

// MARK: - God Mode (без изменений)

struct GodModeUserMetrics {
    var name: String = ""
    var avatarImage: UIImage? = nil
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
        case .none: return "😶"
        case .office: return "👨‍💻"
        case .light: return "🚶‍♂️"
        case .active: return "⚡️"
        case .beast: return "🦍"
        }
    }
    var description: String {
        switch self {
        case .none: return ""
        case .office: return "We sit at the table, minimum steps"
        case .light: return "Warm-ups and 1-2 workouts"
        case .active: return "Sports 3-4 times a week"
        case .beast: return "Daily body loads"
        }
    }
}

struct OnboardingGodMode: View {
    let onNext: () -> Void
    enum Step { case welcome, profile, metrics, activity, finish }

    @State private var step: Step = .welcome
    @State private var metrics = GodModeUserMetrics()

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.08).ignoresSafeArea()

            if step == .welcome || step == .profile || step == .metrics || step == .activity {
                GodModeAnimatedBackground()
            }

            VStack {
                switch step {
                case .welcome:
                    GodModeWelcomeScreen(onNext: { navigate(to: .profile) }).transition(pushTransition)
                case .profile:
                    GodModeProfileScreen(metrics: $metrics, onNext: { navigate(to: .metrics) }).transition(pushTransition)
                case .metrics:
                    GodModeMetricsScreen(metrics: $metrics, onNext: { navigate(to: .activity) }).transition(pushTransition)
                case .activity:
                    GodModeActivityScreen(metrics: $metrics, onNext: { 
                        saveMetrics()
                        navigate(to: .finish) 
                    }).transition(pushTransition)
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

    private func saveMetrics() {
        let defaults = UserDefaults.standard
        defaults.set(metrics.age, forKey: "userAge")
        defaults.set(metrics.height, forKey: "userHeight")
        defaults.set(Double(metrics.weight), forKey: "userBodyWeight")
        defaults.set(metrics.name, forKey: Constants.UserDefaultsKeys.userName.rawValue)
        
        if let avatar = metrics.avatarImage {
            ProfileImageManager.shared.saveImage(avatar)
        }
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
            Text("You are the personal architect of your body. No garbage, just a pure focus on the result.\n\nHow to break the limits?").font(.system(size: 16, weight: .medium)).foregroundStyle(.white.opacity(0.7)).offset(y: isVisible ? 0 : 20).opacity(isVisible ? 1 : 0)
            Spacer()
            GodModeButton(title: "To begin", action: onNext).offset(y: isVisible ? 0 : 30).opacity(isVisible ? 1 : 0)
        }
        .padding(30).onAppear { withAnimation(.easeOut(duration: 0.8).delay(0.2)) { isVisible = true } }
    }
}

struct GodModeProfileScreen: View {
    @Binding var metrics: GodModeUserMetrics
    let onNext: () -> Void
    @State private var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Text("Who are you?").font(.system(size: 32, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Text("Let AI know you better").font(.system(size: 15)).foregroundStyle(.white.opacity(0.6))
            }.padding(.top, 60)
            
            Spacer()
            
            VStack(spacing: 32) {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.05))
                            .frame(width: 120, height: 120)
                            .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
                            .shadow(color: .cyan.opacity(0.2), radius: 15, y: 5)
                            
                        if let img = metrics.avatarImage {
                            Image(uiImage: img).resizable().scaledToFill().frame(width: 110, height: 110).clipShape(Circle())
                        } else {
                            Image(systemName: "person.crop.circle.badge.plus")
                                .font(.system(size: 40))
                                .foregroundStyle(LinearGradient(colors: [.cyan, .blue], startPoint: .top, endPoint: .bottom))
                        }
                    }
                }
                .onChange(of: selectedPhotoItem) { _, newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self),
                           let uiImage = UIImage(data: data) {
                            await MainActor.run { metrics.avatarImage = uiImage }
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("NAME / ALIAS").font(.system(size: 13, weight: .bold)).foregroundStyle(.white.opacity(0.5)).padding(.leading, 4)
                    TextField("Champion", text: $metrics.name)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
                }
                .padding(.horizontal, 30)
            }
            
            Spacer()
            
            GodModeButton(title: "Continue", action: onNext, isDisabled: metrics.name.trimmingCharacters(in: .whitespaces).isEmpty)
                .padding(.horizontal, 30)
                .padding(.bottom, 30)
        }
    }
}

struct GodModeMetricsScreen: View {
    @Binding var metrics: GodModeUserMetrics
    let onNext: () -> Void
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Text("Digitize yourself").font(.system(size: 32, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Text("Basic starting parameters").font(.system(size: 15)).foregroundStyle(.white.opacity(0.6))
            }.padding(.top, 60)
            Spacer()
            HStack(spacing: 0) {
                GodModeWheelColumn(title: "Age", range: 14...100, suffix: "years", selection: $metrics.age)
                GodModeWheelColumn(title: "Height", range: 140...230, suffix: "cm", selection: $metrics.height)
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
    let title: String
    let range: ClosedRange<Int>
    let suffix: String
    @Binding var selection: Int
    var body: some View {
        VStack(spacing: -10) {
            Text(title).font(.system(size: 14, weight: .bold)).foregroundStyle(.white.opacity(0.5)).padding(.bottom, 10)
            Picker(title, selection: $selection) {
                ForEach(range, id: \.self) { value in
                    Text("\(value) \(suffix)").font(.system(size: 20, weight: .semibold, design: .rounded)).foregroundStyle(.white).tag(value)
                }
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
                Text("What is your typical day like?").font(.system(size: 15)).foregroundStyle(.white.opacity(0.6))
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
    @State private var animateUI = false
    @State private var isWarping = false
    @State private var flashWhite = false
    @State private var isJumping = false
    @State private var hasCompleted = false
    @State private var warpTask: Task<Void, Never>?
    @State private var engine = WarpEngine()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            TimelineView(.animation) { timeline in
                Canvas { context, size in
                    engine.update(time: timeline.date.timeIntervalSinceReferenceDate)
                    engine.draw(context: &context, size: size)
                }
            }
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()
                ZStack {
                    Circle().fill(Color.cyan.opacity(0.2)).frame(width: 100, height: 100).blur(radius: 20)
                    Image(systemName: "bolt.shield.fill").font(.system(size: 50)).foregroundStyle(LinearGradient(colors: [.cyan, .blue], startPoint: .top, endPoint: .bottom))
                }
                VStack(spacing: 8) {
                    Text("Your profile is ready").font(.system(size: 32, weight: .black, design: .rounded)).foregroundStyle(.white)
                    Text("Your data is securely stored. Have a good workout, bro.").font(.system(size: 15, weight: .medium)).foregroundStyle(.white.opacity(0.6)).multilineTextAlignment(.center).padding(.horizontal, 30)
                }
                Spacer()
                GodModeButton(title: "Log in to the system") { startExtendedHyperspaceJump() }
                    .padding(.horizontal, 30)
                    .padding(.bottom, 30)
                    .disabled(isJumping)
            }
            .scaleEffect(isWarping ? 0.3 : (animateUI ? 1 : 0.9))
            .opacity(isWarping ? 0 : (animateUI ? 1 : 0))

            Color.white.ignoresSafeArea().opacity(flashWhite ? 1 : 0)

            if isJumping && !hasCompleted {
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            finishWarp()
                        } label: {
                            Text("Skip")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 10)
                                .background(.ultraThinMaterial, in: Capsule())
                        }
                        .padding(.trailing, 20)
                        .padding(.top, 8)
                    }
                    Spacer()
                }
                .transition(.opacity)
            }
        }
        .onAppear { HapticManager.playSuccess(); withAnimation(.spring()) { animateUI = true } }
        .onDisappear { warpTask?.cancel() }
    }

    private func startExtendedHyperspaceJump() {
        guard !isJumping else { return }
        isJumping = true
        HapticManager.playLightImpact()
        withAnimation(.easeIn(duration: 3.5)) { isWarping = true }
        engine.startWarp()

        warpTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .seconds(2.5))
                HapticManager.playLightImpact()
                try await Task.sleep(for: .seconds(2.0))
                HapticManager.playMediumImpact()
                try await Task.sleep(for: .seconds(2.0))
                HapticManager.playHeavyImpact()
                try await Task.sleep(for: .seconds(1.3))
                HapticManager.playHeavyImpact()
                withAnimation(.easeIn(duration: 0.2)) { flashWhite = true }
                try await Task.sleep(for: .seconds(0.4))
                finishWarp()
            } catch {
                // Cancelled (Skip tapped or screen dismissed)
            }
        }
    }

    private func finishWarp() {
        guard !hasCompleted else { return }
        hasCompleted = true
        warpTask?.cancel()
        warpTask = nil
        onWarpComplete()
    }
}

class WarpEngine {
    struct Star { var x, y, z, pz: Double; var color: Color }
    var stars: [Star] = []
    var lastTime: TimeInterval = 0
    var speed: Double = 0.2
    var isWarping = false

    init() {
        let colors: [Color] = [.white, .cyan, .blue, .white.opacity(0.8)]
        for _ in 0..<500 {
            stars.append(Star(x: Double.random(in: -2000...2000), y: Double.random(in: -2000...2000), z: Double.random(in: 10...2000), pz: 0, color: colors.randomElement()!))
        }
    }
    func startWarp() { isWarping = true }
    func update(time: TimeInterval) {
        if lastTime == 0 { lastTime = time }
        let dt = time - lastTime; lastTime = time
        if isWarping { speed = min(speed * 1.01, 220.0) }
        for i in 0..<stars.count {
            stars[i].pz = stars[i].z; stars[i].z -= speed * dt * 60
            if stars[i].z <= 1 {
                stars[i].x = Double.random(in: -2000...2000); stars[i].y = Double.random(in: -2000...2000); stars[i].z = 2000; stars[i].pz = 2000
            }
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
    let title: String
    let action: () -> Void
    var isDisabled: Bool = false
    var body: some View {
        Button(action: action) {
            Text(title).font(.system(size: 17, weight: .bold)).foregroundStyle(isDisabled ? Color.white.opacity(0.3) : .black).frame(maxWidth: .infinity).padding(.vertical, 16).background(isDisabled ? AnyShapeStyle(Color.white.opacity(0.1)) : AnyShapeStyle(LinearGradient(colors: [.white, Color(white: 0.85)], startPoint: .top, endPoint: .bottom))).clipShape(RoundedRectangle(cornerRadius: 16)).shadow(color: isDisabled ? .clear : .white.opacity(0.3), radius: 10, y: 5)
        }.disabled(isDisabled).buttonStyle(BouncyButtonStyle())
    }
}

struct BouncyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed ? 0.95 : 1.0).opacity(configuration.isPressed ? 0.9 : 1.0).animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct GodModeAnimatedBackground: View {
    @State private var move1 = false
    @State private var move2 = false
    var body: some View {
        ZStack {
            Circle().fill(Color.cyan.opacity(0.15)).frame(width: 300, height: 300).blur(radius: 80).offset(x: move1 ? 100 : -100, y: move1 ? -150 : 0)
            Circle().fill(Color.purple.opacity(0.15)).frame(width: 350, height: 350).blur(radius: 100).offset(x: move2 ? -150 : 150, y: move2 ? 200 : 50)
        }.onAppear {
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) { move1 = true }
            withAnimation(.easeInOut(duration: 10).repeatForever(autoreverses: true)) { move2 = true }
        }
    }
}
// removed ThemeCustomizationView

// MARK: - The Oath (Hold to Commit)

struct TheOathView: View {
    let onComplete: () -> Void
    @Environment(ThemeManager.self) private var themeManager
    @AppStorage("userGoal") private var userGoal = ""
    
    @State private var holdProgress: CGFloat = 0.0
    @State private var isHolding = false
    @State private var isCompleted = false
    
    let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.08).ignoresSafeArea()
            
            // Dramatic background glow
            Circle()
                .fill(themeManager.accentColor.opacity(0.15))
                .frame(width: 300, height: 300)
                .blur(radius: 80)
                .scaleEffect(1.0 + holdProgress * 0.5)
                .opacity(0.5 + holdProgress * 0.5)
                .animation(.linear(duration: 0.1), value: holdProgress)
            
            VStack(spacing: 30) {
                Spacer()
                
                Image(systemName: "lock.shield")
                    .font(.system(size: 60, weight: .light))
                    .foregroundColor(themeManager.accentColor)
                    .scaleEffect(isCompleted ? 1.2 : 1.0)
                    .animation(.spring, value: isCompleted)
                
                let goalText = userGoal.isEmpty ? "your goals" : userGoal
                Text("You said you want to\n**\(goalText)**.")
                    .font(.system(size: 28, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                
                Text("The AI is ready to guide you. But the effort must come from you.\n\nAre you ready?")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 40)
                
                Spacer()
                
                // Hold to Commit Button
                ZStack {
                    // Background track
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 4)
                        .frame(width: 120, height: 120)
                    
                    // Progress ring
                    Circle()
                        .trim(from: 0, to: holdProgress)
                        .stroke(themeManager.accentColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))
                    
                    // Fingerprint or text
                    if isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(themeManager.accentColor)
                            .transition(.scale)
                    } else {
                        Text("Hold")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(isHolding ? themeManager.accentColor : .white)
                            .scaleEffect(isHolding ? 1.1 : 1.0)
                    }
                }
                .padding(.bottom, 60)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            if !isCompleted {
                                isHolding = true
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }
                        }
                        .onEnded { _ in
                            isHolding = false
                            if !isCompleted {
                                withAnimation(.spring) {
                                    holdProgress = 0.0
                                }
                            }
                        }
                )
                .onReceive(timer) { _ in
                    if isHolding && !isCompleted {
                        holdProgress += 0.05
                        if holdProgress >= 1.0 {
                            isCompleted = true
                            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                onComplete()
                            }
                        }
                    }
                }
            }
        }
    }
}
