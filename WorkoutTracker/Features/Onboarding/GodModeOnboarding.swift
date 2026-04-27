//
//  GodModeOnboarding.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 27.04.26.
//

internal import SwiftUI
import Combine

// MARK: - ГЛАВНЫЙ КООРДИНАТОР ОНБОРДИНГА
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
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        currentStage = 2
                    }
                })
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            } else if currentStage == 2 {
                PaywallGodModeScreen(onNext: {
                    onFinish()
                })
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - ЭТАП 1: 3D ЛЕТАЮЩИЕ ФИГУРЫ И ВХОД
struct NewOnboardingView: View {
    enum Step {
        case welcome
        case googleSignUp
    }

    let onNext: () -> Void
    @Environment(\.openURL) var openURL
    @State private var step: Step = .welcome
    @State private var showGuestModal = false
    @State private var showAppleAlert = false
    @State private var showGoogleAlert = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.18, green: 0.22, blue: 0.38), Color(red: 0.35, green: 0.25, blue: 0.45)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            FloatingGlassShapes()

            switch step {
            case .welcome:
                WelcomeStepView(
                    onAppleTap: { showAppleAlert = true },
                    onGoogleTap: { showGoogleAlert = true },
                    onGuestTap: { showGuestModal = true }
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))

            case .googleSignUp:
                GoogleRegistrationView(
                    onBack: { withAnimation(.spring(response: 0.45, dampingFraction: 0.9)) { step = .welcome } },
                    onRegister: { onNext() }
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.28), value: step)
        .sheet(isPresented: $showGuestModal) {
            GuestWarningView(
                onStayGuest: { showGuestModal = false; onNext() },
                onSignIn: { showGuestModal = false; withAnimation { step = .googleSignUp } }
            )
            .presentationDetents([.fraction(0.48), .medium])
            .presentationDragIndicator(.visible)
            .background(Color(red: 0.20, green: 0.22, blue: 0.30).ignoresSafeArea())
        }
        .alert("Sign in with Apple", isPresented: $showAppleAlert) {
            Button("Continue") { onNext() }
            Button("Cancel", role: .cancel) { }
        } message: { Text("Placeholder for Apple Sign In") }
        .alert("Sign in with Google", isPresented: $showGoogleAlert) {
            Button("Continue") {
                if let url = URL(string: "https://accounts.google.com") { openURL(url) }
                onNext()
            }
            Button("Cancel", role: .cancel) { }
        } message: { Text("Placeholder for Google Sign In") }
    }
}

private struct WelcomeStepView: View {
    let onAppleTap: () -> Void
    let onGoogleTap: () -> Void
    let onGuestTap: () -> Void
    @State private var buttonPulse = false

    var body: some View {
        VStack(alignment: .center, spacing: 12) {
            Spacer(minLength: 8)
            VStack(alignment: .center, spacing: 10) {
                ZStack(alignment: .center) {
                    Text("Добро пожаловать 👋").font(.system(size: 28, weight: .bold, design: .rounded)).foregroundStyle(.white).blur(radius: 6).opacity(0.6)
                    Text("Добро пожаловать 👋").font(.system(size: 28, weight: .bold, design: .rounded)).foregroundStyle(.white).shadow(color: .white.opacity(0.3), radius: 2)
                }.minimumScaleFactor(0.7).lineLimit(1)
                Text("Твое тело — отражение твоей дисциплины. Сохраняй прогресс, бей собственные рекорды и выходи на новый уровень. Push your limits, no excuses.")
                    .font(.system(size: 14, weight: .medium)).lineSpacing(3).multilineTextAlignment(.center).foregroundStyle(.white.opacity(0.9)).padding(.horizontal)
            }
            Spacer()
            VStack(spacing: 12) {
                SignInButton(title: "Продолжить с Apple", subtitle: "Быстрый вход", icon: "apple.logo", accent: Color.white.opacity(0.15), textColor: .white, action: onAppleTap)
                    .scaleEffect(buttonPulse ? 1.02 : 1.0)
                SignInButton(title: "Продолжить с Google", subtitle: "Регистрация", icon: "globe", accent: Color.white.opacity(0.15), textColor: .white, action: onGoogleTap)
                Button(action: onGuestTap) {
                    Text("Остаться гостем").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white.opacity(0.85)).frame(maxWidth: 300).padding(.vertical, 14)
                        .overlay(Capsule().stroke(LinearGradient(colors: [.white.opacity(0.4), .clear], startPoint: .top, endPoint: .bottom), lineWidth: 1))
                }
            }
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
            Text("Войти как гость?").font(.system(size: 24, weight: .bold, design: .rounded)).foregroundStyle(.white)
            Text("Если остаться гостем, данные тренировок не будут сохраняться в облаке.").font(.system(size: 13)).foregroundStyle(.white.opacity(0.86))
            Text("Почему лучше зарегистрироваться:").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 6) { bullet("Сохранение прогресса в облаке"); bullet("Синхронизация с iPad"); bullet("Умные советы") }
            Spacer(minLength: 8)
            HStack(spacing: 12) {
                Button(action: onStayGuest) { Text("Гость").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 12).background(Color.white.opacity(0.15)).clipShape(RoundedRectangle(cornerRadius: 12)) }
                Button(action: onSignIn) { Text("Войти").font(.system(size: 14, weight: .bold)).foregroundStyle(.black).frame(maxWidth: .infinity).padding(.vertical, 12).background(LinearGradient(colors: [.white, Color(white: 0.9)], startPoint: .top, endPoint: .bottom)).clipShape(RoundedRectangle(cornerRadius: 12)) }
            }
        }.padding(24)
    }
    private func bullet(_ text: String) -> some View { HStack(alignment: .top, spacing: 8) { Circle().fill(Color.cyan).frame(width: 4, height: 4).padding(.top, 6); Text(text).font(.system(size: 13)).foregroundStyle(.white.opacity(0.92)) } }
}

