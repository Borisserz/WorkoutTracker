//
//  ExerciseHistoryView.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 24.12.25.
//
//  Экран детальной истории конкретного упражнения.
//  Включает три вкладки:
//  1. Summary - График и заметки.
//  2. Technique - Информация о технике упражнения.
//  3. History - Список всех выполненных тренировок с этим упражнением.
//

internal import SwiftUI
import SwiftData
import Charts

struct ExerciseHistoryView: View {
    
    // MARK: - Nested Types
    
    enum Tab: String, CaseIterable {
        case summary = "Summary"
        case technique = "Technique"
        case history = "History"
        
        var localizedName: String {
            switch self {
            case .summary: return NSLocalizedString("Summary", comment: "")
            case .technique: return NSLocalizedString("Technique", comment: "")
            case .history: return NSLocalizedString("History", comment: "")
            }
        }
    }
    
    enum GraphMetric: String, CaseIterable {
        case none = "None"
        case max = "Max"
        case average = "Average"
    }
    
    enum TimeRange: String, CaseIterable {
        case month = "1M"
        case threeMonths = "3M"
        case sixMonths = "6M"
        case year = "1Y"
        case all = "All"
    }
    
    enum TrendPeriod: String, CaseIterable, Identifiable {
        case month = "Month"
        case threeMonths = "3 Months"
        case year = "Year"
        
        var id: Self { self }
        
        var displayName: String {
            switch self {
            case .month: return "1M"
            case .threeMonths: return "3M"
            case .year: return "1Y"
            }
        }
    }
    
