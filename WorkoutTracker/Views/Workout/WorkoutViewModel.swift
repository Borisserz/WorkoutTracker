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
            case .cardio:   valString = String(format: "%.2f km", data.result)
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
           let loaded = DataManager.shared.loadWorkouts()
           // Если загружать нечего, оставляем массив пустым.
           // Не подгружаем Workout.examples, чтобы туториал видел "пустое состояние".
           self.workouts = loaded
       }
    private func saveWorkouts() {
        // Не сохраняем дефолтные примеры
        let isExample = workouts.count == Workout.examples.count && workouts.map{$0.id} == Workout.examples.map{$0.id}
        if !isExample {
            DataManager.shared.saveWorkouts(workouts)
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
               print("Creating default presets...")
               
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
        do {
            let jsonData = try JSONEncoder().encode(preset)
            let compressedData = try (jsonData as NSData).compressed(using: .zlib) as Data
            let base64String = compressedData.base64EncodedString()
            
            let baseURL = "https://borisserz.github.io/workout-share/"
            var components = URLComponents(string: baseURL)!
            components.queryItems = [URLQueryItem(name: "data", value: base64String)]
            return components.url
        } catch {
            print("❌ Export error: \(error)")
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
            print("❌ Export to file error: \(error)")
            return nil
        }
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
        guard let jsonData = try? Data(contentsOf: fileURL) else {
            print("❌ Failed to read file data")
            return false
        }
        
        return processImportedData(jsonData)
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
            print("❌ Import JSON Error: \(error)")
            return false
        }
    }
    
    // MARK: - 10. Widget
    
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