private struct GoogleRegistrationView: View {
    @State private var fullName = ""; @State private var email = ""; @State private var password = ""
    let onBack: () -> Void; let onRegister: () -> Void
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                Button(action: onBack) { HStack(spacing: 4) { Image(systemName: "chevron.left"); Text("Назад") }.font(.system(size: 14, weight: .semibold)).foregroundStyle(.white).padding(.horizontal, 10).padding(.vertical, 6).background(.ultraThinMaterial).clipShape(Capsule()) }.padding(.top, 6)
                Text("Регистрация").font(.system(size: 28, weight: .bold, design: .rounded)).foregroundStyle(.white)
                VStack(spacing: 10) {
                    TextField("Имя и фамилия", text: $fullName).customFieldStyle()
                    TextField("Email", text: $email).keyboardType(.emailAddress).textInputAutocapitalization(.never).customFieldStyle()
                    SecureField("Пароль", text: $password).customFieldStyle()
                }.padding(.vertical, 4)
                Button(action: onRegister) { Text("Зарегистрироваться").font(.system(size: 15, weight: .bold)).foregroundStyle(.black).frame(maxWidth: .infinity).padding(.vertical, 14).background(LinearGradient(colors: [.white, Color(white: 0.9)], startPoint: .top, endPoint: .bottom)).clipShape(RoundedRectangle(cornerRadius: 14)) }
                Spacer(minLength: 40)
            }.padding(24)
        }
    }
}

private extension View {
    func customFieldStyle() -> some View {
        self.font(.system(size: 14)).padding(14).background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(LinearGradient(colors: [.white.opacity(0.4), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)).foregroundStyle(.white).tint(.cyan)
    }
}

// 3D КОМПОНЕНТЫ
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

// MARK: - ЭТАП 2: СБОР МЕТРИК С ГИПЕРПРЫЖКОМ
struct GodModeUserMetrics {
    var age: Int = 25
    var height: Int = 175
    var weight: Int = 75
    var activityLevel: GodModeActivityType = .none
}

enum GodModeActivityType: String, CaseIterable {
    case none = "Пока не выбрано"
    case office = "Офисная матрица"
    case light = "Легкое движение"
    case active = "Заряженный мотор"
    case beast = "Режим киборга"
    
