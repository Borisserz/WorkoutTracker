

internal import SwiftUI

struct OnboardingItem: Identifiable {
    let id = UUID()
    let image: String
    let title: LocalizedStringKey
    let description: LocalizedStringKey
    let color: Color
}

struct OnboardingFlowView: View {
    @Binding var isOnboardingCompleted: Bool
    @Environment(TutorialManager.self) var tutorialManager
    @Environment(ThemeManager.self) private var themeManager
    @State private var currentTab = 0
    @AppStorage("userName") private var userName = ""
    @AppStorage("userBodyWeight") private var userBodyWeight = 0.0

    var body: some View {
        ZStack {
            themeManager.current.background.ignoresSafeArea()

            TabView(selection: $currentTab) {
                OnboardingIntroView(onNext: { nextStep() }).tag(0)
                UserDataInputView(name: $userName, weight: $userBodyWeight, onNext: { nextStep() }).tag(1)
                PermissionsView(onNext: { nextStep() }).tag(2)
                TutorialChoiceView(onFinish: { completeOnboarding() }).tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: currentTab)
            .interactiveDismissDisabled()
        }
    }

    private func nextStep() { withAnimation { currentTab += 1 } }
    private func completeOnboarding() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        withAnimation { isOnboardingCompleted = true }
    }
}

struct OnboardingIntroView: View {
    var onNext: () -> Void
    @Environment(ThemeManager.self) private var themeManager
    let items: [OnboardingItem] = [
        OnboardingItem(image: "dumbbell.fill", title: "Track Workouts", description: "Log your sets, reps, and weights with ease. Support for supersets included.", color: .blue),
        OnboardingItem(image: "figure.mind.and.body", title: "Muscle Recovery", description: "Smart heatmap tracks your muscle fatigue and suggests recovery times.", color: .red),
        OnboardingItem(image: "chart.xyaxis.line", title: "Analyze Progress", description: "Visualize your gains with detailed charts and personal records.", color: .purple)
    ]
    @State private var slideIndex = 0

