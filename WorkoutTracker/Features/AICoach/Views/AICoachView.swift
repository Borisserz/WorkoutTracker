

internal import SwiftUI
import SwiftData

struct CoachSheetItem: Identifiable {
    let id: String
}

struct MuscleStats: Identifiable {
    let id = UUID()
    let name: String
    let currentShare: Double; let pastShare: Double
    let color: Color
}

struct AICoachView: View {
    @Environment(DIContainer.self) private var di
    @Environment(AICoachViewModel.self) private var viewModel
    @Environment(UserStatsViewModel.self) private var userStatsViewModel
    @Environment(\.colorScheme) private var colorScheme 
    @State private var actualHRV: Double? = nil
    @State private var actualRHR: Double? = nil
    
    @AppStorage("hasSeenAICoachTooltip") private var hasSeenTooltip = false
    @State private var showTooltip = false
    @State private var showChatView = false
    @State private var showProgressSheet = false
    @State private var showRestSheet = false
    @State private var showAISettings = false
    @AppStorage(Constants.UserDefaultsKeys.hasConsentedToAI.rawValue)
    private var hasConsentedToAI = false
    @State private var showConsentSheet = false
    @State private var pendingAIAction: (() -> Void)? = nil

    @State private var isBreathing = false
    @State private var isLevitating = false
    @State private var userQuery: String = ""

    @State private var readinessValue: CGFloat = 0.0
    @State private var sphereDragOffset: CGSize = .zero
    @State private var shimmerOffset: CGFloat = -1.0

    @AppStorage("cnsScore") private var cnsScore: Double = Constants.CNS.unmeasuredAppStorageDefault
    @AppStorage("sleepHours") private var sleepHours: Double = 7.5
    @AppStorage("hasSleepData") private var hasSleepData = false
    @AppStorage(Constants.UserDefaultsKeys.userName.rawValue) private var userName = ""

    @State private var speechRecognizer = SpeechRecognizer()

    struct QuickPromptItem: Identifiable, Hashable {
        let id = UUID()
        let icon: String
        let text: String
    }

    /// Catalog-facing prompt labels — no fake in-app nutrition product.
    static let defaultQuickPromptTexts = [
        "What should I train today?",
        "Check readiness",
        "Warm-up before training",
        "How do I break a plateau?",
        "Post-workout recovery tips"
    ]

    let quickPrompts = [
        QuickPromptItem(icon: "dumbbell.fill", text: Self.defaultQuickPromptTexts[0]),
        QuickPromptItem(icon: "bolt.heart.fill", text: Self.defaultQuickPromptTexts[1]),
        QuickPromptItem(icon: "flame.fill", text: Self.defaultQuickPromptTexts[2]),
        QuickPromptItem(icon: "chart.line.uptrend.xyaxis", text: Self.defaultQuickPromptTexts[3]),
        QuickPromptItem(icon: "bed.double.fill", text: Self.defaultQuickPromptTexts[4])
    ]