    var emoji: String {
        switch self {
        case .none: return "😶"; case .office: return "👨‍💻"; case .light: return "🚶‍♂️"; case .active: return "⚡️"; case .beast: return "🦍"
        }
    }
    var description: String {
        switch self {
        case .none: return ""; case .office: return "Сидим за столом, минимум шагов"; case .light: return "Разминки и 1-2 тренировки"; case .active: return "Спорт 3-4 раза в неделю"; case .beast: return "Ежедневные нагрузки"
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
            Text("Твоя\nНовая\nЭра.").font(.system(size: 56, weight: .black, design: .rounded)).foregroundStyle(LinearGradient(colors: [.white, .cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)).lineSpacing(-5)
                .offset(y: isVisible ? 0 : 20).opacity(isVisible ? 1 : 0)
            Text("Твой персональный архитектор тела. Никакого мусора — только чистый фокус на результате.\n\nГотов сломать лимиты?").font(.system(size: 16, weight: .medium)).foregroundStyle(.white.opacity(0.7)).offset(y: isVisible ? 0 : 20).opacity(isVisible ? 1 : 0)
            Spacer()
            GodModeButton(title: "Начать", action: onNext).offset(y: isVisible ? 0 : 30).opacity(isVisible ? 1 : 0)
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
                Text("Оцифруй себя").font(.system(size: 32, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Text("Базовые параметры для старта").font(.system(size: 15)).foregroundStyle(.white.opacity(0.6))
            }.padding(.top, 60)
            Spacer()
            HStack(spacing: 0) {
                GodModeWheelColumn(title: "Возраст", range: 14...100, suffix: "лет", selection: $metrics.age)
                GodModeWheelColumn(title: "Рост", range: 140...230, suffix: "см", selection: $metrics.height)
                GodModeWheelColumn(title: "Вес", range: 40...200, suffix: "кг", selection: $metrics.weight)
            }
            .frame(height: 220).background(RoundedRectangle(cornerRadius: 24).fill(Color.white.opacity(0.05)).overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.1), lineWidth: 1))).padding(.horizontal, 20)
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "cpu").font(.system(size: 24, weight: .light)).foregroundStyle(.cyan)
                Text("Алгоритм использует эти данные для точного расчета BMR и адаптации нагрузок. Никакой магии, только наука.").font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.7))
            }
            .padding(16).background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 16)).padding(.horizontal, 20).padding(.top, 30)
            Spacer()
            GodModeButton(title: "Продолжить", action: onNext).padding(.horizontal, 30).padding(.bottom, 30)
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
                Text("Твой ритм").font(.system(size: 32, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Text("Как проходит твой обычный день?").font(.system(size: 15)).foregroundStyle(.white.opacity(0.6))
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
            GodModeButton(title: "Создать профиль", action: onNext, isDisabled: metrics.activityLevel == .none).padding(.horizontal, 30).padding(.bottom, 30)
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
                    Text("Профиль готов").font(.system(size: 32, weight: .black, design: .rounded)).foregroundStyle(.white)
                    Text("Твои данные надежно сохранены.\n\nУдачной тренировки, бро.").font(.system(size: 15, weight: .medium)).foregroundStyle(.white.opacity(0.6)).multilineTextAlignment(.center).padding(.horizontal, 30)
                }
                Spacer()
                GodModeButton(title: "Войти в систему") { startExtendedHyperspaceJump() }.padding(.horizontal, 30).padding(.bottom, 30)
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

// MARK: - ЭТАП 3: PAYWALL
struct SubPlan: Identifiable, Equatable {
    let id = UUID(); let name, price, duration: String; let badge: String?
}
struct CyberFeature: Identifiable, Equatable {
    let id = UUID(); let title, subtitle, icon: String; let colors: [Color]; let detail: String
}

struct PaywallGodModeScreen: View {
    let onNext: () -> Void
    @State private var selectedPlan: String = "Год"
    @State private var selectedFeature: CyberFeature? = nil
    @State private var showWelcomeOverlay: Bool = false
    
    let plans: [SubPlan] = [
        SubPlan(name: "Неделя", price: "290 ₽", duration: "/ нед", badge: nil),
        SubPlan(name: "Месяц", price: "990 ₽", duration: "/ мес", badge: "БАЗА"),
        SubPlan(name: "Год", price: "5 990 ₽", duration: "/ год", badge: "КИБОРГ (ЭКОНОМИЯ 60%)")
    ]
    
    var body: some View {
        ZStack {
            CyberBackgroundView()
            BiometricScannerView()
            
            VStack(spacing: 0) {
                TopCloseButton { onNext() }
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 35) {
                        NeuralSyncProgressView()
                        GodModeHeader()
                        SystemReadyBadgeView()
                        CyberCarouselView(selectedFeature: $selectedFeature)
                        BentoBoxGrid()
                        CyberProsConsView()
                        PricingPlansView(plans: plans, selectedPlan: $selectedPlan)
                        SafeTrialTimelineView()
                        Spacer().frame(height: 180)
                    }.padding(.top, 10)
                }
            }
            
            GodModeCTA(selectedPlan: selectedPlan, plans: plans) {
                HapticManager.playHeavyImpact()
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { showWelcomeOverlay = true }
            }
            
            if let feature = selectedFeature {
                CyberFeatureDetailOverlay(feature: feature) {
                    withAnimation(.spring()) { selectedFeature = nil; HapticManager.playMediumImpact() }
                }.transition(.scale.combined(with: .opacity)).zIndex(100)
            }
            
            if showWelcomeOverlay {
                WelcomeCyborgOverlay {
                    HapticManager.playHeavyImpact()
                    withAnimation(.easeInOut(duration: 0.5)) { onNext() }
                }.transition(.scale.combined(with: .opacity)).zIndex(200)
            }
        }
    }
}

