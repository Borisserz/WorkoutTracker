//
//  TestDataGenerator.swift
//  WorkoutTracker
//
//  ⚠️ ВРЕМЕННЫЙ ФАЙЛ ДЛЯ ТЕСТИРОВАНИЯ ⚠️
//
//  Этот файл генерирует тестовые данные за 2 года:
//  - 3 тренировки в неделю (Push, Pull, Legs + периодически Full Body и Cardio)
//  - Разные упражнения на разные группы мышц
//  - Прогрессия весов и повторов со временем
//  - Разные типы упражнений (strength, cardio, duration)
//  - Всего ~312 тренировок за 2 года
//
//  КАК ИСПОЛЬЗОВАТЬ:
//  1. Откройте приложение
//  2. Перейдите в Settings (шестеренка в Overview)
//  3. Найдите секцию "🧪 TESTING (REMOVE AFTER TEST)"
//  4. Нажмите "Generate 2 Years Test Data"
//  5. Подождите несколько секунд (генерация происходит в фоне)
//
//  КАК УДАЛИТЬ ПОСЛЕ ТЕСТИРОВАНИЯ:
//  1. Удалите этот файл: TestDataGenerator.swift
//  2. Удалите секцию "🧪 TESTING" из SettingsView.swift
//  3. (Опционально) Очистите тестовые данные через кнопку "Clear All Workouts" в настройках
//

import Foundation

class TestDataGenerator {
    
    // MARK: - Configuration
    
    private static let workoutsPerWeek = 3
    private static let yearsToGenerate = 2
    private static let weeksInYear = 52
    private static let totalWorkouts = workoutsPerWeek * yearsToGenerate * weeksInYear // 312 тренировок
    
    // Группы мышц для чередования
    private static let muscleGroups = ["Chest", "Back", "Legs", "Shoulders", "Arms", "Core", "Cardio"]
    
    // Каталог упражнений по группам мышц
    private static let exerciseCatalog: [String: [String]] = Exercise.catalog
    
    // Иконки для разных типов тренировок
    private static let workoutIcons = [
        "img_chest", "img_chest2", "img_back", "img_back2",
        "img_legs", "img_legs2", "img_arms", "img_default", "figure.run"
    ]
    
    // MARK: - Main Generation Method
    
    /// Генерирует тестовые данные за 2 года и сохраняет их
    /// - Parameter startDate: Дата начала генерации (по умолчанию 2 года назад)
    static func generateAndSaveTestData(startDate: Date? = nil) {
        let start = startDate ?? Calendar.current.date(byAdding: .year, value: -yearsToGenerate, to: Date()) ?? Date()
        
        var allWorkouts: [Workout] = []
        var currentDate = start
        
        // Генерируем тренировки на протяжении 2 лет
        var workoutNumber = 0
        
        while workoutNumber < totalWorkouts {
            // 3 тренировки в неделю (например: понедельник, среда, пятница)
            let dayOffset = (workoutNumber % workoutsPerWeek) * 2 // 0, 2, 4 (пн, ср, пт)
            let weekOffset = workoutNumber / workoutsPerWeek
            let daysToAdd = weekOffset * 7 + dayOffset
            
            if let workoutDate = Calendar.current.date(byAdding: .day, value: daysToAdd, to: start) {
                // Проверяем, что не вышли за пределы сегодня
                if workoutDate > Date() {
                    break
                }
                
                let workout = generateWorkout(for: workoutDate, workoutIndex: workoutNumber)
                allWorkouts.append(workout)
                currentDate = workoutDate
            }
            
            workoutNumber += 1
        }
        
        // Сохраняем данные
        DataManager.shared.saveWorkouts(allWorkouts)
    }
    
