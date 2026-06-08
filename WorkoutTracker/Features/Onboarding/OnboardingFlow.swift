internal import SwiftUI
import PhotosUI
import Combine
import Charts

// MARK: - Model

enum OnboardingGraphicType {
    case aiCamera
    case smartBuilder
    case analyticsChart
    case watchMock
    case anatomyHeatmap
    case aiChatbot
    case appleHealth
}

struct OnboardingItem: Identifiable {
    let id = UUID()
    let graphic: OnboardingGraphicType
    let title: LocalizedStringKey
    let description: LocalizedStringKey
    let colors: [Color]
    let targetTab: Int?
}

// MARK: - Mock Graphics

struct MockAppleHealthView: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
                .frame(width: 80, height: 80)
                .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
            
            Image(systemName: "heart.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 45, height: 45)
                .foregroundColor(Color(red: 1.0, green: 0.2, blue: 0.3)) // Classic Apple Health pink/red
        }
    }
}

struct MockAnalyticsChartView: View {
    let colors: [Color]
    let data: [Double] = [30, 45, 60, 50, 80, 70, 95]
    @State private var animatedData: [Double] = [0, 0, 0, 0, 0, 0, 0]
    
    var body: some View {
        Chart {
            ForEach(Array(data.enumerated()), id: \.offset) { index, value in
                BarMark(
                    x: .value("Day", index),
                    y: .value("Value", animatedData[index])
                )
                .foregroundStyle(LinearGradient(colors: colors, startPoint: .bottom, endPoint: .top))
                .cornerRadius(4)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .frame(width: 90, height: 70)
        .onAppear {
            for (index, val) in data.enumerated() {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(Double(index) * 0.05)) {
                    animatedData[index] = val
                }
            }
        }
    }
}

struct MockAICameraView: View {
    @State private var phase: CGFloat = 0
    @State private var glowPhase: CGFloat = 0

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [5]))
                .frame(width: 70, height: 90)
                .scaleEffect(1.0 + 0.05 * sin(phase))
            
            Image(systemName: "figure.walk")
                .font(.system(size: 35))
                .foregroundColor(.white)
            
            Circle()
                .fill(Color.green)
                .frame(width: 12, height: 12)
                .offset(x: 20, y: -20)
                .shadow(color: .green, radius: glowPhase * 10)
        }
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: true)) {
                phase = .pi
            }
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                glowPhase = 1.0
            }
        }
    }
}

struct MockSmartBuilderView: View {
    @State private var appear = false

    var body: some View {
        VStack(spacing: 8) {
            ForEach(0..<3) { i in
                HStack {
                    Circle().fill(Color.white.opacity(0.8)).frame(width: 14, height: 14)
                    RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.3)).frame(width: 50, height: 10)
                }
                .offset(x: appear ? 0 : 20)
                .opacity(appear ? 1 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(Double(i) * 0.15), value: appear)
            }
        }
        .onAppear {
            appear = true
        }
    }
}