    // AI Hub states
    @State private var path = NavigationPath()
    @State private var showSmartBuilder = false
    @State private var showAIBuilder = false
    @State private var showAICameraSelector = false
    @State private var showGlobalAICamera = false
    @State private var selectedAIExercise: String = "Squats"

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 6..<12: return "Good morning"
        case 12..<18: return "Good afternoon"
        case 18..<24: return "Good evening"
        default: return "Recovery time"
        }
    }
    private func requireAIConsent(_ action: @escaping () -> Void) {
        if hasConsentedToAI {
            action()
        } else {
            pendingAIAction = action
            showConsentSheet = true
        }
    }
    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                Color.clear.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        
                        // 1. Header Section
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 8) {
                                    Text("AI Hub")
                                        .font(.system(size: 32, weight: .bold, design: .rounded))
                                        .foregroundStyle(PastelTheme.textPrimary)
                                }

                                Text("Biomechanics and CNS readiness")
                                    .font(.caption)
                                    .foregroundStyle(PastelTheme.textSecondary)
                            }

                            Spacer()

                            Button {
                                HapticManager.shared.impact(.light)
                                showAISettings = true
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(PastelTheme.cardSurfaceSubtle)
                                        .frame(width: 40, height: 40)
                                        .overlay(Circle().stroke(PastelTheme.cardBorder, lineWidth: 1))

                                    Image(systemName: "slider.horizontal.3")
                                        .font(.system(size: 15))
                                        .foregroundStyle(PastelTheme.textPrimary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 10)

                        // 1. Block: Live Coach Dialog (Supreme Hero Feature)
                        SectionHeaderView(
                            title: "Coach chat",
                            icon: "bubble.left.and.bubble.right.fill",
                            accentColor: PastelTheme.pastelLavender
                        )

                        InteractiveCoachDialogCard(
                            score: cnsScore,
                            quickPrompts: quickPrompts,
                            isListening: Binding(get: { speechRecognizer.isRecording }, set: { _ in }),
                            textTranscript: $speechRecognizer.transcript,
                            userQuery: $userQuery,
                            onSelectPrompt: { prompt in
                                requireAIConsent {
                                    viewModel.inputText = prompt
                                    showChatView = true
                                }
                            },
                            onMicTap: {
                                HapticManager.shared.impact(.medium)
                                if speechRecognizer.isRecording {
                                    speechRecognizer.stopTranscribing()
                                    if !speechRecognizer.transcript.isEmpty {
                                        let text = speechRecognizer.transcript
                                        speechRecognizer.transcript = ""
                                        requireAIConsent {
                                            viewModel.inputText = text
                                            showChatView = true
                                        }
                                    }
                                } else {
                                    speechRecognizer.startTranscribing()
                                }
                            },
                            onSubmitQuery: {
                                if !userQuery.isEmpty {
                                    let text = userQuery
                                    userQuery = ""
                                    requireAIConsent {
                                        viewModel.inputText = text
                                        showChatView = true
                                    }
                                }
                            }
                        )
                        .padding(.horizontal, 16)

                        // 3. Block: Workout Tools
                        SectionHeaderView(
                            title: "Training tools",
                            icon: "figure.strengthtraining.traditional",
                            accentColor: PastelTheme.pastelSlate
                        )

                        // Hero Tile: AI Vision Camera
                        Button {
                            HapticManager.shared.impact(.medium)
                            showAICameraSelector = true
                        } label: {
                            HStack(spacing: 14) {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(PastelTheme.pastelLavender)
                                            .frame(width: 6, height: 6)
                                        Text("Computer vision")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(PastelTheme.pastelLavender)
                                    }

                                    Text("AI Camera and form tracking")
                                        .font(.system(size: 17, weight: .bold, design: .rounded))
                                        .foregroundStyle(PastelTheme.textPrimary)

                                    Text("On-device pose tracking and rep counting in real time")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(PastelTheme.textSecondary)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                }

                                Spacer(minLength: 8)

                                ZStack {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(PastelTheme.cardSurfaceSubtle)
                                        .frame(width: 54, height: 54)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .stroke(PastelTheme.pastelLavender.opacity(0.3), lineWidth: 1)
                                        )

                                    Image(systemName: "camera.viewfinder")
                                        .font(.system(size: 26, weight: .medium))
                                        .foregroundStyle(PastelTheme.pastelLavender)
                                }
                            }
                            .padding(16)
                            .background(PastelTheme.cardSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(PastelTheme.cardBorder, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)

                        // Split Row (50/50): Daily Session + Recovery
                        HStack(spacing: 12) {
                            Button {
                                HapticManager.shared.impact(.medium)
                                showSmartBuilder = true
                            } label: {
                                PastelBentoCard(
                                    title: "Session of the day",
                                    subtitle: "Built around muscle readiness",
                                    iconName: "wand.and.stars",
                                    accentColor: PastelTheme.pastelSage
                                )
                            }
                            .buttonStyle(.plain)

                            Button {
                                HapticManager.shared.impact(.medium)
                                showRestSheet = true
                            } label: {
                                PastelBentoCard(
                                    title: "Recovery",
                                    subtitle: "Fatigue and sleep check",
                                    iconName: "moon.stars.fill",
                                    accentColor: PastelTheme.pastelAmber
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 16)

                        // 4. Block: Strategy & Progress
                        SectionHeaderView(
                            title: "Strategy and progress",
                            icon: "chart.line.uptrend.xyaxis",
                            accentColor: PastelTheme.pastelOat
                        )

                        // Split Row (50/50): Program Architect + Progress Analytics
                        HStack(spacing: 12) {
                            Button {
                                HapticManager.shared.impact(.medium)
                                showAIBuilder = true
                            } label: {
                                PastelBentoCard(
                                    title: "Season plan",
                                    subtitle: "Periodization and progression",
                                    iconName: "calendar.badge.plus",
                                    accentColor: PastelTheme.pastelOat
                                )
                            }
                            .buttonStyle(.plain)

                            Button {
                                HapticManager.shared.impact(.medium)
                                requireAIConsent { showProgressSheet = true }
                            } label: {
                                PastelBentoCard(
                                    title: "Weekly analytics",
                                    subtitle: "Biometrics and weight trends",
                                    iconName: "chart.xyaxis.line",
                                    accentColor: PastelTheme.pastelSage
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 30)
                    }
                }
            }
            .navigationBarHidden(true)
            .dynamicTypeSize(.medium ... .accessibility1)
            .onAppear {
                TrackingManager.shared.track(.aiCoachOpened(source: "tab"))
                speechRecognizer.requestPermission()

                withAnimation(.easeOut(duration: 2.5).delay(0.5)) {
                    readinessValue = cnsScore < 0 ? 0 : cnsScore / 100
                }
                withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) { isBreathing = true }
                withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) { isLevitating = true }
                withAnimation(.linear(duration: 2.5).repeatForever(autoreverses: false)) { shimmerOffset = 2.0 }
            }
            .sheet(isPresented: $showRestSheet) { RestAnalysisSheet().presentationDetents([.large]).presentationCornerRadius(35).presentationDragIndicator(.visible) }
            .sheet(isPresented: $showProgressSheet) { ProgressAnalysisSheet().presentationDetents([.large]).presentationCornerRadius(35).presentationDragIndicator(.visible) }
            .sheet(isPresented: Binding(
                get: { showAISettings || di.appState.showAISettingsSheet },
                set: { newVal in
                    showAISettings = newVal
                    di.appState.showAISettingsSheet = newVal
                }
            )) { AISettingsSheet().presentationDetents([.medium, .large]).presentationDragIndicator(.visible) }
            .sheet(isPresented: $showConsentSheet) {
                AIConsentSheet(onConsent: {
                    let action = pendingAIAction
                    pendingAIAction = nil
                    action?()
                })
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .fullScreenCover(isPresented: $showChatView) { AIChatBotView(viewModel: viewModel) }
            .sheet(isPresented: $showAIBuilder) {
                AIProgramBuilderSheet(aiLogicService: di.aiLogicService)
            }
            .sheet(isPresented: $showAICameraSelector) {
                AICameraExerciseSelectorSheet { selected in
                    selectedAIExercise = selected
                    showGlobalAICamera = true
                }
            }
            .fullScreenCover(isPresented: $showGlobalAICamera) {
                AITrackerView(exerciseName: selectedAIExercise) { _ in
                    // Freestyle mode: just dismiss
                }
            }
            .sheet(isPresented: Binding(
                get: { showSmartBuilder || di.appState.showSmartBuilderSheet },
                set: { newVal in
                    showSmartBuilder = newVal
                    di.appState.showSmartBuilderSheet = newVal
                }
            )) {
                SmartGeneratorEntryView(onWorkoutReady: { exerciseDTOs in
                    Task { @MainActor in
                        let generatedDTO = GeneratedWorkoutDTO(
                            title: "Smart Workout",
                            aiMessage: "Generated by Smart Workout",
                            exercises: exerciseDTOs.map { dto in
                                let safeSetsList = dto.setsList ?? []
                                return GeneratedExerciseDTO(
                                    name: dto.name, muscleGroup: dto.muscleGroup, type: dto.type.rawValue,
                                    sets: safeSetsList.count, reps: safeSetsList.first?.reps ?? 10,
                                    recommendedWeightKg: safeSetsList.first?.weight, restSeconds: nil
                                )
                            }
                        )
                        guard let id = await di.workoutService.startGeneratedWorkout(generatedDTO),
                              let newWorkout = di.analyticsService.modelContainer.mainContext.model(for: id) as? Workout else {
                            return
                        }
                        path.append(newWorkout)
                    }
                })
            }
            .navigationDestination(for: Workout.self) { workout in
                WorkoutDetailView(workout: workout, viewModel: di.makeWorkoutDetailViewModel())
                    .environment(di)
            }
        }
    }
}

// MARK: - Apple HIG & PastelTheme UI Components

struct PastelBentoCard: View {
    let title: String
    let subtitle: String?
    let iconName: String
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.14))
                        .frame(width: 40, height: 40)
                        .overlay(Circle().stroke(accentColor.opacity(0.35), lineWidth: 1))

                    Image(systemName: iconName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(accentColor)
                }
                Spacer()
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(PastelTheme.textPrimary)

                if let sub = subtitle {
                    Text(sub)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(PastelTheme.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
        .background(PastelTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(PastelTheme.cardBorder, lineWidth: 1)
        )
    }
}

struct PastelReadinessCard: View {
    let score: Double
    let hrv: Double?
    let rhr: Double?
    let sleep: Double
    let hasSleep: Bool

    private var scoreColor: Color {
        if score < 0 { return PastelTheme.textSecondary }
        if score >= 80 { return PastelTheme.pastelSage }
        if score >= 50 { return PastelTheme.pastelAmber }
        return PastelTheme.pastelPeach
    }

    private var adviceText: String {
        if score < 0 {
            return String(localized: "Readiness not measured")
        }
        if score >= 80 {
            return "CNS fully recovered. Great day for high-intensity compound lifts."
        } else if score >= 50 {
            return "Moderate load. Work at 70–80% of your max with a focus on clean form."
        } else {
            return "High CNS fatigue. Prefer a deload day, light cardio, or mobility work."
        }
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                // Circular Ring in Apple Watch Activity style
                ZStack {
                    Circle()
                        .stroke(PastelTheme.cardBorder, lineWidth: 5)
                        .frame(width: 58, height: 58)

                    Circle()
                        .trim(from: 0, to: CGFloat(min(max(score / 100.0, 0.0), 1.0)))
                        .stroke(scoreColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .frame(width: 58, height: 58)
                        .rotationEffect(.degrees(-90))

                    Text("\(Int(score))")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(PastelTheme.textPrimary)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(scoreColor)
                            .frame(width: 6, height: 6)

                        Text("CNS Readiness")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(PastelTheme.textSecondary)
                    }

                    Text(CNSCalculator.getStatus(for: score).text)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(PastelTheme.textPrimary)
                }

                Spacer()
            }

