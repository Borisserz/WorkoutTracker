//
//  WorkoutDetailView.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 24.12.25.
//
//  Экран активной тренировки (или просмотра истории).
//

internal import SwiftUI
import Charts
import Combine
import ActivityKit
internal import UniformTypeIdentifiers

// MARK: - Main View

struct WorkoutDetailView: View {
    
    // MARK: - Environment & Bindings
    @EnvironmentObject var tutorialManager: TutorialManager
    @Binding var workout: Workout
    @EnvironmentObject var viewModel: WorkoutViewModel
    @EnvironmentObject var timerManager: RestTimerManager
    
    // MARK: - Local State (UI)
    
    @State private var timeElapsed: String = "0:00"
    
    // Управление модальными окнами
    @State private var showExerciseSelection = false
    @State private var showSupersetBuilder = false
    @State private var showShareSheet = false
    @State private var showComparisonSettings = false
    
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
    @State private var exerciseIndexToDelete: Int?
    @State private var showDeleteSupersetAlert = false
    @State private var supersetIndexToDelete: Int?
    
    // Sharing
    @State private var shareItems: [Any] = []
    
    // Управление раскрытостью упражнений
    @State private var expandedExercises: [UUID: Bool] = [:]
    
    // ID упражнения, к которому нужно прокрутить
    @State private var scrollToExerciseId: UUID?
    
    // MARK: - Computed Properties
    
    /// Плоский список всех упражнений (разворачивает супер-сеты для графиков)
    var flattenedExercises: [Exercise] {
        workout.exercises.flatMap { exercise in
            exercise.isSuperset ? exercise.subExercises : [exercise]
        }
    }
    
    /// Карта интенсивности нагрузки на мышцы для Heatmap
    var muscleIntensityMap: [String: Int] {
        var counts = [String: Int]()
        
        for exercise in workout.exercises {
            // Кардио не учитываем на тепловой карте
            if exercise.type == .cardio { continue }
            
            let targets = exercise.isSuperset ? exercise.subExercises : [exercise]
            
            for sub in targets {
                let muscles = MuscleMapping.getMuscles(for: sub.name, group: sub.muscleGroup)
                for muscleSlug in muscles {
                    counts[muscleSlug, default: 0] += 1
                }
            }
        }
        return counts
    }
    
    /// Определяет, является ли тренировка новой (созданной недавно, например, из шаблона)
    /// Тренировка считается новой, если она создана менее минуты назад и имеет упражнения
    var isNewWorkout: Bool {
        let timeSinceCreation = Date().timeIntervalSince(workout.date)
        return timeSinceCreation < 60 && !workout.exercises.isEmpty
    }
    
    // MARK: - Body
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                
                // 1. Заголовок (Картинка, Таймер, Инфо)
                headerSection
                
                // 2. Основная кнопка (Finish / Share)
                actionButtonSection
                
                Divider().padding(.vertical, 5)
                
                // 3. Заголовок списка упражнений + Кнопки добавления
                exercisesToolbarSection
                
                // 4. Список карточек упражнений
                exerciseListSection
                
                // 5. График (Максимальный вес)
                chartSection
                
                // 6. Тепловая карта тела
                muscleHeatmapSection
                
                // 7. Интересный факт (Сравнение веса)
                if !workout.exercises.isEmpty {
                    FunFactView(workout: workout, showSettings: $showComparisonSettings)
                }
                