    /// Генерирует тестовые данные за 2026 год (будущий год)
    static func generate2026TestData() {
        // Создаем дату начала 2026 года
        var components = DateComponents()
        components.year = 2026
        components.month = 1
        components.day = 1
        guard let start2026 = Calendar.current.date(from: components) else {
            return
        }
        
        // Генерируем тренировки на весь 2026 год
        var allWorkouts: [Workout] = []
        let workoutsFor2026 = workoutsPerWeek * weeksInYear // 156 тренировок за год
        
        var workoutNumber = 0
        var baseWorkoutIndex = totalWorkouts // Продолжаем нумерацию с конца прошлых данных
        
        while workoutNumber < workoutsFor2026 {
            // 3 тренировки в неделю (например: понедельник, среда, пятница)
            let dayOffset = (workoutNumber % workoutsPerWeek) * 2 // 0, 2, 4 (пн, ср, пт)
            let weekOffset = workoutNumber / workoutsPerWeek
            let daysToAdd = weekOffset * 7 + dayOffset
            
            if let workoutDate = Calendar.current.date(byAdding: .day, value: daysToAdd, to: start2026) {
                // Проверяем, что не вышли за пределы 2026 года
                let calendar = Calendar.current
                if calendar.component(.year, from: workoutDate) > 2026 {
                    break
                }
                
                let workout = generateWorkout(for: workoutDate, workoutIndex: baseWorkoutIndex + workoutNumber)
                allWorkouts.append(workout)
            }
            
            workoutNumber += 1
        }
        
        // Используем семафор для синхронизации асинхронной загрузки
        let semaphore = DispatchSemaphore(value: 0)
        var existingWorkouts: [Workout] = []
        
        // Загружаем существующие тренировки
        DataManager.shared.loadWorkouts { result in
            switch result {
            case .success(let workouts):
                existingWorkouts = workouts
            case .failure:
                existingWorkouts = []
            }
            semaphore.signal()
        }
        
        // Ждем завершения загрузки
        semaphore.wait()
        
        // Объединяем существующие и новые тренировки
        var combinedWorkouts = existingWorkouts
        combinedWorkouts.append(contentsOf: allWorkouts)
        // Сортируем по дате
        combinedWorkouts.sort { $0.date < $1.date }
        
        // Сохраняем объединенные данные
        DataManager.shared.saveWorkouts(combinedWorkouts)
    }
    
    /// Генерирует тестовые данные веса для графика
    /// Генерирует данные за последние 2 года с реалистичными колебаниями
    static func generateWeightTestData() {
        let weightManager = WeightTrackingManager.shared
        
        // Начальный вес (в кг)
        let startWeight = 75.0
        
        // Генерируем данные за последние 2 года (730 дней)
        let daysToGenerate = 730
        var currentDate = Calendar.current.date(byAdding: .day, value: -daysToGenerate, to: Date()) ?? Date()
        
        var weightEntries: [WeightEntry] = []
        var currentWeight = startWeight
        
        // Генерируем записи примерно раз в 3-7 дней (не каждый день)
        var dayOffset = 0
        
        while dayOffset < daysToGenerate {
            if let entryDate = Calendar.current.date(byAdding: .day, value: dayOffset, to: currentDate) {
                // Добавляем реалистичные колебания веса
                // Общий тренд: медленное снижение веса (похудение)
                let progressFactor = Double(dayOffset) / Double(daysToGenerate) // 0.0 до 1.0
                let targetWeight = startWeight - 5.0 * progressFactor // Потеря 5 кг за 2 года
                
                // Ежедневные колебания: ±0.3 кг
                let dailyVariation = Double.random(in: -0.3...0.3)
                
                // Недельные колебания: ±0.5 кг
                let weeklyVariation = sin(Double(dayOffset) / 7.0 * 2 * .pi) * 0.5
                
                // Случайные скачки: иногда ±1 кг
                let randomSpike = Bool.random() && Int.random(in: 1...20) == 1 ? Double.random(in: -1.0...1.0) : 0.0
                
                currentWeight = targetWeight + dailyVariation + weeklyVariation + randomSpike
                
                // Ограничиваем разумными значениями
                currentWeight = max(65.0, min(85.0, currentWeight))
                
                weightEntries.append(WeightEntry(date: entryDate, weight: currentWeight))
            }
            
            // Следующая запись через 3-7 дней
            dayOffset += Int.random(in: 3...7)
        }
        
        // Добавляем записи в менеджер веса
        for entry in weightEntries {
            weightManager.addWeightEntry(weight: entry.weight, date: entry.date)
        }
    }
    
    // MARK: - Workout Generation
    
