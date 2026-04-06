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
    @Bindable var viewModel: WorkoutDetailViewModel

    var body: some View {
        WorkoutDetailContentView(workout: workout, viewModel: viewModel)
    }
}

// Вспомогательные Enum'ы для локального UI-роутинга
enum DetailSheetDestination: Identifiable {
    case exerciseSelection
    case timerSetup
    case supersetBuilder(Exercise?)
    case swapExercise(Exercise)
    case shareSheet([Any]) // Массив Any
    
    var id: String {
        switch self {
        case .timerSetup: return "timerSetup"
        case .exerciseSelection: return "exSel"
        case .supersetBuilder(let ex): return "super_\(ex?.id.uuidString ?? "new")"
        case .swapExercise(let ex): return "swap_\(ex.id.uuidString)"
        case .shareSheet: return "share"
        }
    }
}


enum DetailFullScreenDestination: Identifiable {
    case prCelebration(PRLevel)
    case achievementPopup(Achievement)
    
    var id: String {
        switch self {
        case .prCelebration(let lvl): return "pr_\(lvl.rank)"
        case .achievementPopup(let ach): return "ach_\(ach.id)"
        }
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
    
    @Environment(DashboardViewModel.self) private var dashboardViewModel
    @Environment(UserStatsViewModel.self) var userStatsViewModel
    @Environment(TutorialManager.self) var tutorialManager
    @Environment(RestTimerManager.self) var timerManager
    @Environment(UnitsManager.self) var unitsManager
    @Environment(DIContainer.self) private var di // ✅ Добавлено для доступа к appState
    
    @Bindable var workout: Workout
    @Bindable var viewModel: WorkoutDetailViewModel
    
    // MARK: - Presentation State
    @State private var activeSheet: DetailSheetDestination?
    @State private var activeFullScreen: DetailFullScreenDestination?
    @State private var showEmptyAlert = false
    
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
        // ✅ FIX: Wrapped in ZStack to allow true transparent overlays for Popups
        ZStack {
            ScrollViewReader { proxy in
                mainLayout(proxy: proxy)
                    .navigationTitle(workout.title)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button { workout.isFavorite.toggle() } label: {
                                Image(systemName: workout.isFavorite ? "star.fill" : "star")
                                    .foregroundColor(workout.isFavorite ? .yellow : .gray).font(.title3)
                            }
                        }
                    }
                    .onAppear {
                        // ✅ ИСПРАВЛЕНИЕ: Разделяем вызовы на новые строки
                        handleOnAppear()
                        if workout.isActive {
                            di.appState.isInsideActiveWorkout = true
                        }
                    }
                    .onDisappear {
                        handleOnDisappear()
                        // ✅ Убеждаемся, что при выходе из экрана баннер может появиться
                        di.appState.isInsideActiveWorkout = false
                    }
                    .onChange(of: selectedTab) { _, newTab in withAnimation { timerManager.isHidden = (newTab == .aiCoach) } }
                    .onChange(of: workout.exercises.count) { _, _ in handleExercisesChanged() }
                    .onChange(of: scrollToExerciseId) { _, newId in handleScrollTo(newId: newId, proxy: proxy) }
                    .onChange(of: tutorialManager.currentStep) { _, newStep in handleTutorialStep(newStep) }
                    .onChange(of: viewModel.activeEvent) { _, event in handleViewModelEvent(event) }
                    .sheet(item: $activeSheet) { sheet in
                        renderSheetContent(for: sheet)
                    }
                    .alert(LocalizedStringKey("Empty Workout"), isPresented: $showEmptyAlert) {
                        Button(LocalizedStringKey("Delete"), role: .destructive) {
                            let workoutToDelete = workout
                            dismiss()
                            
                            Task {
                                try? await Task.sleep(for: .seconds(0.5))
                                await viewModel.deleteEmptyWorkout(workout: workoutToDelete)
                                timerManager.stopRestTimer()
                            }
                        }
                        Button(LocalizedStringKey("Continue"), role: .cancel) { }
                    } message: {
                        Text(LocalizedStringKey("This workout has no completed sets. Do you want to delete it or continue?"))
                    }
            }
            