struct CyberProsConsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("ВЫБЕРИ СВОЙ ПУТЬ").font(.system(size: 14, weight: .bold, design: .monospaced)).foregroundStyle(.white.opacity(0.5)).tracking(4)
            HStack(alignment: .top, spacing: 12) { ConsCardView(); ProsCardView() }
        }.padding(.horizontal, 20)
    }
}

struct ConsCardView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Image(systemName: "figure.walk").foregroundStyle(.red.opacity(0.8)); Text("ЧЕЛОВЕК").font(.system(size: 14, weight: .black, design: .monospaced)).foregroundStyle(.white.opacity(0.8)) }.padding(.bottom, 4)
            CyberComparisonRow(icon: "xmark", color: .red.opacity(0.8), text: "Тренировки наугад")
            CyberComparisonRow(icon: "xmark", color: .red.opacity(0.8), text: "Риск перетрена")
            CyberComparisonRow(icon: "xmark", color: .red.opacity(0.8), text: "Плато через месяц")
            CyberComparisonRow(icon: "xmark", color: .red.opacity(0.8), text: "Усталость и травмы")
            Spacer()
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading).background(Color.red.opacity(0.05)).clipShape(RoundedRectangle(cornerRadius: 20)).overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.red.opacity(0.2), lineWidth: 1))
    }
}

struct ProsCardView: View {
    @State private var borderRotation: Double = 0
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Image(systemName: "cpu").foregroundStyle(.cyan).shadow(color: .cyan, radius: 5); Text("КИБОРГ").font(.system(size: 14, weight: .black, design: .monospaced)).foregroundStyle(.cyan) }.padding(.bottom, 4)
            CyberComparisonRow(icon: "checkmark", color: .cyan, text: "Генетический план")
            CyberComparisonRow(icon: "checkmark", color: .cyan, text: "Идеальное восстановление")
            CyberComparisonRow(icon: "checkmark", color: .cyan, text: "Постоянный рост")
            CyberComparisonRow(icon: "checkmark", color: .cyan, text: "ИИ-контроль весов")
            Spacer()
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading).background(Color.cyan.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(AngularGradient(colors: [.cyan, .clear, .blue, .clear, .cyan], center: .center, angle: .degrees(borderRotation)), lineWidth: 2))
        .shadow(color: .cyan.opacity(0.2), radius: 15).scaleEffect(1.02)
        .onAppear { withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) { borderRotation = 360 } }
    }
}

struct CyberComparisonRow: View {
    let icon: String; let color: Color; let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 8) { Image(systemName: icon).font(.system(size: 12, weight: .bold)).foregroundStyle(color).padding(.top, 2); Text(text).font(.system(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.9)).fixedSize(horizontal: false, vertical: true).lineLimit(2) }
    }
}

