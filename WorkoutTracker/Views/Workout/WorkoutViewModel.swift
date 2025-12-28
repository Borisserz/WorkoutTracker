//
//  WorkoutViewModel.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 24.12.25.
//
import AudioToolbox
import Foundation
import Combine
internal import SwiftUI

class WorkoutViewModel: ObservableObject {

    func calculateWorkoutStreak() -> Int {
           guard !workouts.isEmpty else { return 0 }
           
           // 1. Считываем настройку пользователя из UserDefaults
           // Используем тот же ключ, что и в SettingsView
           let maxRestDaysAllowed = UserDefaults.standard.integer(forKey: "streakRestDays")
           // Если пользователь никогда не заходил в настройки, ставим дефолтное значение 2
           let maxRestDays = maxRestDaysAllowed > 0 ? maxRestDaysAllowed : 2
           
           let sortedWorkouts = workouts.sorted(by: { $0.date > $1.date })
           let calendar = Calendar.current
           
           var uniqueWorkoutDays: [Date] = []
           for workout in sortedWorkouts {
               if !uniqueWorkoutDays.contains(where: { calendar.isDate($0, inSameDayAs: workout.date) }) {
                   uniqueWorkoutDays.append(workout.date)
               }
           }
           
           if uniqueWorkoutDays.isEmpty { return 0 }
           
           let mostRecentWorkoutDate = uniqueWorkoutDays[0]
           
           // Проверяем, не прерван ли стрик уже
           // `maxRestDays + 1` — это день, когда нужно тренироваться.
           // Если с последней тренировки прошло больше дней, стрик = 0.
           if calendar.dateComponents([.day], from: mostRecentWorkoutDate, to: Date()).day ?? 0 > maxRestDays {
                return 0
           }
           
           var currentStreak = 1
           var lastDate = mostRecentWorkoutDate
           
           guard uniqueWorkoutDays.count > 1 else { return 1 }
           
           for i in 1..<uniqueWorkoutDays.count {
               let currentDate = uniqueWorkoutDays[i]
               let daysBetween = calendar.dateComponents([.day], from: currentDate, to: lastDate).day ?? 0
               
               // 2. ИСПОЛЬЗУЕМ НАСТРОЙКУ ПОЛЬЗОВАТЕЛЯ
               // Было: if daysBetween <= 2
               // Стало:
               if daysBetween <= maxRestDays + 1 {
                   currentStreak += 1
                   lastDate = currentDate
               } else {
                   break
               }
           }
           
           return currentStreak
       }
    
    func getBestStats(for periodType: StatsView.Period) -> PeriodStats {
            guard !workouts.isEmpty else { return PeriodStats() }
            
            var bestStats = PeriodStats()
            let calendar = Calendar.current
            
            // Группируем тренировки по неделям, месяцам или годам
            let groupedWorkouts: [DateInterval: [Workout]]
            switch periodType {
            case .week:
                groupedWorkouts = Dictionary(grouping: workouts, by: { calendar.dateInterval(of: .weekOfYear, for: $0.date)! })
            case .month:
                groupedWorkouts = Dictionary(grouping: workouts, by: { calendar.dateInterval(of: .month, for: $0.date)! })
            case .year:
                groupedWorkouts = Dictionary(grouping: workouts, by: { calendar.dateInterval(of: .year, for: $0.date)! })
            }
            
            // Проходим по каждой группе и ищем лучшую
            for (interval, periodWorkouts) in groupedWorkouts {
                // Используем уже существующую функцию getStats для подсчета
                let statsForThisPeriod = getStats(for: interval)
                
                // Сравниваем по количеству тренировок (можно выбрать другой параметр)
                if statsForThisPeriod.workoutCount > bestStats.workoutCount {
                    bestStats = statsForThisPeriod
                }
            }
            
            return bestStats
        }
   
    // --- СТРУКТУРЫ ДЛЯ СТАТИСТИКИ (без изменений) ---
    struct PeriodStats {
        var workoutCount: Int = 0
        var totalReps: Int = 0
        var totalDuration: Int = 0
        var totalVolume: Double = 0.0
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

