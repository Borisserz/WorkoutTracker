//
//  WorkoutDetailView.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 24.12.25.
//
//  Экран активной тренировки (или просмотра истории).
//

internal import SwiftUI
import SwiftData
import Charts
import Combine
import ActivityKit
internal import UniformTypeIdentifiers

// MARK: - Main View

struct WorkoutDetailView: View {
    
    // MARK: - Nested Types
    enum Tab: String, CaseIterable {
        case workout = "Workout"
        case analytics = "Analytics"
        
        var localizedName: LocalizedStringKey {
            LocalizedStringKey(self.rawValue)
        }
    }
    
    // MARK: - Environment & Bindings
    @EnvironmentObject var tutorialManager: TutorialManager
    @Bindable var workout: Workout 
    @EnvironmentObject var viewModel: WorkoutViewModel
    @EnvironmentObject var timerManager: RestTimerManager
    @Environment(\.modelContext) private var context 
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Local State (UI)
    
    // Вкладка по умолчанию
    @State private var selectedTab: Tab = .workout
    
    // Управление модальными окнами
    @State private var showExerciseSelection = false
    @State private var showSupersetBuilder = false
    @State private var showShareSheet = false
    @State private var showEmptyWorkoutAlert = false
    
    // Редактирование
    @State private var exerciseToEdit: Exercise?
    @State private var supersetToEdit: Exercise?
    
    // Drag & Drop
    @State private var draggedExercise: Exercise?
    
    // Swap (Замена упражнения)
    @State private var showSwapSheet = false
    @State private var exerciseToSwap: Exercise?
    @State private var tempSwapList: [Exercise] = [] // Временный буфер для выбора замены
    
    // Удаление с предупреждением
    @State private var showDeleteExerciseAlert = false
    @State private var exerciseToDelete: Exercise?
    @State private var showDeleteSupersetAlert = false
    @State private var supersetToDelete: Exercise?
    
    // Sharing
    @State private var shareItems: [Any] = []
    
    // Управление раскрытостью упражнений
    @State private var expandedExercises: [UUID: Bool] = [:]
    
    // ID упражнения, к которому нужно прокрутить
    @State private var scrollToExerciseId: UUID?
    
    // Выбранное упражнение на графике
    @State private var selectedChartExerciseName: String?
    
    // Хранение предыдущего количества ачивок для отслеживания новых
    @AppStorage("unlockedAchievementsCount") private var unlockedAchievementsCount = 0
    
    // MARK: - Computed Properties (Оптимизированные State-кэши)
    
    @State private var flattenedExercises: [Exercise] = []
    @State private var strengthExercises: [Exercise] = []
    @State private var muscleIntensityMap: [String: Int] = [:]
    @State private var totalStrengthVolume: Double = 0.0
    
    /// Определяет, ли тренировка новой (созданной недавно, например, из шаблона)
    var isNewWorkout: Bool {
        let timeSinceCreation = Date().timeIntervalSince(workout.date)
        return timeSinceCreation < 60 && !workout.exercises.isEmpty
    }
    
    // MARK: - Body
    
    var body: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                    
                        // 1. Заголовок (Таймер, Инфо)
                        headerSection
                        
                        // 2. Основная кнопка (Share - для завершенных)
                        actionButtonSection
                        
                        if !workout.isActive {
                            Divider().padding(.vertical, 5)
                        }
                        