            Divider()
                .background(PastelTheme.separator)

            // Micro-metrics row
            HStack {
                PastelMetricItem(title: "HRV", value: hrv != nil ? "\(Int(hrv!))" : "--", unit: "ms", color: PastelTheme.pastelSlate)
                Spacer()
                PastelMetricItem(title: "Resting HR", value: rhr != nil ? "\(Int(rhr!))" : "--", unit: "bpm", color: PastelTheme.pastelLavender)
                Spacer()
                PastelMetricItem(title: "Sleep", value: hasSleep ? String(format: "%.1f", sleep) : "--", unit: "h", color: PastelTheme.pastelAmber)
            }

            // Actionable 1-sentence verdict
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundStyle(scoreColor)
                    .padding(.top, 1)

                Text(adviceText)
                    .font(.caption)
                    .foregroundStyle(PastelTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(PastelTheme.cardSurfaceSubtle)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(PastelTheme.cardBorder, lineWidth: 1)
            )
        }
        .padding(16)
        .background(PastelTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(PastelTheme.cardBorder, lineWidth: 1)
        )
    }
}

struct PastelMetricItem: View {
    let title: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(PastelTheme.textTertiary)

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(PastelTheme.textPrimary)

                Text(unit)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(color)
            }
        }
    }
}

struct SectionHeaderView: View {
    let title: String
    let icon: String
    var accentColor: Color = PastelTheme.pastelOat

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(accentColor)

            Text(title)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(PastelTheme.textPrimary)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 2)
    }
}

struct InteractiveCoachDialogCard: View {
    let score: Double
    let quickPrompts: [AICoachView.QuickPromptItem]
    @Binding var isListening: Bool
    @Binding var textTranscript: String
    @Binding var userQuery: String
    let onSelectPrompt: (String) -> Void
    let onMicTap: () -> Void
    let onSubmitQuery: () -> Void

    private var coachGreeting: String {
        CNSCalculator.coachGreeting(for: score)
    }

    private var coachStatusBadge: some View {
        let listening = isListening
        let unmeasured = score < 0
        let label: String = {
            if listening { return String(localized: "Listening") }
            if unmeasured { return String(localized: "Standby") }
            return String(localized: "Ready")
        }()
        let color: Color = {
            if listening { return PastelTheme.pastelAmber }
            if unmeasured { return PastelTheme.textTertiary }
            return PastelTheme.pastelSage
        }()
        return HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Coach Persona Header
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(PastelTheme.cardSurfaceSubtle)
                        .frame(width: 44, height: 44)
                        .overlay(Circle().stroke(PastelTheme.cardBorder, lineWidth: 1))

                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(PastelTheme.pastelLavender)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("AI Coach")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(PastelTheme.textPrimary)

                    Text("Personal coach, available anytime")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(PastelTheme.textSecondary)
                }

                Spacer()

                coachStatusBadge
            }

            // Direct Speech Bubble
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "quote.bubble.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(PastelTheme.pastelLavender)
                    .padding(.top, 2)

                Text(coachGreeting)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(PastelTheme.textPrimary)
                    .lineSpacing(3)
                    .multilineTextAlignment(.leading)
            }
            .padding(12)
            .background(PastelTheme.cardSurfaceSubtle)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(PastelTheme.cardBorder, lineWidth: 1)
            )

            // Quick Prompt Pills
            if !isListening {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(quickPrompts) { item in
                            Button {
                                HapticManager.shared.selection()
                                onSelectPrompt(item.text)
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: item.icon)
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(PastelTheme.pastelLavender)

                                    Text(item.text)
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundStyle(PastelTheme.textSecondary)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(PastelTheme.cardSurfaceSubtle)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule().stroke(PastelTheme.cardBorder, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            // Input Bar (Voice Dictation & Text)
            HStack(spacing: 10) {
                // Voice Dictation
                Button(action: onMicTap) {
                    ZStack {
                        Circle()
                            .fill(isListening ? PastelTheme.pastelPeach : PastelTheme.pastelOat)
                            .frame(width: 38, height: 38)
                            .overlay(Circle().stroke(PastelTheme.cardBorderFocused, lineWidth: 1))

                        Image(systemName: isListening ? "stop.fill" : "mic.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(PastelTheme.textOnOat)
                    }
                }
                .buttonStyle(.plain)

                // Text field row
                HStack(spacing: 8) {
                    Image(systemName: "bubble.left")
                        .font(.system(size: 13))
                        .foregroundStyle(PastelTheme.textTertiary)

                    TextField(isListening ? (textTranscript.isEmpty ? "Listening…" : textTranscript) : "Ask the coach about your workout…", text: $userQuery)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(PastelTheme.textPrimary)
                        .submitLabel(.send)
                        .onSubmit(onSubmitQuery)

                    if isListening {
                        SiriWaveformView()
                    } else if !userQuery.isEmpty {
                        Button(action: onSubmitQuery) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(PastelTheme.pastelOat)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(PastelTheme.cardSurfaceSubtle)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(PastelTheme.cardBorder, lineWidth: 1)
                )
            }
        }
        .padding(16)
        .background(PastelTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(PastelTheme.cardBorder, lineWidth: 1)
        )
    }
}

struct PastelAssistantCard: View {
    @Binding var isListening: Bool
    @Binding var textTranscript: String
    @Binding var userQuery: String
    let onMicTap: () -> Void
    let onSubmitQuery: () -> Void

    var body: some View {
        InteractiveCoachDialogCard(
            score: 85,
            quickPrompts: [],
            isListening: $isListening,
            textTranscript: $textTranscript,
            userQuery: $userQuery,
            onSelectPrompt: { _ in },
            onMicTap: onMicTap,
            onSubmitQuery: onSubmitQuery
        )
    }
}

struct SiriWaveformView: View {
    @State private var phase: CGFloat = 0.0

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<6) { index in
                WaveBar(index: index, phase: phase)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                phase = 1.0
            }
        }
    }
}

struct WaveBar: View {
    let index: Int
    let phase: CGFloat

    var height: CGFloat {
        let baseHeights: [CGFloat] = [6, 16, 24, 18, 10, 5]
        let variation: CGFloat = 8
        let value = baseHeights[index % baseHeights.count]
        return phase == 0.0 ? value : max(4, value + (index % 2 == 0 ? variation : -variation))
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 1.5)
            .fill(PastelTheme.pastelLavender)
            .frame(width: 3, height: height)
    }
}

