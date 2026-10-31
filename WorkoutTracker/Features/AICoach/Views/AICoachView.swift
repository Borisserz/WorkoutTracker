

internal import SwiftUI
import SwiftData

struct CoachSheetItem: Identifiable {
    let id: String
}

enum CoachMuscleGroup: String, CaseIterable, Identifiable {
    case chest = "Chest", back = "Back", legs = "Legs", shoulders = "Shoulders", arms = "Arms", abs = "Abs"
    var id: String { self.rawValue }

    var engineName: String {
        switch self {
        case .chest: return "Chest"
        case .back: return "Back"
        case .legs: return "Legs"
        case .shoulders: return "Shoulders"
        case .arms: return "Arms"
        case .abs: return "Core"
        }
    }
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
    @State private var showWorkoutSheet = false
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

    @State private var showSyncToast = false
    @State private var readinessValue: CGFloat = 0.0
    @State private var sphereDragOffset: CGSize = .zero
    @State private var shimmerOffset: CGFloat = -1.0

    @AppStorage("cnsScore") private var cnsScore: Double = 85.0
    @AppStorage("sleepHours") private var sleepHours: Double = 7.5
    @AppStorage("hasSleepData") private var hasSleepData = false
    @AppStorage(Constants.UserDefaultsKeys.userName.rawValue) private var userName = ""

    @State private var speechRecognizer = SpeechRecognizer()

    let quickPrompts = ["How to break a plateau?", "Bench Press Mechanics", "Recovery Tips", "Hypertrophy Split"]