    /// Генерирует одну тренировку для указанной даты
    private static func generateWorkout(for date: Date, workoutIndex: Int) -> Workout {
        // Определяем тип тренировки (Push, Pull, Legs, Full Body, Cardio)
        let workoutType = determineWorkoutType(index: workoutIndex)
        
        // Генерируем упражнения в зависимости от типа тренировки
        let exercises = generateExercises(for: workoutType, workoutIndex: workoutIndex, date: date)
        
        // Время тренировки: 45-90 минут
        let duration = Int.random(in: 45...90) * 60 // в секундах
        let endTime = date.addingTimeInterval(TimeInterval(duration))
        
        // Выбираем иконку
        let icon = workoutIcons[workoutIndex % workoutIcons.count]
        
        return Workout(
            title: workoutType.title,
            date: date,
            endTime: endTime,
            icon: icon,
            exercises: exercises
        )
    }
    
    // MARK: - Workout Type Logic
    
    private enum WorkoutType {
        case push      // Грудь, Плечи, Трицепс
        case pull      // Спина, Бицепс
        case legs      // Ноги
        case fullBody  // Полное тело
        case cardio    // Кардио
        
        var title: String {
            switch self {
            case .push: return "Push Day"
            case .pull: return "Pull Day"
            case .legs: return "Legs Day"
            case .fullBody: return "Full Body"
            case .cardio: return "Cardio Session"
            }
        }
    }
    
    private static func determineWorkoutType(index: Int) -> WorkoutType {
        // Каждую 10-ю тренировку делаем Full Body или Cardio
        if index % 10 == 0 {
            return index % 20 == 0 ? .cardio : .fullBody
        }
        
        // Чередуем типы тренировок: Push, Pull, Legs
        let cycle = index % 3
        switch cycle {
        case 0: return .push
        case 1: return .pull
        case 2: return .legs
        default: return .fullBody
        }
    }
    
    // MARK: - Exercise Generation
    
    /// Генерирует список упражнений для тренировки
    private static func generateExercises(for type: WorkoutType, workoutIndex: Int, date: Date) -> [Exercise] {
        var exercises: [Exercise] = []
        
        switch type {
        case .push:
            exercises.append(contentsOf: generatePushExercises(workoutIndex: workoutIndex, date: date))
            
        case .pull:
            exercises.append(contentsOf: generatePullExercises(workoutIndex: workoutIndex, date: date))
            
        case .legs:
            exercises.append(contentsOf: generateLegsExercises(workoutIndex: workoutIndex, date: date))
            
        case .fullBody:
            exercises.append(contentsOf: generateFullBodyExercises(workoutIndex: workoutIndex, date: date))
            
        case .cardio:
            exercises.append(contentsOf: generateCardioExercises(workoutIndex: workoutIndex, date: date))
        }
        
        return exercises
    }
    
    // MARK: - Specific Exercise Generators
    
    private static func generatePushExercises(workoutIndex: Int, date: Date) -> [Exercise] {
        let chestExercises = exerciseCatalog["Chest"] ?? []
        let shoulderExercises = exerciseCatalog["Shoulders"] ?? []
        let armExercises = exerciseCatalog["Arms"] ?? []
        
        var exercises: [Exercise] = []
        
        // 2-3 упражнения на грудь
        let chestCount = Int.random(in: 2...3)
        for i in 0..<chestCount {
            if let exerciseName = chestExercises.randomElement() {
                exercises.append(createStrengthExercise(
                    name: exerciseName,
                    muscleGroup: "Chest",
                    workoutIndex: workoutIndex,
                    baseWeight: 60.0 + Double(workoutIndex) * 0.3,
                    baseReps: 8 + (workoutIndex % 5)
                ))
            }
        }
        
        // 2 упражнения на плечи
        for i in 0..<2 {
            if let exerciseName = shoulderExercises.randomElement() {
                exercises.append(createStrengthExercise(
                    name: exerciseName,
                    muscleGroup: "Shoulders",
                    workoutIndex: workoutIndex,
                    baseWeight: 25.0 + Double(workoutIndex) * 0.2,
                    baseReps: 10 + (workoutIndex % 5)
                ))
            }
        }
        
        // 2 упражнения на трицепс (фильтруем упражнения на трицепс)
        let tricepExercises = armExercises.filter { $0.contains("Triceps") || $0.contains("triceps") || $0.contains("Extension") || $0.contains("Dips") || $0.contains("Pushdown") }
        for i in 0..<min(2, tricepExercises.count) {
            if let exerciseName = tricepExercises.randomElement() {
                exercises.append(createStrengthExercise(
                    name: exerciseName,
                    muscleGroup: "Arms",
                    workoutIndex: workoutIndex,
                    baseWeight: 20.0 + Double(workoutIndex) * 0.15,
                    baseReps: 12 + (workoutIndex % 5)
                ))
            }
        }
        
        return exercises
    }
    