struct AISettingsSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(AICoachViewModel.self) private var viewModel

    @AppStorage(Constants.UserDefaultsKeys.aiCoachTone.rawValue) private var aiTone = "motivational"
    @State private var availablePersonas: [AIPersona] = []

    var body: some View {
        NavigationStack {
            ZStack {
                PastelTheme.canvas.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header Banner
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(PastelTheme.cardSurfaceSubtle)
                                    .frame(width: 44, height: 44)
                                    .overlay(Circle().stroke(PastelTheme.cardBorder, lineWidth: 1))

                                Image(systemName: "slider.horizontal.3")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(PastelTheme.pastelLavender)
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                Text("Coach style")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundStyle(PastelTheme.textPrimary)

                                Text("Sets tone, focus, and how advice is delivered")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(PastelTheme.textSecondary)
                                    .lineLimit(2)
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(PastelTheme.cardSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(PastelTheme.cardBorder, lineWidth: 1)
                        )

                        // Personas List
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Choose persona")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(PastelTheme.textSecondary)
                                .padding(.horizontal, 4)

                            if availablePersonas.isEmpty {
                                HStack {
                                    Spacer()
                                    ProgressView("Loading profiles…")
                                        .tint(PastelTheme.pastelOat)
                                        .foregroundStyle(PastelTheme.textSecondary)
                                    Spacer()
                                }
                                .padding(.vertical, 24)
                            } else {
                                ForEach(availablePersonas) { persona in
                                    let isSelected = (aiTone == persona.id)
                                    Button {
                                        HapticManager.shared.selection()
                                        aiTone = persona.id
                                    } label: {
                                        HStack(spacing: 14) {
                                            ZStack {
                                                Circle()
                                                    .fill(isSelected ? PastelTheme.pastelLavender.opacity(0.18) : PastelTheme.cardSurfaceSubtle)
                                                    .frame(width: 38, height: 38)
                                                    .overlay(
                                                        Circle().stroke(isSelected ? PastelTheme.pastelLavender : PastelTheme.cardBorder, lineWidth: 1)
                                                    )

                                                Image(systemName: isSelected ? "checkmark" : "brain.head.profile")
                                                    .font(.system(size: 14, weight: .bold))
                                                    .foregroundStyle(isSelected ? PastelTheme.pastelLavender : PastelTheme.textTertiary)
                                            }

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(persona.displayName)
                                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                                    .foregroundStyle(isSelected ? PastelTheme.textPrimary : PastelTheme.textSecondary)

                                                Text(isSelected ? "Active coaching style" : "Tap to switch")
                                                    .font(.system(size: 11, weight: .medium))
                                                    .foregroundStyle(PastelTheme.textTertiary)
                                            }

                                            Spacer()

                                            if isSelected {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(.system(size: 18))
                                                    .foregroundStyle(PastelTheme.pastelLavender)
                                            }
                                        }
                                        .padding(14)
                                        .background(isSelected ? PastelTheme.cardSurface : PastelTheme.cardSurfaceSubtle)
                                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .stroke(isSelected ? PastelTheme.cardBorderFocused : PastelTheme.cardBorder, lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        // Danger Zone: Clear History
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Chat memory")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(PastelTheme.textSecondary)
                                .padding(.horizontal, 4)

                            Button {
                                HapticManager.shared.notification(.warning)
                                viewModel.clearChat()
                                dismiss()
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(PastelTheme.pastelPeach)

                                    Text("Clear chat history")
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        .foregroundStyle(PastelTheme.pastelPeach)

                                    Spacer()
                                }
                                .padding(14)
                                .frame(height: 48)
                                .background(PastelTheme.pastelPeach.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(PastelTheme.pastelPeach.opacity(0.3), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("AI Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(PastelTheme.pastelOat)
                }
            }
            .task {
                self.availablePersonas = await RemoteConfigManager.shared.getAllPersonas()
            }
        }
    }
}

struct AIExerciseRowView: View {
    let index: Int
    let exercise: GeneratedExerciseDTO?
    let unitsManager: UnitsManager
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme 

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                HStack(alignment: .top) {
                    Text(String(format: "%02d", index + 1))
                        .font(.system(size: 22, weight: .black, design: .rounded).monospacedDigit())
                        .foregroundColor(colorScheme == .dark ? PastelTheme.textMuted.opacity(0.6) : .black.opacity(0.2)) 

                    VStack(alignment: .leading, spacing: 4) {
                        Text(exercise != nil ? LocalizationHelper.shared.translateName(exercise!.name) : "Picking an exercise…")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(colorScheme == .dark ? PastelTheme.textPrimary : .black) 
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        Text(exercise?.muscleGroup ?? "Muscle group")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(PastelTheme.pastelSlate)
                    }
                    .padding(.leading, 8)

                    Spacer()
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.title2)
                        .foregroundColor(PastelTheme.pastelLavender.opacity(0.8))
                }

                Divider().background(PastelTheme.separator) 

                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.2.squarepath")
                            .foregroundColor(PastelTheme.pastelLavender)
                        Text("\(exercise?.sets ?? 3)x\(exercise?.reps ?? 10)")
                            .font(.system(size: 14, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundColor(colorScheme == .dark ? PastelTheme.textPrimary : .black) 
                    }
                    Spacer()
                    HStack(spacing: 6) {
                        Image(systemName: "scalemass.fill")
                            .foregroundColor(PastelTheme.pastelAmber)
                        let w = unitsManager.convertFromKilograms(exercise?.recommendedWeightKg ?? 0.0)
                        Text(w > 0 ? "\(Int(w)) \(unitsManager.weightUnitString())" : "Bodyweight")
                            .font(.system(size: 14, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundColor(colorScheme == .dark ? PastelTheme.textPrimary : .black) 
                    }
                }.padding(.top, 4)
            }
            .padding(18)
            .background(colorScheme == .dark ? PastelTheme.cardSurface : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(PastelTheme.cardBorder, lineWidth: 1))
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.2 : 0.04), radius: 6, y: 2)
        }
        .buttonStyle(ParallaxButtonStyle())
    }
}

struct ExerciseRowView: View {
    let index: Int
    let exercise: ExerciseDTO?
    let unitsManager: UnitsManager
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme 

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                HStack(alignment: .top) {
                    Text(String(format: "%02d", index + 1))
                        .font(.system(size: 22, weight: .black, design: .rounded).monospacedDigit())
                        .foregroundColor(colorScheme == .dark ? PastelTheme.textMuted.opacity(0.6) : .black.opacity(0.2)) 

                    VStack(alignment: .leading, spacing: 4) {
                        Text(LocalizationHelper.shared.translateName(exercise?.name ?? "Exercise"))
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(colorScheme == .dark ? PastelTheme.textPrimary : .black) 
                            .lineLimit(1)
                        Text(exercise?.type.rawValue ?? "Type")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(PastelTheme.textSecondary)
                    }
                    .padding(.leading, 8)

                    Spacer()
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.title2)
                        .foregroundColor(PastelTheme.pastelLavender.opacity(0.8))
                }

                Divider().background(PastelTheme.separator) 

                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                            .foregroundColor(PastelTheme.pastelAmber)
                        Text("RPE \(exercise?.effort ?? 8)")
                            .font(.system(size: 12, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundColor(colorScheme == .dark ? PastelTheme.textPrimary : .black) 
                    }
                    Spacer()
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.2.squarepath")
                            .foregroundColor(PastelTheme.pastelLavender)
                        Text("\(exercise?.sets ?? 3)x\(exercise?.reps ?? 10)")
                            .font(.system(size: 12, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundColor(colorScheme == .dark ? PastelTheme.textPrimary : .black) 
                    }
                    Spacer()
                    HStack(spacing: 6) {
                        Image(systemName: "scalemass.fill")
                            .foregroundColor(PastelTheme.pastelAmber)
                        let w = unitsManager.convertFromKilograms(exercise?.recommendedWeightKg ?? 0.0)
                        Text(w > 0 ? "\(Int(w)) \(unitsManager.weightUnitString())" : "Bodyweight")
                            .font(.system(size: 12, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundColor(colorScheme == .dark ? PastelTheme.textPrimary : .black) 
                    }
                }.padding(.top, 4)
            }
            .padding(18)
            .background(colorScheme == .dark ? PastelTheme.cardSurface : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(PastelTheme.cardBorder, lineWidth: 1))
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.2 : 0.04), radius: 6, y: 2)
        }
        .buttonStyle(ParallaxButtonStyle())
    }
}

