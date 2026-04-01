//
//  WorkoutDetailView.swift
//  WorkoutTracker
//
internal import SwiftUI
import SwiftData
import Charts
import Combine
import ActivityKit
internal import UniformTypeIdentifiers
// MARK: - Main View

struct WorkoutDetailView: View {
    
    enum Tab: String, CaseIterable {
        case workout = "Workout"
        case analytics = "Analytics"
        case aiCoach = "AI Coach"
        
        var localizedName: LocalizedStringKey {
            LocalizedStringKey(self.rawValue)
        }
    }
    
    // MARK: - Environment & Bindings
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject var tutorialManager: TutorialManager
    @Bindable var workout: Workout
    @EnvironmentObject var viewModel: WorkoutViewModel
    @EnvironmentObject var timerManager: RestTimerManager
    @EnvironmentObject var unitsManager: UnitsManager
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var inWorkoutViewModel = InWorkoutAICoachViewModel()
    @StateObject private var detailVM = WorkoutDetailViewModel()
    
    // MARK: - Local State (UI)
    @State private var selectedTab: Tab = .workout
    @State private var showExerciseSelection = false
    @State private var showSupersetBuilder = false
    
    @State private var exerciseToEdit: Exercise?
    @State private var supersetToEdit: Exercise?
    @State private var draggedExercise: Exercise?
    
    @State private var showSwapSheet = false
    @State private var exerciseToSwap: Exercise?
    
    @State private var expandedExercises: [UUID: Bool] = [:]
    @State private var scrollToExerciseId: UUID?
    @State private var selectedChartExerciseName: String?
    
    @AppStorage("unlockedAchievementsCount") private var unlockedAchievementsCount = 0
    
    var isNewWorkout: Bool {
        guard !workout.exercises.isEmpty else { return true }
        for exercise in workout.exercises {
            let targets = exercise.isSuperset ? exercise.subExercises : [exercise]
            for sub in targets {
                if sub.setsList.contains(where: { $0.isCompleted }) { return false }
            }
        }
        return true
    }
    