            // ✅ FIX: Render Popups directly in ZStack for beautiful animations and proper background dimming
            if let fullScreen = activeFullScreen {
                renderFullScreenContent(for: fullScreen)
                    .ignoresSafeArea()
                    .zIndex(200)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
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
                                    chartSection
                                    muscleHeatmapSection
                                    if !workout.exercises.isEmpty {
                                        FunFactView(totalStrengthVolume: viewModel.workoutAnalytics.volume)
                                    }
                                }
                                
                                // ✅ FIX: Увеличенный отступ, чтобы скролл уходил ПОД новый премиальный таймер.
                                // Теперь последний сет и график аналитики не перекроются таймером.
                                Spacer(minLength: timerManager.isRestTimerActive ? 280 : 120)
                            }
                            .padding()
                        }
                    }
                }
                
                // Кнопка Finish и Snackbar висят поверх ScrollView, но ПОД таймером
                if workout.isActive && selectedTab != .aiCoach { finishWorkoutButton }
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
                if case .prCelebration = activeFullScreen { activeFullScreen = nil }
            }
            
        case .showShareSheet(let item):
            activeSheet = .shareSheet([item])
            
        case .showEmptyAlert:
            showEmptyAlert = true
            
        case .showAchievement(let ach):
            activeFullScreen = .achievementPopup(ach)
            
        case .showSwapExercise(let ex):
            activeSheet = .swapExercise(ex)
            
        case .workoutSuccessfullyFinished:
            timerManager.stopRestTimer()
            if tutorialManager.currentStep == .finishWorkout {
                tutorialManager.setStep(.recoveryCheck)
            }
        }
        
        viewModel.activeEvent = nil
    }
    
    // MARK: - Sections & Buttons
    
    private var finishWorkoutButton: some View {
            Button {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                viewModel.requestFinishWorkout(workout: workout, progressManager: userStatsViewModel.progressManager)
            } label: {
                Text(LocalizedStringKey("Finish Workout")).font(.headline).frame(maxWidth: .infinity)
                    .padding().background(Color.accentColor).foregroundColor(.white)
                    .cornerRadius(12).shadow(radius: 8)
            }
            .padding(.horizontal)
            // ✅ FIX: Если таймер активен, поднимаем кнопку Finish НАД ним (примерно 200 поинтов от низа экрана)
            .padding(.bottom, timerManager.isRestTimerActive ? 180 : 16)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: timerManager.isRestTimerActive)
            .disabled(viewModel.isShowingSnackbar)
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

    // MARK: - Lifecycle Handlers
    
    private func handleOnAppear() {
        viewModel.loadCaches(from: dashboardViewModel)
        viewModel.updateWorkoutAnalytics(for: workout)
        
        for (index, exercise) in workout.exercises.enumerated() {
            if expandedExercises[exercise.id] == nil {
                expandedExercises[exercise.id] = index == 0 ? true : !isNewWorkout
            }
        }
    }
    
    private func handleOnDisappear() {
        timerManager.isHidden = false
        
        if workout.isActive {
            let hasCompletedSets = workout.exercises.contains { ex in
                let targets = ex.isSuperset ? ex.subExercises : [ex]
                return targets.contains { sub in sub.setsList.contains { $0.isCompleted } }
            }
            
            if !hasCompletedSets {
                Task {
                    await viewModel.deleteEmptyWorkout(workout: workout)
                    timerManager.stopRestTimer()
                }
            }
        }
    }
    
    private func handleExercisesChanged() {
        viewModel.updateWorkoutAnalytics(for: workout)
        for (index, exercise) in workout.exercises.enumerated() {
            if expandedExercises[exercise.id] == nil {
                expandedExercises[exercise.id] = index == 0
            }
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
        if newStep == .highlightChart || newStep == .highlightBody {
            selectedTab = .analytics
        } else if newStep == .addExercise {
            selectedTab = .workout
        }
    }
    
    // MARK: - View Sections
    
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
                        // ✅ Изменено: Вызов шторки вместо моментального старта
                        Button { activeSheet = .timerSetup } label: {
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
        Group {
            if !viewModel.workoutAnalytics.chartExercises.isEmpty {
                VStack(alignment: .leading) {
                    Text(LocalizedStringKey("Analysis (Max Weight)")).font(.title2).bold().padding(.top)
                    if let selected = selectedChartExerciseName {
                        Text(LocalizedStringKey(selected.trimmingCharacters(in: .whitespaces))).font(.subheadline).foregroundColor(.accentColor).padding(.bottom, 4).frame(minHeight: 20)
                    } else {
                        Text(LocalizedStringKey("Tap a bar to see full name")).font(.subheadline).foregroundColor(.secondary).padding(.bottom, 4).frame(minHeight: 20)
                    }
                    
                    Chart {
                        ForEach(Array(viewModel.workoutAnalytics.chartExercises.enumerated()), id: \.element.id) { index, exercise in
                            let maxWeight = exercise.maxWeight
                            let convertedWeight = unitsManager.convertFromKilograms(maxWeight)
                            let uniqueName = exercise.name + String(repeating: " ", count: index)
                            
                            BarMark(
                                x: .value("Exercise", uniqueName),
                                y: .value("Weight", convertedWeight)
                            )
                            .foregroundStyle(selectedChartExerciseName == uniqueName ? Color.orange.gradient : Color.accentColor.gradient)
                            .cornerRadius(4)
                            .annotation(position: .top) { Text("\(Int(convertedWeight))").font(.caption2).foregroundColor(selectedChartExerciseName == uniqueName ? .orange : .secondary) }
                        }
                    }
                    .frame(height: 250).padding(.bottom, 10).chartXSelection(value: $selectedChartExerciseName)
                    .chartXAxis {
                        AxisMarks(values: .automatic) { value in
                            AxisTick()
                            AxisValueLabel {
                                if let uniqueName = value.as(String.self) {
                                    Text(abbreviateName(uniqueName.trimmingCharacters(in: .whitespaces))).font(.caption2)
                                }
                            }
                        }
                    }
                }
                .spotlight(step: .highlightChart, manager: tutorialManager, text: "Track progress here.\nTap chart to continue.", alignment: .bottom)
                .onTapGesture { if tutorialManager.currentStep == .highlightChart { tutorialManager.nextStep() } }
            }
        }
    }
      
    private var muscleHeatmapSection: some View {
        VStack(alignment: .leading) {
            Text(LocalizedStringKey("Body Status")).font(.title2).bold().padding(.top)
            VStack { BodyHeatmapView(muscleIntensities: viewModel.workoutAnalytics.intensity) }
            .padding(.vertical).frame(maxWidth: .infinity).background(Color(UIColor.secondarySystemBackground)).cornerRadius(16)
            .spotlight(step: .highlightBody, manager: tutorialManager, text: "See targeted muscles.\nTap heatmap to continue.", alignment: .top)
            .onTapGesture { if tutorialManager.currentStep == .highlightBody { tutorialManager.nextStep() } }
        }
    }
    
    private func abbreviateName(_ name: String) -> String {
        let words = name.split(separator: " ")
        if words.count > 1 { return words.prefix(2).compactMap { $0.first }.map { String($0) }.joined().uppercased() }
        else { return String(name.prefix(3)).capitalized }
    }
    
    @ViewBuilder
    private func renderSheetContent(for destination: DetailSheetDestination) -> some View {
        switch destination {
        case .shareSheet(let items):
            ActivityViewController(activityItems: items)
                .presentationDetents([.medium, .large])

            
        case .exerciseSelection:
            ExerciseSelectionView { newExercise in
                viewModel.addExercise(newExercise, workout: workout, scrollToExerciseId: { scrollToExerciseId = $0 })
            }
            
        case .supersetBuilder(let existing):
            SupersetBuilderView(existingSuperset: existing) { newSuperset in
                if existing == nil {
                    viewModel.addExercise(newSuperset, workout: workout, scrollToExerciseId: { scrollToExerciseId = $0 })
                }
            } onDelete: {
                if let ex = existing {
                    viewModel.removeExercise(ex, from: workout)
                }
            }
            
        case .swapExercise(let oldEx):
            ExerciseSelectionView { newEx in
                viewModel.performSwap(old: oldEx, new: newEx, workout: workout)
            }
        case .timerSetup: // ✅ ADDED
                   TimerSetupSheet()
                       .environment(timerManager)
        }
    }
    
    @ViewBuilder
    private func renderFullScreenContent(for destination: DetailFullScreenDestination) -> some View {
        switch destination {
        case .prCelebration(let level):
            PRCelebrationView(prLevel: level, onClose: { activeFullScreen = nil })
                .presentationBackground(.clear)
                
        case .achievementPopup(let achievement):
            AchievementPopupView(achievement: achievement) { activeFullScreen = nil }
                .presentationBackground(.clear)
        }
    }
}