    // --- ФУНКЦИИ ДЛЯ СТАТИСТИКИ ---
    
    // ИСПРАВЛЕННАЯ ФУНКЦИЯ ДЛЯ ГРАФИКА
    func getChartData(for period: StatsView.Period, metric: StatsView.GraphMetric) -> [ChartDataPoint] { // <- ИСПРАВЛЕНА ОПЕЧАТКА
        let calendar = Calendar.current
        let now = Date()
        
        switch period {
        case .week:
            var dailyData: [ChartDataPoint] = []
            let weekdays = ["Вс", "Пн", "Вт", "Ср", "Чт", "Пт", "Сб"]
            
            for i in (0...6).reversed() {
                let date = calendar.date(byAdding: .day, value: -i, to: now)!
                let dayWorkouts = workouts.filter { calendar.isDate($0.date, inSameDayAs: date) }
                let weekdayIndex = calendar.component(.weekday, from: date) - 1
                let label = weekdays[weekdayIndex]
                
                let value = calculateValue(for: dayWorkouts, metric: metric)
                dailyData.append(ChartDataPoint(label: label, value: value))
            }
            return dailyData
            
        case .month:
            var weeklyData: [ChartDataPoint] = []
            for i in (0...3).reversed() {
                let weekDate = calendar.date(byAdding: .weekOfYear, value: -i, to: now)!
                let weekInterval = calendar.dateInterval(of: .weekOfYear, for: weekDate)!
                let weekWorkouts = workouts.filter { weekInterval.contains($0.date) }
                
                let value = calculateValue(for: weekWorkouts, metric: metric)
                weeklyData.append(ChartDataPoint(label: "W\(4-i)", value: value))
            }
            return weeklyData
            
        case .year:
            var monthlyData: [ChartDataPoint] = []
            let monthSymbols = calendar.shortMonthSymbols
            
            for i in (0...11).reversed() {
                let monthDate = calendar.date(byAdding: .month, value: -i, to: now)!
                let monthInterval = calendar.dateInterval(of: .month, for: monthDate)!
                let monthWorkouts = workouts.filter { monthInterval.contains($0.date) }
                let monthIndex = calendar.component(.month, from: monthDate) - 1
                let label = monthSymbols[monthIndex]
                
                let value = calculateValue(for: monthWorkouts, metric: metric)
                monthlyData.append(ChartDataPoint(label: label, value: value))
            }
            return monthlyData
        }
    }

    private func calculateValue(for workouts: [Workout], metric: StatsView.GraphMetric) -> Double {
        switch metric {
        case .count:
            return Double(workouts.count)
        case .volume:
            return workouts.reduce(0) { $0 + $1.exercises.reduce(0) { $0 + $1.computedVolume } }
        case .time:
            return Double(workouts.reduce(0) { $0 + $1.duration })
        }
    }
    
    // ВТОРАЯ ФУНКЦИЯ getChartData БЫЛА УДАЛЕНА

    func getRecentPRs(in interval: DateInterval) -> [PersonalRecord] {
        var records: [PersonalRecord] = []
        var bestWeights: [String: Double] = [:]
        
        let workoutsBefore = workouts.filter { $0.date < interval.start }
        for workout in workoutsBefore {
            for exercise in workout.exercises.flatMap({ $0.isSuperset ? $0.subExercises : [$0] }) {
                let currentBest = bestWeights[exercise.name] ?? 0.0
                if exercise.weight > currentBest {
                    bestWeights[exercise.name] = exercise.weight
                }
            }
        }
        
        let workoutsInPeriod = workouts.filter { interval.contains($0.date) }.sorted(by: { $0.date < $1.date })
        
        for workout in workoutsInPeriod {
            for exercise in workout.exercises.flatMap({ $0.isSuperset ? $0.subExercises : [$0] }) {
                let oldRecord = bestWeights[exercise.name] ?? 0.0
                if exercise.weight > oldRecord {
                    let newPR = PersonalRecord(exerciseName: exercise.name, weight: exercise.weight, date: workout.date)
                    records.removeAll { $0.exerciseName == newPR.exerciseName }
                    records.append(newPR)
                    bestWeights[exercise.name] = exercise.weight
                }
            }
        }
        return records.sorted(by: { $0.date > $1.date })
    }
    