struct WelcomeCyborgOverlay: View {
    let onStart: () -> Void
    @State private var borderRotation: Double = 0; @State private var isPulsing: Bool = false
    var body: some View {
        ZStack {
            Color.black.opacity(0.8).background(.ultraThinMaterial).ignoresSafeArea()
            VStack(spacing: 24) {
                ZStack { Circle().fill(Color.cyan.opacity(0.1)).frame(width: 100, height: 100); Image(systemName: "checkmark.seal.fill").font(.system(size: 60)).foregroundStyle(LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)).shadow(color: Color.cyan.opacity(0.8), radius: isPulsing ? 30 : 15).scaleEffect(isPulsing ? 1.05 : 1.0) }
                VStack(spacing: 12) { Text("ДОБРО ПОЖАЛОВАТЬ").font(.system(size: 28, weight: .black, design: .rounded)).foregroundStyle(.white).multilineTextAlignment(.center); Text("ДОСТУП КО ВСЕМ ИИ-МОДУЛЯМ ОТКРЫТ").font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(.cyan) }
                VStack(spacing: 10) { Text("Твое рвение стать лучшей версией себя — принято и обработано.").font(.system(size: 15, weight: .bold)).foregroundStyle(.white); Text("Трансформация начинается сейчас.").font(.system(size: 15, weight: .medium)).foregroundStyle(.white.opacity(0.7)) }.multilineTextAlignment(.center).padding(.horizontal, 8)
                Button(action: onStart) { Text("ВОЙТИ В СИСТЕМУ").font(.system(size: 16, weight: .black, design: .monospaced)).foregroundStyle(.black).frame(maxWidth: .infinity).frame(height: 56).background(LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing)).clipShape(RoundedRectangle(cornerRadius: 16)).shadow(color: Color.cyan.opacity(0.5), radius: 10, y: 5) }.padding(.top, 16)
            }.padding(32).background(Color(red: 0.05, green: 0.05, blue: 0.08)).clipShape(RoundedRectangle(cornerRadius: 40)).overlay(RoundedRectangle(cornerRadius: 40).strokeBorder(AngularGradient(colors: [.cyan, .clear, .blue, .clear, .cyan], center: .center, angle: .degrees(borderRotation)), lineWidth: 3)).padding(.horizontal, 24)
            .onAppear { withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) { borderRotation = 360 }; withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) { isPulsing = true } }
        }
    }
}

struct SafeTrialTimelineView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("КАК РАБОТАЕТ ПРОБНЫЙ ПЕРИОД:").font(.system(size: 13, weight: .black, design: .monospaced)).foregroundStyle(.gray).padding(.bottom, 20)
            TimelineStepView(icon: "lock.open.fill", color: .green, title: "Сегодня", subtitle: "Мгновенный доступ ко всем ИИ-модулям. 0 ₽.", isLast: false)
            TimelineStepView(icon: "bell.badge.fill", color: .yellow, title: "День 5", subtitle: "Пришлем push-уведомление. Никаких сюрпризов.", isLast: false)
            TimelineStepView(icon: "bolt.fill", color: .cyan, title: "День 7", subtitle: "Начало подписки. Отмена в 1 клик в настройках.", isLast: true)
        }.padding(24).background(Color.white.opacity(0.03)).clipShape(RoundedRectangle(cornerRadius: 24)).overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.1), lineWidth: 1)).padding(.horizontal, 20)
    }
}
struct TimelineStepView: View {
    let icon: String; let color: Color; let title: String; let subtitle: String; let isLast: Bool
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(spacing: 0) { ZStack { Circle().fill(color.opacity(0.2)).frame(width: 32, height: 32); Image(systemName: icon).font(.system(size: 14, weight: .bold)).foregroundStyle(color) }; if !isLast { Rectangle().fill(Color.white.opacity(0.1)).frame(width: 2, height: 40).padding(.vertical, 4) } }
            VStack(alignment: .leading, spacing: 4) { Text(title).font(.system(size: 16, weight: .bold)).foregroundStyle(.white); Text(subtitle).font(.system(size: 13, weight: .medium)).foregroundStyle(.gray).fixedSize(horizontal: false, vertical: true) }.padding(.top, 6)
            Spacer()
        }
    }
}

struct SystemReadyBadgeView: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill").font(.system(size: 20)).foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 2) { Text("АНАЛИЗ ЗАВЕРШЕН").font(.system(size: 11, weight: .black, design: .monospaced)).foregroundStyle(.green); Text("Нейросеть откалибрована под ваши ответы").font(.system(size: 13, weight: .medium)).foregroundStyle(.white) }
            Spacer()
        }.padding(.horizontal, 16).padding(.vertical, 12).background(Color.green.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.green.opacity(0.3), lineWidth: 1)).padding(.horizontal, 20)
    }
}

