//
//  WorkoutViewModel.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 24.12.25.
//
//  Главная ViewModel приложения.
//  Является "мозгом", связывающим данные (Workouts, Exercises) с UI.
//  Отвечает за:
//  1. Хранение и сохранение тренировок, пресетов и пользовательских упражнений.
//  2. Расчет статистики, рекордов (PR), стриков и уровней (через ProgressManager).
//  3. Логику таймера отдыха (Rest Timer).
//  4. Расчет восстановления мышц (Recovery).
//  5. Импорт/Экспорт шаблонов.
//

internal import SwiftUI
import Combine
import AudioToolbox
import WidgetKit
internal import UniformTypeIdentifiers

class WorkoutViewModel: ObservableObject {
    
    // MARK: - Nested Models
    
    struct BestResult: Identifiable {
        let id = UUID()
        let exerciseName: String
        let value: String
        let date: Date
        let type: ExerciseType
    }
    
    struct PeriodStats {
        var workoutCount: Int = 0
        var totalReps: Int = 0
        var totalDuration: Int = 0
        var totalVolume: Double = 0.0
        var totalDistance: Double = 0.0
    }
    
    struct ChartDataPoint: Identifiable {
        let id = UUID()
        let label: String
        let value: Double
    }
    
    struct PersonalRecord: Identifiable, Hashable {
        let id = UUID()
        let exerciseName: String
        let weight: Double
        let date: Date
    }
    
    struct MuscleRecoveryStatus {
        var muscleGroup: String
        var recoveryPercentage: Int
    }
    
    // MARK: - Published Properties
    
    /// Список всех выполненных тренировок
    @Published var workouts: [Workout] = [] {
        didSet {
            saveWorkouts()
            calculateRecovery()
            updateWidgetData()
        }
    }
    
    /// Список шаблонов тренировок
    @Published var presets: [WorkoutPreset] = []
    
    /// Список созданных пользователем упражнений
    @Published var customExercises: [CustomExerciseDefinition] = [] {
        didSet {
            saveCustomExercises()
        }
    }
    
    /// Статус восстановления мышц (для UI)
    @Published var recoveryStatus: [MuscleRecoveryStatus] = []
    
    /// Менеджер игрового прогресса (XP, Уровни)
    @Published var progressManager = ProgressManager()
    
    /// Множество удаленных стандартных упражнений
    @Published var deletedDefaultExercises: Set<String> = [] {
        didSet {
            if let encoded = try? JSONEncoder().encode(deletedDefaultExercises) {
                UserDefaults.standard.set(encoded, forKey: "DeletedDefaultExercises")
            }
        }
    }
    
    // --- Timer State ---
    @Published var restTimeRemaining: Int = 0
    @Published var isRestTimerActive: Bool = false
    @Published var restTimerFinished: Bool = false
    
    // MARK: - Error Handling
    