    private static func generatePullExercises(workoutIndex: Int, date: Date) -> [Exercise] {
        let backExercises = exerciseCatalog["Back"] ?? []
        let armExercises = exerciseCatalog["Arms"] ?? []
        
        var exercises: [Exercise] = []
        
        // 3-4 упражнения на спину
        let backCount = Int.random(in: 3...4)
        for i in 0..<backCount {
            if let exerciseName = backExercises.randomElement() {
                exercises.append(createStrengthExercise(
                    name: exerciseName,
                    muscleGroup: "Back",
                    workoutIndex: workoutIndex,
                    baseWeight: 70.0 + Double(workoutIndex) * 0.4,
                    baseReps: 8 + (workoutIndex % 5)
                ))
            }
        }
        
        // 2 упражнения на бицепс
        let bicepExercises = armExercises.filter { $0.contains("Curl") || $0.contains("Bicep") || $0.contains("Biceps") }
        for i in 0..<min(2, bicepExercises.count) {
            if let exerciseName = bicepExercises.randomElement() {
                exercises.append(createStrengthExercise(
                    name: exerciseName,
                    muscleGroup: "Arms",
                    workoutIndex: workoutIndex,
                    baseWeight: 15.0 + Double(workoutIndex) * 0.1,
                    baseReps: 10 + (workoutIndex % 5)
                ))
            }
        }
        
        return exercises
    }
    
    private static func generateLegsExercises(workoutIndex: Int, date: Date) -> [Exercise] {
        let legExercises = exerciseCatalog["Legs"] ?? []
        
        var exercises: [Exercise] = []
        
        // 4-6 упражнений на ноги
        let legCount = Int.random(in: 4...6)
        for i in 0..<legCount {
            if let exerciseName = legExercises.randomElement() {
                exercises.append(createStrengthExercise(
                    name: exerciseName,
                    muscleGroup: "Legs",
                    workoutIndex: workoutIndex,
                    baseWeight: 80.0 + Double(workoutIndex) * 0.5,
                    baseReps: 10 + (workoutIndex % 5)
                ))
            }
        }
        
        return exercises
    }
    
    private static func generateFullBodyExercises(workoutIndex: Int, date: Date) -> [Exercise] {
        var exercises: [Exercise] = []
        
        // По одному упражнению на каждую группу мышц
        let groups = ["Chest", "Back", "Legs", "Shoulders", "Arms", "Core"]
        for group in groups {
            if let groupExercises = exerciseCatalog[group], !groupExercises.isEmpty {
                if let exerciseName = groupExercises.randomElement() {
                    let exerciseType: ExerciseType = group == "Core" ? (Bool.random() ? .duration : .strength) : .strength
                    
                    if exerciseType == .duration {
                        exercises.append(createDurationExercise(
                            name: exerciseName,
                            muscleGroup: group,
                            workoutIndex: workoutIndex
                        ))
                    } else {
                        exercises.append(createStrengthExercise(
                            name: exerciseName,
                            muscleGroup: group,
                            workoutIndex: workoutIndex,
                            baseWeight: 50.0 + Double(workoutIndex) * 0.25,
                            baseReps: 10 + (workoutIndex % 5)
                        ))
                    }
                }
            }
        }
        
        return exercises
    }
    
    private static func generateCardioExercises(workoutIndex: Int, date: Date) -> [Exercise] {
        let cardioExercises = exerciseCatalog["Cardio"] ?? []
        
        var exercises: [Exercise] = []
        
        // 2-3 кардио упражнения
        let cardioCount = Int.random(in: 2...3)
        for i in 0..<cardioCount {
            if let exerciseName = cardioExercises.randomElement() {
                // Чередуем типы кардио
                if Bool.random() {
                    exercises.append(createCardioExercise(
                        name: exerciseName,
                        workoutIndex: workoutIndex
                    ))
                } else {
                    exercises.append(createDurationExercise(
                        name: exerciseName,
                        muscleGroup: "Cardio",
                        workoutIndex: workoutIndex
                    ))
                }
            }
        }
        
        return exercises
    }
    