struct CyberFeatureDetailOverlay: View {
    let feature: CyberFeature; let onClose: () -> Void
    @State private var borderRotation: Double = 0; @State private var isPulsing: Bool = false
    var body: some View {
        ZStack {
            Color.black.opacity(0.6).background(.ultraThinMaterial).ignoresSafeArea().onTapGesture { onClose() }
            VStack(spacing: 24) {
                Image(systemName: feature.icon).font(.system(size: 60)).foregroundStyle(LinearGradient(colors: feature.colors, startPoint: .topLeading, endPoint: .bottomTrailing)).shadow(color: feature.colors[0].opacity(0.8), radius: isPulsing ? 30 : 15).scaleEffect(isPulsing ? 1.05 : 1.0)
                VStack(spacing: 8) { Text(feature.title).font(.system(size: 28, weight: .black, design: .rounded)).foregroundStyle(.white).multilineTextAlignment(.center); Text(feature.subtitle).font(.system(size: 14, weight: .bold, design: .monospaced)).foregroundStyle(feature.colors[0]).tracking(2) }
                Text(feature.detail).font(.system(size: 16, weight: .medium)).foregroundStyle(.white.opacity(0.8)).multilineTextAlignment(.center).lineSpacing(6).padding(.horizontal, 10)
                Button(action: onClose) { Text("СИНХРОНИЗИРОВАНО").font(.system(size: 16, weight: .black, design: .monospaced)).foregroundStyle(.black).frame(maxWidth: .infinity).frame(height: 56).background(LinearGradient(colors: feature.colors, startPoint: .leading, endPoint: .trailing)).clipShape(RoundedRectangle(cornerRadius: 16)).shadow(color: feature.colors[0].opacity(0.5), radius: 10, y: 5) }.padding(.top, 10)
            }.padding(32).background(Color(red: 0.08, green: 0.08, blue: 0.12)).clipShape(RoundedRectangle(cornerRadius: 40)).overlay(RoundedRectangle(cornerRadius: 40).strokeBorder(AngularGradient(colors: [feature.colors[0], .clear, feature.colors[1], .clear, feature.colors[0]], center: .center, angle: .degrees(borderRotation)), lineWidth: 3)).padding(.horizontal, 24)
            .onAppear { withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) { borderRotation = 360 }; withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) { isPulsing = true } }
        }
    }
}

struct CyberCarouselView: View {
    @Binding var selectedFeature: CyberFeature?
    let features = [ CyberFeature(title: "Нейро-Планы", subtitle: "Генерация", icon: "brain", colors: [.cyan, .blue], detail: "ИИ анализирует твои исходные данные для создания плана."), CyberFeature(title: "ЦНС", subtitle: "Восстановление", icon: "bolt.heart.fill", colors: [.purple, .pink], detail: "Следим за твоей нервной системой.") ]
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 20) {
                ForEach(features) { feature in AnimatedFeatureCard(feature: feature) { HapticManager.playLightImpact(); withAnimation { selectedFeature = feature } } }
            }.padding(.horizontal, 20).padding(.vertical, 10)
        }
    }
}

struct AnimatedFeatureCard: View {
    let feature: CyberFeature; let action: () -> Void
    @State private var borderRotation: Double = 0
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: feature.icon).font(.system(size: 36)).foregroundStyle(LinearGradient(colors: feature.colors, startPoint: .topLeading, endPoint: .bottomTrailing)).shadow(color: feature.colors[0].opacity(0.5), radius: 10)
                VStack(alignment: .leading, spacing: 6) { Text(feature.title).font(.system(size: 18, weight: .bold)).foregroundStyle(.white); Text(feature.subtitle).font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.6)) }
            }.padding(24).frame(width: 240, alignment: .leading).background(Color(red: 0.1, green: 0.1, blue: 0.15).opacity(0.6)).clipShape(RoundedRectangle(cornerRadius: 30)).overlay(RoundedRectangle(cornerRadius: 30).strokeBorder(AngularGradient(colors: [feature.colors[0], .clear, feature.colors[1], .clear], center: .center, angle: .degrees(borderRotation)), lineWidth: 2))
        }.buttonStyle(.plain).onAppear { withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) { borderRotation = 360 } }
    }
}

struct CyberBackgroundView: View {
    @State private var rotation: Double = 0
    var body: some View { ZStack { Color(red: 0.03, green: 0.03, blue: 0.05).ignoresSafeArea(); AngularGradient(colors: [.cyan.opacity(0.3), .blue.opacity(0.1), .purple.opacity(0.2), .cyan.opacity(0.3)], center: .center, angle: .degrees(rotation)).blur(radius: 80).ignoresSafeArea().onAppear { withAnimation(.linear(duration: 15).repeatForever(autoreverses: false)) { rotation = 360 } }; Color.black.opacity(0.5).ignoresSafeArea(); CyberParticlesView() } }
}

