

internal import SwiftUI

struct AIWeeklyReviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme 

    let currentStats: PeriodStats
    let previousStats: PeriodStats
    let weakPoints: [WeakPoint]
    let recentPRs: [PersonalRecord]

    private let aiLogicService: AILogicService

    @State private var isAnalyzing = false
    @State private var reviewData: AIWeeklyReviewDTO? = nil
    @State private var errorText: String? = nil

    init(currentStats: PeriodStats, previousStats: PeriodStats, weakPoints: [WeakPoint], recentPRs: [PersonalRecord], aiLogicService: AILogicService) {
        self.currentStats = currentStats
        self.previousStats = previousStats
        self.weakPoints = weakPoints
        self.recentPRs = recentPRs
        self.aiLogicService = aiLogicService
    }

    var body: some View {
        ZStack {

            (colorScheme == .dark ? themeManager.current.background : Color(UIColor.secondarySystemBackground))
                .ignoresSafeArea()

            MoodBackgroundView(mood: reviewData?.coachMood ?? "neutral")

            VStack(spacing: 0) {
                header

                if let data = reviewData {
                    ReviewDashboardView(data: data)
                } else if isAnalyzing {
                    analyzingView
                } else if let error = errorText {
                    errorView(error)
                } else {
                    initialStateView
                }
            }
        }
        .presentationDetents([.large]) 
        .presentationDragIndicator(.hidden)
    }

    private var header: some View {
        HStack {
            Image(systemName: "sparkles")
                .foregroundColor(colorScheme == .dark ? themeManager.current.primaryText : .black) 
            Text(LocalizedStringKey("AI Weekly Brief"))
                .font(.system(.title3, design: .rounded, weight: .heavy))
                .foregroundColor(colorScheme == .dark ? themeManager.current.primaryText : .black) 

            Spacer()

            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary, Color(UIColor.tertiarySystemFill))
            }
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .zIndex(10)
    }

    private var initialStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                Circle()
                    .fill(themeManager.current.primaryAccent.opacity(0.1))
                    .frame(width: 120, height: 120)
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 60))
                    .foregroundStyle(themeManager.current.premiumGradient)
                    .shadow(color: themeManager.current.primaryAccent.opacity(0.4), radius: 20, y: 10)
            }

            VStack(spacing: 8) {
                Text(LocalizedStringKey("Ready for your review?"))
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundColor(colorScheme == .dark ? themeManager.current.primaryText : .black) 

                Text(LocalizedStringKey("The AI Coach will analyze your volume, PRs, and weak points to generate a personalized action plan."))
                    .font(.subheadline)
                    .foregroundColor(colorScheme == .dark ? themeManager.current.secondaryText : .gray) 
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            }

            Spacer()

            Button { generateReview() } label: {
                HStack {
                    Image(systemName: "bolt.fill")
                    Text(LocalizedStringKey("Analyze My Week")).bold()
                }
                .font(.title3)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(themeManager.current.primaryAccent)

                .foregroundColor(colorScheme == .dark ? themeManager.current.background : .white)
                .clipShape(Capsule())
                .shadow(color: themeManager.current.primaryAccent.opacity(0.4), radius: 15, y: 8)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 30)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }

    private var analyzingView: some View {
        VStack(spacing: 30) {
            Spacer()
            ZStack {
                Circle()
                    .fill(themeManager.current.primaryAccent.opacity(0.2))
                    .frame(width: 100, height: 100)
                    .modifier(PulsatingGlowEffect())

                Image(systemName: "cpu")
                    .font(.system(size: 40))
                    .foregroundColor(colorScheme == .dark ? themeManager.current.primaryText : .black) 
            }
            Text(LocalizedStringKey("Crunching the numbers..."))
                .font(.system(.headline, design: .rounded))
                .foregroundColor(colorScheme == .dark ? themeManager.current.primaryText : .black) 
                .modifier(BlinkingTextModifier())
            Spacer()
        }
        .transition(.opacity)
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.red)
            Text(LocalizedStringKey("Analysis Failed"))
                .font(.headline)
                .foregroundColor(colorScheme == .dark ? .white : .black) 
            Text(error)
                .font(.caption)
                .foregroundColor(colorScheme == .dark ? themeManager.current.secondaryText : .gray) 
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Spacer()
        }
        .transition(.opacity)
    }

    private func generateReview() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        withAnimation(.easeInOut(duration: 0.3)) { isAnalyzing = true }

        Task {
            let context = buildStatsContext()
            let lang = Locale.current.language.languageCode?.identifier == "ru" ? "Russian" : "English"

            do {
                let dto = try await aiLogicService.generatePerformanceReview(statsContext: context, language: lang)
                await MainActor.run {
                    let successGen = UINotificationFeedbackGenerator()
                    successGen.notificationOccurred(.success)
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        self.reviewData = dto
                        self.isAnalyzing = false
                    }
                }
            } catch {
                await MainActor.run {
                    withAnimation {
                        self.errorText = error.localizedDescription
                        self.isAnalyzing = false
                    }
                }
            }
        }
    }

    private func buildStatsContext() -> String {
        let safeUnits = UnitsManager.shared.weightUnitString()
        let prNames = recentPRs.isEmpty ? "None" : recentPRs.map { "\($0.exerciseName) (\(Int($0.weight)) \(safeUnits))" }.joined(separator: ", ")
        let weakNames = weakPoints.isEmpty ? "None" : weakPoints.map { $0.muscleGroup }.joined(separator: ", ")

        return """
            THIS WEEK: \(currentStats.workoutCount) workouts, \(Int(currentStats.totalVolume)) \(safeUnits) total volume.
            PREVIOUS WEEK: \(previousStats.workoutCount) workouts, \(Int(previousStats.totalVolume)) \(safeUnits) total volume.
            NEW PERSONAL RECORDS THIS WEEK: \(prNames).
            IDENTIFIED WEAK POINTS: \(weakNames).
            """
    }
}

