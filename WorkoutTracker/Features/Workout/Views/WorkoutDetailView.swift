// ============================================================
// FILE: WorkoutTracker/Features/Workout/Views/WorkoutDetailView.swift
// ============================================================

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
            // ✅ ГЛАВНЫЙ ФИКС: Передаем viewModel в окружение для всех дочерних вью
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
    
    // MARK: - Presentation State
    @State private var activeSheet: DetailDestination?
    @State private var activeFullScreen: DetailDestination?
    @State private var showEmptyAlert = false
    @State private var showTimerSetup = false
    @State private var shareItems: [Any] = []
    
    // MARK: - Local UI State
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
    
    private var tabPicker: some View {
        Picker(LocalizedStringKey("View Mode"), selection: $selectedTab) {
            ForEach(Tab.allCases, id: \.self) { Text($0.localizedName).tag($0) }
        }
        .pickerStyle(.segmented)
    }
    
    var body: some View {
        ZStack {
            ScrollViewReader { proxy in
                mainLayout(proxy: proxy)
                    .onChange(of: scrollToExerciseId) { _, newId in handleScrollTo(newId: newId, proxy: proxy) }
            }
            
            if let fullScreen = activeFullScreen {
                renderFullScreenContent(for: fullScreen)
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
                   isDeletingEmptyWorkout = true // Блокируем логику в onDisappear
                   let safeID = workout.persistentModelID // Безопасно сохраняем ID до удаления
                   dismiss() // Сначала закрываем экран
                   
                   Task {
                       // Ждем, пока экран полностью закроется, чтобы не сломать Bindable
                       try? await Task.sleep(for: .seconds(0.5))
                       await viewModel.deleteEmptyWorkout(workoutID: safeID)
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
                        VStack(alignment: .leading, spacing: 20) {
                            WorkoutDetailHeaderView(workout: workout, viewModel: viewModel)
                            actionButtonSection
                            if !workout.isActive { Divider().padding(.vertical, 5) }
                            tabPicker.padding(.bottom, 8)
                            
                            if selectedTab == .workout {
                                exercisesToolbarSection
                                ExerciseListView(
                                    workout: workout,
                                    expandedExercises: $expandedExercises,
                                    draggedExercise: $draggedExercise,
                                    scrollToExerciseId: { id in self.scrollToExerciseId = id },
                                    onAddExerciseTap: { activeSheet = .exerciseSelection }
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
                            
                            // ✅ Отступ внизу зависит от того, открыт таймер или нет
                            Spacer(minLength: timerManager.isRestTimerActive ? 280 : 120)
                        }
                        .padding()
                    }
                }
            }
            
            // ✅ Кнопка Финиша всплывает НАД таймером
            if workout.isActive && selectedTab != .aiCoach {
                finishWorkoutButton
            }
            
            if viewModel.isShowingSnackbar { snackbarOverlay }
        }
    }
    
    // MARK: - Event Handling
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
        case .showAchievement(let ach):
            activeFullScreen = .achievementPopup(ach)
        case .showSwapExercise(let ex):
            activeSheet = .swapExercise(ex)
        case .workoutSuccessfullyFinished:
            timerManager.stopRestTimer()
            if tutorialManager.currentStep == .finishWorkout { tutorialManager.setStep(.recoveryCheck) }
        }
        viewModel.activeEvent = nil
    }
    
    // MARK: - Buttons
    private var finishWorkoutButton: some View {
        VStack {
            Spacer()
            Button {
                let generator = UIImpactFeedbackGenerator(style: .heavy)
                generator.impactOccurred()
                viewModel.requestFinishWorkout(workout: workout, progressManager: userStatsViewModel.progressManager)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "flag.checkered.circle.fill").font(.title2)
                    Text(LocalizedStringKey("Finish Workout")).font(.title3).bold()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing))
                .foregroundColor(.white)
                .clipShape(Capsule())
                .shadow(color: .blue.opacity(0.4), radius: 15, x: 0, y: 8)
            }
            .padding(.horizontal, 24)
            // ДИНАМИЧЕСКИЙ ОТСТУП СНИЗУ ДЛЯ КНОПКИ (Чтобы таймер снизу пролезал)
            .padding(.bottom, timerManager.isRestTimerActive ? 180 : 16)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: timerManager.isRestTimerActive)
            .disabled(viewModel.isShowingSnackbar)
        }
        .background(
            VStack {
                Spacer()
                LinearGradient(colors: [Color(UIColor.systemBackground).opacity(0), Color(UIColor.systemBackground)], startPoint: .top, endPoint: .bottom)
                    .frame(height: timerManager.isRestTimerActive ? 280 : 100)
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
        .padding(.bottom, timerManager.isRestTimerActive ? 160 : 80)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .zIndex(100)
    }
    
    // MARK: - Lifecycle
    private func handleOnAppear() {
        viewModel.loadCaches(from: dashboardViewModel)
        viewModel.updateWorkoutAnalytics(for: workout)
        for (index, exercise) in workout.exercises.enumerated() {
            if expandedExercises[exercise.id] == nil { expandedExercises[exercise.id] = index == 0 ? true : !isNewWorkout }
        }
    }
    private func handleOnDisappear() {
           timerManager.isHidden = false
           
           // Если мы уже удаляем тренировку через Алерт, дальше не идем
           guard !isDeletingEmptyWorkout, workout.isActive else { return }
           
           let hasCompletedSets = workout.exercises.contains { ex in
               let targets = ex.isSuperset ? ex.subExercises : [ex]
               return targets.contains { sub in sub.setsList.contains { $0.isCompleted } }
           }
           
           if !hasCompletedSets {
               isDeletingEmptyWorkout = true // Ставим флаг
               let safeID = workout.persistentModelID // Безопасно извлекаем ID
               
               Task {
                   await viewModel.deleteEmptyWorkout(workoutID: safeID)
                   timerManager.stopRestTimer()
               }
           }
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
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text(LocalizedStringKey("Share Result"))
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .shadow(radius: 5)
                }
                .opacity(viewModel.isShowingSnackbar ? 0.5 : 1.0)
                .disabled(viewModel.isShowingSnackbar)
            }
        }
        .zIndex(9)
    }
    
    private var exercisesToolbarSection: some View {
        HStack {
            Text(LocalizedStringKey("Exercises")).font(.title2).bold()
            Spacer()
            if workout.isActive {
                Button { showTimerSetup = true } label: {
                    Image(systemName: "timer").font(.headline).padding(8).background(Color.accentColor.opacity(0.1)).foregroundColor(.accentColor).cornerRadius(8)
                }
            }
            Button { activeSheet = .supersetBuilder(nil) } label: {
                Label(LocalizedStringKey("Superset"), systemImage: "plus").font(.caption).bold().padding(8).background(Color.accentColor.opacity(0.1)).foregroundColor(.accentColor).cornerRadius(8)
            }.disabled(!workout.isActive)
            Button { activeSheet = .exerciseSelection } label: {
                Label(LocalizedStringKey("Exercise"), systemImage: "plus").font(.caption).bold().padding(8).background(Color.accentColor.opacity(0.1)).foregroundColor(.accentColor).cornerRadius(8)
            }
            .disabled(!workout.isActive)
            .spotlight(step: .addExercise, manager: tutorialManager, text: "Tap here to add an exercise.", alignment: .top, xOffset: -50, yOffset: 10)
        }
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
                        title: LocalizedStringKey("No Data Yet"),
                        message: LocalizedStringKey("Complete exercises with weight to see your performance chart here.")
                    )
                    .frame(height: 220)
                } else {
                    // Динамический заголовок выбранного столбца
                    if let selected = selectedChartExerciseName {
                        Text(LocalizedStringKey(selected.trimmingCharacters(in: .whitespaces)))
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
                            // Подсветка золотым градиентом при выборе
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
                    // Скрываем лишние линии сетки для чистоты дизайна
                    .chartXAxis {
                        AxisMarks(values: .automatic) { value in
                            AxisValueLabel {
                                if let uniqueName = value.as(String.self) {
                                    Text(String(uniqueName.trimmingCharacters(in: .whitespaces).prefix(3)).capitalized)
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

    // MARK: - 2. Muscle Heatmap Section (WorkoutDetailContentView)
    private var muscleHeatmapSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(LocalizedStringKey("Body Status"))
                    .font(.title2)
                    .bold()
                
                Spacer()
                
                // Пульсирующий бейдж Live Tension
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
                BodyHeatmapView(muscleIntensities: viewModel.workoutAnalytics.intensity)
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
        case .achievementPopup(let achievement): AchievementPopupView(achievement: achievement) { activeFullScreen = nil }.presentationBackground(.clear)
        default: EmptyView()
        }
    }
}
