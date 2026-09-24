internal import SwiftUI
import SwiftData
import Charts
import ActivityKit
import Combine

@Observable
@MainActor
final class OverviewRouter {
    var path = NavigationPath()
    var activeSheet: SheetDestination? = nil

    enum SheetDestination: Identifiable {
        case settings
        case addWorkout
        case muscleColor
        case profile
        case bodyAnalysis(BodyAnalysisReport)

        var id: String {
            switch self {
            case .settings: return "settings"
            case .addWorkout: return "addWorkout"
            case .muscleColor: return "muscleColor"
            case .profile: return "profile"
            case .bodyAnalysis: return "bodyAnalysis"
            }
        }
    }

    enum RouteDestination: Hashable {
        case workoutDetail(Workout)
        case exercises
        case detailedRecovery
        case calendar
        case exerciseDetail(String)
    }

    func push(_ route: RouteDestination) { path.append(route) }
    func present(_ sheet: SheetDestination) { activeSheet = sheet }
    func dismissSheet() { activeSheet = nil }
}

struct OverviewView: View {
    typealias VitalsMonitor = WorkoutTracker.VitalsMonitor
    @Environment(\.colorScheme) private var colorScheme
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.modelContext) private var context
    @Environment(WorkoutService.self) var workoutService
    @Environment(DashboardViewModel.self) var dashboardViewModel
    @Environment(UserStatsViewModel.self) var userStatsViewModel
    @Environment(DIContainer.self) private var di

    @AppStorage("userGender") private var userGender = "male"
    @AppStorage("cnsScore") private var cnsScore: Double = 85.0
    @AppStorage("userRecoveryHours") private var storedRecoveryHours: Double = 48.0
    @AppStorage("hasSeenCommitmentSheet") private var hasSeenCommitmentSheet = false

    @Query(sort: \Workout.date, order: .reverse) private var recentWorkouts: [Workout]

    @State private var router = OverviewRouter()
    @State private var isFrontView = true
    @State private var vitals = VitalsMonitor()
    @State private var showCommitmentSheet = false
    @State private var showCNSSheet = false

    var body: some View {
        NavigationStack(path: $router.path) {
            ZStack {
                PastelTheme.canvas.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        
                        // 1. Header with greeting, date, streak, calendar and profile
                        OverviewHeaderView(
                            streakDays: dashboardViewModel.streakCount,
                            onCalendarTap: { router.push(.calendar) },
                            onProfileTap: { router.present(.profile) }
                        )

                        // 2. Centerpiece: Muscle Readiness Anatomy with Body Analysis CTA
                        OverviewAnatomyCard(
                            isFrontView: $isFrontView,
                            cnsScore: cnsScore,
                            recoveryDict: recoveryDict,
                            userGender: userGender,
                            isLocked: recentWorkouts.isEmpty,
                            recentWorkouts: recentWorkouts,
                            onBodyAnalysisTap: {
                                let report = BodyAnalysisEngine.generateReport(
                                    cnsScore: cnsScore,
                                    recoveryDict: recoveryDict,
                                    recentWorkouts: recentWorkouts,
                                    fullRecoveryHours: storedRecoveryHours
                                )
                                router.present(.bodyAnalysis(report))
                            },
                            onSettingsTap: {
                                router.present(.settings)
                            }
                        )

                        // 3. Compact Vitals Row: CNS, Heart Rate, Water (AppGroup Sync)
                        OverviewVitalsRowView(
                            cnsScore: cnsScore,
                            heartRate: vitals.currentBPM,
                            waterLiters: dashboardViewModel.todayWaterLiters,
                            onCNSTap: {
                                showCNSSheet = true
                            }
                        )

                        // 4. Today's Training Focus & Recommendation (Derived from live body readiness)
                        let dailyReport = BodyAnalysisEngine.generateReport(
                            cnsScore: cnsScore,
                            recoveryDict: recoveryDict,
                            recentWorkouts: recentWorkouts,
                            fullRecoveryHours: storedRecoveryHours
                        )

                        OverviewDailyFocusCard(
                            report: dailyReport,
                            onGoToWorkout: {
                                di.appState.selectedTab = 2
                            },
                            onOpenCatalog: {
                                router.push(.exercises)
                            }
                        )

                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(for: OverviewRouter.RouteDestination.self) { route in
                switch route {
                case .workoutDetail(let workout):
                    WorkoutDetailView(workout: workout, viewModel: di.makeWorkoutDetailViewModel())
                case .exercises:
                    ExerciseView()
                case .detailedRecovery:
                    DetailedRecoveryView()
                case .calendar:
                    WorkoutCalendarView()
                case .exerciseDetail(let name):
                    ExerciseHistoryView(exerciseName: name)
                }
            }
            .sheet(item: $router.activeSheet) { sheet in
                switch sheet {
                case .settings:
                    SettingsView()
                case .profile:
                    ProfileView().environment(userStatsViewModel.progressManager)
                case .bodyAnalysis(let report):
                    BodyAnalysisReportView(report: report)
                case .addWorkout:
                    AddWorkoutView(onWorkoutCreated: {
                        Task { @MainActor in
                            var desc = FetchDescriptor<Workout>(sortBy: [SortDescriptor(\.date, order: .reverse)])
                            desc.fetchLimit = 1
                            if let newWorkout = try? context.fetch(desc).first {
                                router.push(.workoutDetail(newWorkout))
                            }
                        }
                    })
                case .muscleColor:
                    MuscleColorSettingsView()
                }
            }
            .sheet(isPresented: $showCommitmentSheet) {
                FutureSelfCommitmentSheet {
                    hasSeenCommitmentSheet = true
                    showCommitmentSheet = false
                }
                .presentationDetents([.fraction(0.55)])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showCNSSheet) {
                CNSExplanationSheet(cnsScore: cnsScore)
                    .presentationDetents([.height(340)])
                    .presentationDragIndicator(.visible)
            }
            .onAppear {
                vitals.startMonitoring()
                dashboardViewModel.refreshAllCaches()
                if recentWorkouts.isEmpty && !hasSeenCommitmentSheet {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        showCommitmentSheet = true
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var recoveryDict: [String: Int] {
        var dict = [String: Int]()
        for status in dashboardViewModel.recoveryStatus {
            dict[status.muscleGroup] = status.recoveryPercentage
        }
        return dict
    }
}

// MARK: - Vitals Observation
@Observable
final class VitalsMonitor {
    var currentBPM: Double = 0.0
    var lastUpdated: Date? = nil

    var timeAgoText: String {
        guard let date = lastUpdated else { return "No data" }
        let minutes = Int(Date().timeIntervalSince(date) / 60)
        if minutes == 0 { return "Just now" }
        if minutes < 60 { return "" }
        let hours = minutes / 60
        return "\(hours) h back"
    }

    func startMonitoring() {
        Task {
            try? await HealthKitManager.shared.requestAuthorization()

            if let initial = try? await HealthKitManager.shared.fetchLatestHeartRate() {
                await MainActor.run {
                    self.currentBPM = initial.value
                    self.lastUpdated = initial.date
                }
            }

            await HealthKitManager.shared.startHeartRateObservation { hrValue, date in
                Task { @MainActor in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        self.currentBPM = hrValue
                        self.lastUpdated = date
                    }
                }
            }
        }
    }
}

// MARK: - Future Self Commitment Sheet
struct FutureSelfCommitmentSheet: View {
    let onCommit: () -> Void
    @State private var appear = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "figure.mind.and.body")
                .font(.system(size: 48))
                .foregroundStyle(PastelTheme.pastelSlate)
                .padding(.top, 16)

            VStack(spacing: 6) {
                Text("Your Future Self is Waiting")
                    .font(.title3.bold())
                    .foregroundStyle(PastelTheme.textPrimary)

                Text("A goal without a timeline is just a wish. When are we starting your first workout?")
                    .font(.subheadline)
                    .foregroundStyle(PastelTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            VStack(spacing: 10) {
                CommitmentButton(title: "Tonight", icon: "moon.stars.fill") { onCommit() }
                CommitmentButton(title: "Tomorrow Morning", icon: "sun.max.fill") { onCommit() }
                CommitmentButton(title: "This Weekend", icon: "calendar.badge.clock") { onCommit() }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            Spacer()
        }
        .background(PastelTheme.canvas.ignoresSafeArea())
        .opacity(appear ? 1 : 0)
        .offset(y: appear ? 0 : 20)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) { appear = true }
        }
    }
}

struct CommitmentButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        }) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(PastelTheme.pastelSlate)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PastelTheme.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2.bold())
                    .foregroundStyle(PastelTheme.textTertiary)
            }
            .padding(16)
            .background(PastelTheme.cardSurface)
            .clipShape(RoundedRectangle(cornerRadius: PastelTheme.buttonRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: PastelTheme.buttonRadius, style: .continuous)
                    .stroke(PastelTheme.cardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - CNS Explanation Sheet (Calm & Sports Science)
struct CNSExplanationSheet: View {
    let cnsScore: Double
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                PastelTheme.canvas.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Central Nervous System")
                                .font(.headline)
                                .foregroundStyle(PastelTheme.textPrimary)
                            Text("Autonomic readiness evaluation")
                                .font(.caption)
                                .foregroundStyle(PastelTheme.textSecondary)
                        }

                        Spacer()

                        Text("\(Int(cnsScore))%")
                            .font(.title2.bold())
                            .foregroundStyle(PastelTheme.pastelLavender)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(PastelTheme.cardSurface)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(PastelTheme.cardBorder, lineWidth: 1))
                    }

                    Text("The CNS Index reflects the balance between sympathetic (fight-or-flight) and parasympathetic (recovery) nervous pathways. It is calculated using Heart Rate Variability (HRV), resting heart rate, and sleep duration.")
                        .font(.subheadline)
                        .lineSpacing(4)
                        .foregroundStyle(PastelTheme.textSecondary)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(cnsScore >= 80 ? "Readiness: Prime" : (cnsScore >= 60 ? "Readiness: Moderate" : "Readiness: Strained"))
                            .font(.footnote.bold())
                            .foregroundStyle(cnsScore >= 80 ? PastelTheme.pastelSage : (cnsScore >= 60 ? PastelTheme.pastelAmber : PastelTheme.pastelPeach))

                        Text(cnsScore >= 80 
                            ? "Neural pathways are fully restored. Safe to attempt maximal lifts, progressive overload, and explosive movements."
                            : "Accumulated fatigue present. Focus on moderate hypertrophy or active recovery, sparing excessive spinal loading.")
                            .font(.caption)
                            .foregroundStyle(PastelTheme.textSecondary)
                    }
                    .padding(14)
                    .background(PastelTheme.cardSurfaceSubtle)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(PastelTheme.cardBorder, lineWidth: 1))

                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("CNS Readiness")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.body.weight(.medium))
                    .foregroundStyle(PastelTheme.pastelOat)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

