

internal import SwiftUI
import SwiftData
import Charts
import Combine
import ActivityKit

struct WorkoutDetailView: View {
    @Bindable var workout: Workout
    @State private var viewModel: WorkoutDetailViewModel

    init(workout: Workout, viewModel: WorkoutDetailViewModel) {
        self.workout = workout
        self._viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        WorkoutDetailContentView(workout: workout, viewModel: viewModel)

            .environment(viewModel)
    }
}

struct WorkoutDetailContentView: View {
    enum Tab: String, CaseIterable {
        case workout = "Workout"
        case analytics = "Analytics"
        case aiCoach = "AI Coach"
        var localizedName: LocalizedStringKey { LocalizedStringKey(self.rawValue) }
    }

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    @State private var isDeletingEmptyWorkout = false
    @Environment(DashboardViewModel.self) private var dashboardViewModel
    @Environment(UserStatsViewModel.self) var userStatsViewModel
    @Environment(TutorialManager.self) var tutorialManager
    @Environment(RestTimerManager.self) var timerManager
    @Environment(UnitsManager.self) var unitsManager
    @Environment(DIContainer.self) private var di

    @Bindable var workout: Workout
    @Bindable var viewModel: WorkoutDetailViewModel
    @AppStorage(Constants.UserDefaultsKeys.userGender.rawValue) private var userGender = "male"

    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme

    @State private var activeSheet: DetailDestination?
    @State private var activeFullScreen: DetailDestination?
    @State private var showEmptyAlert = false
    @State private var showTimerSetup = false
    @State private var shareItems: [Any] = []

    @State private var selectedTab: Tab = .workout
    @State private var draggedExercise: Exercise?
    @State private var expandedExercises: [UUID: Bool] = [:]
    @State private var scrollToExerciseId: UUID?
    @State private var selectedChartExerciseName: String?

    var isNewWorkout: Bool {
        guard !workout.exercises.isEmpty else { return true }
        return !workout.exercises.contains { ex in
            (ex.isSuperset ? ex.subExercises : [ex]).contains { $0.setsList.contains { $0.isCompleted } }
        }
    }

    @Namespace private var tabNamespace
    