    // AI Hub states
    @State private var path = NavigationPath()
    @State private var showSmartBuilder = false
    @State private var showAIBuilder = false
    @State private var showAICameraSelector = false
    @State private var showGlobalAICamera = false
    @State private var selectedAIExercise: String = "Squats"

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour { case 6..<12: return "Good morning,"; case 12..<18: return "Good afternoon,"; case 18..<24: return "Evening focus,"; default: return "Recovery time," }
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
                PastelTheme.canvas.ignoresSafeArea()
                AtmosphericGymBackdropView(style: .aiHub)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        
                        // 1. Header Section
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 8) {
                                    Text("ИИ-Хаб")
                                        .font(.system(size: 32, weight: .bold, design: .rounded))
                                        .foregroundStyle(PastelTheme.textPrimary)

                                    if showSyncToast {
                                        HStack(spacing: 4) {
                                            Image(systemName: "waveform.path.ecg")
                                                .font(.caption2)
                                                .foregroundStyle(PastelTheme.pastelSage)
                                                .symbolEffect(.pulse, options: .repeating)
                                            Text("Синхронизировано")
                                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                                .foregroundStyle(PastelTheme.pastelSage)
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(PastelTheme.pastelSage.opacity(0.12))
                                        .clipShape(Capsule())
                                        .transition(.opacity.combined(with: .scale))
                                    }
                                }

                                Text("Биомеханика и готовность ЦНС")
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

                        // 2. Apple Watch-Style Readiness & Vitals Hero
                        PastelReadinessCard(
                            score: cnsScore,
                            hrv: actualHRV,
                            rhr: actualRHR,
                            sleep: sleepHours,
                            hasSleep: hasSleepData
                        )
                        .padding(.horizontal, 16)

                        // 3. AI Predictive Recommendation Banner
                        HStack(alignment: .top, spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(PastelTheme.pastelAmber.opacity(0.15))
                                    .frame(width: 38, height: 38)
                                    .overlay(Circle().stroke(PastelTheme.pastelAmber.opacity(0.3), lineWidth: 1))
                                Image(systemName: "sparkles")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(PastelTheme.pastelAmber)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Рекомендация на сегодня")
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundStyle(PastelTheme.textPrimary)
                                    Spacer()
                                    Text("\(Int(cnsScore))% готовность")
                                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                                        .monospacedDigit()
                                        .foregroundStyle(PastelTheme.pastelSage)
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 3)
                                        .background(PastelTheme.pastelSage.opacity(0.12))
                                        .clipShape(Capsule())
                                }

                                Text("ЦНС полностью восстановилась. Свежие мышечные группы: грудь и плечи. Идеальное окно для интенсивной силовой нагрузки.")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(PastelTheme.textSecondary)
                                    .lineSpacing(2)
                            }
                        }
                        .padding(14)
                        .background(PastelTheme.cardSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(PastelTheme.cardBorder, lineWidth: 1)
                        )
                        .padding(.horizontal, 16)

                        // 4. Asymmetrical Bento Grid: Hero Tile (AI Vision Camera)
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
                                        Text("Компьютерное зрение")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(PastelTheme.pastelLavender)
                                    }

                                    Text("AI-Камера и трекинг техники")
                                        .font(.system(size: 17, weight: .bold, design: .rounded))
                                        .foregroundStyle(PastelTheme.textPrimary)

                                    Text("Анализ углов в суставах, траектории штанги и амплитуды в реальном времени")
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

                        // 5. Asymmetrical Bento Grid: Split Row (50/50)
                        HStack(spacing: 12) {
                            // Tile 2: Smart Workout
                            Button {
                                HapticManager.shared.impact(.medium)
                                showSmartBuilder = true
                            } label: {
                                PastelBentoCard(
                                    title: "Сессия дня",
                                    subtitle: "Сборка под готовность мышц",
                                    iconName: "wand.and.stars",
                                    accentColor: PastelTheme.pastelSage
                                )
                            }
                            .buttonStyle(.plain)

                            // Tile 3: Recovery Coach
                            Button {
                                HapticManager.shared.impact(.medium)
                                showRestSheet = true
                            } label: {
                                PastelBentoCard(
                                    title: "Восстановление",
                                    subtitle: "Оценка утомления и сна",
                                    iconName: "moon.stars.fill",
                                    accentColor: PastelTheme.pastelAmber
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 16)

                        // 6. Asymmetrical Bento Grid: Program Architect (Full Width)
                        Button {
                            HapticManager.shared.impact(.medium)
                            showAIBuilder = true
                        } label: {
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(PastelTheme.cardSurfaceSubtle)
                                        .frame(width: 44, height: 44)
                                        .overlay(Circle().stroke(PastelTheme.cardBorder, lineWidth: 1))

                                    Image(systemName: "calendar.badge.plus")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundStyle(PastelTheme.pastelOat)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("План на сезон")
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(PastelTheme.textPrimary)

                                    Text("Персональная периодизация и прогрессия весов")
                                        .font(.caption)
                                        .foregroundStyle(PastelTheme.textSecondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption.bold())
                                    .foregroundStyle(PastelTheme.textTertiary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(PastelTheme.cardSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(PastelTheme.cardBorder, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)

                        // 7. Progress Analytics Full-Width Banner
                        Button {
                            HapticManager.shared.impact(.medium)
                            showProgressSheet = true
                        } label: {
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(PastelTheme.cardSurfaceSubtle)
                                        .frame(width: 42, height: 42)
                                        .overlay(Circle().stroke(PastelTheme.cardBorder, lineWidth: 1))

                                    Image(systemName: "chart.xyaxis.line")
                                        .font(.system(size: 16))
                                        .foregroundStyle(PastelTheme.pastelSage)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Аналитика прогресса")
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(PastelTheme.textPrimary)

                                    Text("Биометрический анализ результатов недели")
                                        .font(.caption2)
                                        .foregroundStyle(PastelTheme.textSecondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption.bold())
                                    .foregroundStyle(PastelTheme.textTertiary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(PastelTheme.cardSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(PastelTheme.cardBorder, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)

                        // 8. Quick Prompt Pills
                        if !speechRecognizer.isRecording {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(quickPrompts, id: \.self) { prompt in
                                        Button {
                                            HapticManager.shared.selection()
                                            requireAIConsent {
                                                viewModel.inputText = prompt
                                                showChatView = true
                                            }
                                        } label: {
                                            Text(prompt)
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(PastelTheme.textSecondary)
                                                .padding(.horizontal, 13)
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
                                .padding(.horizontal, 16)
                            }
                        }

                        // 9. Apple Intelligence Assistant Cockpit (Dictation & Text Input)
                        PastelAssistantCard(
                            isListening: Binding(get: { speechRecognizer.isRecording }, set: { _ in }),
                            textTranscript: $speechRecognizer.transcript,
                            userQuery: $userQuery,
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
                        .padding(.bottom, 30)
                    }
                }
            }
            .navigationBarHidden(true)
            .dynamicTypeSize(.medium ... .accessibility1)
            .onAppear {
                TrackingManager.shared.track(.aiCoachOpened(source: "tab"))
                speechRecognizer.requestPermission()

                Task {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3)) { showSyncToast = true }
                    try? await Task.sleep(nanoseconds: 2_500_000_000)
                    withAnimation(.easeOut) { showSyncToast = false }
                }
                withAnimation(.easeOut(duration: 2.5).delay(0.5)) { readinessValue = cnsScore / 100 }
                withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) { isBreathing = true }
                withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) { isLevitating = true }
                withAnimation(.linear(duration: 2.5).repeatForever(autoreverses: false)) { shimmerOffset = 2.0 }
            }
            .sheet(isPresented: $showRestSheet) { RestAnalysisSheet().presentationDetents([.large]).presentationCornerRadius(35).presentationDragIndicator(.visible) }
            .sheet(isPresented: $showProgressSheet) { ProgressAnalysisSheet().presentationDetents([.large]).presentationCornerRadius(35).presentationDragIndicator(.visible) }
            .sheet(isPresented: $showWorkoutSheet) { WorkoutConfigSheet().presentationDetents([.large]).presentationCornerRadius(35).presentationDragIndicator(.visible) }
            .sheet(isPresented: $showAISettings) { AISettingsSheet().presentationDetents([.medium]).presentationDragIndicator(.visible) }
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
            .sheet(isPresented: $showSmartBuilder) {
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
                        await di.workoutService.startGeneratedWorkout(generatedDTO)
                        if let newWorkout = await di.workoutService.fetchLatestWorkout() {
                            path.append(newWorkout)
                        }
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

typealias CyberBentoCard = PastelBentoCard

struct PastelReadinessCard: View {
    let score: Double
    let hrv: Double?
    let rhr: Double?
    let sleep: Double
    let hasSleep: Bool

    private var scoreColor: Color {
        if score >= 80 { return PastelTheme.pastelSage }
        if score >= 50 { return PastelTheme.pastelAmber }
        return PastelTheme.pastelPeach
    }

    private var adviceText: String {
        if score >= 80 {
            return "ЦНС полностью восстановилась. Отличный день для базовых силовых нагрузок высокой интенсивности."
        } else if score >= 50 {
            return "Умеренная нагрузка. Рекомендуется работа с 70-80% от максимума и фокус на чистой технике."
        } else {
            return "Высокая усталость ЦНС. Рекомендуется день разгрузки, легкое кардио или растяжка."
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

                        Text("Готовность ЦНС")
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
                PastelMetricItem(title: "HRV", value: hrv != nil ? "\(Int(hrv!))" : "--", unit: "мс", color: PastelTheme.pastelSlate)
                Spacer()
                PastelMetricItem(title: "ЧСС покоя", value: rhr != nil ? "\(Int(rhr!))" : "--", unit: "уд/м", color: PastelTheme.pastelLavender)
                Spacer()
                PastelMetricItem(title: "Сон", value: hasSleep ? String(format: "%.1f", sleep) : "--", unit: "ч", color: PastelTheme.pastelAmber)
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

typealias CyberReadinessCard = PastelReadinessCard

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

typealias CyberMetric = PastelMetricItem

struct PastelAssistantCard: View {
    @Binding var isListening: Bool
    @Binding var textTranscript: String
    @Binding var userQuery: String
    let onMicTap: () -> Void
    let onSubmitQuery: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Microphone Dictation Button
                Button(action: onMicTap) {
                    ZStack {
                        Circle()
                            .fill(isListening ? PastelTheme.pastelPeach : PastelTheme.pastelOat)
                            .frame(width: 44, height: 44)
                            .overlay(
                                Circle().stroke(PastelTheme.cardBorderFocused, lineWidth: 1)
                            )

                        Image(systemName: isListening ? "stop.fill" : "mic.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(PastelTheme.textOnOat)
                    }
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(isListening ? "Слушаю вас..." : "Спросить AI Тренера")
                            .font(.subheadline.bold())
                            .foregroundStyle(PastelTheme.textPrimary)

                        if isListening {
                            SiriWaveformView()
                        }
                    }

                    Text(isListening ? (textTranscript.isEmpty ? "Говорите..." : textTranscript) : "Техника, подбор упражнений, диета")
                        .font(.caption2)
                        .foregroundStyle(isListening ? PastelTheme.pastelSage : PastelTheme.textSecondary)
                        .lineLimit(1)
                }

                Spacer()
            }

            // Text input row
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundStyle(PastelTheme.textTertiary)

                TextField("Задайте вопрос тренеру...", text: $userQuery)
                    .font(.subheadline)
                    .foregroundStyle(PastelTheme.textPrimary)
                    .submitLabel(.send)
                    .onSubmit(onSubmitQuery)

                if !userQuery.isEmpty {
                    Button(action: onSubmitQuery) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(PastelTheme.pastelOat)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(PastelTheme.cardSurfaceSubtle)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(PastelTheme.cardBorder, lineWidth: 1)
            )
        }
        .padding(14)
        .background(PastelTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(PastelTheme.cardBorder, lineWidth: 1)
        )
    }
}

typealias CyberAssistantCard = PastelAssistantCard

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
    @Environment(ThemeManager.self) private var themeManager
    @Environment(AICoachViewModel.self) private var viewModel
    @Environment(\.colorScheme) private var colorScheme

    @AppStorage(Constants.UserDefaultsKeys.aiCoachTone.rawValue) private var aiTone = "motivational"
    
    @State private var availablePersonas: [AIPersona] = []

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Характер тренера"), footer: Text("Влияет на стиль общения, подсказки и персональные уведомления.")) {
                    if availablePersonas.isEmpty {
                        ProgressView("Загрузка профилей...")
                    } else {
                        Picker("Стиль", selection: $aiTone) {
                            ForEach(availablePersonas) { persona in
                                Text(persona.displayName).tag(persona.id)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(PastelTheme.pastelOat)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        viewModel.clearChat()
                        dismiss()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Очистить историю диалога")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Настройки ИИ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                        .foregroundColor(PastelTheme.pastelOat)
                }
            }
            .task {
                self.availablePersonas = await RemoteConfigManager.shared.getAllPersonas()
            }
        }
    }
}

struct WorkoutConfigSheet: View {
    @Environment(\.colorScheme) private var colorScheme 
    let levels: [(String, WorkoutDifficulty)] = [("Базовый", .beginner), ("Продвинутый", .intermediate), ("Атлет PRO", .advanced)]

    @State private var selectedLevel: WorkoutDifficulty = .intermediate
    @State private var selectedMuscle: CoachMuscleGroup? = nil

    func synergyFor(_ muscle: CoachMuscleGroup) -> String? {
        switch muscle {
        case .chest: return "Трицепс, дельты"
        case .back: return "Бицепс, трапеции"
        case .legs: return "Ягодицы, икры"
        case .shoulders: return nil
        case .arms: return nil
        case .abs: return nil
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                (colorScheme == .dark ? PastelTheme.canvas : Color(UIColor.secondarySystemBackground))
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 28) {

                        Text("Конструктор программы")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(colorScheme == .dark ? PastelTheme.textPrimary : .black) 
                            .padding(.horizontal, 24)
                            .padding(.top, 24)

                        VStack(alignment: .leading, spacing: 14) {
                            Text("Интенсивность")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(PastelTheme.textSecondary)
                                .padding(.horizontal, 24)

                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 10) {
                                    Spacer().frame(width: 14)
                                    ForEach(levels, id: \.0) { level in
                                        let isSelected = selectedLevel == level.1
                                        Button(action: {
                                            HapticManager.shared.impact(.light)
                                            selectedLevel = level.1
                                        }) {
                                            Text(level.0)
                                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                                .padding(.horizontal, 18)
                                                .frame(height: PastelTheme.ButtonMetrics.pillHeight)
                                                .background(isSelected ? PastelTheme.pastelOat : (colorScheme == .dark ? PastelTheme.cardSurface : Color.white))
                                                .foregroundColor(isSelected ? PastelTheme.textOnOat : (colorScheme == .dark ? PastelTheme.textPrimary : .black))
                                                .clipShape(Capsule())
                                                .overlay(Capsule().stroke(isSelected ? Color.clear : PastelTheme.cardBorder, lineWidth: 1))
                                        }
                                    }
                                    Spacer().frame(width: 14)
                                }
                            }
                            .scrollBounceBehavior(.basedOnSize)
                        }

                        VStack(alignment: .leading, spacing: 14) {
                            Text("Целевая мышечная группа")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(PastelTheme.textSecondary)
                                .padding(.horizontal, 24)

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                                ForEach(CoachMuscleGroup.allCases) { muscle in
                                    Button(action: {
                                        HapticManager.shared.impact(.medium)
                                        selectedMuscle = muscle
                                    }) {
                                        VStack(alignment: .leading, spacing: 10) {
                                            HStack {
                                                Text(muscle.rawValue)
                                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                                    .foregroundColor(colorScheme == .dark ? PastelTheme.textPrimary : .black) 

                                                Spacer()

                                                ZStack {
                                                    Circle()
                                                        .fill(colorScheme == .dark ? PastelTheme.cardSurfaceSubtle : Color.black.opacity(0.05)) 
                                                        .frame(width: 28, height: 28)
                                                    Image(systemName: "chevron.right")
                                                        .font(.system(size: 11, weight: .bold))
                                                        .foregroundColor(PastelTheme.pastelLavender)
                                                }
                                            }

                                            if let syn = synergyFor(muscle) {
                                                HStack(spacing: 4) {
                                                    Image(systemName: "link")
                                                        .font(.system(size: 10, weight: .semibold))
                                                    Text(syn)
                                                        .font(.system(size: 11, weight: .medium))
                                                }
                                                .foregroundColor(PastelTheme.pastelSlate)
                                                .lineLimit(1)
                                            } else {
                                                Text("Изолированная")
                                                    .font(.system(size: 11, weight: .medium))
                                                    .foregroundColor(PastelTheme.textMuted)
                                            }
                                        }
                                        .padding(16)
                                        .background(colorScheme == .dark ? PastelTheme.cardSurface : Color.white)
                                        .cornerRadius(18)
                                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(PastelTheme.cardBorder, lineWidth: 1))
                                        .shadow(color: .black.opacity(colorScheme == .dark ? 0.2 : 0.04), radius: 6, y: 2)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 24)
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationBarHidden(true)
            .sheet(item: $selectedMuscle) { m in
                BestExercisesSheet(muscleGroup: m, difficulty: selectedLevel)
                    .presentationDetents([.fraction(0.9), .large])
                    .presentationCornerRadius(35)
                    .presentationDragIndicator(.visible)
            }
        }
    }
}

struct BestExercisesSheet: View {
    @Environment(\.colorScheme) private var colorScheme 
    let muscleGroup: CoachMuscleGroup
    let difficulty: WorkoutDifficulty

    @Environment(DashboardViewModel.self) private var dashboard
    @Environment(WorkoutService.self) private var workoutService
    @Environment(UnitsManager.self) private var unitsManager
    @Environment(DIContainer.self) private var di
    @Environment(\.dismiss) private var dismiss

    @State private var isGenerating = true
    @State private var aiErrorMessage: String? = nil

    @State private var generatedWorkout: GeneratedWorkoutDTO? = nil
    @State private var aiCoachMessage: String = String(localized: "Analyzing biometrics...")
    @State private var estimatedTonnage: Double = 0.0

    @State private var selectedExercise: GeneratedExerciseDTO? = nil
    @State private var isStarting = false
    @State private var isPulsing = false

    private var dummyExercises: [GeneratedExerciseDTO] {
        return (0..<5).map { _ in
            GeneratedExerciseDTO(name: "Loading exercise...", muscleGroup: "Group", type: "Strength", sets: 3, reps: 10, recommendedWeightKg: 50.0, restSeconds: 90)
        }
    }

    var body: some View {
        ZStack {

            (colorScheme == .dark ? Color(UIColor.systemGroupedBackground) : Color(UIColor.secondarySystemBackground)).ignoresSafeArea()

            VStack(spacing: 0) {

                HStack {
                    Text(isGenerating ? "ИИ составляет протокол..." : "Протокол: \(muscleGroup.rawValue)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(colorScheme == .dark ? PastelTheme.textPrimary : .black) 
                    Spacer()
                    if !isGenerating && aiErrorMessage == nil {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(PastelTheme.pastelSage)
                            .font(.title2)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 30)
                .padding(.bottom, 10)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {

                        if !isGenerating {
                            if let errorMsg = aiErrorMessage {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill").foregroundColor(PastelTheme.pastelAmber)
                                    Text(errorMsg).font(.subheadline).foregroundColor(colorScheme == .dark ? .white : .black)
                                    Spacer()
                                }
                                .padding(16)
                                .background(PastelTheme.pastelAmber.opacity(0.12))
                                .cornerRadius(16)
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(PastelTheme.pastelAmber.opacity(0.3), lineWidth: 1))
                            } else {
                                let msg = generatedWorkout?.aiMessage ?? aiCoachMessage
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: "brain.head.profile")
                                        .font(.title2)
                                        .foregroundStyle(PastelTheme.pastelLavender)

                                    Text(msg)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(colorScheme == .dark ? PastelTheme.textPrimary : .black) 
                                        .lineSpacing(4)
                                    Spacer()
                                }
                                .padding(16)
                                .background(colorScheme == .dark ? PastelTheme.cardSurface : Color.white)
                                .cornerRadius(16)
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(PastelTheme.cardBorder, lineWidth: 1))
                                .shadow(color: .black.opacity(colorScheme == .dark ? 0.2 : 0.05), radius: 5, y: 2)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }

                        if aiErrorMessage == nil {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Расчётный объём").font(.system(size: 12, weight: .bold)).foregroundColor(PastelTheme.textSecondary)
                                    Text("\(Int(estimatedTonnage)) \(unitsManager.weightUnitString())")
                                        .font(.system(size: 20, weight: .black, design: .rounded).monospacedDigit())
                                        .foregroundColor(PastelTheme.pastelLavender)
                                        .contentTransition(.numericText())
                                }
                                Spacer()
                                Divider().background(PastelTheme.separator).frame(height: 30)
                                Spacer()
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("Сложность").font(.system(size: 12, weight: .bold)).foregroundColor(PastelTheme.textSecondary)
                                    Text(difficulty.rawValue).font(.system(size: 16, weight: .bold, design: .rounded)).foregroundColor(PastelTheme.pastelSlate)
                                }
                            }
                            .padding(20)
                            .background(colorScheme == .dark ? PastelTheme.cardSurface : Color.white)
                            .cornerRadius(20)
                            .overlay(RoundedRectangle(cornerRadius: 20).stroke(PastelTheme.cardBorder, lineWidth: 1))
                            .shadow(color: .black.opacity(colorScheme == .dark ? 0.2 : 0.05), radius: 5, y: 2)
                            .redacted(reason: isGenerating ? .placeholder : [])
                            .opacity(isGenerating ? (isPulsing ? 0.6 : 1.0) : 1.0)
                        }

                        if isGenerating {
                            ForEach(Array(dummyExercises.enumerated()), id: \.offset) { index, dummy in
                                AIExerciseRowView(index: index, exercise: dummy, unitsManager: unitsManager) { }
                                    .redacted(reason: .placeholder)
                                    .scaleEffect(isPulsing ? 1.02 : 0.98)
                                    .opacity(isPulsing ? 0.5 : 1.0)
                                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true).delay(Double(index) * 0.1), value: isPulsing)
                            }
                        } else if let workout = generatedWorkout, !workout.exercises.isEmpty {
                            ForEach(Array(workout.exercises.enumerated()), id: \.offset) { index, dto in
                                AIExerciseRowView(index: index, exercise: dto, unitsManager: unitsManager) {
                                    HapticManager.shared.impact(.medium)
                                    selectedExercise = dto
                                }
                                .transition(.opacity.combined(with: .scale))
                            }
                        } else if !isGenerating {
                            Text("Не удалось составить программу. Попробуйте снова.")
                                .foregroundColor(PastelTheme.textSecondary)
                                .padding(.top, 20)
                        }

                        if !isGenerating && generatedWorkout != nil && !(generatedWorkout?.exercises.isEmpty ?? true) {
                            Button(action: startGeneratedWorkout) {
                                HStack(spacing: 8) {
                                    if isStarting {
                                        ProgressView().tint(PastelTheme.textOnOat)
                                    } else {
                                        Text("Начать тренировку").font(.system(size: 16, weight: .bold, design: .rounded))
                                        Image(systemName: "bolt.fill")
                                    }
                                }
                                .foregroundColor(PastelTheme.textOnOat)
                                .frame(maxWidth: .infinity)
                                .frame(height: PastelTheme.ButtonMetrics.heroHeight)
                                .background(PastelTheme.pastelOat)
                                .clipShape(RoundedRectangle(cornerRadius: PastelTheme.ButtonMetrics.heroRadius, style: .continuous))
                                .shadow(color: PastelTheme.pastelOat.opacity(0.18), radius: 10, y: 3)
                            }
                            .padding(.top, 10)
                            .buttonStyle(ParallaxButtonStyle())
                            .disabled(isStarting)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
        }
        .onAppear { isPulsing = true }
        .task { await generateRealAIRoutine() }
        .sheet(item: Binding(
            get: { selectedExercise.map { IdentifiableGeneratedEx(dto: $0) } },
            set: { selectedExercise = $0?.dto }
        )) { wrapper in
            let tempDTO = ExerciseDTO(name: wrapper.dto.name, muscleGroup: wrapper.dto.muscleGroup, type: .strength, category: .other, effort: 8, isCompleted: false)
            ExerciseTechniqueSheet(exercise: tempDTO)
                .presentationDetents([.medium])
                .presentationCornerRadius(35)
                .presentationDragIndicator(.visible)
        }
    }

    private func generateRealAIRoutine() async {
        await MainActor.run {
            self.isGenerating = true
            self.aiErrorMessage = nil
            self.generatedWorkout = nil
        }

        let appLanguage = LocalizationHelper.shared.getAILanguageName()
        let userName = UserDefaults.standard.string(forKey: Constants.UserDefaultsKeys.userName.rawValue) ?? ""

        let relevantExercises = await ExerciseDatabaseService.shared.getRelevantExercisesContext(
            for: muscleGroup.engineName,
            equipmentPref: "full gym",
            limit: 20
        )

        let savedRecoveryHours = UserDefaults.standard.double(forKey: Constants.UserDefaultsKeys.userRecoveryHours.rawValue)
        let fullRecoveryHours = savedRecoveryHours > 0 ? savedRecoveryHours : 48.0
        let workouts = await di.analyticsService.fetchRecentWorkoutsForAnalytics()
        let recoveryStatus = await di.analyticsService.calculateRecovery(hours: fullRecoveryHours, workouts: workouts)
        let fatigued = recoveryStatus.filter { $0.recoveryPercentage < 50 }.map { $0.muscleGroup }

        do {
            let response = try await di.aiLogicService.generateBuilderRoutine(
                muscleGroup: muscleGroup.rawValue,
                difficulty: difficulty.rawValue,
                availableExercises: relevantExercises,
                weightUnit: unitsManager.weightUnitString(),
                language: appLanguage,
                userName: userName,
                fatiguedMuscles: fatigued
            )

            await MainActor.run {
                if let workout = response.workout, !workout.exercises.isEmpty {
                    self.generatedWorkout = workout
                    self.aiCoachMessage = response.text

                    var tonnage = 0.0
                    for ex in workout.exercises {
                        let w = ex.recommendedWeightKg ?? 0.0
                        let s = Double(ex.sets)
                        let r = Double(ex.reps)
                        tonnage += w * s * r
                    }
                    self.estimatedTonnage = unitsManager.convertFromKilograms(tonnage)
                } else {
                    self.aiErrorMessage = String(localized: "The AI responded, but forgot to add exercises. Click Cancel and try again.")
                }
                withAnimation(.easeOut(duration: 0.4)) { self.isGenerating = false }
            }
        } catch {
            await MainActor.run {
                self.aiErrorMessage = String(localized: "Communication error with AI: \(error.localizedDescription)")
                withAnimation(.easeOut(duration: 0.4)) { self.isGenerating = false }
            }
        }
    }

    private func startGeneratedWorkout() {
        guard !isStarting, let dto = generatedWorkout else { return }
        isStarting = true
        HapticManager.shared.impact(.heavy)

        Task {
            await workoutService.startGeneratedWorkout(dto)
            if let newWorkout = await workoutService.fetchLatestWorkout() {
                di.appState.returnToActiveWorkoutId = newWorkout.persistentModelID
                di.appState.selectedTab = 2 
            }
            dismiss()
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
                        Text(exercise != nil ? LocalizationHelper.shared.translateName(exercise!.name) : "Подбор упражнения...")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(colorScheme == .dark ? PastelTheme.textPrimary : .black) 
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        Text(exercise?.muscleGroup ?? "Мышечная группа")
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
                        Text(w > 0 ? "\(Int(w)) \(unitsManager.weightUnitString())" : "Свой вес")
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
                        Text(LocalizationHelper.shared.translateName(exercise?.name ?? "Упражнение"))
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(colorScheme == .dark ? PastelTheme.textPrimary : .black) 
                            .lineLimit(1)
                        Text(exercise?.type.rawValue ?? "Тип")
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
                        Text(w > 0 ? "\(Int(w)) \(unitsManager.weightUnitString())" : "Свой вес")
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
                            Text("Правильная техника").font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundColor(PastelTheme.textSecondary)
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
                            Text("Советы по технике")
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

    @Query(filter: #Predicate<Workout> { $0.endTime != nil }, sort: \.date, order: .reverse)
    private var allWorkouts: [Workout]

    let periods = ["Last 7 days", "Mesocycle (4 weeks)", "Macrocycle (12 weeks))"]
    let focuses = ["Muscle Imbalances, Growth Leaders"]

    @State private var selectedPeriod = "Mesocycle (4 weeks)"
    @State private var selectedFocus = "Muscle imbalance"

    @State private var stats: [MuscleStats] = []
    @State private var activeSegment: UUID? = nil

    @State private var isAnalyzing = true
    @State private var impulseValue: Int = 0
    @State private var impulseMuscle: String = "Breast"
    @State private var aiConclusion: String = "A neural network analyzes your muscle balance..."

    @State private var appearAnimate = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {

                (colorScheme == .dark ? Color(UIColor.systemGroupedBackground) : Color(UIColor.secondarySystemBackground)).ignoresSafeArea()

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
            Text("Сбор данных из базы...").font(.headline).foregroundColor(PastelTheme.textSecondary)
        }
        .frame(maxWidth: .infinity).padding(.top, 100)
    }

    private var emptyDataView: some View {
        EmptyStateView(
            icon: "chart.pie.fill",
            title: "Недостаточно данных",
            message: "Для формирования аналитики проведите ещё несколько тренировок."
        )
        .padding(.top, 50)
    }

    @ViewBuilder
    private var aiPredictorSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "cpu").foregroundColor(PastelTheme.pastelLavender)
                Text("ИИ-прогноз").font(.caption.bold()).foregroundColor(PastelTheme.textSecondary)
            }
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Импульс объёма").font(.system(size: 14, weight: .medium)).foregroundColor(PastelTheme.textSecondary)
                    HStack(alignment: .firstTextBaseline) {
                        Text(impulseValue > 0 ? "+\(impulseValue)%" : "\(impulseValue)%")
                            .font(.system(size: 38, weight: .black, design: .rounded).monospacedDigit())
                            .foregroundColor(impulseValue > 0 ? PastelTheme.pastelSage : (impulseValue < 0 ? PastelTheme.pastelPeach : PastelTheme.textSecondary))
                            .contentTransition(.numericText())
                        Text("к тоннажу").font(.system(size: 16, weight: .bold)).foregroundColor(colorScheme == .dark ? PastelTheme.textPrimary : .black)
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
            Text("На основе тренировочных данных возможен прирост силовых показателей в группе: **\(impulseMuscle)**.")
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
            Text("Детальная аналитика").font(.caption.bold()).foregroundColor(PastelTheme.textSecondary).padding(.horizontal, 24)
            VStack(spacing: 2) {
                Menu {
                    ForEach(periods, id: \.self) { p in
                        Button(p) { selectedPeriod = p }
                    }
                } label: {
                    HStack {
                        Text("Период").foregroundColor(PastelTheme.textSecondary)
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
                        Text("Акцент").foregroundColor(PastelTheme.textSecondary)
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
            Text("Заключение ИИ").font(.caption.bold()).foregroundColor(PastelTheme.pastelLavender).padding(.horizontal, 24)

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
                Text("Анализ прогресса")
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
        case "Last 7 days": days = 7
        case "Mesocycle (4 weeks)": days = 28
        case "Macrocycle (12 weeks)": days = 84
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
        Analyze the provided data and write a short, motivating, and direct conclusion/advice in RUSSIAN (2-3 sentences maximum).
        Point out obvious imbalances or praise focus. Do not use Markdown formatting (no asterisks or bold).
        """

        let userContext = UserProfileContext(userName: "Athlete", weightKg: 80, experienceLevel: "Pro", favoriteMuscles: [], recentPRs: [:], language: "Russian", workoutsThisWeek: 0, currentStreak: 0, fatiguedMuscles: [], availableExercises: [], aiCoachTone: "Strict", weightUnit: "kg")

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
                self.aiConclusion = "Unable to connect to the server. But judging by the numbers, you should pay attention to your lagging muscle groups.."
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
        default: return englishName
        }
    }
}

struct RestAnalysisSheet: View {
    @AppStorage("hasSleepData") private var hasSleepData = false
    @AppStorage("sleepHours") private var sleepHours: Double = 7.5
    @AppStorage("waterCups") private var waterCups: Int = 4
    @AppStorage("cnsScore") private var cnsScore: Double = 85.0
    @Environment(\.colorScheme) private var colorScheme 

    var cnsLoad: Double {
        let sleepFactor = max(0, (8.0 - sleepHours) * 10)
        let waterFactor = max(0, (8 - waterCups) * 2)
        return min(100, 20 + sleepFactor + Double(waterFactor))
    }
    var cnsColor: Color {
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
                            Text("Оценка утомления ЦНС")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(PastelTheme.textSecondary)

                            ZStack {
                                Circle()
                                    .stroke(colorScheme == .dark ? PastelTheme.cardBorder : Color.black.opacity(0.06), lineWidth: 14)
                                    .frame(width: 150, height: 150)
                                Circle()
                                    .trim(from: 0, to: cnsLoad / 100)
                                    .stroke(cnsColor, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                                    .frame(width: 150, height: 150)
                                    .rotationEffect(.degrees(-90))
                                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: cnsLoad)

                                VStack(spacing: 4) {
                                    Text("\(Int(cnsLoad))%")
                                        .font(.system(size: 34, weight: .black, design: .rounded).monospacedDigit())
                                        .foregroundColor(colorScheme == .dark ? PastelTheme.textPrimary : .black)
                                        .contentTransition(.numericText())
                                    Text(cnsLoad < 40 ? "Низкое" : (cnsLoad < 75 ? "Умеренное" : "Высокое"))
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundColor(cnsColor)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 10)

                        VStack(alignment: .leading, spacing: 14) {
                            Text("Биометрия")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(PastelTheme.textSecondary)
                                .padding(.horizontal, 24)

                            VStack(spacing: 12) {
                                HStack {
                                    Image(systemName: "moon.zzz.fill")
                                        .foregroundColor(PastelTheme.pastelLavender)
                                    Text("Сон прошлой ночью")
                                        .font(.system(size: 15, weight: .medium, design: .rounded))
                                        .foregroundColor(colorScheme == .dark ? PastelTheme.textPrimary : .black)
                                    Spacer()
                                    Text(hasSleepData ? String(format: "%.1f ч", sleepHours) : "— ч")
                                        .font(.system(size: 17, weight: .bold, design: .rounded).monospacedDigit())
                                        .foregroundColor(PastelTheme.pastelLavender)
                                }
                                Slider(value: $sleepHours, in: 3...12, step: 0.5) { _ in
                                    HapticManager.shared.selection()
                                    hasSleepData = true
                                    updateCNS()
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
                                    Text("Вода за день (стаканы)")
                                        .font(.system(size: 15, weight: .medium, design: .rounded))
                                        .foregroundColor(colorScheme == .dark ? PastelTheme.textPrimary : .black)
                                    Spacer()
                                    Text("\(waterCups)")
                                        .font(.system(size: 17, weight: .bold, design: .rounded).monospacedDigit())
                                        .foregroundColor(PastelTheme.pastelSlate)
                                }
                                Slider(value: Binding(get: { Double(waterCups) }, set: { waterCups = Int($0) }), in: 0...15, step: 1) { _ in
                                    HapticManager.shared.selection()
                                    updateCNS()
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
                            Text("Рекомендации по восстановлению")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(PastelTheme.textSecondary)
                                .padding(.horizontal, 24)

                            HStack(spacing: 10) {
                                if cnsLoad < 40 {
                                    RecoveryBadge(icon: "flame.fill", text: "Сложные углеводы", color: PastelTheme.pastelAmber)
                                    RecoveryBadge(icon: "figure.walk", text: "Лёгкая прогулка", color: PastelTheme.pastelSage)
                                } else if cnsLoad < 75 {
                                    RecoveryBadge(icon: "snowflake", text: "Контрастный душ", color: PastelTheme.pastelSlate)
                                    RecoveryBadge(icon: "bed.double.fill", text: "Дневной сон (20 мин)", color: PastelTheme.pastelLavender)
                                } else {
                                    RecoveryBadge(icon: "thermometer.sun.fill", text: "Сауна", color: PastelTheme.pastelPeach)
                                    RecoveryBadge(icon: "figure.mind.and.body", text: "МФР и растяжка", color: PastelTheme.pastelSlate)
                                }
                            }
                            .padding(.horizontal, 24)
                        }

                        Text("Показатели утомления и рекомендации носят ориентировочный характер и рассчитываются на основе введённых данных.")
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
                        Text("Восстановление")
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
    private func updateCNS() { cnsScore = 100 - cnsLoad }
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
                UnavailableMetricView(icon: "waveform.path.ecg", text: "Нет данных")
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