    /// Модель ошибки для отображения пользователю
    struct AppError: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }
    
    /// Ошибка для отображения пользователю
    @Published var currentError: AppError?
    
    /// Показывает ошибку пользователю
    func showError(title: String, message: String) {
        DispatchQueue.main.async {
            self.currentError = AppError(title: title, message: message)
        }
    }
    
    // MARK: - Private Properties
    
    private var restEndTime: Date?
    private var restTimer: Timer?
    
    // Для оптимизации расчета восстановления
    private var recoveryCalculationTask: Task<Void, Never>?
    private var recoveryCalculationCancellable: AnyCancellable?
    
    // MARK: - Init
    
    init() {
        loadWorkouts()
        loadPresets()
        loadCustomExercises()
        loadDeletedDefaultExercises()
        calculateRecovery()
    }
    
    deinit {
        // Критично: инвалидируем таймер при деинициализации, чтобы избежать утечки памяти
        restTimer?.invalidate()
        restTimer = nil
        
        // Отменяем фоновые задачи расчета восстановления
        recoveryCalculationTask?.cancel()
        recoveryCalculationCancellable?.cancel()
    }
    
    // MARK: - 1. Statistics & Records Logic
    
    /// Возвращает список лучших результатов по всем упражнениям
    func getAllPersonalRecords() -> [BestResult] {
        var bests: [String: (result: Double, date: Date, type: ExerciseType)] = [:]
        
        for workout in workouts {
            for exercise in workout.exercises {
                let targetExercises = exercise.isSuperset ? exercise.subExercises : [exercise]
                
                for ex in targetExercises {
                    // Ищем лучший результат среди выполненных сетов
                    for set in ex.setsList where set.isCompleted {
                        var currentValue: Double = 0
                        
                        switch ex.type {
                        case .strength: currentValue = set.weight ?? 0
                        case .cardio:   currentValue = set.distance ?? 0
                        case .duration: currentValue = Double(set.time ?? 0)
                        }
                        
                        if currentValue > (bests[ex.name]?.result ?? 0) {
                            bests[ex.name] = (result: currentValue, date: workout.date, type: ex.type)
                        }
                    }
                }
            }
        }
        
        let results = bests.map { name, data -> BestResult in
            var valString = ""
            switch data.type {
            case .strength: valString = "\(Int(data.result)) kg"
            case .cardio:   valString = "\(LocalizationHelper.shared.formatTwoDecimals(data.result)) km"
            case .duration:
                let m = Int(data.result) / 60
                let s = Int(data.result) % 60
                valString = String(format: "%d:%02d min", m, s)
            }
            return BestResult(exerciseName: name, value: valString, date: data.date, type: data.type)
        }
        
        return results.sorted { $0.exerciseName < $1.exerciseName }
    }
    
    /// Вычисляет текущий стрик (серию дней тренировок)
    func calculateWorkoutStreak() -> Int {
        guard !workouts.isEmpty else { return 0 }
        
        // Настройка дней отдыха из Settings
        let maxRestDaysAllowed = UserDefaults.standard.integer(forKey: "streakRestDays")
        let maxRestDays = maxRestDaysAllowed > 0 ? maxRestDaysAllowed : 2
        
        let sortedWorkouts = workouts.sorted(by: { $0.date > $1.date })
        let calendar = Calendar.current
        
        // Оставляем только уникальные дни
        var uniqueWorkoutDays: [Date] = []
        for workout in sortedWorkouts {
            if !uniqueWorkoutDays.contains(where: { calendar.isDate($0, inSameDayAs: workout.date) }) {
                uniqueWorkoutDays.append(workout.date)
            }
        }
        
        if uniqueWorkoutDays.isEmpty { return 0 }
        
        let mostRecentWorkoutDate = uniqueWorkoutDays[0]
        
        // Проверяем, не прерван ли стрик уже сегодня
        if calendar.dateComponents([.day], from: mostRecentWorkoutDate, to: Date()).day ?? 0 > maxRestDays {
            return 0
        }
        
        var currentStreak = 1
        var lastDate = mostRecentWorkoutDate
        
        guard uniqueWorkoutDays.count > 1 else { return 1 }
        
        for i in 1..<uniqueWorkoutDays.count {
            let currentDate = uniqueWorkoutDays[i]
            let daysBetween = calendar.dateComponents([.day], from: currentDate, to: lastDate).day ?? 0
            
            if daysBetween <= maxRestDays + 1 {
                currentStreak += 1
                lastDate = currentDate
            } else {
                break
            }
        }
        return currentStreak
    }
    
    /// Получить статистику за указанный период (количество, объем, время)
    func getStats(for dateInterval: DateInterval) -> PeriodStats {
        var stats = PeriodStats()
        let relevantWorkouts = workouts.filter { dateInterval.contains($0.date) }
        
        stats.workoutCount = relevantWorkouts.count
        
        for workout in relevantWorkouts {
            stats.totalDuration += workout.duration
            
            for exercise in workout.exercises {
                stats.totalVolume += exercise.computedVolume
                
                let targetExercises = exercise.isSuperset ? exercise.subExercises : [exercise]
                
                for ex in targetExercises {
                    // Считаем повторы (только рабочие сеты)
                    let reps = ex.setsList
                        .filter { $0.isCompleted && $0.type != .warmup }
                        .compactMap { $0.reps }
                        .reduce(0, +)
                    stats.totalReps += reps
                    
                    // Считаем дистанцию
                    let dist = ex.setsList
                        .filter { $0.isCompleted }
                        .compactMap { $0.distance }
                        .reduce(0, +)
                    stats.totalDistance += dist
                }
            }
        }
        return stats
    }
    
    /// Находит лучший период (неделю/месяц/год) по количеству тренировок
    func getBestStats(for periodType: StatsView.Period) -> PeriodStats {
        guard !workouts.isEmpty else { return PeriodStats() }
        
        var bestStats = PeriodStats()
        let calendar = Calendar.current
        let groupedWorkouts: [DateInterval: [Workout]]
        
        switch periodType {
        case .week:
            groupedWorkouts = Dictionary(grouping: workouts, by: { calendar.dateInterval(of: .weekOfYear, for: $0.date)! })
        case .month:
            groupedWorkouts = Dictionary(grouping: workouts, by: { calendar.dateInterval(of: .month, for: $0.date)! })
        case .year:
            groupedWorkouts = Dictionary(grouping: workouts, by: { calendar.dateInterval(of: .year, for: $0.date)! })
        }
        
        for (interval, _) in groupedWorkouts {
            let statsForThisPeriod = getStats(for: interval)
            if statsForThisPeriod.workoutCount > bestStats.workoutCount {
                bestStats = statsForThisPeriod
            }
        }
        return bestStats
    }
    
    /// Получить персональный рекорд для конкретного упражнения
    func getPersonalRecord(for exerciseName: String, onlyCompleted: Bool = false) -> Double {
        var maxWeight = 0.0
        for workout in workouts {
            if onlyCompleted && workout.isActive { continue }
            for exercise in workout.exercises {
                let targetExercises = exercise.isSuperset ? exercise.subExercises : [exercise]
                for ex in targetExercises where ex.name == exerciseName {
                    guard ex.type == .strength else { continue }
                    if let maxSetWeight = ex.setsList.compactMap({ $0.weight }).max() {
                        if maxSetWeight > maxWeight { maxWeight = maxSetWeight }
                    }
                }
            }
        }
        return maxWeight
    }
    
    /// Находит новые рекорды, установленные в заданном интервале времени
    func getRecentPRs(in interval: DateInterval) -> [PersonalRecord] {
        var records: [PersonalRecord] = []
        var bestWeights: [String: Double] = [:]
        
        // 1. Ищем рекорды ДО начала периода
        let workoutsBefore = workouts.filter { $0.date < interval.start }
        for workout in workoutsBefore {
            for exercise in workout.exercises.flatMap({ $0.isSuperset ? $0.subExercises : [$0] }) {
                let maxWeightInSets = exercise.setsList.filter { $0.type != .warmup }.compactMap { $0.weight }.max() ?? 0
                if maxWeightInSets > (bestWeights[exercise.name] ?? 0) {
                    bestWeights[exercise.name] = maxWeightInSets
                }
            }
        }
        
        // 2. Ищем новые рекорды ВНУТРИ периода
        let workoutsInPeriod = workouts.filter { interval.contains($0.date) }.sorted(by: { $0.date < $1.date })
        
        for workout in workoutsInPeriod {
            for exercise in workout.exercises.flatMap({ $0.isSuperset ? $0.subExercises : [$0] }) {
                guard exercise.type == .strength else { continue }
                let maxWeight = exercise.setsList.filter { $0.type != .warmup && $0.isCompleted }.compactMap { $0.weight }.max() ?? 0
                
                if maxWeight > (bestWeights[exercise.name] ?? 0) {
                    let newPR = PersonalRecord(exerciseName: exercise.name, weight: maxWeight, date: workout.date)
                    records.removeAll { $0.exerciseName == newPR.exerciseName } // Оставляем только самый свежий
                    records.append(newPR)
                    bestWeights[exercise.name] = maxWeight
                }
            }
        }
        return records.sorted(by: { $0.date > $1.date })
    }
    
    // MARK: - 2. Charts Data Logic
    
    /// Подготовка данных для графиков
    func getChartData(for period: StatsView.Period, metric: StatsView.GraphMetric) -> [ChartDataPoint] {
        let calendar = Calendar.current
        let now = Date()
        
        switch period {
        case .week:
            var dailyData: [ChartDataPoint] = []
            let weekdays = ["Вс", "Пн", "Вт", "Ср", "Чт", "Пт", "Сб"]
            for i in (0...6).reversed() {
                let date = calendar.date(byAdding: .day, value: -i, to: now)!
                let dayWorkouts = workouts.filter { calendar.isDate($0.date, inSameDayAs: date) }
                let label = weekdays[calendar.component(.weekday, from: date) - 1]
                dailyData.append(ChartDataPoint(label: label, value: calculateValue(for: dayWorkouts, metric: metric)))
            }
            return dailyData
            
        case .month:
            var weeklyData: [ChartDataPoint] = []
            for i in (0...3).reversed() {
                let weekDate = calendar.date(byAdding: .weekOfYear, value: -i, to: now)!
                let interval = calendar.dateInterval(of: .weekOfYear, for: weekDate)!
                let wWorkouts = workouts.filter { interval.contains($0.date) }
                weeklyData.append(ChartDataPoint(label: "W\(4-i)", value: calculateValue(for: wWorkouts, metric: metric)))
            }
            return weeklyData
            
        case .year:
            var monthlyData: [ChartDataPoint] = []
            let symbols = calendar.shortMonthSymbols
            for i in (0...11).reversed() {
                let mDate = calendar.date(byAdding: .month, value: -i, to: now)!
                let interval = calendar.dateInterval(of: .month, for: mDate)!
                let mWorkouts = workouts.filter { interval.contains($0.date) }
                let label = symbols[calendar.component(.month, from: mDate) - 1]
                monthlyData.append(ChartDataPoint(label: label, value: calculateValue(for: mWorkouts, metric: metric)))
            }
            return monthlyData
        }
    }
    
    func calculateValue(for workouts: [Workout], metric: StatsView.GraphMetric) -> Double {
        switch metric {
        case .count:
            return Double(workouts.count)
        case .volume:
            return workouts.reduce(0) { wSum, w in wSum + w.exercises.reduce(0) { eSum, e in eSum + e.computedVolume } }
        case .time:
            return Double(workouts.reduce(0) { $0 + $1.duration })
        case .distance:
            return workouts.reduce(0.0) { wSum, w in
                wSum + w.exercises.reduce(0.0) { eSum, e in
                    let subExs = e.isSuperset ? e.subExercises : [e]
                    let dist = subExs.reduce(0.0) { s, sub in
                        s + sub.setsList.filter { $0.isCompleted }.compactMap { $0.distance }.reduce(0, +)
                    }
                    return eSum + dist
                }
            }
        }
    }
    
    // MARK: - 3. Timer Logic
    
    private var defaultRestTime: Int {
        let saved = UserDefaults.standard.integer(forKey: "defaultRestTime")
        return saved > 0 ? saved : 60
    }
    
    func startRestTimer(duration: Int? = nil) {
        let seconds = duration ?? defaultRestTime
        self.restEndTime = Date().addingTimeInterval(Double(seconds))
        self.restTimeRemaining = seconds
        self.isRestTimerActive = true
        self.restTimerFinished = false
        
        NotificationManager.shared.scheduleRestTimerNotification(seconds: Double(seconds))
        startTicker()
    }
    
    private func startTicker() {
        restTimer?.invalidate()
        restTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let endTime = self.restEndTime else { return }
            let timeLeft = Int(endTime.timeIntervalSinceNow)
            
            if timeLeft >= 0 {
                if self.restTimeRemaining != timeLeft + 1 {
                    self.restTimeRemaining = timeLeft + 1
                }
            } else {
                self.finishTimer()
            }
        }
    }
    
    func addRestTime(_ seconds: Int) {
        if isRestTimerActive, let currentEnd = restEndTime {
            let newEnd = currentEnd.addingTimeInterval(Double(seconds))
            self.restEndTime = newEnd
            NotificationManager.shared.scheduleRestTimerNotification(seconds: newEnd.timeIntervalSinceNow)
            self.restTimeRemaining += seconds
        }
    }
    
    func subtractRestTime(_ seconds: Int) {
        if isRestTimerActive, let currentEnd = restEndTime {
            let newEnd = currentEnd.addingTimeInterval(Double(-seconds))
            if newEnd.timeIntervalSinceNow <= 0 {
                finishTimer()
            } else {
                self.restEndTime = newEnd
                NotificationManager.shared.scheduleRestTimerNotification(seconds: newEnd.timeIntervalSinceNow)
                self.restTimeRemaining = max(0, restTimeRemaining - seconds)
            }
        }
    }
    
    func finishTimer() {
        restTimer?.invalidate()
        restTimer = nil
        restTimerFinished = true
        restEndTime = nil
        
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
        AudioServicesPlaySystemSound(1005)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation { self.stopRestTimer() }
        }
    }
    
    func stopRestTimer() {
        isRestTimerActive = false
        restTimerFinished = false
        restEndTime = nil
        restTimer?.invalidate()
        restTimer = nil
        NotificationManager.shared.cancelRestTimerNotification()
    }
    
    // MARK: - 4. Recovery Logic
    
    /// Оптимизированный расчет восстановления с дебаунсом и фоновым потоком
    func calculateRecovery(hours: Double? = nil, debounce: Bool = false) {
        // Отменяем предыдущую задачу, если она еще выполняется
        recoveryCalculationTask?.cancel()
        
        // Захватываем данные для фонового потока
        let workoutsCopy = self.workouts
        
        // Если нужен дебаунс (для слайдера), используем Task с задержкой
        if debounce {
            recoveryCalculationTask = Task {
                // Ждем 150ms перед расчетом, чтобы не считать на каждом движении слайдера
                try? await Task.sleep(nanoseconds: 150_000_000) // 150ms
                
                guard !Task.isCancelled else { return }
                await performRecoveryCalculation(hours: hours, workouts: workoutsCopy)
            }
        } else {
            // Для немедленного расчета (при загрузке данных)
            recoveryCalculationTask = Task {
                await performRecoveryCalculation(hours: hours, workouts: workoutsCopy)
            }
        }
    }
    
    /// Выполняет расчет восстановления на фоновом потоке
    private func performRecoveryCalculation(hours: Double?, workouts: [Workout]) async {
        // Выполняем тяжелые вычисления на фоновом потоке
        let result = await Task.detached(priority: .userInitiated) { () -> [MuscleRecoveryStatus] in
            var rawFatigueMap: [String: Double] = [:]
            
            // Если часы передали (со слайдера), используем их.
            // Иначе берем сохраненное значение.
            let fullRecoveryHours: Double
            if let hours = hours {
                fullRecoveryHours = hours
            } else {
                let savedHours = UserDefaults.standard.double(forKey: "userRecoveryHours")
                fullRecoveryHours = savedHours > 0 ? savedHours : 48.0
            }
            
            // ОПТИМИЗАЦИЯ: Фильтруем тренировки ДО сортировки
            // Тренировки старше fullRecoveryHours не влияют на восстановление
            let cutoffDate = Date().addingTimeInterval(-fullRecoveryHours * 3600)
            let relevantWorkouts = workouts.filter { $0.date >= cutoffDate }
            
            // Сортируем только релевантные тренировки
            let sortedWorkouts = relevantWorkouts.sorted(by: { $0.date < $1.date })
            
            let now = Date()
            for workout in sortedWorkouts {
                let hoursSince = now.timeIntervalSince(workout.date) / 3600
                // Дополнительная проверка (на случай если фильтрация не сработала)
                if hoursSince >= fullRecoveryHours { continue }
                
                let fatigueFactor = 1.0 - (hoursSince / fullRecoveryHours)
                
                for exercise in workout.exercises {
                    let targets = exercise.isSuperset ? exercise.subExercises : [exercise]
                    for ex in targets where ex.type == .strength {
                        let affected = MuscleMapping.getMuscles(for: ex.name, group: ex.muscleGroup)
                        for slug in affected {
                            rawFatigueMap[slug] = max(rawFatigueMap[slug] ?? 0.0, fatigueFactor)
                        }
                    }
                }
            }
            
            // Маппинг слага в красивое имя
            let slugToDisplayName: [String: String] = [
                "chest": "Chest", "upper-back": "Back", "lats": "Back", "lower-back": "Lower Back",
                "trapezius": "Trapezius", "deltoids": "Shoulders", "biceps": "Biceps", "triceps": "Triceps",
                "forearm": "Forearms", "abs": "Abs", "obliques": "Obliques", "gluteal": "Glutes",
                "hamstring": "Hamstrings", "quadriceps": "Legs", "adductors": "Legs", "abductors": "Legs",
                "legs": "Legs", "calves": "Calves"
            ]
            
            var displayFatigueMap: [String: Double] = [:]
            for (slug, fatigue) in rawFatigueMap {
                if let name = slugToDisplayName[slug] {
                    displayFatigueMap[name] = max(displayFatigueMap[name] ?? 0.0, fatigue)
                }
            }
            
            // Убедимся, что все мышцы из allMuscleGroups присутствуют в списке, даже если они 100%
            let allMuscleNames = Set(slugToDisplayName.values)
            for name in allMuscleNames {
                if displayFatigueMap[name] == nil {
                    displayFatigueMap[name] = 0.0
                }
            }
            
            return displayFatigueMap.map { (name, fatigue) in
                let percent = max(0, min(100, Int((1.0 - fatigue) * 100)))
                return MuscleRecoveryStatus(muscleGroup: name, recoveryPercentage: percent)
            }
        }.value
        
        // Обновляем UI на главном потоке
        await MainActor.run {
            self.recoveryStatus = result
        }
    }
    
    // MARK: - 5. Analysis & Recommendations
    
    func getImbalanceRecommendation() -> (title: String, message: String)? {
        let calendar = Calendar.current
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let recentWorkouts = workouts.filter { $0.date >= thirtyDaysAgo }
        
        if recentWorkouts.isEmpty { return nil }
        
        var chestSets = 0, backSets = 0, legSets = 0, upperBodySets = 0
        
        for workout in recentWorkouts {
            for exercise in workout.exercises {
                guard exercise.type == .strength else { continue }
                let list = exercise.isSuperset ? exercise.subExercises : [exercise]
                
                for ex in list {
                    let completedSets = ex.setsList.filter { $0.isCompleted && $0.type != .warmup }.count
                    let count = ex.setsList.isEmpty ? ex.sets : completedSets
                    
                    if ex.muscleGroup == "Chest" { chestSets += count }
                    if ex.muscleGroup == "Back" { backSets += count }
                    if ex.muscleGroup == "Legs" { legSets += count }
                    else if ["Chest", "Back", "Shoulders", "Arms"].contains(ex.muscleGroup) {
                        upperBodySets += count
                    }
                }
            }
        }
        
        if (chestSets + backSets) < 10 { return nil }
        
        if Double(chestSets) > Double(backSets) * 1.5 {
            return ("⚠️ Imbalance Detected", "Last 30 days: \(chestSets) Chest sets vs \(backSets) Back sets.\nAdd more Rows or Pull-ups!")
        }
        if legSets > 0 && Double(upperBodySets) > Double(legSets) * 3.0 {
            return ("🦵 Don't skip Leg Day!", "Upper body: \(upperBodySets) sets vs Legs: \(legSets) sets.\nBalance your physique!")
        }
        return nil
    }
    
    // MARK: - 6. Data Management (Workouts)
    
    func addWorkout(_ workout: Workout) {
        workouts.insert(workout, at: 0)
    }
    
    private func loadWorkouts() {
        DataManager.shared.loadWorkouts { [weak self] result in
            switch result {
            case .success(let workouts):
                DispatchQueue.main.async {
                    self?.workouts = workouts
                }
            case .failure(let error):
                // Ошибка загрузки критична только если у нас уже были данные
                if !(self?.workouts.isEmpty ?? true) {
                    self?.showError(
                        title: NSLocalizedString("Failed to Load Workouts", comment: "Error title when loading workouts fails"),
                        message: String(format: NSLocalizedString("Could not load your workout history. Some data may be missing.\n\nError: %@", comment: "Error message when loading workouts fails"), error.localizedDescription)
                    )
                }
                // При первом запуске ошибка нормальна (файла еще нет)
            }
        }
    }
    private func saveWorkouts() {
        // Не сохраняем дефолтные примеры
        let isExample = workouts.count == Workout.examples.count && workouts.map{$0.id} == Workout.examples.map{$0.id}
        if !isExample {
            DataManager.shared.saveWorkouts(workouts) { [weak self] error in
                self?.showError(
                    title: NSLocalizedString("Failed to Save Workouts", comment: "Error title when saving workouts fails"),
                    message: String(format: NSLocalizedString("Your workout data could not be saved. Please try again or restart the app.\n\nError: %@", comment: "Error message when saving workouts fails"), error.localizedDescription)
                )
            }
            
            // Автоматическое резервное копирование
            performAutoBackupIfNeeded()
        }
    }
    
    /// Выполняет автоматическое резервное копирование, если это необходимо
    private func performAutoBackupIfNeeded() {
        let backupManager = BackupManager.shared
        
        // Проверяем, нужно ли создавать бэкап
        guard backupManager.shouldCreateBackup() else { return }
        
        // Выполняем бэкап в фоновом потоке
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            backupManager.createBackup(workouts: self.workouts, viewModel: self)
        }
    }
    
    func getLastPerformance(for exerciseName: String, currentWorkoutId: UUID) -> Exercise? {
        let pastWorkouts = workouts
            .filter { $0.id != currentWorkoutId && $0.date <= Date() }
            .sorted { $0.date > $1.date }
        
        for workout in pastWorkouts {
            for exercise in workout.exercises {
                if exercise.name == exerciseName { return exercise }
                if exercise.isSuperset {
                    if let sub = exercise.subExercises.first(where: { $0.name == exerciseName }) { return sub }
                }
            }
        }
        return nil
    }
    
    // MARK: - 7. Data Management (Presets)
    
    func updatePreset(_ preset: WorkoutPreset) {
        if let index = presets.firstIndex(where: { $0.id == preset.id }) {
            presets[index] = preset
        } else {
            presets.append(preset)
        }
        savePresets()
    }
    
    func deletePreset(_ preset: WorkoutPreset) {
        if let index = presets.firstIndex(where: { $0.id == preset.id }) {
            presets.remove(at: index)
            savePresets()
        }
    }
    
    func deletePreset(at offsets: IndexSet) {
        presets.remove(atOffsets: offsets)
        savePresets()
    }
    
    private func savePresets() {
        if let encoded = try? JSONEncoder().encode(presets) {
            UserDefaults.standard.set(encoded, forKey: "SavedWorkoutPresets")
        }
    }
    
    private func loadPresets() {
           if let data = UserDefaults.standard.data(forKey: "SavedWorkoutPresets"),
              let decoded = try? JSONDecoder().decode([WorkoutPreset].self, from: data) {
               self.presets = decoded
           }
           
           // --- ВОТ ТУТ МАГИЯ ---
           // Если шаблонов нет (первый запуск), мы берем примеры из Workout.examples
           // и превращаем их в шаблоны (WorkoutPreset).
           if self.presets.isEmpty {
               // Берем твои старые примеры тренировок
               let examples = Workout.examples
               
               // Превращаем их в Presets
               self.presets = examples.map { workout in
                   WorkoutPreset(
                       id: UUID(),
                       name: workout.title, // Берем имя (например "Full Body")
                       icon: workout.icon,  // Берем иконку
                       exercises: workout.exercises // Берем список упражнений
                   )
               }
               
               // Сохраняем, чтобы они остались в памяти
               savePresets()
           }
       }
    
    // MARK: - 8. Data Management (Custom Exercises)
    
    private func loadDeletedDefaultExercises() {
        if let data = UserDefaults.standard.data(forKey: "DeletedDefaultExercises"),
           let decoded = try? JSONDecoder().decode(Set<String>.self, from: data) {
            self.deletedDefaultExercises = decoded
        }
    }
    
    var combinedCatalog: [String: [String]] {
        var catalog = Exercise.catalog
        
        // Исключаем удаленные стандартные упражнения
        for (category, exercises) in catalog {
            catalog[category] = exercises.filter { !deletedDefaultExercises.contains($0) }
        }
        
        // Добавляем пользовательские упражнения
        for custom in customExercises {
            var list = catalog[custom.category] ?? []
            if !list.contains(custom.name) { list.append(custom.name) }
            catalog[custom.category] = list
        }
        return catalog
    }
    
    func addCustomExercise(name: String, category: String, muscles: [String], type: ExerciseType = .strength) {
        let newDef = CustomExerciseDefinition(name: name, category: category, targetedMuscles: muscles, type: type)
        customExercises.append(newDef)
        
        var currentMap = UserDefaults.standard.dictionary(forKey: "CustomExerciseMappings") as? [String: [String]] ?? [:]
        currentMap[name] = muscles
        UserDefaults.standard.set(currentMap, forKey: "CustomExerciseMappings")
    }
    
    func deleteCustomExercise(name: String, category: String) {
        if let index = customExercises.firstIndex(where: { $0.name == name }) {
            customExercises.remove(at: index)
        }
        var currentMap = UserDefaults.standard.dictionary(forKey: "CustomExerciseMappings") as? [String: [String]] ?? [:]
        currentMap.removeValue(forKey: name)
        UserDefaults.standard.set(currentMap, forKey: "CustomExerciseMappings")
    }
    
    /// Удалить упражнение (работает как для пользовательских, так и для стандартных)
    func deleteExercise(name: String, category: String) {
        // Проверяем, является ли упражнение пользовательским
        if isCustomExercise(name: name) {
            deleteCustomExercise(name: name, category: category)
        } else {
            // Если это стандартное упражнение, добавляем его в список удаленных
            deletedDefaultExercises.insert(name)
        }
    }
    
    /// Проверяет, является ли упражнение пользовательским
    func isCustomExercise(name: String) -> Bool {
        return customExercises.contains(where: { $0.name == name })
    }
    
    private func saveCustomExercises() {
        if let encoded = try? JSONEncoder().encode(customExercises) {
            UserDefaults.standard.set(encoded, forKey: "SavedCustomExercises")
        }
    }
    
    private func loadCustomExercises() {
        if let data = UserDefaults.standard.data(forKey: "SavedCustomExercises"),
           let decoded = try? JSONDecoder().decode([CustomExerciseDefinition].self, from: data) {
            self.customExercises = decoded
        }
    }
    
    // MARK: - 9. Import / Export
    
    func generateShareLink(for preset: WorkoutPreset) -> URL? {
        // Проверка интернет-соединения перед экспортом через URL
        guard NetworkManager.shared.checkConnection() else {
            showError(
                title: "No Internet Connection",
                message: "An internet connection is required to generate a share link. Please check your network settings and try again."
            )
            return nil
        }
        
        do {
            let jsonData = try JSONEncoder().encode(preset)
            let compressedData = try (jsonData as NSData).compressed(using: .zlib) as Data
            let base64String = compressedData.base64EncodedString()
            
            let baseURL = "https://borisserz.github.io/workout-share/"
            var components = URLComponents(string: baseURL)!
            components.queryItems = [URLQueryItem(name: "data", value: base64String)]
            return components.url
        } catch {
            showError(
                title: "Export Failed",
                message: "Could not generate share link for the workout template.\n\nError: \(error.localizedDescription)"
            )
            return nil
        }
    }
    
    func exportPresetToFile(_ preset: WorkoutPreset) -> URL? {
        do {
            let jsonData = try JSONEncoder().encode(preset)
            // Очищаем имя файла от недопустимых символов
            let sanitizedName = preset.name
                .replacingOccurrences(of: "/", with: "-")
                .replacingOccurrences(of: "\\", with: "-")
                .replacingOccurrences(of: ":", with: "-")
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(sanitizedName).workouttemplate")
            
            try jsonData.write(to: tempURL)
            
            // Тип файла определяется автоматически по расширению .workouttemplate
            // через настройки в Info.plist (UTExportedTypeDeclarations)
            
            return tempURL
        } catch {
            showError(
                title: "Export Failed",
                message: "Could not export the workout template to file.\n\nError: \(error.localizedDescription)"
            )
            return nil
        }
    }
    
    func exportPresetToCSV(_ preset: WorkoutPreset) -> URL? {
        var csvLines: [String] = []
        
        // Заголовок
        csvLines.append("# Workout Template Export")
        csvLines.append("# Preset Name: \(preset.name)")
        csvLines.append("# Icon: \(preset.icon)")
        csvLines.append("# Exercise Count: \(preset.exercises.count)")
        csvLines.append("")
        
        // Основная информация о пресете
        csvLines.append("## PRESET INFO")
        csvLines.append("Preset ID,Name,Icon,Exercise Count")
        csvLines.append("\(preset.id.uuidString),\"\(escapeCSV(preset.name))\",\(preset.icon),\(preset.exercises.count)")
        csvLines.append("")
        
        // Упражнения
        csvLines.append("## EXERCISES")
        csvLines.append("Exercise ID,Name,Muscle Group,Type,Effort,Is Completed,Set Count")
        
        for exercise in preset.exercises {
            csvLines.append("\(exercise.id.uuidString),\"\(escapeCSV(exercise.name))\",\(exercise.muscleGroup),\(exercise.type.rawValue),\(exercise.effort),\(exercise.isCompleted),\(exercise.setsList.count)")
        }
        csvLines.append("")
        
        // Сеты
        csvLines.append("## SETS")
        csvLines.append("Set ID,Exercise ID,Exercise Name,Set Index,Weight,Reps,Distance (km),Time (sec),Is Completed,Set Type")
        
        for exercise in preset.exercises {
            for set in exercise.setsList {
                let weightStr = set.weight != nil ? String(set.weight!) : ""
                let repsStr = set.reps != nil ? String(set.reps!) : ""
                let distanceStr = set.distance != nil ? String(set.distance!) : ""
                let timeStr = set.time != nil ? String(set.time!) : ""
                
                csvLines.append("\(set.id.uuidString),\(exercise.id.uuidString),\"\(escapeCSV(exercise.name))\",\(set.index),\(weightStr),\(repsStr),\(distanceStr),\(timeStr),\(set.isCompleted),\(set.type.rawValue)")
            }
        }
        
        // Создаем CSV файл
        do {
            let csvContent = csvLines.joined(separator: "\n")
            guard let csvData = csvContent.data(using: .utf8) else {
                showError(
                    title: "Export Failed",
                    message: "Could not convert CSV content to data."
                )
                return nil
            }
            
            // Очищаем имя файла от недопустимых символов
            let sanitizedName = preset.name
                .replacingOccurrences(of: "/", with: "-")
                .replacingOccurrences(of: "\\", with: "-")
                .replacingOccurrences(of: ":", with: "-")
            
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(sanitizedName).csv")
            
            try csvData.write(to: tempURL)
            
            return tempURL
        } catch {
            showError(
                title: "Export Failed",
                message: "Could not export the workout template to CSV file.\n\nError: \(error.localizedDescription)"
            )
            return nil
        }
    }
    
    /// Экранирует специальные символы для CSV
    private func escapeCSV(_ string: String) -> String {
        // Если строка содержит запятую, кавычки или перенос строки, оборачиваем в кавычки
        if string.contains(",") || string.contains("\"") || string.contains("\n") {
            // Экранируем кавычки удвоением
            return string.replacingOccurrences(of: "\"", with: "\"\"")
        }
        return string
    }
    
    func importPreset(from url: URL) -> Bool {
        // Проверяем, это файл или URL-ссылка
        if url.isFileURL {
            // Импорт из файла
            return importPresetFromFile(url)
        } else {
            // Импорт из URL-ссылки (старый способ)
            return importPresetFromURL(url)
        }
    }
    
    private func importPresetFromFile(_ fileURL: URL) -> Bool {
        do {
            let jsonData = try Data(contentsOf: fileURL)
            return processImportedData(jsonData)
        } catch {
            showError(
                title: "Import Failed",
                message: "Could not read the workout template file. Please make sure the file is valid.\n\nError: \(error.localizedDescription)"
            )
            return false
        }
    }
    
    private func importPresetFromURL(_ url: URL) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let queryItem = components.queryItems?.first(where: { $0.name == "data" }),
              var base64String = queryItem.value else { return false }
        
        base64String = base64String.replacingOccurrences(of: " ", with: "+")
        
        guard let rawData = Data(base64Encoded: base64String, options: .ignoreUnknownCharacters) else { return false }
        
        let jsonData: Data
        do {
            jsonData = try (rawData as NSData).decompressed(using: .zlib) as Data
        } catch {
            jsonData = rawData
        }
        
        return processImportedData(jsonData)
    }
    
    private func processImportedData(_ jsonData: Data) -> Bool {
        do {
            var importedPreset = try JSONDecoder().decode(WorkoutPreset.self, from: jsonData)
            importedPreset.id = UUID()
            importedPreset.name = "\(importedPreset.name) (Imported)"
            
            var newExercises: [Exercise] = []
            for var ex in importedPreset.exercises {
                ex.id = UUID()
                var newSets: [WorkoutSet] = []
                for var set in ex.setsList {
                    set.id = UUID()
                    newSets.append(set)
                }
                ex.setsList = newSets
                newExercises.append(ex)
            }
            importedPreset.exercises = newExercises
            
            DispatchQueue.main.async {
                self.presets.insert(importedPreset, at: 0)
                self.savePresets()
            }
            return true
        } catch {
            showError(
                title: "Import Failed",
                message: "The workout template file is invalid or corrupted. Please check the file and try again.\n\nError: \(error.localizedDescription)"
            )
            return false
        }
    }
    
    // MARK: - 10. Advanced Analytics
    
    // MARK: - Exercise Trends
    
    struct ExerciseTrend: Identifiable {
        let id = UUID()
        let exerciseName: String
        let trend: TrendDirection
        let changePercentage: Double
        let currentValue: Double
        let previousValue: Double
        let period: String
    }
    
    enum TrendDirection {
        case growing, declining, stable
        
        var icon: String {
            switch self {
            case .growing: return "arrow.up.right"
            case .declining: return "arrow.down.right"
            case .stable: return "arrow.right"
            }
        }
        
        var color: Color {
            switch self {
            case .growing: return .green
            case .declining: return .red
            case .stable: return .orange
            }
        }
    }
    
    /// Анализ трендов по упражнениям (рост/падение)
    func getExerciseTrends(period: StatsView.Period = .month) -> [ExerciseTrend] {
        let calendar = Calendar.current
        let now = Date()
        
        var currentInterval: DateInterval
        var previousInterval: DateInterval
        
        switch period {
        case .week:
            currentInterval = calendar.dateInterval(of: .weekOfYear, for: now)!
            let lastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: now)!
            previousInterval = calendar.dateInterval(of: .weekOfYear, for: lastWeek)!
        case .month:
            currentInterval = calendar.dateInterval(of: .month, for: now)!
            let lastMonth = calendar.date(byAdding: .month, value: -1, to: now)!
            previousInterval = calendar.dateInterval(of: .month, for: lastMonth)!
        case .year:
            currentInterval = calendar.dateInterval(of: .year, for: now)!
            let lastYear = calendar.date(byAdding: .year, value: -1, to: now)!
            previousInterval = calendar.dateInterval(of: .year, for: lastYear)!
        }
        
        let currentWorkouts = workouts.filter { currentInterval.contains($0.date) }
        let previousWorkouts = workouts.filter { previousInterval.contains($0.date) }
        
        var exerciseData: [String: (current: Double, previous: Double, count: Int)] = [:]
        
        // Собираем данные по текущему периоду
        for workout in currentWorkouts {
            for exercise in workout.exercises {
                let targetExercises = exercise.isSuperset ? exercise.subExercises : [exercise]
                for ex in targetExercises where ex.type == .strength {
                    let maxWeight = ex.setsList
                        .filter { $0.isCompleted && $0.type != .warmup }
                        .compactMap { $0.weight }
                        .max() ?? 0
                    
                    if maxWeight > 0 {
                        let existing = exerciseData[ex.name] ?? (0, 0, 0)
                        exerciseData[ex.name] = (max(existing.current, maxWeight), existing.previous, existing.count + 1)
                    }
                }
            }
        }
        
        // Собираем данные по предыдущему периоду
        for workout in previousWorkouts {
            for exercise in workout.exercises {
                let targetExercises = exercise.isSuperset ? exercise.subExercises : [exercise]
                for ex in targetExercises where ex.type == .strength {
                    let maxWeight = ex.setsList
                        .filter { $0.isCompleted && $0.type != .warmup }
                        .compactMap { $0.weight }
                        .max() ?? 0
                    
                    if maxWeight > 0 {
                        let existing = exerciseData[ex.name] ?? (0, 0, 0)
                        exerciseData[ex.name] = (existing.current, max(existing.previous, maxWeight), existing.count)
                    }
                }
            }
        }
        
        // Формируем тренды
        var trends: [ExerciseTrend] = []
        for (name, data) in exerciseData {
            guard data.current > 0 || data.previous > 0 else { continue }
            
            let change: Double
            let direction: TrendDirection
            
            if data.previous == 0 {
                change = 100.0
                direction = .growing
            } else if data.current == 0 {
                change = -100.0
                direction = .declining
            } else {
                change = ((data.current - data.previous) / data.previous) * 100.0
                if abs(change) < 2.0 {
                    direction = .stable
                } else {
                    direction = change > 0 ? .growing : .declining
                }
            }
            
            trends.append(ExerciseTrend(
                exerciseName: name,
                trend: direction,
                changePercentage: change,
                currentValue: data.current,
                previousValue: data.previous,
                period: period.rawValue
            ))
        }
        
        // Сортируем тренды: сначала растущие (по убыванию изменения), затем падающие (по возрастанию изменения)
        // Это позволяет показать наиболее значимые положительные изменения и самые проблемные падения
        return trends.sorted { trend1, trend2 in
            // Приоритет растущим трендам
            if trend1.trend == .growing && trend2.trend != .growing {
                return true
            }
            if trend1.trend != .growing && trend2.trend == .growing {
                return false
            }
            // Если оба одного типа, сортируем по абсолютному значению изменения
            return abs(trend1.changePercentage) > abs(trend2.changePercentage)
        }
    }
    
    // MARK: - Progress Forecasting
    
    struct ProgressForecast: Identifiable {
        let id = UUID()
        let exerciseName: String
        let currentMax: Double
        let predictedMax: Double
        let confidence: Int // 0-100
        let timeframe: String
    }
    
    /// Прогноз прогресса на основе исторических данных
    ///
    /// **Принцип работы:**
    /// 1. Собирает историю выполнения упражнения за последние 90 дней
    /// 2. Для каждого упражнения находит максимальный вес в каждой тренировке
    /// 3. Вычисляет средний прирост веса в день (линейная экстраполяция)
    /// 4. Прогнозирует результат через N дней: текущий_макс + (средний_прирост × дни)
    ///
    /// **Уверенность (confidence):**
    /// - 70-100%: Высокая уверенность (много данных, стабильный рост)
    /// - 50-69%: Средняя уверенность (достаточно данных, но есть колебания)
    /// - 30-49%: Низкая уверенность (мало данных или нестабильный прогресс)
    ///
    /// **Факторы, влияющие на уверенность:**
    /// - Количество точек данных (больше тренировок = выше уверенность)
    /// - Стабильность прогресса (постоянный рост = выше уверенность)
    /// - Временной охват данных (данные за больший период = выше уверенность)
    func getProgressForecast(daysAhead: Int = 30) -> [ProgressForecast] {
        let calendar = Calendar.current
        let now = Date()
        let cutoffDate = calendar.date(byAdding: .day, value: -90, to: now)!
        
        let recentWorkouts = workouts.filter { $0.date >= cutoffDate }
        
        var exerciseHistory: [String: [(date: Date, maxWeight: Double)]] = [:]
        
        // Собираем историю по каждому упражнению
        for workout in recentWorkouts {
            for exercise in workout.exercises {
                let targetExercises = exercise.isSuperset ? exercise.subExercises : [exercise]
                for ex in targetExercises where ex.type == .strength {
                    let maxWeight = ex.setsList
                        .filter { $0.isCompleted && $0.type != .warmup }
                        .compactMap { $0.weight }
                        .max() ?? 0
                    
                    if maxWeight > 0 {
                        if exerciseHistory[ex.name] == nil {
                            exerciseHistory[ex.name] = []
                        }
                        exerciseHistory[ex.name]?.append((date: workout.date, maxWeight: maxWeight))
                    }
                }
            }
        }
        
        var forecasts: [ProgressForecast] = []
        
        for (name, history) in exerciseHistory {
            guard history.count >= 3 else { continue } // Нужно минимум 3 точки данных
            
            let sortedHistory = history.sorted { $0.date < $1.date }
            let currentMax = sortedHistory.last?.maxWeight ?? 0
            
            // Улучшенная линейная регрессия для прогноза
            // Преобразуем даты в дни от начала истории (для упрощения расчетов)
            let firstDate = sortedHistory.first!.date
            let daysFromStart = sortedHistory.map { now.timeIntervalSince($0.date) / 86400 }
            let weights = sortedHistory.map { $0.maxWeight }
            
            // Вычисляем средний прирост в день (линейная регрессия)
            var totalIncrease = 0.0
            var totalDays = 0.0
            var positiveChanges = 0
            var negativeChanges = 0
            
            for i in 1..<sortedHistory.count {
                let daysDiff = abs(daysFromStart[i] - daysFromStart[i-1])
                if daysDiff > 0 {
                    let weightDiff = weights[i] - weights[i-1]
                    totalIncrease += weightDiff
                    totalDays += daysDiff
                    
                    if weightDiff > 0 {
                        positiveChanges += 1
                    } else if weightDiff < 0 {
                        negativeChanges += 1
                    }
                }
            }
            
            // Средний прирост в день (кг/день)
            let avgIncreasePerDay = totalDays > 0 ? totalIncrease / totalDays : 0
            
            // Прогнозируемый прирост за указанный период
            let predictedIncrease = avgIncreasePerDay * Double(daysAhead)
            
            // Прогнозируемый максимум (не может быть меньше текущего)
            let predictedMax = max(currentMax, currentMax + predictedIncrease)
            
            // Расчет уверенности (confidence) в процентах:
            // 1. Базовый уровень: количество точек данных (больше данных = выше уверенность)
            //    Минимум 30%, максимум 70% за счет данных
            let dataPointsScore = min(70, max(30, sortedHistory.count * 8))
            
            // 2. Стабильность прогресса: если есть положительный тренд, добавляем бонус
            let trendBonus = avgIncreasePerDay > 0 ? 15 : 0
            
            // 3. Консистентность: если прогресс стабильный (больше положительных изменений),
            //    добавляем бонус. Если много отрицательных - штрафуем
            let consistencyBonus: Int
            let totalChanges = positiveChanges + negativeChanges
            if totalChanges > 0 {
                let positiveRatio = Double(positiveChanges) / Double(totalChanges)
                if positiveRatio >= 0.7 {
                    consistencyBonus = 15 // Стабильный рост
                } else if positiveRatio >= 0.5 {
                    consistencyBonus = 5  // Смешанный тренд
                } else {
                    consistencyBonus = -10 // Больше падений, чем ростов
                }
            } else {
                consistencyBonus = 0
            }
            
            // 4. Временной охват: если данные за большой период, выше уверенность
            let timeSpan = daysFromStart.first! - daysFromStart.last!
            let timeSpanBonus = min(10, Int(timeSpan / 30)) // До 10% за каждый месяц данных
            
            // Итоговая уверенность (0-100%)
            let confidence = min(100, max(30, dataPointsScore + trendBonus + consistencyBonus + timeSpanBonus))
            
            let timeframe = daysAhead == 30 ? "30 days" : "\(daysAhead) days"
            
            forecasts.append(ProgressForecast(
                exerciseName: name,
                currentMax: currentMax,
                predictedMax: predictedMax,
                confidence: confidence,
                timeframe: timeframe
            ))
        }
        
        return forecasts.sorted { $0.predictedMax > $1.predictedMax }
    }
    
    // MARK: - Weak Points Analysis
    
    struct WeakPoint: Identifiable {
        let id = UUID()
        let muscleGroup: String
        let frequency: Int // Количество тренировок за последние 30 дней
        let averageVolume: Double
        let recommendation: String
    }
    
    /// Анализ слабых мест (недостаточно тренируемые группы мышц)
    func getWeakPoints() -> [WeakPoint] {
        let calendar = Calendar.current
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let recentWorkouts = workouts.filter { $0.date >= thirtyDaysAgo }
        
        if recentWorkouts.isEmpty { return [] }
        
        var muscleGroupData: [String: (frequency: Int, totalVolume: Double)] = [:]
        
        // Собираем данные по группам мышц
        for workout in recentWorkouts {
            var uniqueMusclesInWorkout = Set<String>()
            
            for exercise in workout.exercises {
                let targetExercises = exercise.isSuperset ? exercise.subExercises : [exercise]
                for ex in targetExercises where ex.type == .strength {
                    let muscles = MuscleMapping.getMuscles(for: ex.name, group: ex.muscleGroup)
                    let volume = ex.computedVolume
                    
                    for muscle in muscles {
                        uniqueMusclesInWorkout.insert(muscle)
                        let existing = muscleGroupData[muscle] ?? (0, 0)
                        muscleGroupData[muscle] = (existing.frequency, existing.totalVolume + volume)
                    }
                }
            }
            
            // Увеличиваем частоту для каждой уникальной группы в этой тренировке
            for muscle in uniqueMusclesInWorkout {
                let existing = muscleGroupData[muscle] ?? (0, 0)
                muscleGroupData[muscle] = (existing.frequency + 1, existing.totalVolume)
            }
        }
        
        // Определяем средние значения для сравнения
        let avgFrequency = muscleGroupData.values.map { Double($0.frequency) }.reduce(0, +) / Double(max(muscleGroupData.count, 1))
        let avgVolume = muscleGroupData.values.map { $0.totalVolume }.reduce(0, +) / Double(max(muscleGroupData.count, 1))
        
        // Находим слабые места
        var weakPoints: [WeakPoint] = []
        
        let muscleDisplayNames: [String: String] = [
            "chest": "Chest", "upper-back": "Back", "lats": "Back", "lower-back": "Lower Back",
            "trapezius": "Trapezius", "deltoids": "Shoulders", "biceps": "Biceps", "triceps": "Triceps",
            "forearm": "Forearms", "abs": "Abs", "obliques": "Obliques", "gluteal": "Glutes",
            "hamstring": "Hamstrings", "quadriceps": "Legs", "adductors": "Legs", "abductors": "Legs",
            "legs": "Legs", "calves": "Calves"
        ]
        
        for (slug, data) in muscleGroupData {
            let displayName = muscleDisplayNames[slug] ?? slug.capitalized
            let frequency = data.frequency
            let avgVol = data.totalVolume / Double(max(frequency, 1))
            
            // Считаем слабым местом, если частота или объем ниже среднего
            if Double(frequency) < avgFrequency * 0.7 || avgVol < avgVolume * 0.7 {
                let recommendation: String
                if frequency == 0 {
                    recommendation = "Start training this muscle group"
                } else if Double(frequency) < avgFrequency * 0.5 {
                    recommendation = "Increase training frequency"
                } else {
                    recommendation = "Increase training volume"
                }
                
                weakPoints.append(WeakPoint(
                    muscleGroup: displayName,
                    frequency: frequency,
                    averageVolume: avgVol,
                    recommendation: recommendation
                ))
            }
        }
        
        return weakPoints.sorted { $0.frequency < $1.frequency }
    }
    
    // MARK: - Data-based Recommendations
    
    struct Recommendation: Identifiable {
        let id = UUID()
        let type: RecommendationType
        let title: String
        let message: String
        let priority: Int // 1-5, где 5 - самый высокий приоритет
    }
    
    enum RecommendationType {
        case frequency, volume, balance, recovery, progression, positive
        
        var icon: String {
            switch self {
            case .frequency: return "calendar"
            case .volume: return "scalemass"
            case .balance: return "scalemass.2"
            case .recovery: return "bed.double"
            case .progression: return "chart.line.uptrend.xyaxis"
            case .positive: return "checkmark.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .frequency: return .blue
            case .volume: return .purple
            case .balance: return .orange
            case .recovery: return .green
            case .progression: return .pink
            case .positive: return .green
            }
        }
    }
    
    /// Генерация рекомендаций на основе данных
    func getRecommendations() -> [Recommendation] {
        var recommendations: [Recommendation] = []
        
        let calendar = Calendar.current
        let now = Date()
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now) ?? now
        let recentWorkouts = workouts.filter { $0.date >= thirtyDaysAgo }
        
        // 1. Рекомендация по частоте тренировок
        let daysSinceLastWorkout = recentWorkouts.isEmpty ? 999 : 
            calendar.dateComponents([.day], from: recentWorkouts[0].date, to: now).day ?? 0
        
        if daysSinceLastWorkout > 7 {
            recommendations.append(Recommendation(
                type: .frequency,
                title: "Increase Training Frequency",
                message: "It's been \(daysSinceLastWorkout) days since your last workout. Try to maintain consistency!",
                priority: 5
            ))
        } else if recentWorkouts.count < 8 {
            recommendations.append(Recommendation(
                type: .frequency,
                title: "Build Consistency",
                message: "You've trained \(recentWorkouts.count) times in the last 30 days. Aim for 3-4 times per week!",
                priority: 4
            ))
        }
        
        // 2. Рекомендация по балансу (используем существующий метод)
        if let imbalance = getImbalanceRecommendation() {
            recommendations.append(Recommendation(
                type: .balance,
                title: imbalance.title,
                message: imbalance.message,
                priority: 4
            ))
        }
        
        // 3. Рекомендация по слабым местам
        let weakPoints = getWeakPoints()
        if !weakPoints.isEmpty {
            let topWeakPoint = weakPoints[0]
            recommendations.append(Recommendation(
                type: .volume,
                title: "Focus on \(topWeakPoint.muscleGroup)",
                message: topWeakPoint.recommendation + ". Only trained \(topWeakPoint.frequency) times in the last 30 days.",
                priority: 3
            ))
        }
        
        // 4. Рекомендация по прогрессу
        let trends = getExerciseTrends(period: .month)
        let decliningExercises = trends.filter { $0.trend == .declining && abs($0.changePercentage) > 10 }
        if !decliningExercises.isEmpty {
            let exercise = decliningExercises[0]
            recommendations.append(Recommendation(
                type: .progression,
                title: "Review \(exercise.exerciseName)",
                message: "Your performance decreased by \(Int(abs(exercise.changePercentage)))%. Consider adjusting your training plan.",
                priority: 3
            ))
        }
        
        // 5. Рекомендация по восстановлению
        let lowRecoveryMuscles = recoveryStatus.filter { $0.recoveryPercentage < 50 }
        if !lowRecoveryMuscles.isEmpty {
            recommendations.append(Recommendation(
                type: .recovery,
                title: "Allow More Recovery",
                message: "\(lowRecoveryMuscles.count) muscle group(s) need more rest. Consider a rest day.",
                priority: 2
            ))
        }
        
        // 6. Позитивные рекомендации (если нет проблем)
        if recommendations.isEmpty {
            // Все хорошо - добавляем позитивные сообщения
            if !recentWorkouts.isEmpty {
                let workoutCount = recentWorkouts.count
                let streak = calculateWorkoutStreak()
                
                if workoutCount >= 12 {
                    recommendations.append(Recommendation(
                        type: .positive,
                        title: "Excellent Consistency! 🎉",
                        message: "You've trained \(workoutCount) times in the last 30 days. Keep up the great work!",
                        priority: 5
                    ))
                } else if workoutCount >= 8 {
                    recommendations.append(Recommendation(
                        type: .positive,
                        title: "Great Progress! 💪",
                        message: "You've trained \(workoutCount) times in the last 30 days. You're on the right track!",
                        priority: 4
                    ))
                }
                
                if streak >= 7 {
                    recommendations.append(Recommendation(
                        type: .positive,
                        title: "Amazing Streak! 🔥",
                        message: "You have a \(streak) day workout streak! Your dedication is inspiring!",
                        priority: 5
                    ))
                }
                
                // Проверяем баланс мышц (позитивно)
                if getImbalanceRecommendation() == nil && recentWorkouts.count >= 4 {
                    recommendations.append(Recommendation(
                        type: .positive,
                        title: "Well-Balanced Training! ⚖️",
                        message: "Your muscle groups are well-balanced. Great job maintaining symmetry!",
                        priority: 3
                    ))
                }
                
                // Проверяем прогресс (позитивно)
                let trends = getExerciseTrends(period: .month)
                let growingExercises = trends.filter { $0.trend == .growing && $0.changePercentage > 5 }
                if !growingExercises.isEmpty {
                    let topExercise = growingExercises.sorted { $0.changePercentage > $1.changePercentage }.first!
                    recommendations.append(Recommendation(
                        type: .positive,
                        title: "Strong Progress! 📈",
                        message: "\(topExercise.exerciseName) improved by \(Int(topExercise.changePercentage))%. Keep pushing!",
                        priority: 4
                    ))
                }
            } else {
                // Нет тренировок - мотивирующее сообщение
                recommendations.append(Recommendation(
                    type: .positive,
                    title: "Ready to Start? 🚀",
                    message: "Start your fitness journey today! Every workout counts towards your goals.",
                    priority: 3
                ))
            }
        }
        
        return recommendations.sorted { $0.priority > $1.priority }
    }
    
    // MARK: - Detailed Period Comparison
    
    struct DetailedComparison {
        let metric: String
        let currentValue: Double
        let previousValue: Double
        let change: Double
        let changePercentage: Double
        let trend: TrendDirection
    }
    
    /// Детальное сравнение с предыдущим периодом
    func getDetailedComparison(period: StatsView.Period) -> [DetailedComparison] {
        let calendar = Calendar.current
        let now = Date()
        
        var currentInterval: DateInterval
        var previousInterval: DateInterval
        
        switch period {
        case .week:
            currentInterval = calendar.dateInterval(of: .weekOfYear, for: now)!
            let lastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: now)!
            previousInterval = calendar.dateInterval(of: .weekOfYear, for: lastWeek)!
        case .month:
            currentInterval = calendar.dateInterval(of: .month, for: now)!
            let lastMonth = calendar.date(byAdding: .month, value: -1, to: now)!
            previousInterval = calendar.dateInterval(of: .month, for: lastMonth)!
        case .year:
            currentInterval = calendar.dateInterval(of: .year, for: now)!
            let lastYear = calendar.date(byAdding: .year, value: -1, to: now)!
            previousInterval = calendar.dateInterval(of: .year, for: lastYear)!
        }
        
        let currentStats = getStats(for: currentInterval)
        let previousStats = getStats(for: previousInterval)
        
        func calculateChange(current: Double, previous: Double) -> (change: Double, percentage: Double, trend: TrendDirection) {
            let change = current - previous
            let percentage = previous == 0 ? (current > 0 ? 100.0 : 0.0) : (change / previous) * 100.0
            let trend: TrendDirection = abs(percentage) < 2 ? .stable : (percentage > 0 ? .growing : .declining)
            return (change, percentage, trend)
        }
        
        var comparisons: [DetailedComparison] = []
        
        // Workout Count
        let (wcChange, wcPct, wcTrend) = calculateChange(
            current: Double(currentStats.workoutCount),
            previous: Double(previousStats.workoutCount)
        )
        comparisons.append(DetailedComparison(
            metric: "Workouts",
            currentValue: Double(currentStats.workoutCount),
            previousValue: Double(previousStats.workoutCount),
            change: wcChange,
            changePercentage: wcPct,
            trend: wcTrend
        ))
        
        // Total Volume
        let (volChange, volPct, volTrend) = calculateChange(
            current: currentStats.totalVolume,
            previous: previousStats.totalVolume
        )
        comparisons.append(DetailedComparison(
            metric: "Total Volume (kg)",
            currentValue: currentStats.totalVolume,
            previousValue: previousStats.totalVolume,
            change: volChange,
            changePercentage: volPct,
            trend: volTrend
        ))
        
        // Total Reps
        let (repsChange, repsPct, repsTrend) = calculateChange(
            current: Double(currentStats.totalReps),
            previous: Double(previousStats.totalReps)
        )
        comparisons.append(DetailedComparison(
            metric: "Total Reps",
            currentValue: Double(currentStats.totalReps),
            previousValue: Double(previousStats.totalReps),
            change: repsChange,
            changePercentage: repsPct,
            trend: repsTrend
        ))
        
        // Total Duration
        let (durChange, durPct, durTrend) = calculateChange(
            current: Double(currentStats.totalDuration),
            previous: Double(previousStats.totalDuration)
        )
        comparisons.append(DetailedComparison(
            metric: "Duration (min)",
            currentValue: Double(currentStats.totalDuration),
            previousValue: Double(previousStats.totalDuration),
            change: durChange,
            changePercentage: durPct,
            trend: durTrend
        ))
        
        // Total Distance
        let (distChange, distPct, distTrend) = calculateChange(
            current: currentStats.totalDistance,
            previous: previousStats.totalDistance
        )
        comparisons.append(DetailedComparison(
            metric: "Distance (km)",
            currentValue: currentStats.totalDistance,
            previousValue: previousStats.totalDistance,
            change: distChange,
            changePercentage: distPct,
            trend: distTrend
        ))
        
        // Average Volume per Workout
        let currentAvgVol = currentStats.workoutCount > 0 ? currentStats.totalVolume / Double(currentStats.workoutCount) : 0
        let previousAvgVol = previousStats.workoutCount > 0 ? previousStats.totalVolume / Double(previousStats.workoutCount) : 0
        let (avgVolChange, avgVolPct, avgVolTrend) = calculateChange(current: currentAvgVol, previous: previousAvgVol)
        comparisons.append(DetailedComparison(
            metric: "Avg Volume/Workout (kg)",
            currentValue: currentAvgVol,
            previousValue: previousAvgVol,
            change: avgVolChange,
            changePercentage: avgVolPct,
            trend: avgVolTrend
        ))
        
        return comparisons
    }
    
    // MARK: - 11. Widget
    
    func updateWidgetData() {
        let currentStreak = calculateWorkoutStreak()
        var points: [WidgetData.WeeklyPoint] = []
        let calendar = Calendar.current
        let today = Date()
        
        for i in (0...5).reversed() {
            if let date = calendar.date(byAdding: .weekOfYear, value: -i, to: today) {
                let interval = calendar.dateInterval(of: .weekOfYear, for: date)!
                let count = workouts.filter { interval.contains($0.date) }.count
                let formatter = DateFormatter()
                formatter.dateFormat = "M/d"
                points.append(WidgetData.WeeklyPoint(label: formatter.string(from: interval.start), count: count))
            }
        }
        
        WidgetDataManager.save(streak: currentStreak, weeklyStats: points)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