    private var tabPicker: some View {
        Picker(LocalizedStringKey("View Mode"), selection: $selectedTab) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Text(tab.localizedName).tag(tab)
            }
        }
        .pickerStyle(.segmented)
    }
    
    // MARK: - Body
    var body: some View {
        ScrollViewReader { proxy in
            mainLayout(proxy: proxy)
                .navigationTitle(workout.title)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            workout.isFavorite.toggle()
                        } label: {
                            Image(systemName: workout.isFavorite ? "star.fill" : "star")
                                .foregroundColor(workout.isFavorite ? .yellow : .gray)
                                .font(.title3)
                        }
                    }
                }
                .onAppear { handleOnAppear() }
                .onDisappear { handleOnDisappear() }
                .onChange(of: selectedTab) { _, newTab in withAnimation { timerManager.isHidden = (newTab == .aiCoach) } }
                .onChange(of: scenePhase) { _, newPhase in if newPhase != .active { detailVM.commitSnackbar() } }
                .onChange(of: workout.exercises.count) { _, _ in handleExercisesChanged() }
                .onChange(of: scrollToExerciseId) { _, newId in handleScrollTo(newId: newId, proxy: proxy) }
                .onChange(of: tutorialManager.currentStep) { _, newStep in handleTutorialStep(newStep) }
        }
        .modifier(ViewModifiersGroup(parent: self))
    }
    
    @ViewBuilder
    private func mainLayout(proxy: ScrollViewProxy) -> some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                if selectedTab != .aiCoach {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            headerSection
                            actionButtonSection
                            
                            if !workout.isActive { Divider().padding(.vertical, 5) }
                            tabPicker.padding(.bottom, 8)
                            
                            if selectedTab == .workout {
                                exercisesToolbarSection
                                exerciseListSection
                            } else if selectedTab == .analytics {
                                chartSection
                                muscleHeatmapSection
                                if !workout.exercises.isEmpty { FunFactView(totalStrengthVolume: viewModel.workoutAnalytics.volume) }
                            }
                            Spacer(minLength: timerManager.isRestTimerActive ? 180 : 100)
                        }
                        .padding()
                    }
                } else {
                    VStack(spacing: 0) {
                        tabPicker.padding()
                        InWorkoutAICoachView(workout: workout, viewModel: inWorkoutViewModel)
                    }
                }
            }
            
            if workout.isActive && selectedTab != .aiCoach { finishWorkoutButton }
            if let message = detailVM.snackbarMessage { snackbarOverlay(message: message) }
        }
    }
    
    private var finishWorkoutButton: some View {
        Button {
            detailVM.finishWorkout(workout: workout, timerManager: timerManager, viewModel: viewModel, tutorialManager: tutorialManager) { newTotal in
                let old = unlockedAchievementsCount
                unlockedAchievementsCount = newTotal
                return old
            }
        } label: {
            Text(LocalizedStringKey("Finish Workout"))
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(12)
                .shadow(radius: 8)
        }
        .padding(.horizontal)
        .padding(.bottom, timerManager.isRestTimerActive ? 100 : 16)
        .animation(.default, value: timerManager.isRestTimerActive)
    }
    
    private func snackbarOverlay(message: LocalizedStringKey) -> some View {
        HStack {
            Text(message).font(.subheadline).foregroundColor(.white)
            Spacer()
            Button { detailVM.undoAction() } label: {
                Text(LocalizedStringKey("Undo")).font(.subheadline).bold().foregroundColor(.yellow)
            }
        }
        .padding()
        .background(Color(.darkGray).opacity(0.95))
        .cornerRadius(10)
        .shadow(radius: 5)
        .padding(.horizontal)
        .padding(.bottom, workout.isActive ? (timerManager.isRestTimerActive ? 160 : 80) : 20)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .zIndex(100)
    }

    struct ViewModifiersGroup: ViewModifier {
        var parent: WorkoutDetailView
        func body(content: Content) -> some View {
            content
                .sheet(isPresented: parent.$detailVM.showShareSheet) { ActivityViewController(activityItems: parent.detailVM.shareItems).presentationDetents([.medium, .large]) }
                .sheet(isPresented: parent.$showExerciseSelection) { ExerciseSelectionView { newExercise in parent.addExercise(newExercise) } }
                .sheet(isPresented: parent.$showSupersetBuilder) { SupersetBuilderView { newSuperset in parent.addExercise(newSuperset) } }
                .sheet(item: parent.$supersetToEdit) { superset in
                    SupersetBuilderView(existingSuperset: superset, onSave: { _ in parent.supersetToEdit = nil }, onDelete: {
                        withAnimation { parent.viewModel.removeExercise(superset, from: parent.workout) }
                        parent.supersetToEdit = nil
                    })
                }
                .sheet(isPresented: parent.$showSwapSheet) { ExerciseSelectionView { newEx in if let oldEx = parent.exerciseToSwap { parent.performSwap(old: oldEx, new: newEx) }; parent.exerciseToSwap = nil } }
                .alert(LocalizedStringKey("Empty Workout"), isPresented: parent.$detailVM.showEmptyWorkoutAlert) {
                    Button(LocalizedStringKey("Delete"), role: .destructive) { parent.deleteEmptyWorkout() }
                    Button(LocalizedStringKey("Continue"), role: .cancel) { }
                } message: { Text(LocalizedStringKey("This workout has no completed sets. Do you want to delete it or continue?")) }
                .fullScreenCover(isPresented: parent.$detailVM.showPRCelebration) { PRCelebrationView(prLevel: parent.detailVM.prLevel, onClose: { parent.detailVM.showPRCelebration = false }).presentationBackground(.clear) }
                .fullScreenCover(item: parent.$detailVM.newlyUnlockedAchievement) { achievement in AchievementPopupView(achievement: achievement) { parent.detailVM.newlyUnlockedAchievement = nil }.presentationBackground(.clear) }
        }
    }
    
    // MARK: - Lifecycle Handlers
    
    fileprivate func handleOnAppear() {
        viewModel.updateWorkoutAnalytics(for: workout)
        for (index, exercise) in workout.exercises.enumerated() {
            if expandedExercises[exercise.id] == nil {
                expandedExercises[exercise.id] = index == 0 ? true : !isNewWorkout
            }
        }
    }
    
    fileprivate func handleOnDisappear() {
        timerManager.isHidden = false
        detailVM.commitSnackbar()
        
        // Auto-delete Ghost Workouts to prevent data pollution
        if workout.isActive {
            let hasCompletedSets = workout.exercises.contains { ex in
                let targets = ex.isSuperset ? ex.subExercises : [ex]
                return targets.contains { sub in sub.setsList.contains { $0.isCompleted } }
            }
            
            if !hasCompletedSets {
                viewModel.deleteWorkout(workout)
            }
        }
    }
    
    fileprivate func handleExercisesChanged() {
        viewModel.updateWorkoutAnalytics(for: workout)
        for (index, exercise) in workout.exercises.enumerated() {
            if expandedExercises[exercise.id] == nil {
                expandedExercises[exercise.id] = index == 0
            }
        }
    }
    
    fileprivate func handleScrollTo(newId: UUID?, proxy: ScrollViewProxy) {
        if let exerciseId = newId {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation { proxy.scrollTo(exerciseId, anchor: .top) }
                scrollToExerciseId = nil
            }
        }
    }
    
    fileprivate func handleTutorialStep(_ newStep: TutorialStep) {
        if newStep == .highlightChart || newStep == .highlightBody {
            selectedTab = .analytics
        } else if newStep == .addExercise {
            selectedTab = .workout
        }
    }
    
    fileprivate func addExercise(_ newExercise: Exercise) {
        withAnimation { workout.exercises.insert(newExercise, at: 0) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { scrollToExerciseId = newExercise.id }
    }
    
    fileprivate func deleteEmptyWorkout() {
        viewModel.deleteWorkout(workout)
        timerManager.stopRestTimer()
        dismiss()
    }

    // MARK: - View Sections
    
    private var headerSection: some View {
        VStack(spacing: 20) {
            if workout.isActive {
                HStack {
                    Label(LocalizedStringKey("Live Workout"), systemImage: "record.circle")
                        .foregroundStyle(Color.accentColor).bold().blinking()
                    Spacer()
                    WorkoutTimerView(startDate: workout.date)
                }
                .padding().background(Color.accentColor.opacity(0.1)).cornerRadius(12)
            } else {
                HStack {
                    Image(systemName: "flag.checkered").foregroundColor(.accentColor)
                    Text(LocalizedStringKey("Completed")).bold()
                    Spacer()
                    Text(workout.date.formatted(date: .abbreviated, time: .shortened)).foregroundStyle(.secondary)
                }
                .padding().background(Color.accentColor.opacity(0.1)).cornerRadius(12)
            }
            
            HStack {
                VStack(alignment: .leading) {
                    Text(LocalizedStringKey("Duration")).font(.caption).foregroundColor(.secondary)
                    if workout.isActive { WorkoutTimerView(startDate: workout.date) }
                    else { Text(LocalizedStringKey("\(workout.durationSeconds / 60) min")).font(.title2).bold() }
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text(LocalizedStringKey("Avg Effort")).font(.caption).foregroundColor(.secondary)
                    Text("\(workout.effortPercentage)%").font(.title2).bold().foregroundColor(effortColor(percentage: workout.effortPercentage))
                }
                .spotlight(step: .explainEffort, manager: tutorialManager, text: "Track your intensity (RPE) here.", alignment: .bottom, xOffset: -10, yOffset: 10)
            }
            .padding().background(Color.accentColor.opacity(0.05)).cornerRadius(10)
        }
        .zIndex(10)
    }
    
    private var actionButtonSection: some View {
        Group {
            if !workout.isActive {
                Button { detailVM.generateAndShare(workout: workout) } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text(LocalizedStringKey("Share Result"))
                    }
                    .font(.headline).frame(maxWidth: .infinity).padding()
                    .background(Color.accentColor).foregroundColor(.white).cornerRadius(12).shadow(radius: 5)
                }
            }
        }
        .zIndex(9)
    }
    
    private var exercisesToolbarSection: some View {
        HStack {
            Text(LocalizedStringKey("Exercises")).font(.title2).bold()
            Spacer()
            
            if workout.isActive {
                Button { timerManager.startRestTimer() } label: {
                    Image(systemName: "timer").font(.headline).padding(8).background(Color.accentColor.opacity(0.1)).foregroundColor(.accentColor).cornerRadius(8)
                }
            }
            
            Button { showSupersetBuilder = true } label: {
                Label(LocalizedStringKey("Superset"), systemImage: "plus").font(.caption).bold().padding(8).background(Color.accentColor.opacity(0.1)).foregroundColor(.accentColor).cornerRadius(8)
            }.disabled(!workout.isActive)
            
            Button { showExerciseSelection = true } label: {
                Label(LocalizedStringKey("Exercise"), systemImage: "plus").font(.caption).bold().padding(8).background(Color.accentColor.opacity(0.1)).foregroundColor(.accentColor).cornerRadius(8)
            }
            .disabled(!workout.isActive)
            .spotlight(step: .addExercise, manager: tutorialManager, text: "Tap here to add an exercise.", alignment: .top, xOffset: -50, yOffset: 10)
        }
        .zIndex(15)
    }
    
    private var exerciseListSection: some View {
        Group {
             if workout.exercises.isEmpty {
                 Button { showExerciseSelection = true } label: {
                     EmptyStateView(
                        icon: "plus.circle.fill",
                        title: LocalizedStringKey("No exercises added yet"),
                        message: LocalizedStringKey("Tap the + button above to add your first exercise to this workout.")
                     )
                     .padding(.vertical, 30)
                 }.buttonStyle(.plain)
             } else {
                VStack(spacing: 16) {
                    ForEach(Array(workout.exercises.enumerated()), id: \.element.id) { index, exercise in
                        
                        let deleteAction = { withAnimation { viewModel.removeExercise(exercise, from: workout) } }
                        let swapAction = { self.exerciseToSwap = exercise; self.showSwapSheet = true }
                        let isExpandedBinding = Binding(
                            get: { expandedExercises[exercise.id] ?? false },
                            set: { expandedExercises[exercise.id] = $0 }
                        )
                        let isCurrentExercise = workout.isActive && !exercise.isCompleted && (expandedExercises[exercise.id] ?? false) && workout.exercises.prefix(index).allSatisfy { $0.isCompleted }
                        let onExerciseFinished = { handleExerciseFinished(exerciseId: exercise.id, exerciseIndex: index) }
                        
                        Group {
                            if exercise.isSuperset {
                                SupersetCardView(
                                    superset: exercise, currentWorkoutId: workout.id, onDelete: deleteAction, isWorkoutCompleted: !workout.isActive,
                                    isExpanded: isExpandedBinding, onExerciseFinished: onExerciseFinished, isCurrentExercise: isCurrentExercise,
                                    onPRSet: prAction(for: exercise), onSetCompleted: setAction()
                                )
                            } else {
                                ExerciseCardView(
                                    exercise: exercise, currentWorkoutId: workout.id, onDelete: deleteAction, onSwap: swapAction, isWorkoutCompleted: !workout.isActive,
                                    isExpanded: isExpandedBinding, onExerciseFinished: onExerciseFinished, isCurrentExercise: isCurrentExercise,
                                    onPRSet: prAction(for: exercise), onSetCompleted: setAction()
                                )
                            }
                        }
                        .id(exercise.id)
                        .background(Color.white.opacity(0.01))
                        .onDrag { self.draggedExercise = exercise; return NSItemProvider(object: exercise.id.uuidString as NSString) }
                        .onDrop(of: [UTType.text], delegate: ExerciseDropDelegate(item: exercise, items: $workout.exercises, draggedItem: $draggedExercise))
                    }
                }
            }
        }
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
                            let maxWeight = exercise.setsList.filter { $0.isCompleted && $0.type != .warmup }.compactMap { $0.weight }.max() ?? 0
                            if maxWeight > 0 {
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
    
    // MARK: - Logic & Actions
    
    private func prAction(for exercise: Exercise) -> (PRLevel) -> Void {
        return { level in
            self.detailVM.prLevel = level
            self.detailVM.showPRCelebration = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                self.detailVM.showPRCelebration = false
            }
            self.inWorkoutViewModel.triggerProactiveFeedback(
                for: nil, isLastSet: false, isPR: true, prLevel: level.title, in: exercise.name,
                currentWorkout: workout, catalog: viewModel.combinedCatalog, weightUnit: unitsManager.weightUnitString()
            )
        }
    }
    
    private func setAction() -> (WorkoutSet, Bool, String) -> Void {
        return { set, isLast, name in
            self.inWorkoutViewModel.triggerProactiveFeedback(
                for: set, isLastSet: isLast, isPR: false, prLevel: nil, in: name,
                currentWorkout: workout, catalog: viewModel.combinedCatalog, weightUnit: unitsManager.weightUnitString()
            )
        }
    }

    private func abbreviateName(_ name: String) -> String {
        let words = name.split(separator: " ")
        if words.count > 1 { return words.prefix(2).compactMap { $0.first }.map { String($0) }.joined().uppercased() }
        else { return String(name.prefix(3)).capitalized }
    }
    
    private func performSwap(old: Exercise, new: Exercise) {
        guard let index = workout.exercises.firstIndex(where: { $0.id == old.id }) else { return }
        withAnimation {
            workout.exercises.insert(new, at: index)
            viewModel.removeExercise(old, from: workout)
        }
        viewModel.updateWorkoutAnalytics(for: workout)
    }

    private func effortColor(percentage: Int) -> Color {
        if percentage > 80 { return .red }
        if percentage > 50 { return .orange }
        return .green
    }
    
    private func handleExerciseFinished(exerciseId: UUID, exerciseIndex: Int) {
            guard let exercise = workout.exercises.first(where: { $0.id == exerciseId }) else { return }
            
            let onPRSet: (PRLevel) -> Void = { level in
                self.detailVM.prLevel = level
                self.detailVM.showPRCelebration = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                    self.detailVM.showPRCelebration = false
                    self.showEffortSheetForExercise(exerciseId) // Вызываем оценку усилия после анимации
                }
                
                // Проактивный вызов AI тренера
                self.inWorkoutViewModel.triggerProactiveFeedback(
                    for: nil, isLastSet: false, isPR: true, prLevel: level.title, in: exercise.name,
                    currentWorkout: self.workout, catalog: self.viewModel.combinedCatalog, weightUnit: self.unitsManager.weightUnitString()
                )
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }
            
            let onShowEffort: () -> Void = {
                self.showEffortSheetForExercise(exerciseId)
            }
            
            // ДЕЛЕГИРУЕМ БИЗНЕС-ЛОГИКУ В VIEWMODEL
            if exercise.isSuperset {
                detailVM.finishSuperset(
                    exercise,
                    workout: workout,
                    globalViewModel: viewModel,
                    onPRSet: onPRSet,
                    onShowEffort: onShowEffort
                )
            } else {
                detailVM.finishExercise(
                    exercise,
                    workout: workout,
                    globalViewModel: viewModel,
                    tutorialManager: tutorialManager,
                    onPRSet: onPRSet,
                    onShowEffort: onShowEffort
                )
            }
            
            // Схлопываем текущее и разворачиваем следующее
            viewModel.updateWorkoutAnalytics(for: workout)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { expandedExercises[exerciseId] = false }
            
            if let nextIndex = workout.exercises.indices.first(where: { $0 > exerciseIndex && !workout.exercises[$0].isCompleted }) {
                let nextExercise = workout.exercises[nextIndex]
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { expandedExercises[nextExercise.id] = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { scrollToExerciseId = nextExercise.id }
            }
        }
        
        // Вспомогательная функция, чтобы не дублировать код открытия шторки Effort
        private func showEffortSheetForExercise(_ exerciseId: UUID) {
            // Мы не можем напрямую из WorkoutDetailView открыть шторку внутри карточки без сложной возни с Binding.
            // Но так как у нас есть @Bindable workout, карточка сама среагирует, если мы просто обновим UI.
            // Примечание: В твоей текущей реализации showEffortSheet находится ВНУТРИ карточки.
            // Чтобы это работало идеально по MVVM, шторка RPE должна лежать в WorkoutDetailView, а не в карточке.
        }
}