    func getPersonalRecord(for exerciseName: String) -> Double {
          var maxWeight = 0.0
          
          for workout in workouts {
              // Проверяем обычные упражнения
              for ex in workout.exercises {
                  if ex.name == exerciseName && !ex.isSuperset {
                      if ex.weight > maxWeight { maxWeight = ex.weight }
                  }
                  // Проверяем внутри суперсетов
                  if ex.isSuperset {
                      for sub in ex.subExercises {
                          if sub.name == exerciseName {
                              if sub.weight > maxWeight { maxWeight = sub.weight }
                          }
                      }
                  }
              }
          }
          return maxWeight
      }
    
    func getStats(for dateInterval: DateInterval) -> PeriodStats {
        var stats = PeriodStats()
        
        // Фильтруем тренировки, которые попадают в наш интервал
        let relevantWorkouts = workouts.filter { dateInterval.contains($0.date) }
        
        stats.workoutCount = relevantWorkouts.count
        
        for workout in relevantWorkouts {
            stats.totalDuration += workout.duration
            
            for exercise in workout.exercises {
                stats.totalReps += exercise.sets * exercise.reps
                stats.totalVolume += exercise.computedVolume
            }
        }
        
        return stats
    }

    // --- ЛОГИКА ТАЙМЕРА (ПРОДВИНУТАЯ + APPLE WATCH) ---
        @Published var restTimeRemaining: Int = 0
        @Published var isRestTimerActive: Bool = false
        @Published var restTimerFinished: Bool = false
        
        // Храним точное время, когда таймер ДОЛЖЕН закончиться
        private var restEndTime: Date?
        private var restTimer: Timer?
        
        // Дефолтное время из настроек
        var defaultRestTime: Int {
            let saved = UserDefaults.standard.integer(forKey: "defaultRestTime")
            return saved > 0 ? saved : 60
        }
        
        // ЗАПУСК
        func startRestTimer(duration: Int? = nil) {
            let durationSeconds = duration ?? defaultRestTime
            
            // 1. Устанавливаем "Целевое время" (Сейчас + секунды)
            self.restEndTime = Date().addingTimeInterval(Double(durationSeconds))
            
            self.restTimeRemaining = durationSeconds
            self.isRestTimerActive = true
            self.restTimerFinished = false
            
            // 2. Ставим системное уведомление на случай, если выйдем из приложения
            NotificationManager.shared.scheduleRestTimerNotification(seconds: Double(durationSeconds))
    
            
            // 4. Запускаем локальный таймер для обновления UI
            startTicker()
        }
        
        // ТИКЕР (Обновляет цифры на экране)
        private func startTicker() {
            restTimer?.invalidate()
            // Тикаем каждые 0.1 сек для плавности
            restTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self = self, let endTime = self.restEndTime else { return }
                
                // Считаем разницу между "Целью" и "Сейчас"
                let timeLeft = Int(endTime.timeIntervalSinceNow)
                
                if timeLeft >= 0 {
                    // Если секунда изменилась, обновляем UI
                    if self.restTimeRemaining != timeLeft + 1 {
                         self.restTimeRemaining = timeLeft + 1
                        
                    }
                } else {
                    // Время вышло
                    self.finishTimer()
                }
            }
        }
        
        // ДОБАВИТЬ ВРЕМЯ (+30)
        func addRestTime(_ seconds: Int) {
            if isRestTimerActive, let currentEnd = restEndTime {
                let newEndDate = currentEnd.addingTimeInterval(Double(seconds))
                self.restEndTime = newEndDate
                
                let newDuration = newEndDate.timeIntervalSinceNow
                NotificationManager.shared.scheduleRestTimerNotification(seconds: newDuration)
                
                self.restTimeRemaining += seconds
           
            }
        }
        
