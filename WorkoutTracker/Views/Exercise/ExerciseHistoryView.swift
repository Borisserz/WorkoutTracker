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
    let allWorkouts: [Workout]
    
    @EnvironmentObject var notesManager: ExerciseNotesManager
    @EnvironmentObject var viewModel: WorkoutViewModel
    @StateObject private var unitsManager = UnitsManager.shared
    @FocusState private var isInputActive: Bool
    
    // MARK: - State
    
    @State private var selectedTab: Tab = .summary
    @State private var selectedTimeRange: TimeRange = .all
    @State private var exerciseNote: String = ""
    @State private var selectedMetric: GraphMetric = .none
    @State private var selectedTrendPeriod: TrendPeriod = .month
    @State private var saveTask: Task<Void, Never>?
    
    // MARK: - Computed Properties (General)
    
    /// Определяет тип упражнения, просматривая историю тренировок
    var exerciseType: ExerciseType {
        for workout in allWorkouts {
            if let ex = findExerciseInWorkout(workout) { return ex.type }
        }
        return .strength
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
        .navigationTitle(exerciseName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Загружаем заметку при открытии
            exerciseNote = notesManager.getNote(for: exerciseName)
        }
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
            let muscleGroup = getMuscleGroup() ?? NSLocalizedString("Unknown", comment: "")
            let targetMuscles = MuscleDisplayHelper.getTargetMuscleNames(for: exerciseName, muscleGroup: muscleGroup)
            
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
        VStack(alignment: .leading, spacing: 10) {
            Text(LocalizedStringKey("My Notes")).font(.headline).foregroundColor(.secondary)
            
            TextEditor(text: $exerciseNote)
                .frame(minHeight: 100, maxHeight: 200)
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .focused($isInputActive)
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
                    
                    // Сохраняем с debounce (300ms) для плавности
                    saveTask = Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 300_000_000) // 300ms
                        if !Task.isCancelled {
                            notesManager.setNote(newValue, for: exerciseName)
                        }
                    }
                }
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button(LocalizedStringKey("Done")) {
                            // При закрытии клавиатуры сохраняем сразу
                            saveTask?.cancel()
                            notesManager.setNote(exerciseNote, for: exerciseName)
                            notesManager.saveImmediately()
                            isInputActive = false
                        }.bold()
                    }
                }
                .onDisappear {
                    // При закрытии view сохраняем финальное значение
                    saveTask?.cancel()
                    notesManager.setNote(exerciseNote, for: exerciseName)
                    notesManager.saveImmediately()
                }
        }
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
            
            if graphData.isEmpty {
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
                if graphData.count > 1 {
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
        NavigationLink(destination: WorkoutDetailView(workout: .constant(workout))) {
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
                        let convertedDist = unitsManager.convertFromKilometers(exercise.distance ?? 0)
                        Text("\(LocalizationHelper.shared.formatDecimal(convertedDist)) \(unitsManager.distanceUnitString())").bold().foregroundColor(.orange)
                        Text(formatTime(exercise.timeSeconds ?? 0)).font(.caption).foregroundColor(.secondary)
                    case .duration:
                        Text(formatTime(exercise.timeSeconds ?? 0)).bold().foregroundColor(.purple)
                        Text("\(exercise.sets) sets").font(.caption).foregroundColor(.secondary)
                    }
                }
            }
            .padding().background(Color.gray.opacity(0.05)).cornerRadius(10)
        }
    }
    
    /// Список истории тренировок
    private var historyListSection: some View {
        VStack(alignment: .leading) {
            Text(LocalizedStringKey("History")).font(.title2).bold()
            
            if filteredWorkouts.isEmpty {
                EmptyStateView(
                    icon: "clock.fill",
                    title: LocalizedStringKey("No history yet"),
                    message: LocalizedStringKey("This exercise hasn't been performed in any workouts yet. Add it to a workout to start tracking your progress!")
                )
                .padding(.top, 20)
            } else {
                ForEach(filteredWorkouts) { workout in
                    // filteredWorkouts гарантирует, что упражнение существует
                    workoutRowContent(workout: workout, exercise: findExerciseInWorkout(workout)!)
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
            if let val = metricValue, graphData.count > 1 {
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
        ForEach(graphData) { dataPoint in
            // ЛИНИЯ (если больше 1 точки)
            if graphData.count > 1 {
                LineMark(x: .value("Date", dataPoint.date), y: .value("Value", dataPoint.value))
                    .interpolationMethod(.linear)
                    .foregroundStyle(chartColor)
                    .lineStyle(StrokeStyle(lineWidth: 3))
            }
            
            // ТОЧКА
            PointMark(x: .value("Date", dataPoint.date), y: .value("Value", dataPoint.value))
                .foregroundStyle(chartColor)
                .symbolSize(graphData.count == 1 ? 50 : 30)
                .annotation(position: .top) {
                    if graphData.count < 10 {
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
        guard graphData.count == 1, let point = graphData.first else { return nil }
        let start = Calendar.current.date(byAdding: .day, value: -1, to: point.date)!
        let end = Calendar.current.date(byAdding: .day, value: 1, to: point.date)!
        return start...end
    }
    
    // Масштаб по Y (добавляем отступы сверху и снизу)
    var customYDomain: ClosedRange<Double>? {
        guard !graphData.isEmpty else { return nil }
        let values = graphData.map { $0.value }
        let minVal = values.min() ?? 0
        let maxVal = values.max() ?? 0
        
        if values.count == 1 || minVal == maxVal {
            let buffer = (maxVal == 0 ? 10 : maxVal * 0.2)
            return (minVal - buffer)...(maxVal + buffer)
        }
        return nil
    }
    
    // MARK: - Data Processing
    
    /// Подготовка данных для графика
    var graphData: [DataPoint] {
        let allData = filteredWorkouts.reversed().compactMap { workout -> DataPoint? in
            guard let exercise = findExerciseInWorkout(workout) else { return nil }
            
            var value: Double = 0.0
            
            switch exercise.type {
            case .strength:
                // 1. СИЛОВЫЕ: Максимальный вес в сетах (исключая разминку)
                let maxSetWeight = exercise.setsList
                    .filter { $0.isCompleted && $0.type != .warmup }
                    .compactMap { $0.weight }
                    .max()
                let kgValue = maxSetWeight ?? exercise.weight
                // Конвертируем в выбранные единицы для графика
                value = unitsManager.convertFromKilograms(kgValue)
                
            case .cardio:
                // 2. КАРДИО: Сумма дистанции
                let totalDist = exercise.setsList
                    .filter { $0.isCompleted }
                    .compactMap { $0.distance }
                    .reduce(0, +)
                let finalDist = (totalDist > 0) ? totalDist : (exercise.distance ?? 0.0)
                value = unitsManager.convertFromKilometers(finalDist)
                
            case .duration:
                // 3. ВРЕМЯ: Сумма времени (в минутах)
                let totalSeconds = exercise.setsList
                    .filter { $0.isCompleted }
                    .compactMap { $0.time }
                    .reduce(0, +)
                let finalSeconds = (totalSeconds > 0) ? totalSeconds : (exercise.timeSeconds ?? 0)
                value = Double(finalSeconds) / 60.0
            }
            
            if value == 0 { return nil }
            return DataPoint(date: workout.date, value: value)
        }
        
        // Фильтрация по времени
        if selectedTimeRange == .all { return allData }
        
        let calendar = Calendar.current
        let days: Int
        switch selectedTimeRange {
        case .month: days = 30
        case .threeMonths: days = 90
        case .sixMonths: days = 180
        case .year: days = 365
        case .all: days = 0
        }
        
        guard let cutoff = calendar.date(byAdding: .day, value: -days, to: Date()) else { return allData }
        return allData.filter { $0.date >= cutoff }
    }
    
    /// Значение для линии метрики (Average / Max)
    var metricValue: Double? {
        let values = graphData.map { $0.value }
        guard !values.isEmpty else { return nil }
        switch selectedMetric {
        case .none: return nil
        case .max: return values.max()
        case .average: return values.reduce(0, +) / Double(values.count)
        }
    }
    
    /// Все тренировки, где встречалось это упражнение
    var filteredWorkouts: [Workout] {
        return allWorkouts.filter { workout in
            findExerciseInWorkout(workout) != nil
        }.sorted(by: { $0.date > $1.date })
    }
    
    /// Тренд для текущего упражнения
    var exerciseTrend: WorkoutViewModel.ExerciseTrend? {
        let period: StatsView.Period
        switch selectedTrendPeriod {
        case .month:
            period = .month
        case .threeMonths:
            // Для 3 месяцев используем кастомную логику
            return getCustomTrendPeriod(months: 3)
        case .year:
            period = .year
        }
        let trends = viewModel.getExerciseTrends(period: period)
        return trends.first { $0.exerciseName == exerciseName }
    }
    
    /// Кастомный расчет тренда для периода в месяцах
    private func getCustomTrendPeriod(months: Int) -> WorkoutViewModel.ExerciseTrend? {
        let calendar = Calendar.current
        let now = Date()
        
        // Текущий период
        let currentStart = calendar.date(byAdding: .month, value: -months, to: now)!
        let currentInterval = DateInterval(start: currentStart, end: now)
        
        // Предыдущий период
        let previousEnd = currentStart
        let previousStart = calendar.date(byAdding: .month, value: -months, to: previousEnd)!
        let previousInterval = DateInterval(start: previousStart, end: previousEnd)
        
        let currentWorkouts = allWorkouts.filter { currentInterval.contains($0.date) }
        let previousWorkouts = allWorkouts.filter { previousInterval.contains($0.date) }
        
        // Находим максимальный вес в каждом периоде для этого упражнения
        var currentMax: Double = 0
        var previousMax: Double = 0
        
        for workout in currentWorkouts {
            if let exercise = findExerciseInWorkout(workout), exercise.type == .strength {
                let maxWeightKg = exercise.setsList
                    .filter { $0.isCompleted && $0.type != .warmup }
                    .compactMap { $0.weight }
                    .max() ?? 0
                let maxWeight = unitsManager.convertFromKilograms(maxWeightKg)
                if maxWeight > currentMax {
                    currentMax = maxWeight
                }
            }
        }
        
        for workout in previousWorkouts {
            if let exercise = findExerciseInWorkout(workout), exercise.type == .strength {
                let maxWeightKg = exercise.setsList
                    .filter { $0.isCompleted && $0.type != .warmup }
                    .compactMap { $0.weight }
                    .max() ?? 0
                let maxWeight = unitsManager.convertFromKilograms(maxWeightKg)
                if maxWeight > previousMax {
                    previousMax = maxWeight
                }
            }
        }
        
        guard currentMax > 0 || previousMax > 0 else { return nil }
        
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
        
        // Возвращаем значения в кг для внутреннего использования
        return WorkoutViewModel.ExerciseTrend(
            exerciseName: exerciseName,
            trend: direction,
            changePercentage: change,
            currentValue: unitsManager.convertToKilograms(currentMax),
            previousValue: unitsManager.convertToKilograms(previousMax),
            period: "\(months)M"
        )
    }
    
    /// Прогноз для текущего упражнения
    var exerciseForecast: WorkoutViewModel.ProgressForecast? {
        let forecasts = viewModel.getProgressForecast(daysAhead: 30)
        return forecasts.first { $0.exerciseName == exerciseName }
    }
    
    // MARK: - Helpers
    
    func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
    
    /// Ищет упражнение внутри тренировки (включая вложенные в супер-сеты)
    func findExerciseInWorkout(_ workout: Workout) -> Exercise? {
        // Прямой поиск
        if let direct = workout.exercises.first(where: { $0.name == exerciseName && !$0.isSuperset }) {
            return direct
        }
        // Поиск внутри супер-сетов
        for ex in workout.exercises where ex.isSuperset {
            if let sub = ex.subExercises.first(where: { $0.name == exerciseName }) {
                return sub
            }
        }
        return nil
    }
    
    // MARK: - Technique Helpers
    
    /// Получить описание техники упражнения
    func getTechniqueDescription() -> String {
        // Базовая информация о технике в зависимости от названия упражнения
        let lowercased = exerciseName.lowercased()
        
        if lowercased.contains("squat") {
            return NSLocalizedString("Stand with your feet shoulder-width apart. Lower your body by bending your knees and pushing your hips back, as if sitting into a chair. Keep your chest up and core engaged. Lower until your thighs are parallel to the ground, then push through your heels to return to the starting position.", comment: "")
        } else if lowercased.contains("bench") || lowercased.contains("press") {
            return NSLocalizedString("Lie on a flat bench with your feet flat on the floor. Grip the bar with hands slightly wider than shoulder-width. Lower the bar to your chest with control, then press it back up explosively. Keep your shoulders retracted and core tight throughout the movement.", comment: "")
        } else if lowercased.contains("deadlift") {
            return NSLocalizedString("Stand with feet hip-width apart, bar over mid-foot. Hinge at the hips and bend your knees to grip the bar. Keep your back straight and chest up. Drive through your heels and extend your hips and knees simultaneously to lift the bar. Keep the bar close to your body throughout the movement.", comment: "")
        } else if lowercased.contains("pull") || lowercased.contains("row") {
            return NSLocalizedString("Grasp the bar or handles with an overhand or underhand grip. Pull the weight toward your torso, squeezing your shoulder blades together at the end of the movement. Keep your core engaged and avoid swinging. Lower the weight with control to complete the repetition.", comment: "")
        } else if lowercased.contains("curl") {
            return NSLocalizedString("Stand or sit with a dumbbell in each hand, arms fully extended. Keeping your elbows close to your body, curl the weights up by contracting your biceps. Squeeze at the top of the movement, then lower the weights slowly with control.", comment: "")
        } else {
            return NSLocalizedString("Perform this exercise with proper form, focusing on controlled movements and full range of motion. Engage your core throughout the exercise and avoid using momentum. Consult with a fitness professional for specific technique guidance.", comment: "")
        }
    }
    
    /// Получить советы по технике
    func getTechniqueTips() -> [String] {
        let lowercased = exerciseName.lowercased()
        
        if lowercased.contains("squat") {
            return [
                NSLocalizedString("Keep your knees in line with your toes, never let them cave inward", comment: ""),
                NSLocalizedString("Maintain a neutral spine throughout the entire movement", comment: ""),
                NSLocalizedString("Focus on pushing through your heels, not your toes", comment: ""),
                NSLocalizedString("Don't let your knees go past your toes when descending", comment: ""),
                NSLocalizedString("Keep your chest up and gaze forward to maintain proper posture", comment: "")
            ]
        } else if lowercased.contains("bench") || lowercased.contains("press") {
            return [
                NSLocalizedString("Keep your shoulder blades retracted and pressed into the bench", comment: ""),
                NSLocalizedString("Lower the bar with control - don't let it drop onto your chest", comment: ""),
                NSLocalizedString("Keep your feet firmly planted on the floor for stability", comment: ""),
                NSLocalizedString("Maintain a slight arch in your lower back (not excessive)", comment: ""),
                NSLocalizedString("Press the bar in a straight line up and slightly back", comment: "")
            ]
        } else if lowercased.contains("deadlift") {
            return [
                NSLocalizedString("Keep the bar close to your body - it should almost scrape your shins", comment: ""),
                NSLocalizedString("Start with your hips higher than your knees", comment: ""),
                NSLocalizedString("Drive through your heels and extend your hips forward at the top", comment: ""),
                NSLocalizedString("Never round your back - keep it neutral throughout", comment: ""),
                NSLocalizedString("Breathe out as you lift and breathe in as you lower", comment: "")
            ]
        } else {
            return [
                NSLocalizedString("Focus on proper form over the amount of weight", comment: ""),
                NSLocalizedString("Control the negative (lowering) portion of the movement", comment: ""),
                NSLocalizedString("Keep your core engaged throughout the exercise", comment: ""),
                NSLocalizedString("Breathe properly - exhale on exertion, inhale on return", comment: ""),
                NSLocalizedString("If you feel sharp pain, stop immediately and consult a professional", comment: "")
            ]
        }
    }
    
    /// Получить группу мышц
    func getMuscleGroup() -> String? {
        // Попытка найти группу мышц из истории тренировок
        for workout in allWorkouts {
            if let ex = findExerciseInWorkout(workout) {
                return ex.muscleGroup
            }
        }
        return nil
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