struct ReviewDashboardView: View {
    let data: AIWeeklyReviewDTO
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme 

    @State private var showGauge = false
    @State private var showTitle = false
    @State private var showTopRow = false
    @State private var showBottomRow = false

    private var moodColor: Color {
        switch data.coachMood.lowercased() {
        case "fire": return .orange
        case "ice": return .cyan
        case "warning": return .yellow
        default: return themeManager.current.primaryAccent
        }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 20) {

                VStack(spacing: 12) {
                    ScoreGaugeView(score: data.weeklyScore, color: moodColor, triggerAnimation: showGauge)
                        .frame(width: 180, height: 180)

                    if showTitle {
                        Text(data.title)
                            .font(.system(size: 28, weight: .heavy, design: .rounded))
                            .foregroundColor(colorScheme == .dark ? themeManager.current.primaryText : .black) 
                            .multilineTextAlignment(.center)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(.vertical, 20)

                if showTopRow {
                    Grid(horizontalSpacing: 16, verticalSpacing: 16) {
                        GridRow {
                            BentoInsightCard(
                                title: "Highlight",
                                icon: "star.fill",
                                color: .green,
                                content: data.topHighlight
                            )

                            BentoInsightCard(
                                title: "Attention",
                                icon: "exclamationmark.triangle.fill",
                                color: .red,
                                content: data.weakPointAlert
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                if showBottomRow {
                    BentoInsightCard(
                        title: "Coach Advice",
                        icon: "brain.head.profile",
                        color: moodColor,
                        content: data.coachAdvice
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .onAppear { animateIn() }
    }

    private func animateIn() {
        withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) { showGauge = true }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let gen = UIImpactFeedbackGenerator(style: .light); gen.impactOccurred()
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) { showTitle = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let gen = UIImpactFeedbackGenerator(style: .rigid); gen.impactOccurred()
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) { showTopRow = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            let gen = UIImpactFeedbackGenerator(style: .medium); gen.impactOccurred()
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) { showBottomRow = true }
        }
    }
}

struct ScoreGaugeView: View {
    let score: Int
    let color: Color
    let triggerAnimation: Bool

    @State private var animatedScore: Int = 0
    @State private var animatedProgress: CGFloat = 0.0
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme 

    var body: some View {
        ZStack {

            Circle()
                .fill(color.opacity(0.15))
                .blur(radius: 20)

            Circle()
                .stroke(Color.gray.opacity(0.15), lineWidth: 16)

            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    AngularGradient(colors: [color.opacity(0.5), color], center: .center, startAngle: .degrees(-90), endAngle: .degrees(270)),
                    style: StrokeStyle(lineWidth: 16, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 4) {
                Text(LocalizedStringKey("SCORE"))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(colorScheme == .dark ? themeManager.current.secondaryText : .gray) 

                Text("\(animatedScore)")
                    .font(.system(size: 54, weight: .heavy, design: .rounded))
                    .foregroundColor(colorScheme == .dark ? themeManager.current.primaryText : .black) 
                    .contentTransition(.numericText())
            }
        }
        .onChange(of: triggerAnimation) { _, newValue in
            if newValue {
                withAnimation(.spring(response: 1.5, dampingFraction: 0.8)) {
                    animatedProgress = CGFloat(score) / 100.0
                }
                withAnimation(.easeOut(duration: 1.5)) {
                    animatedScore = score
                }
            }
        }
    }
}

struct BentoInsightCard: View {
    let title: LocalizedStringKey
    let icon: String
    let color: Color
    let content: String
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme 

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.2))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(color)
                }
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(colorScheme == .dark ? themeManager.current.secondaryText : .gray) 
                    .textCase(.uppercase)
            }

            Text(content)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(colorScheme == .dark ? themeManager.current.primaryText : .black) 
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(20)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(.ultraThinMaterial) 
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(

                    colorScheme == .dark
                    ? LinearGradient(colors: [color.opacity(0.5), Color.clear], startPoint: .topLeading, endPoint: .bottomTrailing)
                    : LinearGradient(colors: [color.opacity(0.3), Color.black.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.05 : 0.1), radius: 10, y: 5) 
    }
}

struct MoodBackgroundView: View {
    let mood: String
    @State private var animateBg = false
    @Environment(\.colorScheme) private var colorScheme 

