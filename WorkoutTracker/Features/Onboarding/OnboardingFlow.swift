internal import SwiftUI
import PhotosUI

// MARK: - Model

struct OnboardingItem: Identifiable {
    let id = UUID()
    let image: String
    let title: LocalizedStringKey
    let description: LocalizedStringKey
    let color: Color
}

// MARK: - Root Flow

struct OnboardingFlowView: View {
    @Binding var isOnboardingCompleted: Bool
    @Environment(TutorialManager.self) var tutorialManager
    @Environment(ThemeManager.self) private var themeManager
    @State private var currentTab = 0
    @State private var didFinish = false
    @AppStorage("userName") private var userName = ""
    @AppStorage("userBodyWeight") private var userBodyWeight = 0.0

    private let stepCount = 4

    var body: some View {
        ZStack {
            OnboardingBackground()

            VStack(spacing: 0) {
                StepProgressBar(current: currentTab, total: stepCount)
                    .padding(.horizontal, 30)
                    .padding(.top, 12)

                TabView(selection: $currentTab) {
                    OnboardingIntroView(onNext: nextStep).tag(0)
                    UserDataInputView(name: $userName, weight: $userBodyWeight, onNext: nextStep).tag(1)
                    PermissionsView(onNext: nextStep).tag(2)
                    TutorialChoiceView(onFinish: completeOnboarding).tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(response: 0.45, dampingFraction: 0.85), value: currentTab)
                .interactiveDismissDisabled()
            }
        }
        .sensoryFeedback(.success, trigger: didFinish)
        .onAppear {
            TrackingManager.shared.track(.onboardingStarted)
        }
    }

    private func nextStep() {
        TrackingManager.shared.track(.onboardingStepCompleted(step: "Step \(currentTab + 1)"))
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { currentTab += 1 }
    }

    private func completeOnboarding() {
        TrackingManager.shared.track(.onboardingCompleted(goal: "unknown", daysPerWeek: 0, experienceLevel: "unknown"))
        didFinish.toggle()
        withAnimation { isOnboardingCompleted = true }
    }
}

// MARK: - Step 1: Intro

struct OnboardingIntroView: View {
    var onNext: () -> Void
    @Environment(ThemeManager.self) private var themeManager
    @State private var slideIndex = 0

    private let items: [OnboardingItem] = [
        OnboardingItem(image: "dumbbell.fill",
                       title: "Track Workouts",
                       description: "Log your sets, reps, and weights with ease. Support for supersets included.",
                       color: .blue),
        OnboardingItem(image: "figure.mind.and.body",
                       title: "Muscle Recovery",
                       description: "Smart heatmap tracks your muscle fatigue and suggests recovery times.",
                       color: .red),
        OnboardingItem(image: "chart.xyaxis.line",
                       title: "Analyze Progress",
                       description: "Visualize your gains with detailed charts and personal records.",
                       color: .purple)
    ]

    private var isLastSlide: Bool { slideIndex == items.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $slideIndex) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    VStack(spacing: 24) {
                        Spacer()
                        OnboardingIconBadge(systemName: item.image, tint: item.color)
                        VStack(spacing: 12) {
                            Text(item.title)
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                                .foregroundStyle(themeManager.current.primaryText)
                            Text(item.description)
                                .font(.system(size: 16, design: .rounded))
                                .foregroundStyle(themeManager.current.secondaryText)
                                .multilineTextAlignment(.center)
                                .lineSpacing(3)
                                .padding(.horizontal, 32)
                        }
                        Spacer()
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            PageDots(current: slideIndex, total: items.count, tint: themeManager.current.primaryAccent)
                .padding(.bottom, 24)

            Button {
                if isLastSlide { onNext() }
                else { withAnimation(.spring) { slideIndex += 1 } }
            } label: {
                Text(isLastSlide ? "Let's Set Up Profile" : "Next")
            }
            .buttonStyle(OnboardingPrimaryButtonStyle())
            .padding(.horizontal, 30)
            .padding(.bottom, 40)
        }
    }
}

// MARK: - Step 2: User Data

struct UserDataInputView: View {
    @Binding var name: String
    @Binding var weight: Double
    var onNext: () -> Void
    @Environment(ThemeManager.self) private var themeManager