struct MockAnatomyHeatmapView: View {
    @State private var pulse = false
    var body: some View {
        ZStack {
            Image(systemName: "figure.mind.and.body")
                .font(.system(size: 50))
                .foregroundColor(.white.opacity(0.8))
            
            Circle()
                .fill(Color.red.opacity(0.6))
                .frame(width: 16, height: 16)
                .blur(radius: 4)
                .offset(x: -15, y: -5)
                .scaleEffect(pulse ? 1.5 : 1.0)
                .opacity(pulse ? 0.4 : 1.0)
            
            Circle()
                .fill(Color.orange.opacity(0.8))
                .frame(width: 12, height: 12)
                .blur(radius: 2)
                .offset(x: 10, y: 15)
                .scaleEffect(pulse ? 1.3 : 1.0)
                .opacity(pulse ? 0.6 : 1.0)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

struct MockAIChatbotView: View {
    @State private var wave = false
    var body: some View {
        ZStack {
            Image(systemName: "message.fill")
                .font(.system(size: 50))
                .foregroundColor(.white.opacity(0.3))
                .offset(y: -5)
            
            Image(systemName: "sparkles")
                .font(.system(size: 24))
                .foregroundColor(.yellow)
                .offset(x: 20, y: -25)
                .rotationEffect(.degrees(wave ? 15 : -15))
                .scaleEffect(wave ? 1.2 : 0.9)
            
            HStack(spacing: 4) {
                Circle().fill(Color.white).frame(width: 6, height: 6).offset(y: wave ? -3 : 3)
                Circle().fill(Color.white).frame(width: 6, height: 6).offset(y: wave ? 3 : -3)
                Circle().fill(Color.white).frame(width: 6, height: 6).offset(y: wave ? -3 : 3)
            }
            .offset(y: -5)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                wave = true
            }
        }
    }
}

struct MockWatchView: View {
    @State private var drawRing: CGFloat = 0.0
    @State private var showText = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.black.opacity(0.6))
                .frame(width: 60, height: 80)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.3), lineWidth: 2))
            
            Circle()
                .stroke(Color.green.opacity(0.2), lineWidth: 4)
                .frame(width: 34, height: 34)

            Circle()
                .trim(from: 0, to: drawRing)
                .stroke(Color.green, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: 34, height: 34)
                .rotationEffect(.degrees(-90))
            
            Text("142")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .opacity(showText ? 1 : 0)
                .scaleEffect(showText ? 1 : 0.5)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2)) {
                drawRing = 0.8
            }
            withAnimation(.spring().delay(0.5)) {
                showText = true
            }
        }
    }
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
    @AppStorage("userGoal") private var userGoal = ""

    private let stepCount = 6

    var body: some View {
        ZStack {
            OnboardingBackground()

            VStack(spacing: 0) {
                StepProgressBar(current: currentTab, total: stepCount)
                    .padding(.horizontal, 30)
                    .padding(.top, 12)

                TabView(selection: $currentTab) {
                    OnboardingIntroView(onNext: { _ in nextStep() }).tag(0)
                    UserDataInputView(name: $userName, weight: $userBodyWeight, goal: $userGoal, onNext: nextStep).tag(1)
                    PermissionsView(onNext: nextStep).tag(2)
                    HealthPermissionsView(onNext: nextStep).tag(3)
                    TutorialChoiceView(onFinish: nextStep).tag(4)
                    AnalyzingView(onFinish: completeOnboarding).tag(5)
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
    var onNext: (Int?) -> Void
    @Environment(ThemeManager.self) private var themeManager
    @AppStorage("userName") private var userName = ""
    @State private var slideIndex: Int? = 0
    @State private var slideProgress: CGFloat = 0.0
    @State private var backgroundPulse: CGFloat = 1.0
    @State private var savedTargetTab: Int? = nil
    
    let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    private let slideDuration: CGFloat = 4.0

    private var items: [OnboardingItem] {
        let namePrefix = userName.isEmpty ? "" : "\(userName), "
        let namePrefixCap = userName.isEmpty ? "" : "\(userName), "
        
        return [
            OnboardingItem(graphic: .appleHealth,
                           title: LocalizedStringKey("Works with Apple Health"),
                           description: LocalizedStringKey("Using Workout Tracker with the Apple Health app on iPhone empowers you to better manage your health and track your progress in one place."),
                           colors: [Color.pink, Color.red.opacity(0.8)],
                           targetTab: nil),
            OnboardingItem(graphic: .aiCamera,
                           title: "AI Camera Coach",
                           description: "\(namePrefix)a flawless eye on your form. Real-time tracking and rep counting that ensures you never cheat a set.",
                           colors: [.purple, .blue], targetTab: 3),
            OnboardingItem(graphic: .smartBuilder,
                           title: "Smart Builder",
                           description: "Zero guesswork. Tell the AI what equipment you have, and it crafts the ultimate workout tailored just for you.",
                           colors: [.blue, .cyan], targetTab: 2),
            OnboardingItem(graphic: .anatomyHeatmap,
                           title: "Unlock Your Anatomy",
                           description: "Visualize your recovery. See exactly which muscles are ready to perform and which ones need rest on a dynamic heatmap.",
                           colors: [.red, .orange], targetTab: 4),
            OnboardingItem(graphic: .analyticsChart,
                           title: "Deep Analytics",
                           description: "Your body, decoded. Advanced charts reveal exactly what’s working and what’s next.",
                           colors: [.cyan, .green], targetTab: 4),
            OnboardingItem(graphic: .aiChatbot,
                           title: "24/7 AI Architect",
                           description: "Not sure what to do? Chat with the AI Coach anytime to generate multi-week programs or adjust your routine.",
                           colors: [.indigo, .purple], targetTab: 3),
            OnboardingItem(graphic: .watchMock,
                           title: "Watch Integration",
                           description: "Leave your phone in the locker. Full, seamless workout tracking right from your wrist.",
                           colors: [.green, .yellow], targetTab: 0)
        ]
    }

    private var isLastSlide: Bool { (slideIndex ?? 0) == items.count - 1 }

    var body: some View {
        ZStack {
            // Dynamic Background Glow
            GeometryReader { geo in
                let currentIndex = slideIndex ?? 0
                Circle()
                    .fill(items[currentIndex].colors[0].opacity(0.15))
                    .frame(width: geo.size.width * 1.2, height: geo.size.width * 1.2)
                    .blur(radius: 80)
                    .scaleEffect(backgroundPulse)
                    .offset(x: -geo.size.width * 0.1, y: geo.size.height * 0.1)
                    .animation(.easeInOut(duration: 0.8), value: currentIndex)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                            backgroundPulse = 1.15
                        }
                    }
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 0) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            PremiumFeatureCard(
                                item: item, 
                                isSelected: (slideIndex ?? 0) == index,
                                isSaved: savedTargetTab == item.targetTab
                            ) {
                                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                                savedTargetTab = item.targetTab
                            }
                            .id(index)
                            .containerRelativeFrame(.horizontal)
                            .scrollTransition(axis: .horizontal) { content, phase in
                                content
                                    .rotation3DEffect(.degrees(phase.value * -15), axis: (x: 0, y: 1, z: 0))
                                    .scaleEffect(phase.isIdentity ? 1.0 : 0.85)
                                    .opacity(phase.isIdentity ? 1.0 : 0.5)
                            }
                        }
                    }
                }
                .scrollTargetBehavior(.paging)
                .scrollPosition(id: $slideIndex)
                .onChange(of: slideIndex) { _, _ in
                    UISelectionFeedbackGenerator().selectionChanged()
                    slideProgress = 0.0
                }

                OnboardingStoryProgressBar(current: slideIndex ?? 0, total: items.count, progress: slideProgress, tint: themeManager.current.primaryAccent)
                    .padding(.bottom, 24)
                    .padding(.horizontal, 30)

                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    if isLastSlide { onNext(savedTargetTab) }
                    else { withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { slideIndex = (slideIndex ?? 0) + 1 } }
                } label: {
                    Text(isLastSlide ? "Let's Go!" : "Next")
                }
                .buttonStyle(OnboardingPrimaryButtonStyle())
                .padding(.horizontal, 30)
                .padding(.bottom, 40)
            }
            .overlay(alignment: .topTrailing) {
                Button("Skip") {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onNext(savedTargetTab)
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
                .padding()
                .padding(.top, 40)
            }
            .onReceive(timer) { _ in
                if slideProgress < 1.0 {
                    slideProgress += 0.05 / slideDuration
                } else {
                    if !isLastSlide {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                            slideIndex = (slideIndex ?? 0) + 1
                            slideProgress = 0.0
                        }
                    } else {
                        slideProgress = 1.0
                    }
                }
            }
        }
    }
}