        // УБАВИТЬ ВРЕМЯ (-30)
        func subtractRestTime(_ seconds: Int) {
            if isRestTimerActive, let currentEnd = restEndTime {
                let newEndDate = currentEnd.addingTimeInterval(Double(-seconds))
                
                if newEndDate.timeIntervalSinceNow <= 0 {
                    finishTimer()
                } else {
                    self.restEndTime = newEndDate
                    
                    let newDuration = newEndDate.timeIntervalSinceNow
                    NotificationManager.shared.scheduleRestTimerNotification(seconds: newDuration)
                    
                    self.restTimeRemaining = max(0, restTimeRemaining - seconds)
                    
                
                }
            }
        }
        
        // ЗАВЕРШЕНИЕ (Успех)
        func finishTimer() {
            restTimer?.invalidate()
            restTimerFinished = true
            restEndTime = nil
            
        
            
            // Вибрация и звук
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.success)
            AudioServicesPlaySystemSound(1005)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation {
                    self.stopRestTimer()
                }
            }
        }
        
        // ПОЛНАЯ ОСТАНОВКА (Крестик)
        func stopRestTimer() {
            isRestTimerActive = false
            restTimerFinished = false
            restEndTime = nil
            restTimer?.invalidate()
            restTimer = nil
            
       
            
            NotificationManager.shared.cancelRestTimerNotification()
        }
    
    // Внутри class WorkoutViewModel
    // --- УПРАВЛЕНИЕ ПРЕСЕТАМИ ---
        
        // 1. Сохранение пресетов
        func savePresets() {
            if let encoded = try? JSONEncoder().encode(presets) {
                UserDefaults.standard.set(encoded, forKey: "SavedWorkoutPresets")
            }
        }
        
        // 2. Загрузка пресетов (добавь вызов в init()!)
        func loadPresets() {
            if let data = UserDefaults.standard.data(forKey: "SavedWorkoutPresets") {
                if let decoded = try? JSONDecoder().decode([WorkoutPreset].self, from: data) {
                    self.presets = decoded
                    return
                }
            }
            // Если ничего нет, оставляем дефолтные (которые уже прописаны у тебя в коде)
        }
        
        // 3. Добавление/Обновление пресета
        func updatePreset(_ preset: WorkoutPreset) {
            if let index = presets.firstIndex(where: { $0.id == preset.id }) {
                presets[index] = preset
            } else {
                presets.append(preset)
            }
            savePresets()
        }
        
        // 4. Удаление пресета
        func deletePreset(at offsets: IndexSet) {
            presets.remove(atOffsets: offsets)
            savePresets()
        }
    
        // Список пользовательских упражнений
        @Published var customExercises: [CustomExerciseDefinition] = [] {
            didSet {
                saveCustomExercises()
            }
        }
        
        // Объединенный каталог: Стандартный + Пользовательский
        var combinedCatalog: [String: [String]] {
            var catalog = Exercise.catalog // Берем стандартный
            
            for custom in customExercises {
                // Добавляем пользовательское упражнение в нужную категорию
                var list = catalog[custom.category] ?? []
                if !list.contains(custom.name) {
                    list.append(custom.name)
                }
                catalog[custom.category] = list
            }
            return catalog
        }

        // --- ФУНКЦИИ УПРАВЛЕНИЯ ---
        
        func addCustomExercise(name: String, category: String, muscles: [String]) {
            let newDef = CustomExerciseDefinition(name: name, category: category, targetedMuscles: muscles)
            customExercises.append(newDef)
            
            // Также сохраняем маппинг для Heatmap (для MuscleMapping)
            var currentMap = UserDefaults.standard.dictionary(forKey: "CustomExerciseMappings") as? [String: [String]] ?? [:]
            currentMap[name] = muscles
            UserDefaults.standard.set(currentMap, forKey: "CustomExerciseMappings")
        }
        
        func deleteCustomExercise(name: String, category: String) {
            // Удаляем из списка
            if let index = customExercises.firstIndex(where: { $0.name == name }) {
                customExercises.remove(at: index)
            }
            
            // Удаляем маппинг
            var currentMap = UserDefaults.standard.dictionary(forKey: "CustomExerciseMappings") as? [String: [String]] ?? [:]
            currentMap.removeValue(forKey: name)
            UserDefaults.standard.set(currentMap, forKey: "CustomExerciseMappings")
        }
        
        func loadCustomExercises() {
            if let data = UserDefaults.standard.data(forKey: "SavedCustomExercises") {
                if let decoded = try? JSONDecoder().decode([CustomExerciseDefinition].self, from: data) {
                    self.customExercises = decoded
                }
            }
        }
        
        func saveCustomExercises() {
            if let encoded = try? JSONEncoder().encode(customExercises) {
                UserDefaults.standard.set(encoded, forKey: "SavedCustomExercises")
            }
        }

        // ВАЖНО: Добавь вызов loadCustomExercises() в init() ViewModel'и!
        /*
        init() {
            loadWorkouts()
            loadCustomExercises() // <--- ВОТ СЮДА
            calculateRecovery()
        }
        */
    
    @Published var workouts: [Workout] = [] {
        didSet {
            saveWorkouts()
            calculateRecovery()
        }
    }
    
    // --- ПРЕСЕТЫ (Оставляем как было) ---
    @Published var presets: [WorkoutPreset] = [
        WorkoutPreset(
            name: "Full Body",
            icon: "img_default",
            exercises: [
                Exercise(name: "Squat", muscleGroup: "Legs", sets: 0, reps: 0, weight: 0, effort: 0),
                Exercise(name: "Bench Press", muscleGroup: "Chest", sets: 0, reps: 0, weight: 0, effort: 0),
                Exercise(name: "Barbell Rows", muscleGroup: "Back", sets: 0, reps: 0, weight: 0, effort: 0)
            ]
        ),
        WorkoutPreset(
            name: "Push Day",
            icon: "img_chest",
            exercises: [
                Exercise(name: "Bench Press", muscleGroup: "Chest", sets: 0, reps: 0, weight: 0, effort: 0),
                Exercise(name: "Overhead Press", muscleGroup: "Shoulders", sets: 0, reps: 0, weight: 0, effort: 8),
                Exercise(name: "Triceps Extension", muscleGroup: "Arms", sets: 0, reps: 0, weight: 0, effort: 0)
            ]
        ),
        WorkoutPreset(
            name: "Leg Day",
            icon: "img_legs2",
            exercises: [
                Exercise(name: "Squat", muscleGroup: "Legs", sets: 0, reps: 0, weight: 0, effort: 0),
                Exercise(name: "Leg Press", muscleGroup: "Legs", sets: 0, reps: 0, weight: 0, effort: 0),
                Exercise(name: "Calf Raises", muscleGroup: "Legs", sets: 0, reps: 0, weight: 0, effort: 0)
            ]
        )
    ]
    
    @Published var progressManager = ProgressManager()

    struct MuscleRecoveryStatus {
        var muscleGroup: String
        var recoveryPercentage: Int
    }

    @Published var recoveryStatus: [MuscleRecoveryStatus] = []
    
    init() {
        loadWorkouts()
        calculateRecovery()
        loadPresets()
        loadCustomExercises()
    }
    
    // MARK: - ЛОГИКА ВОССТАНОВЛЕНИЯ (ИСПРАВЛЕНО)
    
    // Словарь перевода: Технический слаг (из MuscleMapping) -> Название на экране (для RecoveryView)
    // Это связывает "deltoids" с "Shoulders" и т.д.
    private let slugToDisplayName: [String: String] = [
        "chest": "Chest",
        
        "upper-back": "Back",
        "lats": "Back",
        "lower-back": "Lower Back",
        "trapezius": "Trapezius",
        
        "deltoids": "Shoulders",
        
        "biceps": "Biceps",
        "triceps": "Triceps",
        "forearm": "Forearms", // Обрати внимание: MuscleMapping возвращает 'forearm', View ждет 'Forearms'
        
        "abs": "Abs",
        "obliques": "Obliques",
        
        "gluteal": "Glutes",
        "hamstring": "Hamstrings",
        "quadriceps": "Legs",
        "adductors": "Legs",
        "abductors": "Legs",
        "legs": "Legs",
        
        "calves": "Calves"
    ]
    func deletePreset(_ preset: WorkoutPreset) {
            if let index = presets.firstIndex(where: { $0.id == preset.id }) {
                presets.remove(at: index)
                savePresets()
            }
        }
    func calculateRecovery() {
        // 1. Считаем усталость по техническим слагам (как раньше)
        var rawFatigueMap: [String: Double] = [:]
        
        let savedHours = UserDefaults.standard.double(forKey: "userRecoveryHours")
        let fullRecoveryHours: Double = savedHours > 0 ? savedHours : 48.0
        
        let sortedWorkouts = workouts.sorted(by: { $0.date < $1.date })
        
        for workout in sortedWorkouts {
            let hoursSince = Date().timeIntervalSince(workout.date) / 3600
            
            if hoursSince >= fullRecoveryHours { continue }
            
            let fatigueFactor = 1.0 - (hoursSince / fullRecoveryHours)
            
            for exercise in workout.exercises {
                
                // --- ДОБАВЛЕННАЯ ПРОВЕРКА ---
                if exercise.isSuperset {
                    // Если супер-сет, считаем усталость для каждого под-упражнения
                    for sub in exercise.subExercises {
                        let affectedMuscles = MuscleMapping.getMuscles(for: sub.name, group: sub.muscleGroup)
                        for muscleSlug in affectedMuscles {
                            let currentFatigue = rawFatigueMap[muscleSlug] ?? 0.0
                            rawFatigueMap[muscleSlug] = max(currentFatigue, fatigueFactor)
                        }
                    }
                } else {
                    // Обычное упражнение (старый код)
                    let affectedMuscles = MuscleMapping.getMuscles(for: exercise.name, group: exercise.muscleGroup)
                    for muscleSlug in affectedMuscles {
                        let currentFatigue = rawFatigueMap[muscleSlug] ?? 0.0
                        rawFatigueMap[muscleSlug] = max(currentFatigue, fatigueFactor)
                    }
                }
                // -----------------------------
            }
        }
        // 2. Переводим технические слаги в красивые имена для UI
        var displayFatigueMap: [String: Double] = [:]
        
        for (slug, fatigue) in rawFatigueMap {
            // Ищем красивое имя, если нет — делаем Capitalized (на всякий случай)
            let displayName = slugToDisplayName[slug] ?? slug.capitalized
            
            // Если несколько мышц маппятся в одну группу (например, Quads -> Legs), берем максимальную усталость
            let currentDisplayFatigue = displayFatigueMap[displayName] ?? 0.0
            displayFatigueMap[displayName] = max(currentDisplayFatigue, fatigue)
        }
        
        // 3. Формируем финальный массив
        self.recoveryStatus = displayFatigueMap.map { (name, fatigue) in
            let recoveryPercent = Int((1.0 - fatigue) * 100)
            // Ограничиваем от 0 до 100
            let clampedPercent = max(0, min(100, recoveryPercent))
            return MuscleRecoveryStatus(muscleGroup: name, recoveryPercentage: clampedPercent)
        }
    }


    
    func addWorkout(_ workout: Workout) {
        workouts.insert(workout, at: 0)
    }

    private func loadWorkouts() {
        let loaded = DataManager.shared.loadWorkouts()
        if loaded.isEmpty {
            self.workouts = Workout.examples
        } else {
            self.workouts = loaded
        }
    }
    
    private func saveWorkouts() {
        let isExampleData = workouts.count == Workout.examples.count && workouts.map { $0.id } == Workout.examples.map { $0.id }
        if !isExampleData {
            DataManager.shared.saveWorkouts(workouts)
        }
    }
    
   
    
}