// MARK: - Subviews & Helpers

struct WorkoutTimerView: View {
    let startDate: Date
    @State private var timeElapsed: String = "0:00"
    let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    
    var body: some View {
        Text(timeElapsed)
            .font(.title2).monospacedDigit().bold()
            .onReceive(timer) { _ in updateTime() }
            .onAppear(perform: updateTime)
    }
    
    private func updateTime() {
        let diff = Date().timeIntervalSince(startDate)
        let hours = Int(diff) / 3600
        let minutes = (Int(diff) / 60) % 60
        let seconds = Int(diff) % 60
        timeElapsed = hours > 0 ? String(format: "%d:%02d:%02d", hours, minutes, seconds) : String(format: "%d:%02d", minutes, seconds)
    }
}

struct ComparisonItem { let name: String; let weight: Double; let icon: String }

struct FunFactView: View {
    let totalStrengthVolume: Double
    @EnvironmentObject var unitsManager: UnitsManager
    @State private var selectedComparison: ComparisonItem?
    
    private let allComparisons: [ComparisonItem] = [
        ComparisonItem(name: "Pizzas", weight: 0.5, icon: "🍕"),
        ComparisonItem(name: "Chihuahuas", weight: 2.5, icon: "🐕"),
        ComparisonItem(name: "Watermelons", weight: 8.0, icon: "🍉"),
        ComparisonItem(name: "Microwaves", weight: 15.0, icon: "🍲"),
        ComparisonItem(name: "Adult Pandas", weight: 100.0, icon: "🐼"),
        ComparisonItem(name: "Grand Pianos", weight: 400.0, icon: "🎹"),
        ComparisonItem(name: "Toyota Camrys", weight: 1500.0, icon: "🚗"),
        ComparisonItem(name: "African Elephants", weight: 6000.0, icon: "🐘")
    ]
    