struct CyberParticlesView: View {
    @State private var isAnimating = false
    var body: some View {
        GeometryReader { proxy in ZStack { ForEach(0..<15, id: \.self) { i in Circle().fill(Color.cyan.opacity(Double.random(in: 0.2...0.6))).frame(width: CGFloat.random(in: 2...6)).position(x: isAnimating ? CGFloat.random(in: 0...proxy.size.width) : CGFloat.random(in: 0...proxy.size.width), y: isAnimating ? CGFloat.random(in: 0...proxy.size.height) : (proxy.size.height + 50)).blur(radius: 1).animation(.linear(duration: Double.random(in: 10...20)).repeatForever(autoreverses: false).delay(Double.random(in: 0...5)), value: isAnimating) } } }.ignoresSafeArea().onAppear { isAnimating = true }
    }
}

struct BiometricScannerView: View {
    @State private var scanOffset: CGFloat = -200
    var body: some View { Rectangle().fill(LinearGradient(colors: [.clear, .cyan.opacity(0.4), .clear], startPoint: .top, endPoint: .bottom)).frame(height: 100).offset(y: scanOffset).onAppear { withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) { scanOffset = UIScreen.main.bounds.height + 200 } }.allowsHitTesting(false) }
}

struct TopCloseButton: View {
    let action: () -> Void
    var body: some View { HStack { Spacer(); Button(action: action) { Image(systemName: "xmark.circle.fill").font(.system(size: 28)).foregroundStyle(.white.opacity(0.3)) }.padding(.trailing, 20).padding(.top, 10) } }
}

struct NeuralSyncProgressView: View {
    @State private var progress: CGFloat = 0.0
    var body: some View { HStack { Text("СИНХРОНИЗАЦИЯ...").font(.system(size: 10, weight: .black, design: .monospaced)).foregroundStyle(.cyan); GeometryReader { geo in ZStack(alignment: .leading) { Capsule().fill(Color.white.opacity(0.1)); Capsule().fill(Color.cyan).frame(width: geo.size.width * progress).shadow(color: .cyan, radius: 5) } }.frame(height: 4); Text("\(Int(progress * 100))%").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(.cyan) }.padding(.horizontal, 20).onAppear { withAnimation(.easeInOut(duration: 2.5)) { progress = 1.0 } } }
}

struct GodModeHeader: View {
    @State private var textRotation: Double = 0
    var body: some View { VStack(spacing: 8) { Text("АКТИВАЦИЯ").font(.system(size: 14, weight: .bold, design: .monospaced)).foregroundStyle(.white.opacity(0.5)).tracking(8); Text("GOD MODE").font(.system(size: 56, weight: .black, design: .rounded)).foregroundStyle(.clear).overlay(AngularGradient(colors: [.cyan, .white, .blue, .purple, .cyan], center: .center, angle: .degrees(textRotation)).mask(Text("GOD MODE").font(.system(size: 56, weight: .black, design: .rounded)))).onAppear { withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) { textRotation = 360 } }; Text("Нейронная сеть построит тело твоей мечты.").font(.system(size: 15, weight: .medium)).foregroundStyle(.white.opacity(0.7)).multilineTextAlignment(.center) } }
}

struct BentoBoxGrid: View {
    var body: some View { VStack(spacing: 12) { HStack(spacing: 12) { BentoCard(icon: "nosign", title: "0% Рекламы", color: .white); BentoCard(icon: "cpu", title: "100% ИИ", color: .cyan) }; HStack(spacing: 12) { BentoCard(icon: "chart.line.uptrend.xyaxis", title: "Аналитика", color: .purple); BentoCard(icon: "infinity", title: "Без лимитов", color: .blue) } }.padding(.horizontal, 20) }
}
struct BentoCard: View {
    let icon: String; let title: String; let color: Color
    var body: some View { HStack(spacing: 12) { Image(systemName: icon).font(.system(size: 20, weight: .bold)).foregroundStyle(color); Text(title).font(.system(size: 14, weight: .bold)).foregroundStyle(.white); Spacer() }.padding(20).background(Color.white.opacity(0.03)).clipShape(RoundedRectangle(cornerRadius: 24)).overlay(RoundedRectangle(cornerRadius: 24).stroke(color.opacity(0.2), lineWidth: 1)) }
}