struct ExerciseTechniqueSheet: View {
    let exercise: ExerciseDTO
    @Environment(\.colorScheme) private var colorScheme 

    var body: some View {
        ZStack(alignment: .top) {
            (colorScheme == .dark ? PastelTheme.canvas : Color(UIColor.secondarySystemBackground)).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {

                    VStack(alignment: .leading, spacing: 8) {
                        Text(LocalizationHelper.shared.translateName(exercise.name))
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(colorScheme == .dark ? PastelTheme.textPrimary : .black) 

                        HStack(spacing: 12) {
                            BadgeView(text: exercise.muscleGroup, color: PastelTheme.pastelLavender)
                            BadgeView(text: "RPE \(exercise.effort)", color: PastelTheme.pastelAmber)
                        }
                    }.padding(.horizontal, 24).padding(.top, 30)

                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "figure.strengthtraining.traditional").foregroundColor(PastelTheme.pastelSlate)
                            Text("Good form").font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundColor(PastelTheme.textSecondary)
                        }
                        Text(TechniqueHelper.getDescription(for: exercise.category))
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(colorScheme == .dark ? PastelTheme.textPrimary : .black) 
                            .lineSpacing(6)
                    }
                    .padding(20).frame(maxWidth: .infinity, alignment: .leading)
                    .background(colorScheme == .dark ? PastelTheme.cardSurface : Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(PastelTheme.cardBorder, lineWidth: 1))
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0.2 : 0.04), radius: 6, y: 2)
                    .padding(.horizontal, 24)

                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .foregroundColor(PastelTheme.pastelAmber)
                            Text("Form tips")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(PastelTheme.pastelAmber)
                        }

                        let tips = TechniqueHelper.getTips(for: exercise.category)
                        ForEach(tips, id: \.self) { tip in
                            HStack(alignment: .top, spacing: 10) {
                                RoundedRectangle(cornerRadius: 1.5)
                                    .fill(PastelTheme.pastelAmber)
                                    .frame(width: 3, height: 16)
                                    .padding(.top, 2)
                                Text(tip)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(colorScheme == .dark ? PastelTheme.textPrimary : .black)
                            }
                        }
                    }
                    .padding(18).frame(maxWidth: .infinity, alignment: .leading)
                    .background(colorScheme == .dark ? PastelTheme.cardSurface : Color.white)
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(PastelTheme.cardBorder, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .padding(.horizontal, 24)

                }.padding(.bottom, 40)
            }
        }
    }
}

struct ProgressAnalysisSheet: View {
    @Environment(DIContainer.self) private var di
    @Environment(ThemeManager.self) private var themeManager
    @Environment(UnitsManager.self) private var unitsManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var colorManager = MuscleColorManager.shared

    @Query private var allWorkouts: [Workout]

    init() {
        var descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate<Workout> { $0.endTime != nil },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 400
        _allWorkouts = Query(descriptor)
    }

    let periods = ["Last 7 days", "Mesocycle (4 weeks)", "Macrocycle (12 weeks)"]
    let focuses = ["Muscle balance", "Growth leaders"]

    @State private var selectedPeriod = "Mesocycle (4 weeks)"
    @State private var selectedFocus = "Muscle balance"

    @State private var stats: [MuscleStats] = []
    @State private var activeSegment: UUID? = nil

    @State private var isAnalyzing = true
    @State private var impulseValue: Int = 0
    @State private var impulseMuscle: String = "Chest"
    @State private var aiConclusion: String = "Analyzing muscle load distribution…"