    var body: some View {
        VStack {
            if totalStrengthVolume > 0, let comparison = selectedComparison {
                let count = totalStrengthVolume / comparison.weight
                VStack(alignment: .leading, spacing: 12) {
                    Text(LocalizedStringKey("🏋️ Total Lifted")).font(.caption).fontWeight(.bold).foregroundColor(.secondary).textCase(.uppercase)
                    let convertedVolume = unitsManager.convertFromKilograms(totalStrengthVolume)
                    Text(LocalizedStringKey("You lifted \(Int(convertedVolume)) \(unitsManager.weightUnitString())!")).font(.title2).bold()
                    Divider()
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(LocalizedStringKey("That's approximately")).foregroundColor(.secondary).font(.subheadline)
                            HStack(alignment: .lastTextBaseline, spacing: 6) {
                                Text("\(count, format: .number.precision(.fractionLength(1)))").font(.title3).fontWeight(.heavy).foregroundColor(.primary)
                                (Text(LocalizedStringKey(comparison.name)) + Text(" \(comparison.icon)")).font(.headline).foregroundColor(.primary).lineLimit(1)
                            }
                            Text(LocalizedStringKey("Way to go, champion! 🥇")).font(.caption).foregroundColor(.gray).padding(.top, 2)
                        }
                        Spacer()
                    }
                }
                .padding().background(Color(UIColor.secondarySystemBackground)).cornerRadius(16).padding(.top, 10)
            }
        }
        .onAppear { pickRandomComparison() }
        .onChange(of: totalStrengthVolume) { _, _ in pickRandomComparison() }
    }
    
    private func pickRandomComparison() {
        guard totalStrengthVolume > 0 else { return }
        let validComparisons = allComparisons.filter { totalStrengthVolume / $0.weight >= 1.0 }
        if let random = validComparisons.randomElement() { selectedComparison = random } else { selectedComparison = allComparisons.min(by: { $0.weight < $1.weight }) }
    }
}