struct PricingPlansView: View {
    let plans: [SubPlan]; @Binding var selectedPlan: String
    var body: some View { VStack(spacing: 16) { ForEach(plans) { plan in PlanRowView(plan: plan, isSelected: selectedPlan == plan.name) { withAnimation { selectedPlan = plan.name; HapticManager.playSelection() } } } }.padding(.horizontal, 20) }
}
struct PlanRowView: View {
    let plan: SubPlan; let isSelected: Bool; let action: () -> Void
    var body: some View { Button(action: action) { HStack { Circle().strokeBorder(isSelected ? Color.cyan : .white.opacity(0.2), lineWidth: 2).background(Circle().fill(isSelected ? Color.cyan.opacity(0.2) : .clear)).frame(width: 24, height: 24).overlay(Circle().fill(isSelected ? Color.cyan : .clear).frame(width: 10, height: 10)); VStack(alignment: .leading, spacing: 4) { Text(plan.name).font(.system(size: 18, weight: .bold)).foregroundStyle(.white); if let badge = plan.badge { Text(badge).font(.system(size: 10, weight: .black, design: .monospaced)).padding(.horizontal, 8).padding(.vertical, 4).background(isSelected ? Color.cyan : .white.opacity(0.1)).foregroundStyle(isSelected ? Color.black : .white).clipShape(Capsule()) } }.padding(.leading, 10); Spacer(); VStack(alignment: .trailing) { Text(plan.price).font(.system(size: 20, weight: .black, design: .rounded)).foregroundStyle(.white); Text(plan.duration).font(.system(size: 12, weight: .medium)).foregroundStyle(.gray) } }.padding(20).background(isSelected ? Color.cyan.opacity(0.08) : .white.opacity(0.02)).clipShape(RoundedRectangle(cornerRadius: 24)).shadow(color: isSelected ? Color.cyan.opacity(0.3) : .clear, radius: 15).overlay(RoundedRectangle(cornerRadius: 24).stroke(isSelected ? Color.cyan : .white.opacity(0.1), lineWidth: isSelected ? 2 : 1)).scaleEffect(isSelected ? 1.02 : 1.0) }.buttonStyle(.plain) }
}

struct GodModeCTA: View {
    let selectedPlan: String; let plans: [SubPlan]; let onActivate: () -> Void
    @State private var shimmerOffset: CGFloat = -200; @State private var buttonPulse: Bool = false; @State private var timeRemaining = 899
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 16) {
                HStack(spacing: 6) { Image(systemName: "clock.fill").foregroundStyle(.cyan); Text("КИБЕР-ОКНО ЗАКРОЕТСЯ ЧЕРЕЗ: \(String(format: "%02d:%02d", timeRemaining / 60, timeRemaining % 60))").font(.system(size: 11, weight: .black, design: .monospaced)).foregroundStyle(.cyan) }.padding(.horizontal, 12).padding(.vertical, 6).background(Color.cyan.opacity(0.1)).clipShape(Capsule()).onReceive(timer) { _ in if timeRemaining > 0 { timeRemaining -= 1 } }
                Button(action: onActivate) { ZStack { LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing); LinearGradient(colors: [.clear, .white.opacity(0.5), .clear], startPoint: .leading, endPoint: .trailing).rotationEffect(.degrees(30)).offset(x: shimmerOffset); Text("АКТИВИРОВАТЬ 7 ДНЕЙ").font(.system(size: 18, weight: .black, design: .rounded)).foregroundStyle(.black).tracking(1.5) }.frame(height: 65).clipShape(RoundedRectangle(cornerRadius: 20)).shadow(color: .cyan.opacity(0.5), radius: buttonPulse ? 20 : 10, y: 5).scaleEffect(buttonPulse ? 1.03 : 1.0) }.buttonStyle(.plain).onAppear { withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) { shimmerOffset = 400 }; withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) { buttonPulse = true } }
                Text("Потом \(plans.first(where: { $0.name == selectedPlan })?.price ?? ""). Отменишь в 1 клик.").font(.system(size: 13, weight: .medium)).foregroundStyle(.gray)
            }.padding(.horizontal, 20).padding(.top, 40).padding(.bottom, 15).background(LinearGradient(colors: [Color(red: 0.03, green: 0.03, blue: 0.05).opacity(0), Color(red: 0.03, green: 0.03, blue: 0.05)], startPoint: .top, endPoint: .bottom))
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