    private var moodColors: [Color] {
        switch mood {
        case "fire": return [.red, .orange]
        case "ice": return [.cyan, .blue]
        case "warning": return [.yellow, .orange]
        default: return [.purple, .indigo]
        }
    }

    var body: some View {
        ZStack {

            (colorScheme == .dark ? Color(hex: "0A0A0A") : Color(UIColor.secondarySystemBackground))
                .ignoresSafeArea()

            Circle()
                .fill(moodColors[0].opacity(colorScheme == .dark ? 0.25 : 0.15)) 
                .frame(width: 400, height: 400)
                .blur(radius: 80)
                .offset(x: animateBg ? 100 : -100, y: animateBg ? -150 : -250)

            Circle()
                .fill(moodColors[1].opacity(colorScheme == .dark ? 0.25 : 0.15))
                .frame(width: 350, height: 350)
                .blur(radius: 80)
                .offset(x: animateBg ? -150 : 150, y: animateBg ? 200 : 100)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 5).repeatForever(autoreverses: true)) {
                animateBg = true
            }
        }
    }
}

struct PulsatingGlowEffect: ViewModifier {
    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 0.5
    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    scale = 1.3
                    opacity = 0.1
                }
            }
    }
}

struct BlinkingTextModifier: ViewModifier {
    @State private var isBlinking = false
    func body(content: Content) -> some View {
        content
            .opacity(isBlinking ? 0.4 : 1.0)
            .onAppear { withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { isBlinking = true } }
    }
}