    struct DataPoint: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
    }
    
    // MARK: - Properties
    
    let exerciseName: String
    
    // ИСПРАВЛЕНИЕ: Удаляем @Query. Будем загружать данные асинхронно, чтобы не блокировать UI при переходе
    @Environment(\.modelContext) private var context
    
    @EnvironmentObject var viewModel: WorkoutViewModel
    @ObservedObject private var unitsManager = UnitsManager.shared
    @FocusState private var isInputActive: Bool
    
    // MARK: - State
    
    @State private var selectedTab: Tab = .summary
    @State private var selectedTimeRange: TimeRange = .all
    @State private var selectedMetric: GraphMetric = .none
    @State private var selectedTrendPeriod: TrendPeriod = .month
    
    // MARK: - Cached State for Performance Optimization
    
    @State private var isDataLoaded: Bool = false
    @State private var exerciseType: ExerciseType = .strength
    @State private var exerciseCategory: ExerciseCategory? = nil
    @State private var muscleGroup: String? = nil
    @State private var filteredWorkoutsData: [(workout: Workout, exercise: Exercise)] = []
    
    @State private var exerciseTrend: WorkoutViewModel.ExerciseTrend?
    @State private var exerciseForecast: WorkoutViewModel.ProgressForecast?
    
    // Кэш для быстрого рендеринга графика
    @State private var allDataPoints: [DataPoint] = []
    @State private var displayedGraphData: [DataPoint] = []
    @State private var currentMetricValue: Double? = nil
    
    // MARK: - Initialization
    
    init(exerciseName: String) {
        self.exerciseName = exerciseName
    }
    
    // MARK: - Computed Properties (General)
    
    private var safeCategory: ExerciseCategory {
        exerciseCategory ?? ExerciseCategory.determine(from: exerciseName)
    }
    
    var unitLabel: String {
        switch exerciseType {
        case .strength: return unitsManager.weightUnitString()
        case .cardio: return unitsManager.distanceUnitString()
        case .duration: return "min"
        }
    }

    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Вкладки навигации
            tabBar
            
            if !isDataLoaded {
                Spacer()
                ProgressView(LocalizedStringKey("Loading data..."))
                    .controlSize(.large)
                Spacer()
            } else {
                // Контент выбранной вкладки
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 30) {
                            switch selectedTab {
                            case .summary:
                                summaryContent
                            case .technique:
                                techniqueContent
                            case .history:
                                historyContent
                            }
                        }
                        .padding()
                    }
                    .onChange(of: isInputActive) { oldValue, newValue in
                        if newValue {
                            // Прокручиваем к секции заметок когда начинается ввод
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo("notesSection", anchor: .center)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(exerciseName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // Запускаем асинхронную загрузку при открытии экрана
            loadInitialData()
        }
        .onChange(of: selectedTrendPeriod) { _, _ in
            if isDataLoaded {
                exerciseTrend = calculateTrend(for: selectedTrendPeriod)
            }
        }
        .onChange(of: selectedTimeRange) { _, _ in
            if isDataLoaded {
                updateGraphData()
            }
        }
        .onChange(of: selectedMetric) { _, _ in
            if isDataLoaded {
                updateGraphData()
            }
        }
    }
    
    // MARK: - Data Loading & Processing (Optimized)
    
    private func loadInitialData() {
        Task { @MainActor in
            // ИСПРАВЛЕНИЕ ЗАВИСАНИЙ: Даем SwiftUI время завершить анимацию перехода (50 мс),
            // прежде чем нагружать процессор выборкой из базы данных.
            try? await Task.sleep(nanoseconds: 50_000_000)
            
            let localName = exerciseName
            let filter = #Predicate<Exercise> { ex in
                ex.name == localName && ex.preset == nil
            }
            let descriptor = FetchDescriptor<Exercise>(predicate: filter)
            
            // Выполняем запрос к БД вручную и безопасно
            guard let fetchedExercises = try? context.fetch(descriptor) else {
                self.isDataLoaded = true
                return
            }
            
            var foundType: ExerciseType = .strength
            var foundCategory: ExerciseCategory? = nil
            var foundMuscle: String? = nil
            
            var workoutMap: [UUID: (workout: Workout, exercises: [Exercise])] = [:]
            
            for ex in fetchedExercises {
                let targetWorkout = ex.workout ?? ex.parentExercise?.workout
                if let w = targetWorkout, w.endTime != nil {
                    if workoutMap[w.id] == nil {
                        workoutMap[w.id] = (w, [ex])
                    } else {
                        workoutMap[w.id]?.exercises.append(ex)
                    }
                }
                
                if foundCategory == nil {
                    foundType = ex.type
                    foundCategory = ex.category
                    foundMuscle = ex.muscleGroup
                }
            }
            
            var filtered: [(workout: Workout, exercise: Exercise)] = []
            
            // Выбираем лучший результат, если было несколько одинаковых упражнений в одной тренировке
            for (_, data) in workoutMap {
                let bestExercise = data.exercises.max { e1, e2 in
                    let max1 = e1.setsList.compactMap { $0.weight }.max() ?? 0
                    let max2 = e2.setsList.compactMap { $0.weight }.max() ?? 0
                    return max1 < max2
                } ?? data.exercises.first!
                
                filtered.append((data.workout, bestExercise))
            }
            
            // Сортируем по дате завершения
            filtered.sort { $0.workout.date > $1.workout.date }
            
            // Вычисляем базовые точки графика ОДИН РАЗ
            let dataPoints = filtered.reversed().compactMap { item -> DataPoint? in
                let exercise = item.exercise
                var value: Double = 0.0
                
                switch foundType {
                case .strength:
                    let maxSetWeight = exercise.setsList
                        .filter { $0.isCompleted && $0.type != .warmup }
                        .compactMap { $0.weight }
                        .max()
                    let kgValue = maxSetWeight ?? exercise.weight
                    value = unitsManager.convertFromKilograms(kgValue)
                    
                case .cardio:
                    let totalDist = exercise.setsList
                        .filter { $0.isCompleted }
                        .compactMap { $0.distance }
                        .reduce(0, +)
                    let finalDist = (totalDist > 0) ? totalDist : (exercise.distance ?? 0.0)
                    value = unitsManager.convertFromMeters(finalDist)
                    
                case .duration:
                    let totalSeconds = exercise.setsList
                        .filter { $0.isCompleted }
                        .compactMap { $0.time }
                        .reduce(0, +)
                    let finalSeconds = (totalSeconds > 0) ? totalSeconds : (exercise.timeSeconds ?? 0)
                    value = Double(finalSeconds) / 60.0
                }
                
                if value == 0 { return nil }
                return DataPoint(date: item.workout.date, value: value)
            }
            
            self.allDataPoints = dataPoints
            self.filteredWorkoutsData = filtered
            self.exerciseType = foundType
            self.exerciseCategory = foundCategory
            self.muscleGroup = foundMuscle
            
            self.exerciseForecast = calculateForecast()
            self.exerciseTrend = calculateTrend(for: selectedTrendPeriod)
            
            self.updateGraphData()
            
            withAnimation {
                self.isDataLoaded = true
            }
        }
    }
    
    /// Быстро обновляет отображаемые данные графика без глубокого пересчета истории
    private func updateGraphData() {
        let calendar = Calendar.current
        let filteredByDate: [DataPoint]
        
        if selectedTimeRange == .all {
            filteredByDate = allDataPoints
        } else {
            let days: Int
            switch selectedTimeRange {
            case .month: days = 30
            case .threeMonths: days = 90
            case .sixMonths: days = 180
            case .year: days = 365
            case .all: days = 0
            }
            if let cutoff = calendar.date(byAdding: .day, value: -days, to: Date()) {
                filteredByDate = allDataPoints.filter { $0.date >= cutoff }
            } else {
                filteredByDate = allDataPoints
            }
        }
        
        var newMetric: Double? = nil
        if selectedMetric != .none && !filteredByDate.isEmpty {
            let values = filteredByDate.map { $0.value }
            if selectedMetric == .max {
                newMetric = values.max()
            } else if selectedMetric == .average {
                newMetric = values.reduce(0, +) / Double(values.count)
            }
        }
        
        withAnimation(.easeInOut(duration: 0.2)) {
            self.displayedGraphData = filteredByDate
            self.currentMetricValue = newMetric
        }
    }
    
    private func calculateTrend(for period: TrendPeriod) -> WorkoutViewModel.ExerciseTrend? {
        if exerciseType != .strength { return nil }
        
        let months: Int
        switch period {
        case .month: months = 1
        case .threeMonths: months = 3
        case .year: months = 12
        }
        
        let calendar = Calendar.current
        let now = Date()
        
        let currentStart = calendar.date(byAdding: .month, value: -months, to: now)!
        let currentInterval = DateInterval(start: currentStart, end: now)
        
        let previousStart = calendar.date(byAdding: .month, value: -(months * 2), to: now)!
        let previousInterval = DateInterval(start: previousStart, end: currentStart)
        
        let currentWorkouts = filteredWorkoutsData.filter { currentInterval.contains($0.workout.date) }
        let previousWorkouts = filteredWorkoutsData.filter { previousInterval.contains($0.workout.date) }
        
        var currentMax: Double = 0
        var previousMax: Double = 0
        
        for item in currentWorkouts {
            let maxWeightKg = item.exercise.setsList
                .filter { $0.isCompleted && $0.type != .warmup }
                .compactMap { $0.weight }
                .max() ?? 0
            if maxWeightKg > currentMax { currentMax = maxWeightKg }
        }
        
        for item in previousWorkouts {
            let maxWeightKg = item.exercise.setsList
                .filter { $0.isCompleted && $0.type != .warmup }
                .compactMap { $0.weight }
                .max() ?? 0
            if maxWeightKg > previousMax { previousMax = maxWeightKg }
        }
        
        if currentMax == 0 && previousMax == 0 { return nil }
        
        let change: Double
        let direction: WorkoutViewModel.TrendDirection
        
        if previousMax == 0 {
            change = 100.0
            direction = .growing
        } else if currentMax == 0 {
            change = -100.0
            direction = .declining
        } else {
            change = ((currentMax - previousMax) / previousMax) * 100.0
            if abs(change) < 2.0 {
                direction = .stable
            } else {
                direction = change > 0 ? .growing : .declining
            }
        }
        
        return WorkoutViewModel.ExerciseTrend(
            exerciseName: exerciseName,
            trend: direction,
            changePercentage: change,
            currentValue: currentMax,
            previousValue: previousMax,
            period: period.displayName
        )
    }
    
    private func calculateForecast() -> WorkoutViewModel.ProgressForecast? {
        if exerciseType != .strength { return nil }
        
        let now = Date()
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -90, to: now)!
        let recentData = filteredWorkoutsData.filter { $0.workout.date >= cutoffDate }
        
        var history: [(date: Date, maxWeight: Double)] = []
        for item in recentData {
            let maxWeight = item.exercise.setsList
                .filter { $0.isCompleted && $0.type != .warmup }
                .compactMap { $0.weight }
                .max() ?? 0
            if maxWeight > 0 { history.append((date: item.workout.date, maxWeight: maxWeight)) }
        }
        
        guard history.count >= 3 else { return nil }
        let sorted = history.sorted { $0.date < $1.date }
        let currentMax = sorted.last!.maxWeight
        
        let daysFromStart = sorted.map { now.timeIntervalSince($0.date) / 86400 }
        let weights = sorted.map { $0.maxWeight }
        
        var totalInc = 0.0, totalDays = 0.0, posChanges = 0, negChanges = 0
        for i in 1..<sorted.count {
            let daysDiff = abs(daysFromStart[i] - daysFromStart[i-1])
            if daysDiff > 0 {
                let wDiff = weights[i] - weights[i-1]
                totalInc += wDiff; totalDays += daysDiff
                if wDiff > 0 { posChanges += 1 } else if wDiff < 0 { negChanges += 1 }
            }
        }
        
        let avgInc = totalDays > 0 ? totalInc / totalDays : 0
        let daysAhead = 30
        let predMax = max(currentMax, currentMax + (avgInc * Double(daysAhead)))
        
        let dataScore = min(70, max(30, sorted.count * 8))
        let trendBonus = avgInc > 0 ? 15 : 0
        let totalChanges = posChanges + negChanges
        let consistencyBonus = totalChanges > 0 ? (Double(posChanges)/Double(totalChanges) >= 0.7 ? 15 : (Double(posChanges)/Double(totalChanges) >= 0.5 ? 5 : -10)) : 0
        let timeSpanBonus = min(10, Int((daysFromStart.first! - daysFromStart.last!) / 30))
        
        let confidence = min(100, max(30, dataScore + trendBonus + consistencyBonus + timeSpanBonus))
        
        return WorkoutViewModel.ProgressForecast(
            exerciseName: exerciseName,
            currentMax: currentMax,
            predictedMax: predMax,
            confidence: confidence,
            timeframe: String(localized: "30 days")
        )
    }
    
    // MARK: - Tab Bar
    
    private var tabBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = tab
                        }
                    }) {
                        VStack(spacing: 8) {
                            Text(LocalizedStringKey(tab.localizedName))
                                .font(.subheadline)
                                .fontWeight(selectedTab == tab ? .semibold : .regular)
                                .foregroundColor(selectedTab == tab ? .blue : .secondary)
                            
                            // Подчеркивание активной вкладки
                            Rectangle()
                                .fill(selectedTab == tab ? Color.blue : Color.clear)
                                .frame(height: 2)
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 4)
            
            // Разделитель под вкладками
            Divider()
        }
        .background(Color(UIColor.systemBackground))
    }
    
    // MARK: - Tab Content
    
    /// Контент вкладки Summary (График и заметки)
    private var summaryContent: some View {
        VStack(spacing: 30) {
            // 1. Блок графика
            chartContainerView
            
            // 2. Тренды упражнения
            if let exerciseTrend = exerciseTrend {
                exerciseTrendSection(trend: exerciseTrend)
            }
            
            // 3. Прогноз прогресса
            if let exerciseForecast = exerciseForecast {
                exerciseForecastSection(forecast: exerciseForecast)
            }
            
            // 4. Блок заметок
            noteSection
        }
    }
    
    /// Контент вкладки Technique (Техника упражнения)
    private var techniqueContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(LocalizedStringKey("Exercise Technique"))
                .font(.title2)
                .bold()
                .padding(.bottom, 10)
            
            // Базовое описание упражнения
            VStack(alignment: .leading, spacing: 15) {
                Text(LocalizedStringKey("How to Perform"))
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Text(getTechniqueDescription())
                    .font(.body)
                    .lineSpacing(4)
                    .foregroundColor(.primary)
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            .shadow(radius: 5)
            
            // Основные советы
            VStack(alignment: .leading, spacing: 15) {
                Text(LocalizedStringKey("Key Tips"))
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                ForEach(getTechniqueTips(), id: \.self) { tip in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                            .font(.caption)
                            .padding(.top, 4)
                        
                        Text(tip)
                            .font(.body)
                            .lineSpacing(4)
                    }
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            .shadow(radius: 5)
            
            // Мышцы, которые работают
            let muscleGroupToUse = muscleGroup ?? NSLocalizedString("Unknown", comment: "")
            let targetMuscles = MuscleDisplayHelper.getTargetMuscleNames(for: exerciseName, muscleGroup: muscleGroupToUse)
            
            if !targetMuscles.isEmpty {
                VStack(alignment: .leading, spacing: 15) {
                    HStack {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(LocalizedStringKey("Target Muscles"))
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Отображаем мускулы как теги в LazyVGrid
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 100), spacing: 8)
                    ], spacing: 8) {
                        ForEach(targetMuscles, id: \.self) { muscle in
                            // Обернули каждый тег в NavigationLink для перехода в каталог упражнений
                            NavigationLink(destination: ExerciseView(preselectedCategory: muscleGroup)) {
                                HStack(spacing: 4) {
                                    Image(systemName: "figure.strengthtraining.traditional")
                                        .font(.caption2)
                                    Text(muscle)
                                        .font(.subheadline)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(8)
                            }
                        }
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
                .shadow(radius: 5)
            }
        }
    }
    
    /// Контент вкладки History (История тренировок)
    private var historyContent: some View {
        historyListSection
    }
    
    // MARK: - View Components
    
    /// Секция заметок
    private var noteSection: some View {
        ExerciseNoteEditor(exerciseName: exerciseName, isInputActive: $isInputActive)
            .id("notesSection")
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            .shadow(radius: 5)
    }
    
    /// Контейнер для графика (Заголовок, График, Фильтры)
    private var chartContainerView: some View {
        VStack(alignment: .leading, spacing: 15) {
            // Заголовок и выбор диапазона
            HStack {
                Text(chartTitle).font(.headline).foregroundColor(.secondary)
                Spacer()
                Picker(LocalizedStringKey("Range"), selection: $selectedTimeRange) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Text(LocalizedStringKey(range.rawValue)).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
            
            if displayedGraphData.isEmpty {
                Text(LocalizedStringKey("Not enough data"))
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            } else {
                // Сам график
                chartView
                
                Divider()
                
                // Выбор метрики (Среднее / Макс), если данных достаточно
                if displayedGraphData.count > 1 {
                    HStack {
                        Text(LocalizedStringKey("Show line:"))
                            .font(.caption).foregroundColor(.secondary)
                        Picker(LocalizedStringKey("Metric"), selection: $selectedMetric) {
                            ForEach(GraphMetric.allCases, id: \.self) { metric in
                                Text(LocalizedStringKey(metric.rawValue)).tag(metric)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(radius: 5)
    }
    
    /// Контент строки тренировки
    @ViewBuilder
    private func workoutRowContent(workout: Workout, exercise: Exercise) -> some View {
        NavigationLink(destination: WorkoutDetailView(workout: workout)) {
            HStack {
                VStack(alignment: .leading) {
                    Text(workout.title).font(.headline).foregroundColor(.primary)
                    Text(workout.date, style: .date).font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                // Отображение результата справа в зависимости от типа
                VStack(alignment: .trailing) {
                    switch exercise.type {
                    case .strength:
                        let convertedWeight = unitsManager.convertFromKilograms(exercise.weight)
                        Text("\(Int(convertedWeight)) \(unitsManager.weightUnitString())").bold().foregroundColor(.blue)
                        Text("\(exercise.sets) x \(exercise.reps)").font(.caption).foregroundColor(.secondary)
                    case .cardio:
                        let convertedDist = unitsManager.convertFromMeters(exercise.distance ?? 0)
                        Text("\(LocalizationHelper.shared.formatDecimal(convertedDist)) \(unitsManager.distanceUnitString())").bold().foregroundColor(.orange)
                        Text(formatTime(exercise.timeSeconds ?? 0)).font(.caption).foregroundColor(.secondary)
                    case .duration:
                        Text(formatTime(exercise.timeSeconds ?? 0)).bold().foregroundColor(.purple)
                        Text("\(exercise.sets) sets").font(.caption).foregroundColor(.secondary)
                    }
                }
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray.opacity(0.5))
                    .padding(.leading, 4)
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(10)
            .contentShape(Rectangle()) // Чтобы весь блок был кликабельным
        }
        .buttonStyle(.plain) // Убирает дефолтное "синее" наложение для всего содержимого
    }
    
    /// Список истории тренировок
    private var historyListSection: some View {
        VStack(alignment: .leading) {
            Text(LocalizedStringKey("History")).font(.title2).bold()
            
            if filteredWorkoutsData.isEmpty {
                EmptyStateView(
                    icon: "clock.fill",
                    title: LocalizedStringKey("No history yet"),
                    message: LocalizedStringKey("This exercise hasn't been performed in any workouts yet. Add it to a workout to start tracking your progress!")
                )
                .padding(.top, 20)
            } else {
                ForEach(filteredWorkoutsData, id: \.workout.id) { item in
                    workoutRowContent(workout: item.workout, exercise: item.exercise)
                }
            }
        }
    }
    
    // MARK: - Chart Logic (Builders & Data)
    
    /// Построитель самого графика (оси, масштаб)
    @ViewBuilder
    var chartView: some View {
        // 1. Создаем базовый график
        let baseChart = Chart {
            // Рисуем содержимое (линии и точки)
            chartContent
            
            // Рисуем линию метрики (среднее/макс), если выбрано
            if let val = currentMetricValue, displayedGraphData.count > 1 {
                RuleMark(y: .value("Metric", val))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                    .foregroundStyle(.secondary)
                    .annotation(position: .top, alignment: .leading) {
                        Text("\(selectedMetric.rawValue): \(val, format: .number.precision(.fractionLength(1))) \(unitLabel)")
                            .font(.caption).bold()
                            .foregroundColor(.secondary)
                    }
            }
        }
        .frame(height: 250)
        .chartXAxis {
            AxisMarks(values: .automatic) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 1))
                    .foregroundStyle(.secondary.opacity(0.3))
                AxisTick(stroke: StrokeStyle(lineWidth: 1))
                    .foregroundStyle(.secondary)
                AxisValueLabel(format: .dateTime.month(.abbreviated).day(), centered: true)
                    .foregroundStyle(.primary)
            }
        }
        .chartYAxis {
            AxisMarks { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 1))
                    .foregroundStyle(.secondary.opacity(0.3))
                AxisTick(stroke: StrokeStyle(lineWidth: 1))
                    .foregroundStyle(.secondary)
                AxisValueLabel()
                    .foregroundStyle(.primary)
            }
        }

        // 2. Применяем кастомные масштабы (Domains), если точек мало
        if let yDom = customYDomain, let xDom = customXDomain {
            baseChart.chartYScale(domain: yDom).chartXScale(domain: xDom)
        } else if let xDom = customXDomain {
            baseChart.chartYScale(domain: .automatic(includesZero: false)).chartXScale(domain: xDom)
        } else {
            baseChart.chartYScale(domain: .automatic(includesZero: false))
        }
    }
    
    /// Содержимое графика (Точки и Линии)
    @ChartContentBuilder
    var chartContent: some ChartContent {
        ForEach(displayedGraphData) { dataPoint in
            // ЛИНИЯ (если больше 1 точки)
            if displayedGraphData.count > 1 {
                LineMark(x: .value("Date", dataPoint.date), y: .value("Value", dataPoint.value))
                    .interpolationMethod(.linear)
                    .foregroundStyle(chartColor)
                    .lineStyle(StrokeStyle(lineWidth: 3))
            }
            
            // ТОЧКА
            PointMark(x: .value("Date", dataPoint.date), y: .value("Value", dataPoint.value))
                .foregroundStyle(chartColor)
                .symbolSize(displayedGraphData.count == 1 ? 50 : 30)
                .annotation(position: .top) {
                    if displayedGraphData.count < 10 {
                        Text(LocalizationHelper.shared.formatInteger(dataPoint.value))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
        }
    }
    
    // --- Chart Helpers (Scaling & Data) ---
    
    var chartTitle: String {
        switch exerciseType {
        case .strength: return NSLocalizedString("Progress (Weight)", comment: "")
        case .cardio: return NSLocalizedString("Progress (Distance)", comment: "")
        case .duration: return NSLocalizedString("Progress (Time)", comment: "")
        }
    }
    
    var chartColor: Color {
        switch exerciseType {
        case .strength: return .blue
        case .cardio: return .orange
        case .duration: return .purple
        }
    }
    
    // Масштаб по X (если одна точка - показываем день до и после)
    var customXDomain: ClosedRange<Date>? {
        guard displayedGraphData.count == 1, let point = displayedGraphData.first else { return nil }
        let start = Calendar.current.date(byAdding: .day, value: -1, to: point.date)!
        let end = Calendar.current.date(byAdding: .day, value: 1, to: point.date)!
        return start...end
    }
    
    // Масштаб по Y (добавляем отступы сверху и снизу)
    var customYDomain: ClosedRange<Double>? {
        guard !displayedGraphData.isEmpty else { return nil }
        let values = displayedGraphData.map { $0.value }
        let minVal = values.min() ?? 0
        let maxVal = values.max() ?? 0
        
        if values.count == 1 || minVal == maxVal {
            let buffer = (maxVal == 0 ? 10 : maxVal * 0.2)
            return (minVal - buffer)...(maxVal + buffer)
        }
        return nil
    }
    
    // MARK: - Helpers
    
    func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
    
    // MARK: - Technique Helpers
    
    /// Получить описание техники упражнения
    func getTechniqueDescription() -> String {
        switch safeCategory {
        case .squat:
            return NSLocalizedString("Stand with your feet shoulder-width apart. Lower your body by bending your knees and pushing your hips back, as if sitting into a chair. Keep your chest up and core engaged. Lower until your thighs are parallel to the ground, then push through your heels to return to the starting position.", comment: "")
        case .press:
            return NSLocalizedString("Lie on a flat bench with your feet flat on the floor. Grip the bar with hands slightly wider than shoulder-width. Lower the bar to your chest with control, then press it back up explosively. Keep your shoulders retracted and core tight throughout movement.", comment: "")
        case .deadlift:
            return NSLocalizedString("Stand with feet hip-width apart, bar over mid-foot. Hinge at the hips and bend your knees to grip the bar. Keep your back straight and chest up. Drive through your heels and extend your hips and knees simultaneously to lift the bar. Keep the bar close to your body throughout movement.", comment: "")
        case .pull:
            return NSLocalizedString("Grasp the bar or handles with an overhand or underhand grip. Pull the weight toward your torso, squeezing your shoulder blades together at the end of the movement. Keep your core engaged and avoid swinging. Lower the weight with control to complete the repetition.", comment: "")
        case .curl:
            return NSLocalizedString("Stand or sit with a dumbbell in each hand, arms fully extended. Keeping your elbows close to your body, curl the weights up by contracting your biceps. Squeeze at the top of the movement, then lower the weights slowly with control.", comment: "")
        default:
            return NSLocalizedString("Perform this exercise with proper form, focusing on controlled movements and full range of motion. Engage your core throughout the exercise and avoid using momentum. Consult with a fitness professional for specific technique guidance.", comment: "")
        }
    }
    
    /// Получить советы по технике
    func getTechniqueTips() -> [String] {
        switch safeCategory {
        case .squat:
            return [
                NSLocalizedString("Keep your knees in line with your toes, never let them cave inward", comment: ""),
                NSLocalizedString("Maintain a neutral spine throughout the entire movement", comment: ""),
                NSLocalizedString("Focus on pushing through your heels, not your toes", comment: ""),
                NSLocalizedString("Don't let your knees go past your toes when descending", comment: ""),
                NSLocalizedString("Keep your chest up and gaze forward to maintain proper posture", comment: "")
            ]
        case .press:
            return [
                NSLocalizedString("Keep your shoulder blades retracted and pressed into the bench", comment: ""),
                NSLocalizedString("Lower the bar with control - don't let it drop onto your chest", comment: ""),
                NSLocalizedString("Keep your feet firmly planted on the floor for stability", comment: ""),
                NSLocalizedString("Maintain a slight arch in your lower back (not excessive)", comment: ""),
                NSLocalizedString("Press the bar in a straight line up and slightly back", comment: "")
            ]
        case .deadlift:
            return [
                NSLocalizedString("Keep the bar close to your body - it should almost scrape your shins", comment: ""),
                NSLocalizedString("Start with your hips higher than your knees", comment: ""),
                NSLocalizedString("Drive through your heels and extend your hips forward at the top", comment: ""),
                NSLocalizedString("Never round your back - keep it neutral throughout", comment: ""),
                NSLocalizedString("Breathe out as you lift and breathe in as you lower", comment: "")
            ]
        default:
            return [
                NSLocalizedString("Focus on proper form over the amount of weight", comment: ""),
                NSLocalizedString("Control the negative (lowering) portion of the movement", comment: ""),
                NSLocalizedString("Keep your core engaged throughout the exercise", comment: ""),
                NSLocalizedString("Breathe properly - exhale on exertion, inhale on return", comment: ""),
                NSLocalizedString("If you feel sharp pain, stop immediately and consult a professional", comment: "")
            ]
        }
    }
    
    // MARK: - Exercise Trends & Forecast Views
    
    /// Секция тренда упражнения
    @ViewBuilder
    private func exerciseTrendSection(trend: WorkoutViewModel.ExerciseTrend) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(LocalizedStringKey("Exercise Trend"))
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Переключатель периода в правом верхнем углу
                Picker(LocalizedStringKey("Period"), selection: $selectedTrendPeriod) {
                    ForEach(TrendPeriod.allCases) { period in
                        Text(period.displayName).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 120)
            }
            
            HStack {
                Image(systemName: trend.trend.icon)
                    .foregroundColor(trend.trend.color)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                        let prevConverted = unitsManager.convertFromKilograms(trend.previousValue)
                        let currConverted = unitsManager.convertFromKilograms(trend.currentValue)
                        Text("\(Int(prevConverted)) \(unitsManager.weightUnitString())")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text("\(Int(currConverted)) \(unitsManager.weightUnitString())")
                            .font(.caption)
                            .bold()
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(trend.changePercentage, specifier: "%.0f")%")
                        .font(.headline)
                        .foregroundColor(trend.trend.color)
                    
                    Text(trend.trend == .growing ? LocalizedStringKey("↑ Growing") : trend.trend == .declining ? LocalizedStringKey("↓ Declining") : LocalizedStringKey("→ Stable"))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 8)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(radius: 5)
    }
    
    /// Секция прогноза упражнения
    @ViewBuilder
    private func exerciseForecastSection(forecast: WorkoutViewModel.ProgressForecast) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(LocalizedStringKey("Progress Forecast"))
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Индикатор уверенности с цветовой кодировкой
                HStack(spacing: 4) {
                    Circle()
                        .fill(forecast.confidence >= 70 ? Color.green :
                              forecast.confidence >= 50 ? Color.orange : Color.red)
                        .frame(width: 8, height: 8)
                    Text("\(forecast.confidence)%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedStringKey("Current"))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    let currentConverted = unitsManager.convertFromKilograms(forecast.currentMax)
                    Text("\(Int(currentConverted)) \(unitsManager.weightUnitString())")
                        .font(.subheadline)
                        .bold()
                }
                
                Image(systemName: "arrow.right")
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedStringKey("Predicted"))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    let predictedConverted = unitsManager.convertFromKilograms(forecast.predictedMax)
                    Text("\(Int(predictedConverted)) \(unitsManager.weightUnitString())")
                        .font(.subheadline)
                        .bold()
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    let diffConverted = unitsManager.convertFromKilograms(forecast.predictedMax - forecast.currentMax)
                    Text("+\(Int(diffConverted)) \(unitsManager.weightUnitString())")
                        .font(.caption)
                        .bold()
                        .foregroundColor(.green)
                    Text(LocalizedStringKey("in \(forecast.timeframe)"))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            // Прогресс бар для визуализации
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)
                        .cornerRadius(3)
                    
                    Rectangle()
                        .fill(Color.blue.gradient)
                        .frame(
                            width: geometry.size.width * min(1.0, forecast.predictedMax / max(forecast.currentMax, 1)),
                            height: 6
                        )
                        .cornerRadius(3)
                }
            }
            .frame(height: 6)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(radius: 5)
    }
}