struct PremiumFeatureCard: View {
    let item: OnboardingItem
    let isSelected: Bool
    let isSaved: Bool
    let onTryNow: () -> Void
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 28) {
                // Glowing Icon
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: item.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 140, height: 140)
                        .shadow(color: item.colors[0].opacity(0.5), radius: 25, y: 15)
                    
                    switch item.graphic {
                    case .aiCamera:
                        MockAICameraView()
                    case .smartBuilder:
                        MockSmartBuilderView()
                    case .analyticsChart:
                        MockAnalyticsChartView(colors: item.colors)
                    case .watchMock:
                        MockWatchView()
                    case .anatomyHeatmap:
                        MockAnatomyHeatmapView()
                    case .aiChatbot:
                        MockAIChatbotView()
                    case .appleHealth:
                        MockAppleHealthView()
                    }
                }
                .scaleEffect(isSelected ? 1.0 : 0.85)
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: isSelected)
                .padding(.bottom, 10)

                VStack(spacing: 24) {
                    Text(item.title)
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(themeManager.current.primaryText)
                        .multilineTextAlignment(.center)
                        
                    Text(item.description)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(themeManager.current.secondaryText)
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                        .padding(.horizontal, 24)

                    Button(action: {
                        if !isSaved { onTryNow() }
                    }) {
                        HStack(spacing: 8) {
                            if isSaved {
                                Image(systemName: "checkmark")
                            }
                            Text(isSaved ? "Saved!" : "Try it now")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                            .background(
                                LinearGradient(colors: item.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .clipShape(Capsule())
                            .shadow(color: item.colors[0].opacity(0.4), radius: 8, y: 4)
                    }
                    .padding(.top, 8)
                }
            }
            .padding(.vertical, 40)
            .frame(maxWidth: .infinity)
            .background {
                // Glassmorphic Card Background
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(themeManager.current.surface.opacity(0.6))
                    .background(
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .stroke(LinearGradient(colors: [
                                .white.opacity(0.4),
                                .white.opacity(0.0)
                            ], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
                    )
                    .shadow(color: Color.black.opacity(0.15), radius: 30, y: 15)
            }
            .padding(.horizontal, 24)
            .scaleEffect(isSelected ? 1.0 : 0.9)
            .opacity(isSelected ? 1.0 : 0.6)
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isSelected)

            Spacer()
        }
    }
}