    // MARK: - Exercise Creation Helpers
    
    /// Создает силовое упражнение с прогрессией
    private static func createStrengthExercise(
        name: String,
        muscleGroup: String,
        workoutIndex: Int,
        baseWeight: Double,
        baseReps: Int
    ) -> Exercise {
        // Прогрессия: вес постепенно увеличивается, повторы могут варьироваться
        let progressFactor = 1.0 + Double(workoutIndex) / 500.0 // Медленная прогрессия
        let weight = baseWeight * progressFactor + Double.random(in: -5...5)
        let reps = baseReps + Int.random(in: -2...2)
        let sets = Int.random(in: 3...5)
        
        // Создаем сеты с небольшими вариациями
        var setsList: [WorkoutSet] = []
        for i in 1...sets {
            // Первый сет может быть разминкой с меньшим весом
            let isWarmup = i == 1 && Bool.random() && sets > 3
            let setWeight = isWarmup ? weight * 0.7 : weight + Double.random(in: -2...2)
            let setReps = isWarmup ? reps + 2 : reps + Int.random(in: -1...1)
            
            // Последний сет может быть до отказа
            let isFailure = i == sets && Bool.random() && !isWarmup
            let setType: SetType = isWarmup ? .warmup : (isFailure ? .failure : .normal)
            
            setsList.append(WorkoutSet(
                index: i,
                weight: max(0, setWeight),
                reps: max(1, setReps),
                isCompleted: true,
                type: setType
            ))
        }
        
        // Effort: 6-10 с небольшой вариацией
        let effort = 6 + (workoutIndex % 5)
        
        return Exercise(
            name: name,
            muscleGroup: muscleGroup,
            type: .strength,
            sets: sets,
            reps: reps,
            weight: weight,
            effort: effort,
            setsList: setsList,
            isCompleted: true
        )
    }
    
    /// Создает кардио упражнение
    private static func createCardioExercise(name: String, workoutIndex: Int) -> Exercise {
        // Дистанция: 3-10 км с прогрессией
        let baseDistance = 5.0 + Double(workoutIndex) / 100.0
        let distance = baseDistance + Double.random(in: -2...2)
        let timeMinutes = Int(20 + workoutIndex / 20 + Int.random(in: -5...10))
        let sets = Int.random(in: 1...3)
        
        var setsList: [WorkoutSet] = []
        for i in 1...sets {
            setsList.append(WorkoutSet(
                index: i,
                distance: max(1.0, distance / Double(sets) + Double.random(in: -0.5...0.5)),
                time: timeMinutes * 60 / sets + Int.random(in: -60...60),
                isCompleted: true,
                type: .normal
            ))
        }
        
        let effort = 5 + (workoutIndex % 6)
        
        return Exercise(
            name: name,
            muscleGroup: "Cardio",
            type: .cardio,
            sets: sets,
            reps: 0,
            weight: 0,
            distance: distance,
            timeSeconds: timeMinutes * 60,
            effort: effort,
            setsList: setsList,
            isCompleted: true
        )
    }
    
    /// Создает упражнение на время (duration)
    private static func createDurationExercise(name: String, muscleGroup: String, workoutIndex: Int) -> Exercise {
        // Время: 30-120 секунд с прогрессией
        let baseTime = 60 + workoutIndex / 10
        let time = baseTime + Int.random(in: -10...30)
        let sets = Int.random(in: 2...4)
        
        var setsList: [WorkoutSet] = []
        for i in 1...sets {
            setsList.append(WorkoutSet(
                index: i,
                time: max(20, time + Int.random(in: -5...10)),
                isCompleted: true,
                type: .normal
            ))
        }
        
        let effort = 5 + (workoutIndex % 5)
        
        return Exercise(
            name: name,
            muscleGroup: muscleGroup,
            type: .duration,
            sets: sets,
            reps: 0,
            weight: 0,
            timeSeconds: time,
            effort: effort,
            setsList: setsList,
            isCompleted: true
        )
    }
}