    private enum Field { case name, weight }
    @FocusState private var focusedField: Field?
    @State private var weightString = ""
    @State private var isNameInvalid = false
    @State private var isWeightInvalid = false
    @State private var shakeTriggerName = 0
    @State private var shakeTriggerWeight = 0
    
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var profileImage: UIImage?

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 28) {
                    Spacer(minLength: 20)

                    VStack(spacing: 10) {
                        Text("About You")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(themeManager.current.primaryText)
                        Text("This helps us personalize your profile and calculate stats.")
                            .font(.system(size: 16, design: .rounded))
                            .foregroundStyle(themeManager.current.secondaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    // Avatar Picker
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: [.red, .orange], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 80, height: 80)
                                .shadow(color: .red.opacity(0.4), radius: 10, x: 0, y: 5)

                            if let profileImage {
                                Image(uiImage: profileImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 76, height: 76)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "camera.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                            }
                            
                            // Edit Badge
                            ZStack {
                                Circle()
                                    .fill(themeManager.current.primaryAccent)
                                    .frame(width: 24, height: 24)
                                    .overlay(
                                        Circle().stroke(themeManager.current.background, lineWidth: 2)
                                    )
                                Image(systemName: "pencil")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .offset(x: 28, y: 28)
                        }
                    }
                    .onChange(of: selectedPhotoItem) { _, newItem in
                        Task {
                            if let data = try? await newItem?.loadTransferable(type: Data.self),
                               let uiImage = UIImage(data: data) {
                                await MainActor.run {
                                    profileImage = uiImage
                                    ProfileImageManager.shared.saveImage(uiImage)
                                }
                            }
                        }
                    }

                    VStack(spacing: 18) {
                        field(title: "Your Name",
                              isInvalid: isNameInvalid,
                              shake: shakeTriggerName) {
                            TextField(LocalizedStringKey("Champion"), text: $name)
                                .focused($focusedField, equals: .name)
                                .submitLabel(.next)
                                .onChange(of: name) { _, _ in isNameInvalid = false }
                                .onSubmit { focusedField = .weight }
                        }

                        field(title: LocalizedStringKey("Body Weight (\(UnitsManager.shared.weightUnitString()))"),
                              isInvalid: isWeightInvalid,
                              shake: shakeTriggerWeight) {
                            TextField("75", text: $weightString)
                                .keyboardType(.decimalPad)
                                .focused($focusedField, equals: .weight)
                                .onChange(of: weightString) { _, newValue in
                                    isWeightInvalid = false
                                    if let val = Double(newValue.replacingOccurrences(of: ",", with: ".")) { weight = val }
                                }
                        }
                    }
                    .padding(.horizontal, 30)

                    Spacer(minLength: 20)

                    Button("Continue", action: validateAndContinue)
                        .buttonStyle(OnboardingPrimaryButtonStyle())
                        .padding(.horizontal, 30)
                        .padding(.bottom, 40)
                }
                .frame(minHeight: geometry.size.height)
            }
            .defaultFocus($focusedField, .name)
        }
        .sensoryFeedback(.error, trigger: shakeTriggerName)
        .sensoryFeedback(.error, trigger: shakeTriggerWeight)
        .onAppear { weightString = LocalizationHelper.shared.formatInteger(weight) }
        .scrollDismissesKeyboard(.interactively)
        .onTapGesture { focusedField = nil }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }.bold()
            }
        }
    }

    @ViewBuilder
    private func field<Content: View>(title: LocalizedStringKey,
                                      isInvalid: Bool,
                                      shake: Int,
                                      @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(isInvalid ? Color.red : themeManager.current.secondaryText)
            content()
                .font(.title3)
                .padding()
                .background(isInvalid ? Color.red.opacity(0.1) : themeManager.current.surface,
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(isInvalid ? Color.red : Color.clear, lineWidth: 1)
                )
        }
        .modifier(ShakeEffectModifier(trigger: shake))
    }

    private func validateAndContinue() {
        let parsedWeight = Double(weightString.replacingOccurrences(of: ",", with: ".")) ?? 0
        let validName = !name.trimmingCharacters(in: .whitespaces).isEmpty
        let validWeight = parsedWeight > 0

        isNameInvalid = !validName
        isWeightInvalid = !validWeight

        if validName && validWeight {
            onNext()
        } else {
            if !validName { shakeTriggerName += 1 }
            if !validWeight { shakeTriggerWeight += 1 }
        }
    }
}

// MARK: - Step 3: Permissions

struct PermissionsView: View {
    var onNext: () -> Void
    @Environment(ThemeManager.self) private var themeManager
    @State private var notificationsAllowed = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            OnboardingIconBadge(systemName: "bell.badge.fill",
                                tint: themeManager.current.secondaryMidTone)
            VStack(spacing: 12) {
                Text("Stay on Track")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(themeManager.current.primaryText)
                Text("Enable notifications to use the Rest Timer and get streak reminders. We promise not to spam.")
                    .font(.system(size: 16, design: .rounded))
                    .foregroundStyle(themeManager.current.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button { requestNotifications() } label: {
                HStack(spacing: 8) {
                    Text(notificationsAllowed ? "Allowed" : "Enable Notifications")
                    if notificationsAllowed { Image(systemName: "checkmark") }
                }
            }
            .buttonStyle(OnboardingPrimaryButtonStyle(fill: notificationsAllowed ? .green : nil))
            .disabled(notificationsAllowed)
            .padding(.horizontal, 50)
            .padding(.top, 8)

            Spacer()

            Button("Continue", action: onNext)
                .buttonStyle(OnboardingPrimaryButtonStyle())
                .padding(.horizontal, 30)
                .padding(.bottom, 40)
        }
    }