// MARK: - Isolated Note Editor View (SWIFT DATA)

/// Вынесенное представление для редактирования заметки.
/// Интегрировано с SwiftData с помощью @Query
struct ExerciseNoteEditor: View {
    let exerciseName: String
    var isInputActive: FocusState<Bool>.Binding
    
    @Environment(\.modelContext) private var context
    @Query private var notes: [ExerciseNote]
    
    @State private var exerciseNote: String = ""
    @State private var saveTask: Task<Void, Never>?
    
    init(exerciseName: String, isInputActive: FocusState<Bool>.Binding) {
        self.exerciseName = exerciseName
        self.isInputActive = isInputActive
        
        // Фильтруем данные прямо из базы SwiftData
        let filter = #Predicate<ExerciseNote> { $0.exerciseName == exerciseName }
        _notes = Query(filter: filter)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(LocalizedStringKey("My Notes")).font(.headline).foregroundColor(.secondary)
            
            TextEditor(text: $exerciseNote)
                .frame(minHeight: 100, maxHeight: 200)
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .focused(isInputActive)
                .overlay(
                    Text(exerciseNote.isEmpty ? LocalizedStringKey("Write notes...") : "")
                        .foregroundColor(.gray.opacity(0.6))
                        .padding(12)
                        .allowsHitTesting(false),
                    alignment: .topLeading
                )
                .onChange(of: exerciseNote) { oldValue, newValue in
                    // Отменяем предыдущую задачу сохранения
                    saveTask?.cancel()
                    
                    // Сохраняем с debounce (300ms)
                    saveTask = Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 300_000_000)
                        if !Task.isCancelled {
                            saveNote(newValue)
                        }
                    }
                }
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button(LocalizedStringKey("Done")) {
                            saveTask?.cancel()
                            saveNote(exerciseNote)
                            isInputActive.wrappedValue = false
                        }.bold()
                    }
                }
                .onDisappear {
                    saveTask?.cancel()
                    saveNote(exerciseNote)
                }
        }
        .onAppear {
            exerciseNote = notes.first?.text ?? ""
        }
    }
    
    // Прямое сохранение в SwiftData ModelContext
    private func saveNote(_ text: String) {
        if let existingNote = notes.first {
            existingNote.text = text
        } else if !text.isEmpty {
            let newNote = ExerciseNote(exerciseName: exerciseName, text: text)
            context.insert(newNote)
        }
    }
}