    @State private var appearAnimate = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {

                (colorScheme == .dark ? PastelTheme.canvas : Color(UIColor.secondarySystemBackground)).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 30) {
                        Spacer().frame(height: 70)

                        if isAnalyzing && stats.isEmpty {
                            loadingView
                        } else if stats.isEmpty {
                            emptyDataView
                        } else {
                            aiPredictorSection
                            analyticsParamsSection
                            chartsSection
                            aiConclusionSection
                        }
                    }
                    .padding(.bottom, 40)
                }

                floatingHeader
            }
            .navigationBarHidden(true)
            .task(id: selectedPeriod) { await loadDataAndAnalyze() }
            .task(id: selectedFocus) { await generateAIConclusion() }
            .onAppear {
                withAnimation(.spring(response: 0.7, dampingFraction: 0.7)) { appearAnimate = true }
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView().scaleEffect(1.5).tint(PastelTheme.pastelLavender)
            Text("Gathering training data…").font(.headline).foregroundColor(PastelTheme.textSecondary)
        }
        .frame(maxWidth: .infinity).padding(.top, 100)
    }

    private var emptyDataView: some View {
        EmptyStateView(
            icon: "chart.pie.fill",
            title: "Not enough data",
            message: "Log a few more workouts to unlock analytics."
        )
        .padding(.top, 50)
    }

    @ViewBuilder
    private var aiPredictorSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "cpu").foregroundColor(PastelTheme.pastelLavender)
                Text("AI forecast").font(.caption.bold()).foregroundColor(PastelTheme.textSecondary)
            }
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Volume impulse").font(.system(size: 14, weight: .medium)).foregroundColor(PastelTheme.textSecondary)
                    HStack(alignment: .firstTextBaseline) {
                        Text(impulseValue > 0 ? "+\(impulseValue)%" : "\(impulseValue)%")
                            .font(.system(size: 38, weight: .black, design: .rounded).monospacedDigit())
                            .foregroundColor(impulseValue > 0 ? PastelTheme.pastelSage : (impulseValue < 0 ? PastelTheme.pastelPeach : PastelTheme.textSecondary))
                            .contentTransition(.numericText())
                        Text("to tonnage").font(.system(size: 16, weight: .bold)).foregroundColor(colorScheme == .dark ? PastelTheme.textPrimary : .black)
                    }
                }
                Spacer()
                ZStack {
                    Circle().stroke(PastelTheme.pastelSage.opacity(0.3), lineWidth: 2).frame(width: 60, height: 60)
                    Circle().fill(PastelTheme.pastelSage.opacity(0.1)).frame(width: 60, height: 60)
                    Image(systemName: impulseValue >= 0 ? "arrow.up.forward" : "arrow.down.right")
                        .font(.title2)
                        .foregroundColor(impulseValue >= 0 ? PastelTheme.pastelSage : PastelTheme.pastelPeach)
                        .offset(x: appearAnimate ? 5 : -5, y: appearAnimate ? -5 : 5)
                }.modifier(PulseEffect())
            }
            Text("Based on your training data, possible strength gains in: **\(impulseMuscle)**.")
                .font(.system(size: 14)).foregroundColor(PastelTheme.textSecondary)
        }
        .padding(20)
        .background(colorScheme == .dark ? PastelTheme.cardSurface : Color.white)
        .cornerRadius(24)
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(PastelTheme.cardBorder, lineWidth: 1))
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.2 : 0.05), radius: 10, y: 5)
        .padding(.horizontal, 24)
    }

    @ViewBuilder
    private var analyticsParamsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Detailed analytics").font(.caption.bold()).foregroundColor(PastelTheme.textSecondary).padding(.horizontal, 24)
            VStack(spacing: 2) {
                Menu {
                    ForEach(periods, id: \.self) { p in
                        Button(p) { selectedPeriod = p }
                    }
                } label: {
                    HStack {
                        Text("Period").foregroundColor(PastelTheme.textSecondary)
                        Spacer()
                        Text(selectedPeriod).fontWeight(.bold).foregroundColor(colorScheme == .dark ? PastelTheme.textPrimary : .black)
                        Image(systemName: "chevron.up.chevron.down").foregroundColor(PastelTheme.pastelSlate).font(.caption)
                    }
                    .padding()
                    .background(colorScheme == .dark ? PastelTheme.cardSurfaceSubtle : Color.white)
                }

                Divider().background(PastelTheme.separator).padding(.horizontal)

                Menu {
                    ForEach(focuses, id: \.self) { f in
                        Button(f) { selectedFocus = f }
                    }
                } label: {
                    HStack {
                        Text("Focus").foregroundColor(PastelTheme.textSecondary)
                        Spacer()
                        Text(selectedFocus).fontWeight(.bold).foregroundColor(colorScheme == .dark ? PastelTheme.textPrimary : .black)
                        Image(systemName: "chevron.up.chevron.down").foregroundColor(PastelTheme.pastelLavender).font(.caption)
                    }
                    .padding()
                    .background(colorScheme == .dark ? PastelTheme.cardSurfaceSubtle : Color.white)
                }
            }
            .cornerRadius(20)
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.03 : 0.05), radius: 5, y: 2)
            .padding(.horizontal, 24)
        }
    }

    @ViewBuilder
    private var chartsSection: some View {
        VStack(alignment: .center, spacing: 24) {
            ZStack {
                CustomDonutChart(data: stats.map { ($0.pastShare, $0.color.opacity(0.3), $0.id) }, thickness: 10, activeId: $activeSegment)
                    .frame(width: 150, height: 150)

                CustomDonutChart(data: stats.map { ($0.currentShare, $0.color, $0.id) }, thickness: 18, activeId: $activeSegment)
                    .frame(width: 210, height: 210)
                    .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 5)

                VStack {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 34))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                }
            }
            .scaleEffect(appearAnimate ? 1 : 0.8).opacity(appearAnimate ? 1 : 0)
            .padding(.vertical, 10)

            VStack(spacing: 16) {
                ForEach(stats) { stat in
                    StatRowView(stat: stat, appearAnimate: appearAnimate, isSelected: activeSegment == stat.id)
                        .onTapGesture {
                            withAnimation(.spring()) { activeSegment = (activeSegment == stat.id) ? nil : stat.id }
                        }
                }
            }
        }.frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var aiConclusionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AI summary").font(.caption.bold()).foregroundColor(PastelTheme.pastelLavender).padding(.horizontal, 24)

            HStack(alignment: .top, spacing: 16) {
                Image(systemName: "sparkles.tv")
                    .font(.title)
                    .foregroundStyle(PastelTheme.pastelLavender)

                VStack(alignment: .leading, spacing: 8) {
                    if isAnalyzing {
                        ProgressView().tint(PastelTheme.pastelLavender)
                    } else {
                        Text(aiConclusion)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(colorScheme == .dark ? PastelTheme.textPrimary : .black)
                            .lineSpacing(4)
                            .transition(.opacity)
                    }
                }
                Spacer()
            }
            .padding(20)
            .background(colorScheme == .dark ? PastelTheme.cardSurface : Color.white)
            .cornerRadius(24)
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(PastelTheme.cardBorder, lineWidth: 1))
            .shadow(color: Color.black.opacity(0.1), radius: 10, y: 5)
            .padding(.horizontal, 24)
        }
    }

    private var floatingHeader: some View {
        VStack {
            HStack {
                Text("Progress analysis")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(colorScheme == .dark ? PastelTheme.textPrimary : .black)
                Spacer()
            }
            .padding(.horizontal, 24).padding(.top, 20).padding(.bottom, 10)
        }
        .background(.regularMaterial)
    }

    private func loadDataAndAnalyze() async {
        isAnalyzing = true
        let calendar = Calendar.current
        let now = Date()

        let days: Int
        switch selectedPeriod {
        case "Last 7 days", "Last 7 days": days = 7
        case "Mesocycle (4 weeks)", "Mesocycle (4 weeks)": days = 28
        case "Macrocycle (12 weeks)", "Macrocycle (12 weeks)": days = 84
        default: days = 28
        }

        let currentStart = calendar.date(byAdding: .day, value: -days, to: now)!
        let previousStart = calendar.date(byAdding: .day, value: -(days * 2), to: now)!

        var currentSets: [String: Double] = [:]
        var previousSets: [String: Double] = [:]
        var currentVolume = 0.0
        var previousVolume = 0.0

        for workout in allWorkouts {
            let isCurrent = workout.date >= currentStart && workout.date <= now
            let isPrev = workout.date >= previousStart && workout.date < currentStart
            if !isCurrent && !isPrev { continue }

            for ex in workout.exercises {
                let targets = ex.isSuperset ? ex.subExercises : [ex]
                for sub in targets where sub.type == .strength {
                    let completedSets = sub.setsList.filter { $0.isCompleted && $0.type != .warmup }
                    if !completedSets.isEmpty {
                        let broadCategory = MuscleCategoryMapper.getBroadCategory(for: sub.muscleGroup)
                        if broadCategory != "Other" {
                            let vol = completedSets.reduce(0.0) { result, set in
                                result + ((set.weight ?? 0) * Double(set.reps ?? 0))
                            }
                            if isCurrent {
                                currentSets[broadCategory, default: 0] += Double(completedSets.count)
                                currentVolume += vol
                            } else {
                                previousSets[broadCategory, default: 0] += Double(completedSets.count)
                                previousVolume += vol
                            }
                        }
                    }
                }
            }
        }

        let totalCurrent = currentSets.values.reduce(0, +)
        let totalPrevious = previousSets.values.reduce(0, +)

        var newStats: [MuscleStats] = []
        let allKeys = Set(currentSets.keys).union(Set(previousSets.keys))

        var maxSets = 0.0
        var topCurrentMuscleEnglish = "Chest"

        for key in allKeys {
            let cShare = totalCurrent > 0 ? (currentSets[key] ?? 0) / totalCurrent * 100.0 : 0
            let pShare = totalPrevious > 0 ? (previousSets[key] ?? 0) / totalPrevious * 100.0 : 0
            if (currentSets[key] ?? 0) > maxSets {
                maxSets = currentSets[key] ?? 0
                topCurrentMuscleEnglish = key
            }
            let color = colorManager.getColor(for: key)
            let localizedName = localizeMuscle(key)
            newStats.append(MuscleStats(name: localizedName, currentShare: cShare, pastShare: pShare, color: color))
        }

        newStats.sort { $0.currentShare > $1.currentShare }

        let impulse: Int
        if previousVolume > 0 {
            impulse = Int(((currentVolume - previousVolume) / previousVolume) * 100.0)
        } else if currentVolume > 0 {
            impulse = 100
        } else {
            impulse = 0
        }

        let topCurrentMuscleLocalized = localizeMuscle(topCurrentMuscleEnglish)

        await MainActor.run {
            self.stats = Array(newStats.prefix(6))
            self.impulseValue = impulse
            self.impulseMuscle = topCurrentMuscleLocalized

            if !self.stats.isEmpty {
                Task { await generateAIConclusion() }
            } else {
                self.isAnalyzing = false
            }
        }
    }

    private func generateAIConclusion() async {
        guard !stats.isEmpty else { return }
        isAnalyzing = true

        var contextStr = "My statistics for the period:\n"
        for stat in stats {
            let diff = stat.currentShare - stat.pastShare
            let sign = diff >= 0 ? "+" : ""
            contextStr += "- \(stat.name): Was \(Int(stat.pastShare))%, Became \(Int(stat.currentShare))% (Trend: \(sign)\(Int(diff))%)\n"
        }

        let prompt = """
        You are a professional AI trainer.
        The user is looking at the muscle load distribution analytics.
        Their emphasis is now: "(selectedFocus)".
        Analyze the provided data and write a short, motivating, and direct conclusion/advice in the user's language (2-3 sentences maximum).
        Point out obvious imbalances or praise focus. Do not use Markdown formatting (no asterisks or bold).
        """

        let userContext = UserProfileContext(userName: "Athlete", weightKg: 80, experienceLevel: "Pro", favoriteMuscles: [], recentPRs: [:], language: Locale.autoupdatingCurrent.language.languageCode?.identifier == "ru" ? "Russian" : "English", workoutsThisWeek: 0, currentStreak: 0, fatiguedMuscles: [], availableExercises: [], aiCoachTone: "Strict", weightUnit: "kg")

        do {
            let stream = try await di.aiLogicService.streamChatResponse(userRequest: prompt + "\n\n" + contextStr, userProfile: userContext)

            var fullResponse = ""
            for try await chunk in stream {
                fullResponse += chunk
                await MainActor.run {
                    self.aiConclusion = fullResponse
                }
            }
            await MainActor.run { self.isAnalyzing = false }
        } catch {
            await MainActor.run {
                self.aiConclusion = error.userFacingAIMessage
                self.isAnalyzing = false
            }
        }
    }

    private func localizeMuscle(_ englishName: String) -> String {
        switch englishName {
        case "Chest": return "Chest"
        case "Back": return "Back"
        case "Legs": return "Legs"
        case "Shoulders": return "Shoulders"
        case "Arms": return "Arms"
        case "Core": return "Core"
        case "Cardio": return "Cardio"
        default: return LocalizationHelper.shared.translateName(englishName)
        }
    }
}