    private var tabPicker: some View {
        HStack(spacing: 4) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        selectedTab = tab
                        UISelectionFeedbackGenerator().selectionChanged()
                    }
                } label: {
                    Text(tab.localizedName)
                        .font(.system(size: 13, weight: selectedTab == tab ? .bold : .medium, design: .rounded))
                        .foregroundColor(selectedTab == tab ? PastelTheme.textOnOat : PastelTheme.textTertiary)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background {
                            if selectedTab == tab {
                                Capsule()
                                    .fill(PastelTheme.pastelOat)
                                    .matchedGeometryEffect(id: "activeTab", in: tabNamespace)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(PastelTheme.cardSurfaceSubtle)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(PastelTheme.cardBorder, lineWidth: 1)
        )
    }

    var body: some View {
        ZStack {
            PastelTheme.canvas.ignoresSafeArea()

            ScrollViewReader { proxy in
                mainLayout(proxy: proxy)
                    .onChange(of: scrollToExerciseId) { _, newId in handleScrollTo(newId: newId, proxy: proxy) }
            }

            if let fullScreen = activeFullScreen {
                renderFullScreenContent(for: fullScreen)
                    .id(fullScreen.id)
                    .ignoresSafeArea()
                    .zIndex(200)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    viewModel.toggleFavorite(workout: workout, presetService: di.presetService)
                } label: {
                    Image(systemName: workout.isFavorite ? "star.fill" : "star")
                        .foregroundColor(workout.isFavorite ? .yellow : .gray)
                        .font(.title3)
                }
            }
        }
        .onAppear {
            handleOnAppear()
            if workout.isActive { di.appState.isInsideActiveWorkout = true }
        }
        .onDisappear {
            handleOnDisappear()
            di.appState.isInsideActiveWorkout = false
        }
        .onChange(of: selectedTab) { _, newTab in withAnimation { timerManager.isHidden = (newTab == .aiCoach) } }
        .onChange(of: workout.exercises.count) { _, _ in handleExercisesChanged() }
        .onChange(of: tutorialManager.currentStep) { _, newStep in handleTutorialStep(newStep) }
        .onChange(of: viewModel.activeEvent) { _, event in handleViewModelEvent(event) }
        .sheet(item: $activeSheet) { sheet in renderSheetContent(for: sheet) }
        .sheet(isPresented: $showTimerSetup) { TimerSetupSheet().environment(timerManager) }
        .alert(LocalizedStringKey("Empty Workout"), isPresented: $showEmptyAlert) {
                      Button(LocalizedStringKey("Delete"), role: .destructive) {
                          isDeletingEmptyWorkout = true
                          timerManager.stopRestTimer()
                          dismiss()

                          Task {
                       try? await Task.sleep(for: .seconds(0.5))
                       await viewModel.deleteEmptyWorkout(id: workout.id)
                   }
               }
               Button(LocalizedStringKey("Continue"), role: .cancel) { }
           } message: {
               Text(LocalizedStringKey("This workout has no completed sets. Do you want to delete it or continue?"))
           }
    }

    @ViewBuilder
    private func mainLayout(proxy: ScrollViewProxy) -> some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                if selectedTab == .aiCoach {
                    VStack(spacing: 0) {
                        tabPicker.padding()
                        InWorkoutAICoachView(workout: workout, viewModel: viewModel.aiCoach)
                    }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            WorkoutDetailHeaderView(workout: workout, viewModel: viewModel, onFinish: {
                                finishCurrentWorkout()
                            })
                            if !workout.isActive { Divider().padding(.vertical, 5) }
                            tabPicker.padding(.bottom, 8)

                            if selectedTab == .workout {
                                exercisesToolbarSection
                                ExerciseListView(
                                    workout: workout,
                                    expandedExercises: $expandedExercises,
                                    draggedExercise: $draggedExercise,
                                    scrollToExerciseId: { id in self.scrollToExerciseId = id },
                                    onAddExerciseTap: { activeSheet = .exerciseSelection },
                                    onAddSupersetTap: { activeSheet = .supersetBuilder(nil) }
                                )
                                .environment(viewModel)
                            } else if selectedTab == .analytics {
                                SessionSummaryGrid(workout: workout, viewModel: viewModel)

                                chartSection

                                muscleHeatmapSection

                                if !workout.exercises.isEmpty {
                                    FunFactView(totalStrengthVolume: viewModel.workoutAnalytics.volume)
                                }
                            }

                            Spacer(minLength: 120)
                        }
                        .padding()
                    }
                }
            }

            if workout.isActive && selectedTab != .aiCoach {
                activeWorkoutThumbCockpit
            }

            if viewModel.isShowingSnackbar && activeFullScreen == nil { snackbarOverlay }
        }
    }

    private func handleViewModelEvent(_ event: WorkoutDetailEvent?) {
        guard let event = event else { return }
        switch event {
        case .showPR(let level):
            activeFullScreen = .prCelebration(level)
            Task {
                try? await Task.sleep(for: .seconds(3.5))
                if activeFullScreen == .prCelebration(level) { activeFullScreen = nil }
            }
        case .showShareSheet(let item):
            self.shareItems = [item]
            activeSheet = .shareSheet
        case .showEmptyAlert:
            showEmptyAlert = true
        case .showXPBreakdownPopup(let breakdown, let isLevelUp, let newLevel, let newTitle, let achievements):
            activeFullScreen = .xpBreakdownPopup(breakdown, isLevelUp, newLevel, newTitle, achievements)
        case .showAchievements(let achievements):
            activeFullScreen = .achievementPopup(achievements)
        case .showSwapExercise(let ex):
            activeSheet = .swapExercise(ex)
        case .workoutSuccessfullyFinished:
            timerManager.stopRestTimer()
            if tutorialManager.currentStep == .finishWorkout { tutorialManager.setStep(.recoveryCheck) }
        }
        viewModel.activeEvent = nil
    }

    // MARK: - Active Workout 1-Tap Thumb HUD Cockpit (Exact Mockup Match)
    private var nextPendingSetInfo: (exercise: Exercise, setIndex: Int, set: WorkoutSet)? {
        for exercise in workout.exercises {
            let sortedSets = exercise.sortedSets
            for (idx, set) in sortedSets.enumerated() {
                if !set.isCompleted {
                    return (exercise, idx + 1, set)
                }
            }
        }
        return nil
    }

    private func formatSetWeightReps(_ set: WorkoutSet) -> String {
        let weight = set.weight ?? 90
        let reps = set.reps ?? 8
        return "\(Int(weight)) кг × \(reps)"
    }

    private func completeNextPendingSet(_ pending: (exercise: Exercise, setIndex: Int, set: WorkoutSet)) {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            pending.set.isCompleted = true
            viewModel.updateWorkoutAnalytics(for: workout)
            timerManager.startRestTimer(duration: 105, exerciseName: pending.exercise.name)
        }
    }

    private func toggleOrSkipRestTimer() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        if timerManager.isRestTimerActive {
            timerManager.stopRestTimer()
        } else {
            timerManager.startRestTimer(duration: 105)
        }
    }

    private func finishCurrentWorkout() {
        let isEmpty = workout.exercises.isEmpty
        let generator = UIImpactFeedbackGenerator(style: isEmpty ? .medium : .heavy)
        generator.impactOccurred()
        timerManager.stopRestTimer()
        viewModel.requestFinishWorkout(workout: workout, progressManager: userStatsViewModel.progressManager)
    }

    private var activeWorkoutThumbCockpit: some View {
        VStack(spacing: 10) {
            Spacer()

            // 1. Primary Action Button: 1-Tap Set Completion (Hero 48pt Warm Oat)
            if let pending = nextPendingSetInfo {
                Button {
                    completeNextPendingSet(pending)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16, weight: .bold))
                        Text("Закрыть сет \(pending.setIndex) (\(formatSetWeightReps(pending.set)))")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(PastelTheme.textOnOat)
                    .frame(maxWidth: .infinity)
                    .frame(height: PastelTheme.ButtonMetrics.heroHeight)
                    .background(PastelTheme.pastelOat)
                    .clipShape(RoundedRectangle(cornerRadius: PastelTheme.ButtonMetrics.heroRadius, style: .continuous))
                    .shadow(color: Color.black.opacity(0.4), radius: 10, y: 5)
                }
                .buttonStyle(ScaleButtonStyle())
            } else {
                Button {
                    finishCurrentWorkout()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "flag.checkered.circle.fill")
                            .font(.system(size: 16, weight: .bold))
                        Text("Все сеты закрыты: Завершить")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    .foregroundStyle(PastelTheme.textOnOat)
                    .frame(maxWidth: .infinity)
                    .frame(height: PastelTheme.ButtonMetrics.heroHeight)
                    .background(PastelTheme.pastelEmerald)
                    .clipShape(RoundedRectangle(cornerRadius: PastelTheme.ButtonMetrics.heroRadius, style: .continuous))
                    .shadow(color: Color.black.opacity(0.4), radius: 10, y: 5)
                }
                .buttonStyle(ScaleButtonStyle())
            }

            // 2. Secondary Action Button: Rest Timer Control (Hero 48pt Warm Amber)
            Button {
                toggleOrSkipRestTimer()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: timerManager.isRestTimerActive ? "stopwatch.fill" : "timer")
                        .font(.system(size: 16, weight: .bold))

                    if timerManager.isRestTimerActive {
                        let mins = timerManager.restTimeRemaining / 60
                        let secs = timerManager.restTimeRemaining % 60
                        Text(String(format: "%02d:%02d Отдых — Пропустить", mins, secs))
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    } else {
                        Text("01:45 Отдых — Пропустить")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                }
                .foregroundStyle(Color(red: 0.08, green: 0.08, blue: 0.1))
                .frame(maxWidth: .infinity)
                .frame(height: PastelTheme.ButtonMetrics.heroHeight)
                .background(PastelTheme.pastelAmber)
                .clipShape(RoundedRectangle(cornerRadius: PastelTheme.ButtonMetrics.heroRadius, style: .continuous))
                .shadow(color: PastelTheme.pastelAmber.opacity(0.25), radius: 8, y: 4)
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .background(
            VStack(spacing: 0) {
                Spacer()
                LinearGradient(
                    colors: [
                        PastelTheme.canvas.opacity(0),
                        PastelTheme.canvas.opacity(0.85),
                        PastelTheme.canvas
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 150)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        )
    }

    private var snackbarOverlay: some View {
        HStack {
            Text(LocalizedStringKey("Workout finished")).font(.subheadline).foregroundColor(.white)
            Spacer()
            Button {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                viewModel.undoFinishWorkout(workout: workout)
            } label: {
                Text(LocalizedStringKey("Undo")).font(.subheadline).bold().foregroundColor(.yellow)
            }
        }
        .padding()
        .background(Color(.darkGray).opacity(0.95))
        .cornerRadius(10)
        .shadow(radius: 5)
        .padding(.horizontal)
        .padding(.bottom, 80)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .zIndex(100)
    }

    private func handleOnAppear() {
        viewModel.loadCaches(from: dashboardViewModel)
        viewModel.updateWorkoutAnalytics(for: workout)
        for (index, exercise) in workout.exercises.enumerated() {
            if expandedExercises[exercise.id] == nil { expandedExercises[exercise.id] = index == 0 ? true : !isNewWorkout }
        }
    }
    private func handleOnDisappear() {
        timerManager.isHidden = false
    }

    private func handleExercisesChanged() {
        viewModel.updateWorkoutAnalytics(for: workout)
        for (index, exercise) in workout.exercises.enumerated() {
            if expandedExercises[exercise.id] == nil { expandedExercises[exercise.id] = index == 0 }
        }
    }

    private func handleScrollTo(newId: UUID?, proxy: ScrollViewProxy) {
        if let exerciseId = newId {
            Task {
                try? await Task.sleep(for: .seconds(0.1))
                guard !Task.isCancelled else { return }
                withAnimation { proxy.scrollTo(exerciseId, anchor: .top) }
                scrollToExerciseId = nil
            }
        }
    }

    private func handleTutorialStep(_ newStep: TutorialStep) {
        if newStep == .highlightChart || newStep == .highlightBody { selectedTab = .analytics }
        else if newStep == .addExercise { selectedTab = .workout }
    }

    private var actionButtonSection: some View {
        Group {
            if !workout.isActive {
                Button {
                    viewModel.generateAndShare(workout: workout)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 15, weight: .bold))
                        Text(LocalizedStringKey("Share Result"))
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: PastelTheme.ButtonMetrics.heroHeight)
                    .background(PastelTheme.pastelOat)
                    .foregroundColor(PastelTheme.textOnOat)
                    .clipShape(RoundedRectangle(cornerRadius: PastelTheme.ButtonMetrics.heroRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: PastelTheme.ButtonMetrics.heroRadius, style: .continuous)
                            .stroke(PastelTheme.cardBorderFocused, lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.25), radius: 8, y: 4)
                }
                .opacity(viewModel.isShowingSnackbar ? 0.5 : 1.0)
                .disabled(viewModel.isShowingSnackbar)
            }
        }
        .zIndex(9)
    }

    private var exercisesToolbarSection: some View {
        HStack(spacing: 12) {
            Button {
                activeSheet = .exerciseSelection
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                    Text("Упражнение")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(PastelTheme.textPrimary)
                .padding(.horizontal, 16)
                .frame(height: PastelTheme.ButtonMetrics.inCardHeight)
                .background(PastelTheme.cardSurfaceSubtle)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(PastelTheme.cardBorder, lineWidth: 1))
            }
            .buttonStyle(.plain)

            Button {
                activeSheet = .supersetBuilder(nil)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "circle.grid.2x2")
                        .font(.system(size: 13, weight: .bold))
                    Text("Калькулятор блинов")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(PastelTheme.textPrimary)
                .padding(.horizontal, 16)
                .frame(height: PastelTheme.ButtonMetrics.inCardHeight)
                .background(PastelTheme.cardSurfaceSubtle)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(PastelTheme.cardBorder, lineWidth: 1))
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.horizontal, 4)
        .zIndex(15)
    }

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(LocalizedStringKey("Analysis (Max Weight)"))
                .font(.title2)
                .bold()
                .padding(.horizontal, 4)

            VStack(alignment: .leading, spacing: 16) {
                if viewModel.workoutAnalytics.chartExercises.isEmpty {
                    EmptyStateView(
                        icon: "chart.bar.xaxis",
                        title: LocalizedStringKey("No Performance Data"),
                        message: LocalizedStringKey("Complete at least one set with weight to see your performance graph."),
                        iconColor: .purple
                    )
                } else {
                    if let selected = selectedChartExerciseName {
                        Text(LocalizationHelper.shared.translateName(selected.trimmingCharacters(in: .whitespaces)))
                            .font(.headline)
                            .foregroundColor(.orange)
                            .padding(.bottom, 4)
                            .frame(minHeight: 24)
                    } else {
                        Text(LocalizedStringKey("Tap a bar to see full name"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.bottom, 4)
                            .frame(minHeight: 24)
                    }

                    Chart {
                        ForEach(Array(viewModel.workoutAnalytics.chartExercises.enumerated()), id: \.element.id) { index, exercise in
                            let maxWeight = exercise.maxWeight
                            let convertedWeight = unitsManager.convertFromKilograms(maxWeight)
                            let uniqueName = exercise.name + String(repeating: " ", count: index)
                            let isSelected = selectedChartExerciseName == uniqueName

                            BarMark(
                                x: .value("Exercise", uniqueName),
                                y: .value("Weight", convertedWeight)
                            )

                            .foregroundStyle(
                                isSelected
                                ? LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom)
                                : LinearGradient(colors: [.cyan, .blue], startPoint: .top, endPoint: .bottom)
                            )
                            .cornerRadius(6)
                            .annotation(position: .top) {
                                if isSelected {
                                    Text("\(Int(convertedWeight))")
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundColor(.orange)
                                        .padding(.bottom, 4)
                                        .contentTransition(.numericText())
                                } else {
                                    Text("\(Int(convertedWeight))")
                                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                                        .foregroundColor(.secondary)
                                        .contentTransition(.numericText())
                                }
                            }
                        }
                    }
                    .frame(height: 220)
                    .chartXSelection(value: $selectedChartExerciseName)
                    .chartXAxis {
                        AxisMarks(values: .automatic) { value in
                            AxisValueLabel {
                                if let uniqueName = value.as(String.self) {
                                    let translatedName = LocalizationHelper.shared.translateName(String(uniqueName.trimmingCharacters(in: .whitespaces)))
Text(String(translatedName.prefix(3)).capitalized)
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { _ in
                            AxisGridLine().foregroundStyle(Color.gray.opacity(0.1))
                            AxisValueLabel().foregroundStyle(Color.secondary)
                        }
                    }
                    .onChange(of: selectedChartExerciseName) { _, newValue in
                        if newValue != nil {
                            UISelectionFeedbackGenerator().selectionChanged()
                        }
                    }
                }
            }
            .padding(20)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(24)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
        }
        .padding(.top, 10)
    }

    private var muscleHeatmapSection: some View {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(LocalizedStringKey("Body Status"))
                        .font(.title2)
                        .bold()

                    Spacer()

                    if workout.isActive {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                                .symbolEffect(.pulse)
                            Text(LocalizedStringKey("Live Tension"))
                                .font(.caption)
                                .bold()
                                .foregroundColor(.green)
                                .textCase(.uppercase)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.green.opacity(0.15))
                        .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 4)

                VStack {
                    BodyHeatmapView(
                        muscleIntensities: viewModel.workoutAnalytics.intensity,
                        rawMuscleCounts: viewModel.workoutAnalytics.rawCounts,
                        isRecoveryMode: false,
                        isCompactMode: false,
                        userGender: userGender,
                        countLabel: "exercises"
                    )
                }
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(24)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
            }
        }

    @ViewBuilder
    private func renderSheetContent(for destination: DetailDestination) -> some View {
        switch destination {
        case .shareSheet: ActivityViewController(activityItems: shareItems).presentationDetents([.medium, .large])
        case .exerciseSelection: ExerciseSelectionView { newEx in viewModel.addExercise(newEx, workout: workout, scrollToExerciseId: { scrollToExerciseId = $0 }) }
        case .supersetBuilder(let existing): SupersetBuilderView(existingSuperset: existing) { newSuper in if existing == nil { viewModel.addExercise(newSuper, workout: workout, scrollToExerciseId: { scrollToExerciseId = $0 }) } } onDelete: { if let ex = existing { viewModel.removeExercise(ex, from: workout) } }
        case .swapExercise(let oldEx): ExerciseSelectionView { newEx in viewModel.performSwap(old: oldEx, new: newEx, workout: workout) }
        default: EmptyView()
        }
    }

    @ViewBuilder
    private func renderFullScreenContent(for destination: DetailDestination) -> some View {
        switch destination {
        case .prCelebration(let level): PRCelebrationView(prLevel: level, onClose: { activeFullScreen = nil }).presentationBackground(.clear)
        case .achievementPopup(let achievements): AchievementPopupView(achievements: achievements) { 
            activeFullScreen = nil
            AppReviewManager.processQueuedReview()
        }.presentationBackground(.clear)
        case .xpBreakdownPopup(let breakdown, let isLevelUp, let newLevel, let newTitle, let achievements):
            XPBreakdownPopupView(breakdown: breakdown, isLevelUp: isLevelUp, newLevel: newLevel, newTitle: newTitle) {
                activeFullScreen = nil
                if !achievements.isEmpty {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        activeFullScreen = .achievementPopup(achievements)
                    }
                } else {
                    AppReviewManager.processQueuedReview()
                }
            }
            .presentationBackground(.clear)
        default: EmptyView()
        }
    }
}