    var body: some View {
        VStack {
            TabView(selection: $slideIndex) {
                ForEach(0..<items.count, id: \.self) { index in
                    VStack(spacing: 20) {
                        Spacer()
                        Image(systemName: items[index].image)
                            .resizable().scaledToFit().frame(height: 120).foregroundColor(items[index].color)
                            .padding().background(Circle().fill(items[index].color.opacity(0.1)).frame(width: 220, height: 220))
                        Text(items[index].title).font(.system(size: 28, weight: .bold, design: .rounded)).padding(.top, 20)
                        Text(items[index].description).multilineTextAlignment(.center).foregroundColor(themeManager.current.secondaryText).padding(.horizontal, 30)
                        Spacer()
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button(action: {
                if slideIndex < items.count - 1 { withAnimation { slideIndex += 1 } } else { onNext() }
            }) {
                let buttonTitle: LocalizedStringKey = slideIndex == items.count - 1 ? "Let's Set Up Profile" : "Next"
                Text(buttonTitle).font(.headline).foregroundColor(.white).frame(maxWidth: .infinity).padding().background(themeManager.current.primaryAccent).cornerRadius(12)
            }
            .padding(.horizontal, 30).padding(.bottom, 50)
        }
    }
}

struct UserDataInputView: View {
    @Binding var name: String
    @Binding var weight: Double
    var onNext: () -> Void
    @Environment(ThemeManager.self) private var themeManager

    private enum Field { case name, weight }
    @FocusState private var focusedField: Field?
    @State private var weightString: String = ""
    @State private var isNameInvalid = false
    @State private var isWeightInvalid = false
    @State private var shakeTriggerName = 0
    @State private var shakeTriggerWeight = 0

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 25) {
                    Spacer(minLength: 20)
                    Text(LocalizedStringKey("About You")).font(.largeTitle).bold()
                    Text(LocalizedStringKey("This helps us personalize your profile and calculate stats.")).foregroundColor(themeManager.current.secondaryText).multilineTextAlignment(.center).padding(.horizontal)

                    VStack(spacing: 20) {
                        VStack(alignment: .leading) {
                            Text("Your Name").font(.caption).foregroundColor(isNameInvalid ? .red : .gray)
                            TextField(LocalizedStringKey("Champion"), text: $name)
                                .font(.title3).padding()
                                .background(isNameInvalid ? Color.red.opacity(0.1) : themeManager.current.surface)
                                .cornerRadius(12)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(isNameInvalid ? Color.red : Color.clear, lineWidth: 1))
                                .focused($focusedField, equals: .name)
                                .submitLabel(.next)
                                .onChange(of: name) { _, _ in isNameInvalid = false }
                                .onSubmit { focusedField = .weight }
                        }
                        .modifier(ShakeEffectModifier(trigger: shakeTriggerName)) 

                        VStack(alignment: .leading) {
                            Text("Body Weight (\(UnitsManager.shared.weightUnitString()))").font(.caption).foregroundColor(isWeightInvalid ? .red : .gray)
                            TextField("75", text: $weightString)
                                .font(.title3).keyboardType(.decimalPad).padding()
                                .background(isWeightInvalid ? Color.red.opacity(0.1) : themeManager.current.surface)
                                .cornerRadius(12)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(isWeightInvalid ? Color.red : Color.clear, lineWidth: 1))
                                .focused($focusedField, equals: .weight)
                                .onChange(of: weightString) { _, newValue in
                                    isWeightInvalid = false
                                    if let val = Double(newValue.replacingOccurrences(of: ",", with: ".")) { weight = val }
                                }
                        }
                        .modifier(ShakeEffectModifier(trigger: shakeTriggerWeight)) 
                    }
                    .padding(.horizontal, 30)

                    Spacer(minLength: 20)

                    Button(action: validateAndContinue) {
                        Text("Continue").font(.headline).foregroundColor(.white).frame(maxWidth: .infinity).padding().background(themeManager.current.primaryAccent).cornerRadius(12)
                    }
                    .padding(.horizontal, 30).padding(.bottom, 50)
                }
                .frame(minHeight: geometry.size.height)
            }
            .defaultFocus($focusedField, .name)
        }
        .sensoryFeedback(.error, trigger: shakeTriggerName)
        .sensoryFeedback(.error, trigger: shakeTriggerWeight)
        .onAppear { weightString = LocalizationHelper.shared.formatInteger(weight) }
        .onTapGesture { focusedField = nil }
        .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { focusedField = nil }.bold() } }
    }

    private func validateAndContinue() {
        let parsedWeight = Double(weightString.replacingOccurrences(of: ",", with: ".")) ?? 0
        let validName = !name.trimmingCharacters(in: .whitespaces).isEmpty
        let validWeight = parsedWeight > 0

        isNameInvalid = !validName
        isWeightInvalid = !validWeight

        if validName && validWeight { onNext() }
        else {
            if !validName { shakeTriggerName += 1 }
            if !validWeight { shakeTriggerWeight += 1 }
        }
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

struct PermissionsView: View {
    var onNext: () -> Void
    @Environment(ThemeManager.self) private var themeManager
    @State private var notificationsAllowed = false

    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            Image(systemName: "bell.badge.fill").font(.system(size: 80)).foregroundColor(themeManager.current.secondaryMidTone).padding().background(Circle().fill(themeManager.current.secondaryMidTone.opacity(0.1)).frame(width: 150, height: 150))
            Text("Stay on Track").font(.largeTitle).bold()
            Text("Enable notifications to use the Rest Timer and get streak reminders. We promise not to spam.").multilineTextAlignment(.center).foregroundColor(themeManager.current.secondaryText).padding(.horizontal)

            Button { requestNotifications() } label: {
                HStack { Text(notificationsAllowed ? "Allowed" : "Enable Notifications"); if notificationsAllowed { Image(systemName: "checkmark") } }
                .fontWeight(.semibold).padding().frame(maxWidth: .infinity).background(notificationsAllowed ? Color.green : themeManager.current.secondaryMidTone).foregroundColor(.white).cornerRadius(12)
            }
            .padding(.horizontal, 50).disabled(notificationsAllowed)

            Spacer()
            Button(action: onNext) { Text("Continue").font(.headline).foregroundColor(.white).frame(maxWidth: .infinity).padding().background(themeManager.current.primaryAccent).cornerRadius(12) }
            .padding(.horizontal, 30).padding(.bottom, 50)
        }
    }

    private func requestNotifications() {

        NotificationManager.shared.requestPermission { granted in
            DispatchQueue.main.async { withAnimation { self.notificationsAllowed = granted } }
        }
    }
}

struct TutorialChoiceView: View {
    var onFinish: () -> Void
    @Environment(TutorialManager.self) var tutorialManager
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            Image(systemName: "graduationcap.fill").font(.system(size: 80)).foregroundColor(.purple).padding().background(Circle().fill(Color.purple.opacity(0.1)).frame(width: 150, height: 150))
            Text("Quick Tutorial").font(.largeTitle).bold()
            Text("Would you like a quick interactive tour to learn how to create workouts and track progress?").multilineTextAlignment(.center).foregroundColor(themeManager.current.secondaryText).padding(.horizontal)
            Spacer()
            VStack(spacing: 15) {
                Button { tutorialManager.reset(); onFinish() } label: { Text("Start Tutorial").font(.headline).foregroundColor(.white).frame(maxWidth: .infinity).padding().background(themeManager.current.primaryAccent).cornerRadius(12).shadow(radius: 5) }
                Button { tutorialManager.complete(); onFinish() } label: { Text("No, I'll figure it out").font(.headline).foregroundColor(themeManager.current.secondaryAccent).padding() }
            }
            .padding(.horizontal, 30).padding(.bottom, 40)
        }
    }
}