struct RestAnalysisSheet: View {
    @AppStorage("hasSleepData") private var hasSleepData = false
    @AppStorage("sleepHours") private var sleepHours: Double = 7.5
    @AppStorage("waterCups") private var waterCups: Int = 4
    /// Local estimate only — never overwrite Overview `cnsScore` AppStorage (ADR honesty).
    @Environment(\.colorScheme) private var colorScheme

    var cnsLoad: Double {
        RestFatigueEstimator.cnsLoad(sleepHours: sleepHours, waterCups: waterCups)
    }
    /// Rest tips + ring only after sleep is measured — water alone must not invent readiness.
    private var showsMeasuredFatigue: Bool {
        RestFatigueEstimator.showsMeasuredFatigue(hasSleepData: hasSleepData)
    }
    private var displayLoadPercent: Int? {
        RestFatigueEstimator.displayLoadPercent(
            hasSleepData: hasSleepData,
            sleepHours: sleepHours,
            waterCups: waterCups
        )
    }
    var cnsColor: Color {
        guard showsMeasuredFatigue else { return PastelTheme.textSecondary }
        switch cnsLoad {
        case 0..<40: return PastelTheme.pastelSage
        case 40..<75: return PastelTheme.pastelAmber
        default: return PastelTheme.pastelPeach
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                (colorScheme == .dark ? PastelTheme.canvas : Color(UIColor.secondarySystemBackground)).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 28) {
                        Spacer().frame(height: 70)

                        VStack(spacing: 16) {
                            Text("Rest readiness estimate")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(PastelTheme.textSecondary)

                            ZStack {
                                Circle()
                                    .stroke(colorScheme == .dark ? PastelTheme.cardBorder : Color.black.opacity(0.06), lineWidth: 14)
                                    .frame(width: 150, height: 150)
                                Circle()
                                    .trim(from: 0, to: displayLoadPercent.map { CGFloat($0) / 100 } ?? 0)
                                    .stroke(cnsColor, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                                    .frame(width: 150, height: 150)
                                    .rotationEffect(.degrees(-90))
                                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: displayLoadPercent)

                                VStack(spacing: 4) {
                                    Text(displayLoadPercent.map { "\($0)%" } ?? "—")
                                        .font(.system(size: 34, weight: .black, design: .rounded).monospacedDigit())
                                        .foregroundColor(colorScheme == .dark ? PastelTheme.textPrimary : .black)
                                        .contentTransition(.numericText())
                                    Text(
                                        displayLoadPercent == nil
                                            ? String(localized: "Not measured")
                                            : (cnsLoad < 40 ? String(localized: "Low") : (cnsLoad < 75 ? String(localized: "Moderate") : String(localized: "High")))
                                    )
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundColor(cnsColor)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 10)

                        VStack(alignment: .leading, spacing: 14) {
                            Text("Biometrics")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(PastelTheme.textSecondary)
                                .padding(.horizontal, 24)

                            VStack(spacing: 12) {
                                HStack {
                                    Image(systemName: "moon.zzz.fill")
                                        .foregroundColor(PastelTheme.pastelLavender)
                                    Text("Last night's sleep")
                                        .font(.system(size: 15, weight: .medium, design: .rounded))
                                        .foregroundColor(colorScheme == .dark ? PastelTheme.textPrimary : .black)
                                    Spacer()
                                    Text(hasSleepData ? String(format: "%.1f h", sleepHours) : "— h")
                                        .font(.system(size: 17, weight: .bold, design: .rounded).monospacedDigit())
                                        .foregroundColor(PastelTheme.pastelLavender)
                                }
                                Slider(value: $sleepHours, in: 3...12, step: 0.5) { _ in
                                    HapticManager.shared.selection()
                                    hasSleepData = true
                                }
                                .tint(PastelTheme.pastelLavender)
                            }
                            .padding(20)
                            .background(colorScheme == .dark ? PastelTheme.cardSurface : Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(PastelTheme.cardBorder, lineWidth: 1))
                            .shadow(color: .black.opacity(colorScheme == .dark ? 0.2 : 0.04), radius: 6, y: 2)
                            .padding(.horizontal, 24)

                            VStack(spacing: 12) {
                                HStack {
                                    Image(systemName: "drop.fill", variableValue: Double(waterCups)/10.0)
                                        .foregroundColor(PastelTheme.pastelSlate)
                                    Text("Water today (cups)")
                                        .font(.system(size: 15, weight: .medium, design: .rounded))
                                        .foregroundColor(colorScheme == .dark ? PastelTheme.textPrimary : .black)
                                    Spacer()
                                    Text("\(waterCups)")
                                        .font(.system(size: 17, weight: .bold, design: .rounded).monospacedDigit())
                                        .foregroundColor(PastelTheme.pastelSlate)
                                }
                                Slider(value: Binding(get: { Double(waterCups) }, set: { waterCups = Int($0) }), in: 0...15, step: 1) { _ in
                                    HapticManager.shared.selection()
                                }
                                .tint(PastelTheme.pastelSlate)
                            }
                            .padding(20)
                            .background(colorScheme == .dark ? PastelTheme.cardSurface : Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(PastelTheme.cardBorder, lineWidth: 1))
                            .shadow(color: .black.opacity(colorScheme == .dark ? 0.2 : 0.04), radius: 6, y: 2)
                            .padding(.horizontal, 24)
                        }

                        VStack(alignment: .leading, spacing: 14) {
                            Text("Recovery recommendations")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(PastelTheme.textSecondary)
                                .padding(.horizontal, 24)

                            Group {
                                if showsMeasuredFatigue {
                                    HStack(spacing: 10) {
                                        if cnsLoad < 40 {
                                            RecoveryBadge(icon: "flame.fill", text: "Complex carbs", color: PastelTheme.pastelAmber)
                                            RecoveryBadge(icon: "figure.walk", text: "Easy walk", color: PastelTheme.pastelSage)
                                        } else if cnsLoad < 75 {
                                            RecoveryBadge(icon: "snowflake", text: "Contrast shower", color: PastelTheme.pastelSlate)
                                            RecoveryBadge(icon: "bed.double.fill", text: "Nap (20 min)", color: PastelTheme.pastelLavender)
                                        } else {
                                            RecoveryBadge(icon: "thermometer.sun.fill", text: "Sauna", color: PastelTheme.pastelPeach)
                                            RecoveryBadge(icon: "figure.mind.and.body", text: "Foam roll and stretch", color: PastelTheme.pastelSlate)
                                        }
                                    }
                                } else {
                                    Text("Log last night's sleep to unlock recommendations.")
                                        .font(.footnote)
                                        .foregroundStyle(PastelTheme.textSecondary)
                                }
                            }
                            .padding(.horizontal, 24)
                        }

                        Text("Fatigue scores and tips are approximate and based on the data you enter.")
                            .font(.caption2)
                            .foregroundColor(PastelTheme.textMuted)
                            .multilineTextAlignment(.leading)
                            .padding(.horizontal, 24)
                            .padding(.top, 4)
                    }
                    .padding(.bottom, 40)
                }

                VStack {
                    HStack {
                        Text("Recovery")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(colorScheme == .dark ? PastelTheme.textPrimary : .black)
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 10)
                }
                .background(.ultraThinMaterial)
            }
            .navigationBarHidden(true)
            .task {
                if let sleep = await HealthKitManager.shared.fetchSleepDuration() {
                    sleepHours = sleep
                    hasSleepData = true
                }
            }
        }
    }
}