                    // Отступ снизу, чтобы глобальный таймер отдыха не перекрывал контент
                    Spacer(minLength: 80)
                }
                .padding()
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
                // Инициализируем состояние раскрытости для всех упражнений
                // Первое упражнение всегда раскрыто, остальные - по логике
                for (index, exercise) in workout.exercises.enumerated() {
                    if expandedExercises[exercise.id] == nil {
                        expandedExercises[exercise.id] = index == 0 ? true : !isNewWorkout
                    }
                }
            }
            .onChange(of: workout.exercises.count) { oldCount, newCount in
                // При добавлении нового упражнения инициализируем его состояние
                // Первое упражнение всегда раскрыто, остальные - свернуты
                for (index, exercise) in workout.exercises.enumerated() {
                    if expandedExercises[exercise.id] == nil {
                        expandedExercises[exercise.id] = index == 0
                    }
                }
            }
            .onChange(of: scrollToExerciseId) { oldId, newId in
                // Прокручиваем к упражнению когда изменяется scrollToExerciseId
                if let exerciseId = newId {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation {
                            proxy.scrollTo(exerciseId, anchor: .top)
                        }
                        scrollToExerciseId = nil // Сбрасываем после прокрутки
                    }
                }
            }
        }
        
        // --- Modals & Sheets ---
        
        // Поделиться
        .sheet(isPresented: $showShareSheet) {
            ActivityViewController(activityItems: shareItems)
                .presentationDetents([.medium, .large])
        }
        
        // Добавление упражнения
        .sheet(isPresented: $showExerciseSelection) {
            ExerciseSelectionView(selectedExercises: $workout.exercises)
        }
        
        // Редактирование упражнения
        .sheet(item: $exerciseToEdit) { exerciseToSave in
            if let index = workout.exercises.firstIndex(where: { $0.id == exerciseToSave.id }) {
                NavigationStack {
                    EditExerciseView(exercise: $workout.exercises[index])
                        .toolbar {
                            ToolbarItem(placement: .destructiveAction) {
                                Button(LocalizedStringKey("Delete"), role: .destructive) {
                                    exerciseIndexToDelete = index
                                    showDeleteExerciseAlert = true
                                }
                            }
                        }
                }
                .presentationDetents([.medium, .large])
            }
        }
        
        // Настройка сравнения (Арбузы)
        .sheet(isPresented: $showComparisonSettings) {
            ComparisonSettingsView().presentationDetents([.medium])
        }
        
        // Создание супер-сета
        .sheet(isPresented: $showSupersetBuilder) {
            SupersetBuilderView { newSuperset in
                workout.exercises.append(newSuperset)
            }
        }
        
        // Редактирование супер-сета
        .sheet(item: $supersetToEdit) { superset in
            SupersetBuilderView(existingSuperset: superset, onSave: { updatedSuperset in
                if let index = workout.exercises.firstIndex(where: { $0.id == superset.id }) {
                    workout.exercises[index] = updatedSuperset
                }
                supersetToEdit = nil
            }, onDelete: {
                if let index = workout.exercises.firstIndex(where: { $0.id == superset.id }) {
                    supersetIndexToDelete = index
                    showDeleteSupersetAlert = true
                }
                supersetToEdit = nil
            })
        }
        
        // Замена упражнения (Swap)
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
        
        // Таймер обновления времени
        .onReceive(Foundation.Timer.publish(every: 1.0, on: RunLoop.main, in: RunLoop.Mode.common).autoconnect()) { _ in
            if workout.isActive { updateTimer() }
        }
        .onAppear(perform: updateTimer)
        // Предупреждения при удалении
        .alert(LocalizedStringKey("Delete Exercise?"), isPresented: $showDeleteExerciseAlert) {
            Button(LocalizedStringKey("Delete"), role: .destructive) {
                if let index = exerciseIndexToDelete {
                    withAnimation { workout.exercises.remove(at: index) }
                    exerciseIndexToDelete = nil
                }
                if exerciseToEdit != nil {
                    exerciseToEdit = nil
                }
            }
            Button(LocalizedStringKey("Cancel"), role: .cancel) {
                exerciseIndexToDelete = nil
            }
        } message: {
            if let index = exerciseIndexToDelete, index < workout.exercises.count {
                let exerciseName = workout.exercises[index].name
                Text(LocalizedStringKey("Are you sure you want to delete '\(exerciseName)'? This action cannot be undone."))
            } else {
                Text(LocalizedStringKey("Are you sure you want to delete this exercise? This action cannot be undone."))
            }
        }
        .alert(LocalizedStringKey("Delete Superset?"), isPresented: $showDeleteSupersetAlert) {
            Button(LocalizedStringKey("Delete"), role: .destructive) {
                if let index = supersetIndexToDelete {
                    withAnimation { workout.exercises.remove(at: index) }
                    supersetIndexToDelete = nil
                }
                if supersetToEdit != nil {
                    supersetToEdit = nil
                }
            }
            Button(LocalizedStringKey("Cancel"), role: .cancel) {
                supersetIndexToDelete = nil
            }
        } message: {
            Text(LocalizedStringKey("Are you sure you want to delete this superset? This action cannot be undone."))
        }
    }
    
    // MARK: - View Sections
    
    private var headerSection: some View {
            VStack(spacing: 20) {
                // Статус бар
                if workout.isActive {
                    HStack {
                        Label(LocalizedStringKey("Live Workout"), systemImage: "record.circle")
                            .foregroundStyle(.red).bold().blinking()
                        Spacer()
                        Text(timeElapsed)
                            .font(.title2).monospacedDigit().bold()
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(12)
                } else {
                    HStack {
                        Image(systemName: "flag.checkered").foregroundColor(.green)
                        Text(LocalizedStringKey("Completed")).bold()
                        Spacer()
                        Text(workout.date.formatted(date: .abbreviated, time: .shortened))
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                }
                
                // Картинка
                workoutImage
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    .shadow(radius: 5)
                
                // Статистика (Время, Усилие)
                HStack {
                    VStack(alignment: .leading) {
                        Text(LocalizedStringKey("Duration")).font(.caption).foregroundColor(.secondary)
                        Text(workout.isActive ? LocalizedStringKey(timeElapsed) : LocalizedStringKey("\(workout.duration) min")).font(.title2).bold()
                    }
                    Spacer()
                    
                    // БЛОК EFFORT
                    VStack(alignment: .trailing) {
                        Text(LocalizedStringKey("Avg Effort")).font(.caption).foregroundColor(.secondary)
                        Text("\(workout.effortPercentage)%")
                            .font(.title2).bold()
                            .foregroundColor(effortColor(percentage: workout.effortPercentage))
                    }
                    // ПОДСКАЗКА ДЛЯ УСТАЛОСТИ
                    .spotlight(
                        step: .explainEffort,
                        manager: tutorialManager,
                        text: "Track your intensity (RPE) here.",
                        alignment: .bottom, // Прижимаем к правому краю
                        xOffset: -10, // Чуть сдвигаем влево, чтобы не обрезалось
                        yOffset: 10
                    )
                }
                .padding()
                .background(Color.blue.opacity(0.05))
                .cornerRadius(10)
            }
            .zIndex(10) // <--- ВАЖНО: Поднимаем хедер над остальным контентом
        }
        
        private var actionButtonSection: some View {
            Group {
                if workout.isActive {
                    Button(action: finishWorkout) {
                        Text(LocalizedStringKey("Finish Workout"))
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .shadow(radius: 5)
                    }
                    // ПОДСКАЗКА ДЛЯ КНОПКИ ФИНИШ
                    .spotlight(
                                        step: .finishWorkout,
                                        manager: tutorialManager,
                                        text: "Tap here to save and finish.",
                                        alignment: .top)
                } else {
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
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .shadow(radius: 5)
                    }
                }
            }
            .zIndex(9) // <--- ВАЖНО: Кнопка тоже должна быть выше списка упражнений
        }
    
    private var exercisesToolbarSection: some View {
            HStack {
                Text(LocalizedStringKey("Exercises")).font(.title2).bold()
                Spacer()
                
                // Кнопка ручного запуска таймера (только для активной)
                if workout.isActive {
                    Button {
                        timerManager.startRestTimer()
                    } label: {
                        Image(systemName: "timer")
                            .font(.headline)
                            .padding(8)
                            .background(Color.orange.opacity(0.1))
                            .foregroundColor(.orange)
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
                        .background(Color.purple.opacity(0.1))
                        .foregroundColor(.purple)
                        .cornerRadius(8)
                }
                .disabled(!workout.isActive)
                
                // --- КНОПКА ДОБАВЛЕНИЯ УПРАЖНЕНИЯ ---
                Button {
                    showExerciseSelection = true
                } label: {
                    Label(LocalizedStringKey("Exercise"), systemImage: "plus")
                        .font(.caption).bold()
                        .padding(8)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                }
                .disabled(!workout.isActive)
                .spotlight(
                    step: .addExercise,
                    manager: tutorialManager,
                    text: "Tap here to add an exercise.",
                    alignment: .top,   // Текст СВЕРХУ кнопки
                    xOffset: -50,      // Сдвигаем влево, чтобы не ушло за экран
                    yOffset: 10
                )
            }
            // ВАЖНО: Поднимаем тулбар над списком, чтобы подсказка не обрезалась
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
                    ForEach(workout.exercises) { exercise in
                        
                        if let index = workout.exercises.firstIndex(where: { $0.id == exercise.id }) {
                            
                            let exerciseBinding = $workout.exercises[index]
                            
                            let deleteAction = {
                                exerciseIndexToDelete = index
                                showDeleteExerciseAlert = true
                            }
                            
                            let swapAction = {
                                self.exerciseToSwap = exercise
                                self.showSwapSheet = true
                            }
                            
                            // Binding для состояния раскрытости
                            let isExpandedBinding = Binding(
                                get: { expandedExercises[exercise.id] ?? false },
                                set: { expandedExercises[exercise.id] = $0 }
                            )
                            
                            // Определяем, является ли это упражнение текущим (активным)
                            // Текущее упражнение - это первое незавершенное и раскрытое упражнение
                            let isCurrentExercise = workout.isActive && 
                                !exercise.isCompleted && 
                                !exercise.isSuperset &&
                                (expandedExercises[exercise.id] ?? false) &&
                                workout.exercises.prefix(index).allSatisfy { $0.isCompleted || $0.isSuperset }
                            
                            // Callback при завершении упражнения
                            let onExerciseFinished = {
                                handleExerciseFinished(exerciseId: exercise.id, exerciseIndex: index)
                            }
                            
                            // Рендерим либо Супер-сет, либо обычную карточку
                            Group {
                                if exercise.isSuperset {
                                    SupersetCardView(
                                        superset: exerciseBinding,
                                        currentWorkoutId: workout.id,
                                        onDelete: deleteAction,
                                        isWorkoutCompleted: !workout.isActive
                                    )
                                } else {
                                    ExerciseCardView(
                                        exercise: exerciseBinding,
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
                            .id(exercise.id) // ID для ScrollViewReader
                            // Модификаторы Drag & Drop
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
    }
    
    private var chartSection: some View {
        let strengthExercises = flattenedExercises.filter { $0.type == .strength }
        
        return Group {
            if !strengthExercises.isEmpty {
                VStack(alignment: .leading) {
                    Text(LocalizedStringKey("Analysis (Max Weight)"))
                        .font(.title2).bold().padding(.top)
                    
                    // Получаем список всех имен упражнений для явного указания на оси X
                    let exerciseNames = strengthExercises.map { $0.name }
                    
                    Chart {
                        ForEach(strengthExercises) { exercise in
                            // Берем макс. вес из выполненных подходов
                            let maxWeight = exercise.setsList
                                .filter { $0.isCompleted && $0.type != .warmup }
                                .compactMap { $0.weight }
                                .max() ?? exercise.weight
                            
                            if maxWeight > 0 {
                                // Конвертируем вес для отображения на графике
                                let unitsManager = UnitsManager.shared
                                let convertedWeight = unitsManager.convertFromKilograms(maxWeight)
                                BarMark(
                                    x: .value("Exercise", exercise.name),
                                    y: .value("Weight", convertedWeight)
                                )
                                .foregroundStyle(Color.blue.gradient)
                                .cornerRadius(4)
                                .annotation(position: .top) {
                                    Text("\(Int(convertedWeight))")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .frame(height: 280)
                    .padding(.bottom, 40)
                    .chartXAxis {
                        // Явно указываем все значения для оси X, чтобы все подписи отображались
                        AxisMarks(values: exerciseNames) { value in
                            AxisTick()
                            AxisValueLabel {
                                if let exerciseName = value.as(String.self) {
                                    Text(exerciseName)
                                        .font(.caption2)
                                        .rotationEffect(.degrees(-45))
                                        .offset(x: 0, y: 5)
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
                                       tutorialManager.nextStep() // -> highlightBody
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
                                tutorialManager.nextStep() // -> finishWorkout
                            }
            }
        }
    }
    
    // MARK: - Logic & Actions
    
    // Генерация картинки на основе мышц
    private var workoutImage: Image {
        if workout.exercises.isEmpty { return Image("img_default") }
        
        var counts: [String: Int] = [:]
        for exercise in workout.exercises {
            let targets = exercise.isSuperset ? exercise.subExercises : [exercise]
            for t in targets { counts[t.muscleGroup, default: 0] += 1 }
        }
        
        // Сортировка (сначала по кол-ву, потом по алфавиту для стабильности)
        let sortedGroups = counts.sorted { (item1, item2) -> Bool in
            if item1.value == item2.value {
                return item1.key < item2.key
            }
            return item1.value > item2.value
        }
        
        let dominantGroup = sortedGroups.first?.key ?? "Default"
        
        let imageName: String
        switch dominantGroup {
        case "Chest": imageName = pickVariant(from: ["img_chest", "img_chest2"])
        case "Back": imageName = pickVariant(from: ["img_back", "img_back2"])
        case "Legs": imageName = pickVariant(from: ["img_legs", "img_legs2"])
        case "Arms": imageName = "img_arms"
        case "Shoulders": imageName = "img_shoulders"
        default: imageName = "img_default"
        }
        
        return Image(imageName)
    }
    
    // Стабильный выбор варианта картинки по ID тренировки
    private func pickVariant(from options: [String]) -> String {
        guard !options.isEmpty else { return "img_default" }
        let stableHash = workout.id.uuidString.utf8.reduce(0) { Int($0) + Int($1) }
        let index = abs(stableHash) % options.count
        return options[index]
    }
    
    private func updateTimer() {
        let diff = Date().timeIntervalSince(workout.date)
        let hours = Int(diff) / 3600
        let minutes = (Int(diff) / 60) % 60
        let seconds = Int(diff) % 60
        timeElapsed = hours > 0 ? String(format: "%d:%02d:%02d", hours, minutes, seconds) : String(format: "%d:%02d", minutes, seconds)
    }
    
    private func performSwap(old: Exercise, new: Exercise) {
        guard let index = workout.exercises.firstIndex(where: { $0.id == old.id }) else { return }
        withAnimation {
            workout.exercises[index] = new
        }
    }
    
    private func finishWorkout() {
        // 1. Фиксируем время
        workout.endTime = Date()
        
        if tutorialManager.currentStep == .finishWorkout {
            tutorialManager.setStep(.recoveryCheck)}
        // 2. Начисляем XP
        viewModel.progressManager.addXP(for: workout)
        
        // 3. Планируем уведомления
        NotificationManager.shared.scheduleNotifications(after: workout)
        
        // 4. Проверяем ачивки
        checkAchievements()
        
        // 5. Останавливаем Live Activity
        stopLiveActivity()
        
        // 6. Обновляем виджеты сразу после завершения тренировки
        viewModel.updateWidgetData()
    }
    
    private func checkAchievements() {
        let oldAchievements = AchievementCalculator.calculateAchievements(workouts: viewModel.workouts, streak: 0).filter { $0.isUnlocked }.count
        
        // Поскольку endTime уже установлен, тренировка считается завершенной
        // Пересчитываем ачивки с учетом нового стрика
        let newAchievements = AchievementCalculator.calculateAchievements(workouts: viewModel.workouts, streak: viewModel.calculateWorkoutStreak()).filter { $0.isUnlocked }.count
        
        if newAchievements > oldAchievements {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
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
    
    // Обработка завершения упражнения: сворачиваем текущее и раскрываем следующее
    private func handleExerciseFinished(exerciseId: UUID, exerciseIndex: Int) {
        // Сворачиваем текущее упражнение
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            expandedExercises[exerciseId] = false
        }
        
        // Ищем следующее незавершенное упражнение
        let nextIndex = workout.exercises.indices.first { index in
            index > exerciseIndex && !workout.exercises[index].isCompleted && !workout.exercises[index].isSuperset
        }
        
        if let nextIndex = nextIndex {
            let nextExercise = workout.exercises[nextIndex]
            
            // Раскрываем следующее упражнение
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                expandedExercises[nextExercise.id] = true
            }
            
            // Устанавливаем ID для прокрутки (onChange обработает прокрутку)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                scrollToExerciseId = nextExercise.id
            }
        }
    }
}

// MARK: - Subviews & Helpers

struct FunFactView: View {
    let workout: Workout
    @Binding var showSettings: Bool
    
    @AppStorage("comparisonName") private var comparisonName = "Watermelons 🍉"
    @AppStorage("comparisonWeight") private var comparisonWeight = 8.0
    @StateObject private var unitsManager = UnitsManager.shared
    
    var totalStrengthVolume: Double {
        var total = 0.0
        for exercise in workout.exercises {
            if exercise.isSuperset {
                for sub in exercise.subExercises where sub.type == .strength {
                    total += sub.computedVolume
                }
            } else if exercise.type == .strength {
                total += exercise.computedVolume
            }
        }
        return total
    }
    
    var body: some View {
        if totalStrengthVolume > 0 && comparisonWeight > 0 {
            let count = totalStrengthVolume / comparisonWeight
            
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
                            
                            Text(comparisonName.isEmpty ? LocalizedStringKey("Items") : LocalizedStringKey(comparisonName))
                                .font(.headline).foregroundColor(.primary).lineLimit(1)
                        }
                        Text(LocalizedStringKey("Way to go, champion! 🥇"))
                            .font(.caption).foregroundColor(.gray).padding(.top, 2)
                    }
                    Spacer()
                    Button { showSettings = true } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.title2).foregroundColor(.blue)
                            .padding(8).background(Color.blue.opacity(0.1)).clipShape(Circle())
                    }
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(16)
            .padding(.top, 10)
        } else {
            EmptyView()
        }
    }
}

struct ComparisonSettingsView: View {
    @Environment(\.dismiss) var dismiss
    
    @AppStorage("comparisonName") private var comparisonName = "Watermelons 🍉"
    @AppStorage("comparisonWeight") private var comparisonWeight = 8.0
    @StateObject private var unitsManager = UnitsManager.shared
    
    let presets: [(name: String, weight: Double, icon: String)] = [
        ("Watermelons 🍉", 8.0, "🍉"),
        ("African Elephants 🐘", 6000.0, "🐘"),
        ("Toyota Camrys 🚗", 1500.0, "🚗"),
        ("Adult Pandas 🐼", 100.0, "🐼"),
        ("Gold Bars 🧈", 12.4, "🧈"),
        ("SpaceX Starships 🚀", 5000000.0, "🚀")
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(LocalizedStringKey("Custom Comparison"))) {
                    TextField(LocalizedStringKey("Object Name (e.g. Pizzas)"), text: $comparisonName)
                    HStack {
                        Text(LocalizedStringKey("Weight (\(unitsManager.weightUnitString()))"))
                        Spacer()
                        TextField(LocalizedStringKey("Weight"), value: $comparisonWeight, format: .number)
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    }
                }
                
                Section(header: Text(LocalizedStringKey("Quick Presets"))) {
                    ForEach(presets, id: \.name) { preset in
                        Button {
                            comparisonName = preset.name
                            comparisonWeight = preset.weight
                            dismiss()
                        } label: {
                            HStack {
                                Text(preset.icon).font(.title2)
                                VStack(alignment: .leading) {
                                    Text(LocalizedStringKey(preset.name)).foregroundColor(.primary)
                                    // Вес в пресетах хранится в кг, конвертируем для отображения
                                    let convertedWeight = unitsManager.convertFromKilograms(preset.weight)
                                    Text("\(Int(convertedWeight)) \(unitsManager.weightUnitString())").font(.caption).foregroundColor(.secondary)
                                }
                                Spacer()
                                if comparisonName == preset.name {
                                    Image(systemName: "checkmark").foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(LocalizedStringKey("Compare With..."))
            .toolbar { Button(LocalizedStringKey("Done")) { dismiss() } }
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

// MARK: - Preview

#Preview {
    NavigationStack {
        WorkoutDetailView(workout: .constant(
            Workout(title: "Live Test", date: Date(), exercises: [
                Exercise(name: "Bench Press", muscleGroup: "Chest", sets: 3, reps: 10, weight: 80, effort: 9)
            ])
        )).environmentObject(WorkoutViewModel())
    }
}