// MARK: - Step 2: User Data

struct UserDataInputView: View {
    @Binding var name: String
    @Binding var weight: Double
    @Binding var goal: String
    var onNext: () -> Void
    @Environment(ThemeManager.self) private var themeManager

    private let goals = ["Build Muscle", "Lose Fat", "Get Fit", "Strength"]

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

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Main Goal")
                                .font(.caption)
                                .foregroundStyle(themeManager.current.secondaryText)
                            
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                ForEach(goals, id: \.self) { g in
                                    Button(action: { UIImpactFeedbackGenerator(style: .light).impactOccurred(); goal = g }) {
                                        Text(g)
                                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                                            .foregroundStyle(goal == g ? .white : themeManager.current.primaryText)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 14)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(goal == g ? themeManager.current.primaryAccent : themeManager.current.surface)
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .strokeBorder(goal == g ? .clear : themeManager.current.secondaryAccent.opacity(0.3), lineWidth: 1)
                                            )
                                    }
                                }
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
            
            // Live Activity Mockup
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "timer")
                        .foregroundColor(.orange)
                        .font(.system(size: 14, weight: .bold))
                    Text("Rest Timer")
                        .font(.caption.bold())
                        .foregroundColor(.white.opacity(0.8))
                    Spacer()
                    Text("01:30")
                        .font(.system(.subheadline, design: .monospaced).bold())
                        .foregroundColor(.orange)
                }
                Text("Next: Bench Press")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
            }
            .padding()
            .background(Color.black.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(.white.opacity(0.15), lineWidth: 1))
            .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
            .padding(.horizontal, 40)
            .rotation3DEffect(.degrees(10), axis: (x: 1, y: 0, z: 0))

            VStack(spacing: 12) {
                Text("Stay on Track")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(themeManager.current.primaryText)
                Text("Enable notifications to track rest times directly from your Lock Screen or Dynamic Island.")
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

// MARK: - Step 3.5: Health Integration

struct HealthPermissionsView: View {
    var onNext: () -> Void
    @Environment(ThemeManager.self) private var themeManager
    @State private var healthAllowed = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            
            // Activity Rings Mockup
            ZStack {
                Circle()
                    .stroke(Color.red.opacity(0.2), lineWidth: 16)
                    .frame(width: 160, height: 160)
                Circle()
                    .trim(from: 0, to: 0.75)
                    .stroke(Color.red, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90))
                    
                Circle()
                    .stroke(Color.green.opacity(0.2), lineWidth: 16)
                    .frame(width: 124, height: 124)
                Circle()
                    .trim(from: 0, to: 0.5)
                    .stroke(Color.green, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                    .frame(width: 124, height: 124)
                    .rotationEffect(.degrees(-90))
                    
                Circle()
                    .stroke(Color.blue.opacity(0.2), lineWidth: 16)
                    .frame(width: 88, height: 88)
                Circle()
                    .trim(from: 0, to: 0.9)
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                    .frame(width: 88, height: 88)
                    .rotationEffect(.degrees(-90))
            }
            .shadow(color: .black.opacity(0.4), radius: 20, y: 10)
            .padding(.bottom, 20)

            VStack(spacing: 12) {
                Text("Close Your Rings")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(themeManager.current.primaryText)
                Text("Sync your workouts directly to Apple Health to track active calories and earn your daily goals.")
                    .font(.system(size: 16, design: .rounded))
                    .foregroundStyle(themeManager.current.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button { requestHealth() } label: {
                HStack(spacing: 8) {
                    Text(healthAllowed ? "Connected" : "Connect Apple Health")
                    if healthAllowed { Image(systemName: "checkmark") }
                }
            }
            .buttonStyle(OnboardingPrimaryButtonStyle(fill: healthAllowed ? .green : Color.red))
            .disabled(healthAllowed)
            .padding(.horizontal, 50)
            .padding(.top, 8)

            Spacer()

            Button("Continue", action: onNext)
                .buttonStyle(OnboardingPrimaryButtonStyle())
                .padding(.horizontal, 30)
                .padding(.bottom, 40)
        }
    }

    private func requestHealth() {
        Task {
            do {
                try await HealthKitManager.shared.requestAuthorization()
                await MainActor.run {
                    withAnimation { self.healthAllowed = true }
                }
            } catch {
                print("HealthKit authorization failed: \(error)")
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

// MARK: - Step 5: Analyzing

struct AnalyzingView: View {
    var onFinish: () -> Void
    @Environment(ThemeManager.self) private var themeManager
    @State private var messageIndex = 0
    private let messages = [
        "Analyzing your goals...",
        "Setting up AI Coach...",
        "Preparing algorithms...",
        "Ready to crush it!"
    ]

    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            ZStack {
                Circle()
                    .strokeBorder(themeManager.current.primaryAccent.opacity(0.3), lineWidth: 4)
                    .frame(width: 100, height: 100)
                
                Circle()
                    .trim(from: 0, to: 0.8)
                    .stroke(themeManager.current.primaryAccent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 100, height: 100)
                    .rotationEffect(Angle(degrees: messageIndex > 0 ? 360 * Double(messageIndex) : 0))
                    .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: messageIndex)
                    
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 40))
                    .foregroundStyle(themeManager.current.primaryAccent)
            }
            .scaleEffect(messageIndex == messages.count - 1 ? 1.2 : 1.0)
            .animation(.spring, value: messageIndex)

            Text(messages[min(messageIndex, messages.count - 1)])
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(themeManager.current.primaryText)
                .contentTransition(.numericText())
                .animation(.easeInOut, value: messageIndex)
            
            Spacer()
        }
        .onAppear {
            runSequence()
        }
    }
    
    private func runSequence() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        for i in 1..<messages.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.8) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                messageIndex = i
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(messages.count) * 0.8) {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            onFinish()
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

struct OnboardingStoryProgressBar: View {
    let current: Int
    let total: Int
    let progress: CGFloat
    var tint: Color

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { i in
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.gray.opacity(0.3))
                        
                        Capsule()
                            .fill(tint)
                            .frame(width: calculateWidth(geoWidth: geo.size.width, index: i))
                    }
                }
                .frame(height: 4)
            }
        }
    }
    
    private func calculateWidth(geoWidth: CGFloat, index: Int) -> CGFloat {
        if index < current {
            return geoWidth
        } else if index == current {
            return geoWidth * progress
        } else {
            return 0
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