    private func requestNotifications() {
        NotificationManager.shared.requestPermission { granted in
            DispatchQueue.main.async {
                withAnimation { self.notificationsAllowed = granted }
            }
        }
    }
}

// MARK: - Step 4: Tutorial Choice

struct TutorialChoiceView: View {
    var onFinish: () -> Void
    @Environment(TutorialManager.self) var tutorialManager
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            OnboardingIconBadge(systemName: "graduationcap.fill", tint: .purple)
            VStack(spacing: 12) {
                Text("Quick Tutorial")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(themeManager.current.primaryText)
                Text("Would you like a quick interactive tour to learn how to create workouts and track progress?")
                    .font(.system(size: 16, design: .rounded))
                    .foregroundStyle(themeManager.current.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            Spacer()
            VStack(spacing: 14) {
                Button("Start Tutorial") { tutorialManager.reset(); onFinish() }
                    .buttonStyle(OnboardingPrimaryButtonStyle())
                Button("No, I'll figure it out") { tutorialManager.complete(); onFinish() }
                    .buttonStyle(OnboardingSecondaryButtonStyle())
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 36)
        }
    }
}

// MARK: - Reusable Components

struct OnboardingIconBadge: View {
    let systemName: String
    var tint: Color
    var size: CGFloat = 190

    var body: some View {
        ZStack {
            Circle()
                .fill(tint.opacity(0.14))
                .frame(width: size, height: size)
            Circle()
                .strokeBorder(tint.opacity(0.25), lineWidth: 1)
                .frame(width: size, height: size)
            Image(systemName: systemName)
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(colors: [tint, tint.opacity(0.7)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .shadow(color: tint.opacity(0.4), radius: 16, y: 6)
        }
    }
}

struct OnboardingBackground: View {
    @Environment(ThemeManager.self) private var themeManager
    @State private var animate = false

    var body: some View {
        ZStack {
            themeManager.current.background
            Circle()
                .fill(themeManager.current.primaryAccent.opacity(0.30))
                .frame(width: 320).blur(radius: 90)
                .offset(x: animate ? -120 : -70, y: -260)
            Circle()
                .fill(themeManager.current.secondaryAccent.opacity(0.22))
                .frame(width: 300).blur(radius: 100)
                .offset(x: animate ? 120 : 70, y: 280)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 7).repeatForever(autoreverses: true)) { animate = true }
        }
    }
}

struct PageDots: View {
    let current: Int
    let total: Int
    var tint: Color

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<total, id: \.self) { i in
                Capsule()
                    .fill(i == current ? tint : Color.gray.opacity(0.3))
                    .frame(width: i == current ? 22 : 8, height: 8)
                    .animation(.spring(response: 0.35, dampingFraction: 0.7), value: current)
            }
        }
    }
}

struct StepProgressBar: View {
    let current: Int
    let total: Int

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.gray.opacity(0.2))
                Capsule()
                    .fill(LinearGradient(colors: [.purple, .blue],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: geo.size.width * progress)
                    .animation(.spring(response: 0.45, dampingFraction: 0.85), value: current)
            }
        }
        .frame(height: 6)
    }

    private var progress: CGFloat {
        guard total > 1 else { return 1 }
        return CGFloat(current + 1) / CGFloat(total)
    }
}

// MARK: - Button Styles

struct OnboardingPrimaryButtonStyle: ButtonStyle {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.isEnabled) private var isEnabled
    var fill: Color? = nil

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(fill ?? themeManager.current.primaryAccent,
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.6)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
            .sensoryFeedback(.impact(weight: .medium), trigger: configuration.isPressed) { _, pressed in pressed }
    }
}

struct OnboardingSecondaryButtonStyle: ButtonStyle {
    @Environment(ThemeManager.self) private var themeManager

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .medium, design: .rounded))
            .foregroundStyle(themeManager.current.secondaryAccent)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .opacity(configuration.isPressed ? 0.6 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct ShakeEffectModifier: ViewModifier {
    let trigger: Int
    func body(content: Content) -> some View {
        content.keyframeAnimator(initialValue: 0.0, trigger: trigger) { view, xOffset in
            view.offset(x: xOffset)
        } keyframes: { _ in
            KeyframeTrack {
                CubicKeyframe(10, duration: 0.05)
                CubicKeyframe(-10, duration: 0.05)
                CubicKeyframe(10, duration: 0.05)
                CubicKeyframe(-10, duration: 0.05)
                CubicKeyframe(0, duration: 0.05)
            }
        }
    }
}