                        // ТАБЫ: Устранение когнитивного перегруза
                        Picker(LocalizedStringKey("View Mode"), selection: $selectedTab) {
                            ForEach(Tab.allCases, id: \.self) { tab in
                                Text(tab.localizedName).tag(tab)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.bottom, 8)
                        
                        if selectedTab == .workout {
                            // 3. Заголовок списка упражнений + Кнопки добавления
                            exercisesToolbarSection
                            
                            // 4. Список карточек упражнений
                            exerciseListSection
                        } else {
                            // 5. График (Максимальный вес)
                            chartSection
                            
                            // 6. Тепловая карта тела
                            muscleHeatmapSection
                            
                            // 7. Интересный факт (Сравнение веса)
                            if !workout.exercises.isEmpty {
                                FunFactView(totalStrengthVolume: totalStrengthVolume)
                            }
                        }
                        
                        // Отступ снизу, чтобы глобальный таймер отдыха и кнопка завершения не перекрывали контент
                        Spacer(minLength: timerManager.isRestTimerActive ? 180 : 100)
                    }
                    .padding()
                }
                
                // Floating Action Button для завершения тренировки
                if workout.isActive {
                    Button(action: finishWorkout) {
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
                    .spotlight(
                        step: .finishWorkout,
                        manager: tutorialManager,
                        text: "Tap here to save and finish.",
                        alignment: .top
                    )
                }
            }
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
            .onAppear {
                updateComputedData()
                for (index, exercise) in workout.exercises.enumerated() {
                    if expandedExercises[exercise.id] == nil {
                        expandedExercises[exercise.id] = index == 0 ? true : !isNewWorkout
                    }
                }
            }
            .onChange(of: workout.exercises.count) { oldCount, newCount in
                updateComputedData()
                for (index, exercise) in workout.exercises.enumerated() {
                    if expandedExercises[exercise.id] == nil {
                        expandedExercises[exercise.id] = index == 0
                    }
                }
            }
            .onChange(of: scrollToExerciseId) { oldId, newId in
                if let exerciseId = newId {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation {
                            proxy.scrollTo(exerciseId, anchor: .top)
                        }
                        scrollToExerciseId = nil
                    }
                }
            }
            .onChange(of: tutorialManager.currentStep) { _, newStep in
                // Автоматическое переключение вкладки для туториала, если необходимо
                if newStep == .highlightChart || newStep == .highlightBody {
                    selectedTab = .analytics
                } else if newStep == .addExercise {
                    selectedTab = .workout
                }
            }
        }
        
        // --- Modals & Sheets ---
        .sheet(isPresented: $showShareSheet) {
            ActivityViewController(activityItems: shareItems)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showExerciseSelection) {
            ExerciseSelectionView(selectedExercises: $workout.exercises)
        }
        .sheet(isPresented: $showSupersetBuilder) {
            SupersetBuilderView { newSuperset in
                workout.exercises.append(newSuperset)
            }
        }
        .sheet(item: $supersetToEdit) { superset in
            SupersetBuilderView(existingSuperset: superset, onSave: { updatedSuperset in
                supersetToEdit = nil
            }, onDelete: {
                if let index = workout.exercises.firstIndex(where: { $0.id == superset.id }) {
                    supersetToDelete = workout.exercises[index]
                    showDeleteSupersetAlert = true
                }
                supersetToEdit = nil
            })
        }
        .sheet(isPresented: $showSwapSheet) {
            ExerciseSelectionView(selectedExercises: $tempSwapList)
                .onDisappear {
                    if let newExercise = tempSwapList.first, let oldExercise = exerciseToSwap {
                        performSwap(old: oldExercise, new: newExercise)
                    }
                    tempSwapList = []
                    exerciseToSwap = nil
                }
        }
        
        .alert(LocalizedStringKey("Delete Exercise?"), isPresented: $showDeleteExerciseAlert) {
            Button(LocalizedStringKey("Delete"), role: .destructive) {
                if let ex = exerciseToDelete {
                    withAnimation {
                        if let index = workout.exercises.firstIndex(where: { $0.id == ex.id }) {
                            workout.exercises.remove(at: index)
                        }
                        context.delete(ex)
                    }
                    exerciseToDelete = nil
                }
            }
            Button(LocalizedStringKey("Cancel"), role: .cancel) {
                exerciseToDelete = nil
            }
        } message: {
            if let ex = exerciseToDelete {
                Text(LocalizedStringKey("Are you sure you want to delete '\(ex.name)'? This action cannot be undone."))
            } else {
                Text(LocalizedStringKey("Are you sure you want to delete this exercise? This action cannot be undone."))
            }
        }
        .alert(LocalizedStringKey("Delete Superset?"), isPresented: $showDeleteSupersetAlert) {
            Button(LocalizedStringKey("Delete"), role: .destructive) {
                if let ex = supersetToDelete {
                    withAnimation {
                        if let index = workout.exercises.firstIndex(where: { $0.id == ex.id }) {
                            workout.exercises.remove(at: index)
                        }
                        context.delete(ex)
                    }
                    supersetToDelete = nil
                }
            }
            Button(LocalizedStringKey("Cancel"), role: .cancel) {
                supersetToDelete = nil
            }
        } message: {
            Text(LocalizedStringKey("Are you sure you want to delete this superset? This action cannot be undone."))
        }
        .alert(LocalizedStringKey("Empty Workout"), isPresented: $showEmptyWorkoutAlert) {
            Button(LocalizedStringKey("Delete"), role: .destructive) {
                context.delete(workout)
                
                // Фикс: сохраняем изменения и обновляем кэш, чтобы Overview не пытался прочесть удаленный объект
                try? context.save()
                viewModel.updateWidgetData(container: context.container)
                viewModel.refreshAllCaches(container: context.container)
                
                // Останавливаем таймер при удалении пустой тренировки
                timerManager.stopRestTimer()
                
                dismiss()
            }
            Button(LocalizedStringKey("Continue"), role: .cancel) { }
        } message: {
            Text(LocalizedStringKey("This workout has no completed sets. Do you want to delete it or continue?"))
        }
    }
    
    // MARK: - View Sections
    
    private var headerSection: some View {
            VStack(spacing: 20) {
                // Статус бар
                if workout.isActive {
                    HStack {
                        Label(LocalizedStringKey("Live Workout"), systemImage: "record.circle")
                            .foregroundStyle(Color.accentColor).bold().blinking()
                        Spacer()
                        
                        WorkoutTimerView(startDate: workout.date)
                    }
                    .padding()
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(12)
                } else {
                    HStack {
                        Image(systemName: "flag.checkered").foregroundColor(.accentColor)
                        Text(LocalizedStringKey("Completed")).bold()
                        Spacer()
                        Text(workout.date.formatted(date: .abbreviated, time: .shortened))
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(12)
                }
                
                // Статистика (Время, Усилие)
                HStack {
                    VStack(alignment: .leading) {
                        Text(LocalizedStringKey("Duration")).font(.caption).foregroundColor(.secondary)
                        if workout.isActive {
                            WorkoutTimerView(startDate: workout.date)
                        } else {
                            Text(LocalizedStringKey("\(workout.duration) min")).font(.title2).bold()
                        }
                    }
                    Spacer()
                    
                    // БЛОК EFFORT
                    VStack(alignment: .trailing) {
                        Text(LocalizedStringKey("Avg Effort")).font(.caption).foregroundColor(.secondary)
                        Text("\(workout.effortPercentage)%")
                            .font(.title2).bold()
                            .foregroundColor(effortColor(percentage: workout.effortPercentage))
                    }
                    .spotlight(
                        step: .explainEffort,
                        manager: tutorialManager,
                        text: "Track your intensity (RPE) here.",
                        alignment: .bottom,
                        xOffset: -10,
                        yOffset: 10
                    )
                }
                .padding()
                .background(Color.accentColor.opacity(0.05))
                .cornerRadius(10)
            }
            .zIndex(10)
        }
        
        private var actionButtonSection: some View {
            Group {
                if !workout.isActive {
                    Button {
                        generateAndShare()
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
                }
            }
            .zIndex(9) 
        }
    
    private var exercisesToolbarSection: some View {
            HStack {
                Text(LocalizedStringKey("Exercises")).font(.title2).bold()
                Spacer()
                
                // Кнопка ручного запуска таймера
                if workout.isActive {
                    Button {
                        timerManager.startRestTimer()
                    } label: {
                        Image(systemName: "timer")
                            .font(.headline)
                            .padding(8)
                            .background(Color.accentColor.opacity(0.1))
                            .foregroundColor(.accentColor)
                            .cornerRadius(8)
                    }
                }
                
                // Кнопка Супер-сета
                Button {
                    showSupersetBuilder = true
                } label: {
                    Label(LocalizedStringKey("Superset"), systemImage: "plus")
                        .font(.caption).bold()
                        .padding(8)
                        .background(Color.accentColor.opacity(0.1))
                        .foregroundColor(.accentColor)
                        .cornerRadius(8)
                }
                .disabled(!workout.isActive)
                
                // КНОПКА ДОБАВЛЕНИЯ УПРАЖНЕНИЯ
                Button {
                    showExerciseSelection = true
                } label: {
                    Label(LocalizedStringKey("Exercise"), systemImage: "plus")
                        .font(.caption).bold()
                        .padding(8)
                        .background(Color.accentColor.opacity(0.1))
                        .foregroundColor(.accentColor)
                        .cornerRadius(8)
                }
                .disabled(!workout.isActive)
                .spotlight(
                    step: .addExercise,
                    manager: tutorialManager,
                    text: "Tap here to add an exercise.",
                    alignment: .top,
                    xOffset: -50,
                    yOffset: 10
                )
            }
            .zIndex(15)
        }
    
    private var exerciseListSection: some View {
        Group {
            if workout.exercises.isEmpty {
                EmptyStateView(
                    icon: "plus.circle.fill",
                    title: LocalizedStringKey("No exercises added yet"),
                    message: LocalizedStringKey("Tap the + button above to add your first exercise to this workout.")
                )
                .padding(.vertical, 30)
            } else {
                VStack(spacing: 16) {
                    ForEach(Array(workout.exercises.enumerated()), id: \.element.id) { index, exercise in
                        
                        let deleteAction = {
                            self.exerciseToDelete = exercise
                            self.showDeleteExerciseAlert = true
                        }
                        
                        let swapAction = {
                            self.exerciseToSwap = exercise
                            self.showSwapSheet = true
                        }
                        
                        let isExpandedBinding = Binding(
                            get: { expandedExercises[exercise.id] ?? false },
                            set: { expandedExercises[exercise.id] = $0 }
                        )
                        
                        // ИСПРАВЛЕНИЕ: Суперсеты теперь тоже могут быть Current, а условие стало проще
                        let isCurrentExercise = workout.isActive && 
                            !exercise.isCompleted && 
                            (expandedExercises[exercise.id] ?? false) &&
                            workout.exercises.prefix(index).allSatisfy { $0.isCompleted }
                        
                        let onExerciseFinished = {
                            handleExerciseFinished(exerciseId: exercise.id, exerciseIndex: index)
                        }
                        
                        Group {
                            if exercise.isSuperset {
                                SupersetCardView(
                                    superset: exercise,
                                    currentWorkoutId: workout.id,
                                    onDelete: deleteAction,
                                    isWorkoutCompleted: !workout.isActive,
                                    isExpanded: isExpandedBinding,
                                    onExerciseFinished: onExerciseFinished,
                                    isCurrentExercise: isCurrentExercise
                                )
                            } else {
                                ExerciseCardView(
                                    exercise: exercise,
                                    currentWorkoutId: workout.id,
                                    onDelete: deleteAction,
                                    onSwap: swapAction,
                                    isWorkoutCompleted: !workout.isActive,
                                    isExpanded: isExpandedBinding,
                                    onExerciseFinished: onExerciseFinished,
                                    isCurrentExercise: isCurrentExercise
                                )
                            }
                        }
                        .id(exercise.id) 
                        .background(Color.white.opacity(0.01))
                        .onDrag {
                            self.draggedExercise = exercise
                            return NSItemProvider(object: exercise.id.uuidString as NSString)
                        }
                        .onDrop(of: [UTType.text], delegate: ExerciseDropDelegate(
                            item: exercise,
                            items: $workout.exercises,
                            draggedItem: $draggedExercise
                        ))
                    }
                }
            }
        }
    }
    
    private var chartSection: some View {
        return Group {
            if !strengthExercises.isEmpty {
                VStack(alignment: .leading) {
                    Text(LocalizedStringKey("Analysis (Max Weight)"))
                        .font(.title2).bold().padding(.top)
                    
                    if let selected = selectedChartExerciseName {
                        Text(LocalizedStringKey(selected))
                            .font(.subheadline)
                            .foregroundColor(.accentColor)
                            .padding(.bottom, 4)
                            .frame(minHeight: 20)
                    } else {
                        Text(LocalizedStringKey("Tap a bar to see full name"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.bottom, 4)
                            .frame(minHeight: 20)
                    }
                    
                    let exerciseNames = strengthExercises.map { $0.name }
                    
                    Chart {
                        ForEach(strengthExercises) { exercise in
                            // ИСПРАВЛЕНИЕ: Берем вес только из завершенных подходов
                            let maxWeight = exercise.setsList
                                .filter { $0.isCompleted && $0.type != .warmup }
                                .compactMap { $0.weight }
                                .max() ?? 0
                            
                            if maxWeight > 0 {
                                let unitsManager = UnitsManager.shared
                                let convertedWeight = unitsManager.convertFromKilograms(maxWeight)
                                BarMark(
                                    x: .value("Exercise", exercise.name),
                                    y: .value("Weight", convertedWeight)
                                )
                                .foregroundStyle(selectedChartExerciseName == exercise.name ? Color.orange.gradient : Color.accentColor.gradient)
                                .cornerRadius(4)
                                .annotation(position: .top) {
                                    Text("\(Int(convertedWeight))")
                                        .font(.caption2)
                                        .foregroundColor(selectedChartExerciseName == exercise.name ? .orange : .secondary)
                                }
                            }
                        }
                    }
                    .frame(height: 250)
                    .padding(.bottom, 10)
                    .chartXSelection(value: $selectedChartExerciseName)
                    .chartXAxis {
                        AxisMarks(values: exerciseNames) { value in
                            AxisTick()
                            AxisValueLabel {
                                if let exerciseName = value.as(String.self) {
                                    Text(abbreviateName(exerciseName))
                                        .font(.caption2)
                                }
                            }
                        }
                    }
                }
                .spotlight(
                                   step: .highlightChart,
                                   manager: tutorialManager,
                                   text: "Track progress here.\nTap chart to continue.",
                                   alignment: .bottom
                               )
                               .onTapGesture {
                                   if tutorialManager.currentStep == .highlightChart {
                                       tutorialManager.nextStep() 
                                   }
                }
            }
        }
    }
    
    private var muscleHeatmapSection: some View {
        VStack(alignment: .leading) {
            Text(LocalizedStringKey("Body Status"))
                .font(.title2).bold().padding(.top)
            
            VStack {
                BodyHeatmapView(muscleIntensities: muscleIntensityMap)
            }
            .padding(.vertical)
            .frame(maxWidth: .infinity)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(16)
            .spotlight(
                            step: .highlightBody,
                            manager: tutorialManager,
                            text: "See targeted muscles.\nTap heatmap to continue.",
                            alignment: .top
                        )
                        .onTapGesture {
                            if tutorialManager.currentStep == .highlightBody {
                                tutorialManager.nextStep() 
                            }
            }
        }
    }
    
    // MARK: - Logic & Actions
    
    private func updateComputedData() {
        let newFlattened = workout.exercises.flatMap { exercise in
            exercise.isSuperset ? exercise.subExercises : [exercise]
        }
        
        var counts = [String: Int]()
        var volume = 0.0
        
        for exercise in workout.exercises {
            let targets = exercise.isSuperset ? exercise.subExercises : [exercise]
            
            for sub in targets {
                // ИСПРАВЛЕНИЕ: Проверяем, есть ли хотя бы один завершенный подход
                let hasCompletedSets = sub.setsList.contains(where: { $0.isCompleted })
                
                if sub.type != .cardio && hasCompletedSets {
                    let muscles = MuscleMapping.getMuscles(for: sub.name, group: sub.muscleGroup)
                    for muscleSlug in muscles {
                        counts[muscleSlug, default: 0] += 1
                    }
                }
            }
            
            if exercise.isSuperset {
                for sub in exercise.subExercises where sub.type == .strength {
                    volume += sub.computedVolume
                }
            } else if exercise.type == .strength {
                volume += exercise.computedVolume
            }
        }
        
        self.flattenedExercises = newFlattened
        
        // ИСПРАВЛЕНИЕ: Фильтруем для графика, оставляя только упражнения, в которых есть завершенные силовые сеты с весом > 0
        self.strengthExercises = newFlattened.filter { exercise in
            exercise.type == .strength && exercise.setsList.contains(where: { $0.isCompleted && $0.type != .warmup && ($0.weight ?? 0) > 0 })
        }
        
        self.muscleIntensityMap = counts
        self.totalStrengthVolume = volume
    }
    
    private func abbreviateName(_ name: String) -> String {
        let words = name.split(separator: " ")
        if words.count > 1 {
            return words.prefix(2).compactMap { $0.first }.map { String($0) }.joined().uppercased()
        } else {
            return String(name.prefix(3)).capitalized
        }
    }
    
    private func performSwap(old: Exercise, new: Exercise) {
        guard let index = workout.exercises.firstIndex(where: { $0.id == old.id }) else { return }
        withAnimation {
            workout.exercises[index] = new
            context.delete(old) 
        }
        updateComputedData()
    }
    
    private func finishWorkout() {
        // Проверяем, есть ли хотя бы один завершенный подход
        var hasAnyCompletedSet = false
        for exercise in workout.exercises {
            let targets = exercise.isSuperset ? exercise.subExercises : [exercise]
            if targets.contains(where: { $0.setsList.contains(where: { $0.isCompleted }) }) {
                hasAnyCompletedSet = true
                break
            }
        }
        
        // Защита от пустых тренировок (если нет ни одного выполненного подхода)
        guard hasAnyCompletedSet else {
            showEmptyWorkoutAlert = true
            return
        }

        // 1. Фиксируем время
        workout.endTime = Date()
        
        if tutorialManager.currentStep == .finishWorkout {
            tutorialManager.setStep(.recoveryCheck)
        }
        
        // 2. Начисляем XP
        viewModel.progressManager.addXP(for: workout)
        
        // 3. Планируем уведомления
        NotificationManager.shared.scheduleNotifications(after: workout)
        
        // 4. Останавливаем Live Activity
        stopLiveActivity()
        
        // Останавливаем глобальный таймер отдыха
        timerManager.stopRestTimer()
        
        // 5. Инкрементальное обновление глобальной статистики (Агрегация: Предотвращение N+1 Faulting Bomb)
        let statsDescriptor = FetchDescriptor<UserStats>()
        let stats = (try? context.fetch(statsDescriptor))?.first ?? {
            let newStats = UserStats()
            context.insert(newStats)
            return newStats
        }()
        
        // Считаем дистанцию (Cardio) только для текущей тренировки
        var currentWorkoutDistance = 0.0
        for exercise in workout.exercises {
            let targets = exercise.isSuperset ? exercise.subExercises : [exercise]
            for ex in targets where ex.type == .cardio {
                currentWorkoutDistance += ex.setsList.filter { $0.isCompleted }.compactMap { $0.distance }.reduce(0, +)
            }
        }
        
        // Инкремент
        stats.totalWorkouts += 1
        stats.totalVolume += self.totalStrengthVolume // Уже посчитано во View!
        stats.totalDistance += currentWorkoutDistance
        
        let hour = Calendar.current.component(.hour, from: workout.date)
        if hour >= 4 && hour < 8 { stats.earlyWorkouts += 1 }
        if hour >= 22 || hour < 4 { stats.nightWorkouts += 1 }
        
        // Сохраняем агрегированную модель на главном потоке
        try? context.save()
        
        // Копируем скалярные значения для безопасной передачи в фоновую задачу
        let tWorkouts = stats.totalWorkouts
        let tVolume = stats.totalVolume
        let tDistance = stats.totalDistance
        let eWorkouts = stats.earlyWorkouts
        let nWorkouts = stats.nightWorkouts
        
        let modelContainer = context.container
        let cachedUnlockedCount = self.unlockedAchievementsCount
        
        Task.detached(priority: .background) {
            let bgContext = ModelContext(modelContainer)
            
            // Запрашиваем тренировки ТОЛЬКО для расчета streak. 
            // Prefetching удален, чтобы не грузить упражнения и сеты (предотвращение N+1).
            let descriptor = FetchDescriptor<Workout>(
                predicate: #Predicate<Workout> { $0.endTime != nil },
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            
            guard let workouts = try? bgContext.fetch(descriptor) else { return }
            
            // Расчет стрик-статуса безопасен: он читает только свойство .date у Workout.
            let streak = StatisticsManager.calculateWorkoutStreak(workouts: workouts)
            
            // Передаем O(1) статистику вместо прохода по вложенным массивам сотен тренировок
            let calculatedAchievements = AchievementCalculator.calculateAchievements(
                totalWorkouts: tWorkouts,
                totalVolume: tVolume,
                totalDistance: tDistance,
                earlyWorkouts: eWorkouts,
                nightWorkouts: nWorkouts,
                streak: streak
            )
            
            let currentUnlockedCount = calculatedAchievements.filter { $0.isUnlocked }.count
            
            // Проверяем, появились ли *новые* ачивки
            if currentUnlockedCount > cachedUnlockedCount {
                await MainActor.run {
                    self.unlockedAchievementsCount = currentUnlockedCount
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                }
            }
        }
        
        // 6. Обновляем виджеты
        viewModel.updateWidgetData(container: context.container)
        
        // 7. Обновляем кеши напрямую через ViewModel
        viewModel.refreshAllCaches(container: context.container)
    }
    
    private func stopLiveActivity() {
        Task {
            for activity in Activity<WorkoutActivityAttributes>.activities {
                await activity.end(dismissalPolicy: .after(Date().addingTimeInterval(5)))
            }
        }
    }
    
    @MainActor
    private func generateAndShare() {
        let renderer = ImageRenderer(content: WorkoutShareCard(workout: workout))
        renderer.scale = 3.0
        
        if let uiImage = renderer.uiImage {
            self.shareItems = [uiImage]
            self.showShareSheet = true
        }
    }
    
    private func effortColor(percentage: Int) -> Color {
        if percentage > 80 { return .red }
        if percentage > 50 { return .orange }
        return .green
    }
    
    private func handleExerciseFinished(exerciseId: UUID, exerciseIndex: Int) {
        updateComputedData() // Пересчитываем объем после завершения упражнения
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            expandedExercises[exerciseId] = false
        }
        
        // ИСПРАВЛЕНИЕ: Теперь мы ищем и Суперсеты тоже, чтобы развернуть их
        let nextIndex = workout.exercises.indices.first { index in
            index > exerciseIndex && !workout.exercises[index].isCompleted
        }
        
        if let nextIndex = nextIndex {
            let nextExercise = workout.exercises[nextIndex]
            
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                expandedExercises[nextExercise.id] = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                scrollToExerciseId = nextExercise.id
            }
        }
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
            .onReceive(timer) { _ in
                updateTime()
            }
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

struct ComparisonItem {
    let name: String
    let weight: Double
    let icon: String
}

struct FunFactView: View {
    let totalStrengthVolume: Double
    @StateObject private var unitsManager = UnitsManager.shared
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
        // Оборачиваем содержимое в постоянный контейнер (VStack), 
        // чтобы SwiftUI гарантированно запустил .onAppear, когда вкладка монтируется.
        VStack {
            if totalStrengthVolume > 0, let comparison = selectedComparison {
                let count = totalStrengthVolume / comparison.weight
                
                VStack(alignment: .leading, spacing: 12) {
                    Text(LocalizedStringKey("🏋️ Total Lifted"))
                        .font(.caption).fontWeight(.bold)
                        .foregroundColor(.secondary).textCase(.uppercase)
                    
                    let convertedVolume = unitsManager.convertFromKilograms(totalStrengthVolume)
                    Text(LocalizedStringKey("You lifted \(Int(convertedVolume)) \(unitsManager.weightUnitString())!"))
                        .font(.title2).bold()
                    
                    Divider()
                    
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(LocalizedStringKey("That's approximately"))
                                .foregroundColor(.secondary).font(.subheadline)
                            
                            HStack(alignment: .lastTextBaseline, spacing: 6) {
                                Text("\(count, format: .number.precision(.fractionLength(1)))")
                                    .font(.title3).fontWeight(.heavy).foregroundColor(.primary)
                                
                                Text("\(LocalizedStringKey(comparison.name)) \(comparison.icon)")
                                    .font(.headline).foregroundColor(.primary).lineLimit(1)
                            }
                            Text(LocalizedStringKey("Way to go, champion! 🥇"))
                                .font(.caption).foregroundColor(.gray).padding(.top, 2)
                        }
                        Spacer()
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(16)
                .padding(.top, 10)
            }
        }
        .onAppear {
            pickRandomComparison()
        }
        .onChange(of: totalStrengthVolume) { _, _ in
            pickRandomComparison()
        }
    }
    
    private func pickRandomComparison() {
        guard totalStrengthVolume > 0 else { return }
        
        // Filter out items that are heavier than the user's lifted volume
        // Ensures the count is always >= 1.0
        let validComparisons = allComparisons.filter { totalStrengthVolume / $0.weight >= 1.0 }
        
        if let random = validComparisons.randomElement() {
            selectedComparison = random
        } else {
            // If the user lifted very little, pick the lightest possible option
            selectedComparison = allComparisons.min(by: { $0.weight < $1.weight })
        }
    }
}

struct ExerciseRowView: View {
    let exercise: Exercise
    @StateObject private var unitsManager = UnitsManager.shared
    
    var body: some View {
        HStack {
            Rectangle()
                .frame(width: 4)
                .foregroundColor(effortColor(value: exercise.effort))
                .cornerRadius(2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey(exercise.name))
                    .font(.headline).foregroundColor(.primary)
                
                HStack {
                    detailText
                    Spacer()
                    rpeBadge
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
    
    @ViewBuilder
    private var detailText: some View {
        switch exercise.type {
        case .strength:
            let convertedWeight = unitsManager.convertFromKilograms(exercise.weight)
            Text("\(exercise.sets)s x \(exercise.reps)r • \(LocalizationHelper.shared.formatInteger(convertedWeight))\(unitsManager.weightUnitString())")
        case .cardio:
            if let dist = exercise.distance, let time = exercise.timeSeconds {
                let convertedDist = unitsManager.convertFromKilometers(dist)
                Text(LocalizedStringKey("\(LocalizationHelper.shared.formatTwoDecimals(convertedDist)) \(unitsManager.distanceUnitString()) in \(formatTime(time))"))
            } else {
                Text(LocalizedStringKey("Cardio"))
            }
        case .duration:
            if let time = exercise.timeSeconds {
                Text(LocalizedStringKey("\(exercise.sets) sets x \(formatTime(time))"))
            } else {
                Text(LocalizedStringKey("Duration"))
            }
        }
    }
    
    private var rpeBadge: some View {
        Text(LocalizedStringKey("RPE \(exercise.effort)"))
            .font(.caption2).bold()
            .padding(4)
            .background(effortColor(value: exercise.effort).opacity(0.2))
            .foregroundColor(effortColor(value: exercise.effort))
            .cornerRadius(4)
    }
    
    private func formatTime(_ totalSeconds: Int) -> String {
        let m = totalSeconds / 60
        let s = totalSeconds % 60
        return String(format: "%d:%02d", m, s)
    }
    
    private func effortColor(value: Int) -> Color {
        switch value {
        case 1...4: return .green
        case 5...7: return .orange
        case 8...10: return .red
        default: return .blue
        }
    }
}

// Анимация пульсации для Live индикатора
struct Blinking: ViewModifier {
    @State private var isOn = false
    func body(content: Content) -> some View {
        content.opacity(isOn ? 1 : 0.5).onAppear {
            withAnimation(Animation.easeInOut(duration: 1).repeatForever()) { isOn = true }
        }
    }
}
extension View { func blinking() -> some View { modifier(Blinking()) } }