struct MicroMetric: View {
    var title: String
    var value: String
    var unit: String
    var color: Color
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundColor(PastelTheme.textSecondary)
            if value == "--" {
                UnavailableMetricView(icon: "waveform.path.ecg", text: "No data")
                    .padding(.top, 2)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(value).font(.system(size: 18, weight: .black, design: .rounded).monospacedDigit()).foregroundColor(color)
                    Text(unit).font(.system(size: 10, weight: .medium, design: .rounded)).foregroundColor(PastelTheme.textMuted)
                }
            }
        }
    }
}

struct AICoachIsland: View {
    var title: String
    var icon: String
    var color: Color
    var action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: {
            HapticManager.shared.impact(.light)
            action()
        }) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(colorScheme == .dark ? PastelTheme.textPrimary : .black)
            }
            .padding(.horizontal, 16)
            .frame(height: PastelTheme.ButtonMetrics.pillHeight)
            .background(colorScheme == .dark ? PastelTheme.cardSurface : Color.white)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(PastelTheme.cardBorder, lineWidth: 1))
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.2 : 0.04), radius: 5, y: 2)
        }
        .buttonStyle(.plain)
    }
}

struct StatRowView: View {
    let stat: MuscleStats
    let appearAnimate: Bool
    let isSelected: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let diff = stat.currentShare - stat.pastShare
        let diffStr = diff > 0 ? "+\(String(format: "%.1f", diff))%" : "\(String(format: "%.1f", diff))%"
        VStack(spacing: 6) {
            HStack {
                Circle().fill(stat.color).frame(width: 8, height: 8).scaleEffect(isSelected ? 1.5 : 1.0)
                Text(stat.name).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundColor(colorScheme == .dark ? PastelTheme.textPrimary : .black)
                Spacer()
                Text(diffStr).font(.system(size: 13, weight: .bold, design: .rounded).monospacedDigit()).foregroundColor(diff > 0 ? PastelTheme.pastelSage : (diff < 0 ? PastelTheme.pastelPeach : PastelTheme.textMuted))
                Text("\(String(format: "%.1f", stat.currentShare))%").font(.system(size: 16, weight: .black, design: .rounded).monospacedDigit()).foregroundColor(colorScheme == .dark ? PastelTheme.textPrimary : .black).frame(width: 55, alignment: .trailing)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.gray.opacity(0.15)).frame(height: 6)
                    Capsule()
                        .fill(stat.color)
                        .frame(width: appearAnimate ? geo.size.width * (stat.currentShare / 40.0) : 0, height: 6)
                }
            }.frame(height: 6)
        }.padding(.horizontal, 24)
    }
}

struct RecoveryBadge: View {
    var icon: String
    var text: String
    var color: Color
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundColor(color)
            Text(text)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(colorScheme == .dark ? PastelTheme.textPrimary : .black)
                .lineLimit(2)
        }
        .padding(.horizontal, 12).padding(.vertical, 10).frame(maxWidth: .infinity, alignment: .leading)
        .background(colorScheme == .dark ? PastelTheme.cardSurface : Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(PastelTheme.cardBorder, lineWidth: 1))
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.2 : 0.04), radius: 5, y: 2)
    }
}

struct BadgeView: View {
    let text: String; let color: Color
    var body: some View { Text(text).font(.system(size: 12, weight: .bold)).foregroundColor(color).padding(.horizontal, 10).padding(.vertical, 6).background(color.opacity(0.15)).cornerRadius(8) }
}
struct IdentifiableGeneratedEx: Identifiable {
    let dto: GeneratedExerciseDTO
    var id: String { dto.name }
}

extension Color {
    static let cyberPurple = PastelTheme.pastelLavender
    static let cyberOrange = PastelTheme.pastelAmber
    static let cyberBlue = PastelTheme.pastelSlate
    static let cyberCyan = PastelTheme.pastelSlate
    static let cyberGreen = PastelTheme.pastelSage
    static let cyberRed = PastelTheme.pastelPeach
}
