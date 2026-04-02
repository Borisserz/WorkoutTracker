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

struct WorkoutDetailView: View {
    
    enum Tab: String, CaseIterable {
        case workout = "Workout"
        case analytics = "Analytics"
        case aiCoach = "AI Coach"
        var localizedName: LocalizedStringKey { LocalizedStringKey(self.rawValue) }
    }
    
    // MARK: - Environment & State
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Environment(DashboardViewModel.self) private var dashboardViewModel
    @Environment(WorkoutViewModel.self) private var globalViewModel
    
    @Environment(CatalogViewModel.self) var catalogViewModel
    @Environment(UserStatsViewModel.self) var userStatsViewModel
    @Environment(TutorialManager.self) var tutorialManager
    @Environment(RestTimerManager.self) var timerManager
    @Environment(UnitsManager.self) var unitsManager
    
    @Bindable var workout: Workout
    @State private var viewModel = WorkoutDetailViewModel()
    
    // MARK: - UI State
    @State private var selectedTab: Tab = .workout
    @State private var draggedExercise: Exercise?
    @State private var expandedExercises: [UUID: Bool] = [:]
    @State private var scrollToExerciseId: UUID?
    @State private var selectedChartExerciseName: String?
    @AppStorage("unlockedAchievementsCount") private var unlockedAchievementsCount = 0
    
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