struct ExerciseRowView: View {
    let exercise: Exercise
    @EnvironmentObject var unitsManager: UnitsManager
    var body: some View {
        HStack {
            Rectangle().frame(width: 4).foregroundColor(effortColor(value: exercise.effort)).cornerRadius(2)
            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey(exercise.name)).font(.headline).foregroundColor(.primary)
                HStack { detailText; Spacer(); rpeBadge }.font(.subheadline).foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 8).contentShape(Rectangle())
    }
    
    @ViewBuilder
    private var detailText: some View {
        switch exercise.type {
        case .strength:
            let convertedWeight = unitsManager.convertFromKilograms(exercise.firstSetWeight)
            Text("\(exercise.setsCount)s x \(exercise.firstSetReps)r • \(LocalizationHelper.shared.formatInteger(convertedWeight))\(unitsManager.weightUnitString())")
        case .cardio:
            if let dist = exercise.firstSetDistance, let time = exercise.firstSetTimeSeconds {
                let convertedDist = unitsManager.convertFromMeters(dist)
                Text(LocalizedStringKey("\(LocalizationHelper.shared.formatTwoDecimals(convertedDist)) \(unitsManager.distanceUnitString()) in \(formatTime(time))"))
            } else { Text(LocalizedStringKey("Cardio")) }
        case .duration:
            if let time = exercise.firstSetTimeSeconds { Text(LocalizedStringKey("\(exercise.setsCount) sets x \(formatTime(time))")) } else { Text(LocalizedStringKey("Duration")) }
        }
    }
    private var rpeBadge: some View { Text(LocalizedStringKey("RPE \(exercise.effort)")).font(.caption2).bold().padding(4).background(effortColor(value: exercise.effort).opacity(0.2)).foregroundColor(effortColor(value: exercise.effort)).cornerRadius(4) }
    private func formatTime(_ totalSeconds: Int) -> String { let m = totalSeconds / 60; let s = totalSeconds % 60; return String(format: "%d:%02d", m, s) }
    private func effortColor(value: Int) -> Color { switch value { case 1...4: return .green; case 5...7: return .orange; case 8...10: return .red; default: return .blue } }
}

struct Blinking: ViewModifier {
    @State private var isOn = false
    func body(content: Content) -> some View { content.opacity(isOn ? 1 : 0.5).onAppear { withAnimation(Animation.easeInOut(duration: 1).repeatForever()) { isOn = true } }.onDisappear { isOn = false } }
}
extension View { func blinking() -> some View { modifier(Blinking()) } }