    // MARK: - Body
    var body: some View {
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
                .onAppear(perform: handleOnAppear)
                .onDisappear(perform: handleOnDisappear)
                .onChange(of: selectedTab) { _, newTab in withAnimation { timerManager.isHidden = (newTab == .aiCoach) } }
                .onChange(of: scenePhase) { _, newPhase in if newPhase != .active { viewModel.commitSnackbar() } }
                .onChange(of: workout.exercises.count) { _, _ in handleExercisesChanged() }
                .onChange(of: scrollToExerciseId) { _, newId in handleScrollTo(newId: newId, proxy: proxy) }
                .onChange(of: tutorialManager.currentStep) { _, newStep in handleTutorialStep(newStep) }
                
                // ✅ ЧИСТАЯ НАВИГАЦИЯ ЧЕРЕЗ ENUM
                .sheet(item: $viewModel.activeSheet) { destination in
                    switch destination {
                    case .shareSheet:
                        ActivityViewController(activityItems: viewModel.shareItems)
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
                                withAnimation { globalViewModel.removeExercise(ex, from: workout) }
                            }
                        }
                    case .swapExercise(let oldEx):
                        ExerciseSelectionView { newEx in
                            viewModel.performSwap(old: oldEx, new: newEx, workout: workout, globalViewModel: globalViewModel, modelContainer: modelContext.container)
                        }
                    default: EmptyView()
                    }
                }
                // ✅ АЛЕРТЫ
                .alert(LocalizedStringKey("Empty Workout"), isPresented: $viewModel.isShowingEmptyAlert) {
                    Button(LocalizedStringKey("Delete"), role: .destructive) {
                        viewModel.deleteEmptyWorkout(workout: workout, globalViewModel: globalViewModel, timerManager: timerManager, dismiss: dismiss)
                    }
                    Button(LocalizedStringKey("Continue"), role: .cancel) { }
                } message: {
                    Text(LocalizedStringKey("This workout has no completed sets. Do you want to delete it or continue?"))
                }
                // ✅ ПОЛНОЭКРАННЫЕ ПОПАПЫ
                .fullScreenCover(item: $viewModel.activeFullScreen) { destination in
                    switch destination {
                    case .prCelebration(let level):
                        PRCelebrationView(prLevel: level, onClose: { viewModel.activeDestination = nil })
                            .presentationBackground(.clear)
                    case .achievementPopup(let achievement):
                        AchievementPopupView(achievement: achievement) { viewModel.activeDestination = nil }
                            .presentationBackground(.clear)
                    default: EmptyView()
                    }
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
                            WorkoutDetailHeaderView(workout: workout)
                            actionButtonSection
                            if !workout.isActive { Divider().padding(.vertical, 5) }
                            tabPicker.padding(.bottom, 8)
                            
                            if selectedTab == .workout {
                                exercisesToolbarSection
                                ExerciseListView(
                                        workout: workout,
                                        expandedExercises: $expandedExercises,
                                        draggedExercise: $draggedExercise,
                                        scrollToExerciseId: { id in self.scrollToExerciseId = id } 
                                    )
                                    .environment(viewModel)
                            } else if selectedTab == .analytics {
                                chartSection
                                muscleHeatmapSection
                                if !workout.exercises.isEmpty { FunFactView(totalStrengthVolume: viewModel.workoutAnalytics.volume) }
                            }
                            Spacer(minLength: timerManager.isRestTimerActive ? 180 : 100)
                        }
                        .padding()
                    }
                }
            }
            if workout.isActive && selectedTab != .aiCoach { finishWorkoutButton }
            if let message = viewModel.snackbarMessage { snackbarOverlay(message: message) }
        }
    }
    
    private var finishWorkoutButton: some View {
        Button {
            viewModel.finishWorkout(
                workout: workout,
                modelContainer: modelContext.container,
                progressManager: userStatsViewModel.progressManager,
                onRefreshGlobalCaches: { dashboardViewModel.refreshAllCaches() },
                updateAchievementsCount: { newTotal in
                    let old = unlockedAchievementsCount
                    unlockedAchievementsCount = newTotal
                    return old
                },
                onSuccessUI: {
                    timerManager.stopRestTimer()
                    if tutorialManager.currentStep == .finishWorkout {
                        tutorialManager.setStep(.recoveryCheck)
                    }
                }
            )
        } label: {
            Text(LocalizedStringKey("Finish Workout")).font(.headline).frame(maxWidth: .infinity)
                .padding().background(Color.accentColor).foregroundColor(.white)
                .cornerRadius(12).shadow(radius: 8)
        }
        .padding(.horizontal)
        .padding(.bottom, timerManager.isRestTimerActive ? 100 : 16)
        .animation(.default, value: timerManager.isRestTimerActive)
    }
    
    private func snackbarOverlay(message: LocalizedStringKey) -> some View {
        HStack {
            Text(message).font(.subheadline).foregroundColor(.white)
            Spacer()
            Button { viewModel.undoAction() } label: {
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

    // MARK: - Lifecycle Handlers
    fileprivate func handleOnAppear() {
        viewModel.updateWorkoutAnalytics(for: workout, modelContainer: modelContext.container)
        for (index, exercise) in workout.exercises.enumerated() {
            if expandedExercises[exercise.id] == nil {
                expandedExercises[exercise.id] = index == 0 ? true : !isNewWorkout
            }
        }
    }
    
    fileprivate func handleOnDisappear() {
        timerManager.isHidden = false
        viewModel.commitSnackbar()
        
        if workout.isActive {
            let hasCompletedSets = workout.exercises.contains { ex in
                let targets = ex.isSuperset ? ex.subExercises : [ex]
                return targets.contains { sub in sub.setsList.contains { $0.isCompleted } }
            }
            
            if !hasCompletedSets {
                globalViewModel.deleteWorkout(workout)
            }
        }
    }
    
    fileprivate func handleExercisesChanged() {
        viewModel.updateWorkoutAnalytics(for: workout, modelContainer: modelContext.container)
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
    
    // MARK: - View Sections
    private var actionButtonSection: some View {
        Group {
            if !workout.isActive {
                Button { viewModel.generateAndShare(workout: workout) } label: {
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
            
            Button { viewModel.activeDestination = .supersetBuilder(nil) } label: {
                Label(LocalizedStringKey("Superset"), systemImage: "plus").font(.caption).bold().padding(8).background(Color.accentColor.opacity(0.1)).foregroundColor(.accentColor).cornerRadius(8)
            }.disabled(!workout.isActive)
            
            Button { viewModel.activeDestination = .exerciseSelection } label: {
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
    @Environment(UnitsManager.self) var unitsManager
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
    @Environment(UnitsManager.self) var unitsManager
    
    var body: some View {
        HStack {
            Rectangle().frame(width: 4).foregroundColor(effortColor(value: exercise.effort)).cornerRadius(2)
            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey(exercise.name)).font(.headline).foregroundColor(.primary)
                HStack {
                    Text(exercise.formattedDetails(unitsManager: unitsManager))
                    Spacer()
                    rpeBadge
                }
                .font(.subheadline).foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 8).contentShape(Rectangle())
    }
    
    private var rpeBadge: some View { Text(LocalizedStringKey("RPE \(exercise.effort)")).font(.caption2).bold().padding(4).background(effortColor(value: exercise.effort).opacity(0.2)).foregroundColor(effortColor(value: exercise.effort)).cornerRadius(4) }
    private func effortColor(value: Int) -> Color { switch value { case 1...4: return .green; case 5...7: return .orange; case 8...10: return .red; default: return .blue } }
}

struct Blinking: ViewModifier {
    @State private var isOn = false
    func body(content: Content) -> some View { content.opacity(isOn ? 1 : 0.5).onAppear { withAnimation(Animation.easeInOut(duration: 1).repeatForever()) { isOn = true } }.onDisappear { isOn = false } }
}
extension View { func blinking() -> some View { modifier(Blinking()) } }
