internal import SwiftUI
import SwiftData
import Observation

// Изменить WorkoutDetailEvent:
enum WorkoutDetailEvent: Equatable {
    case showPR(PRLevel)
    case showShareSheet(Any) 
    case showEmptyAlert
    case showAchievement(Achievement)
    case showSwapExercise(Exercise)
    case workoutSuccessfullyFinished
    
    static func == (lhs: WorkoutDetailEvent, rhs: WorkoutDetailEvent) -> Bool {
        String(describing: lhs) == String(describing: rhs)
    }
}


@Observable
@MainActor
final class WorkoutDetailViewModel {
    
    // MARK: - Business Data
    var aiCoach: InWorkoutAICoachViewModel
    var workoutAnalytics = WorkoutAnalyticsDataDTO()
    
    var personalRecordsCache: [String: Double] = [:]
    var lastPerformancesCache: [String: Exercise] = [:]
    var newlyAddedSetId: UUID? = nil
    
    // MARK: - UI State & Events
    var activeEvent: WorkoutDetailEvent? = nil
    var isShowingSnackbar: Bool = false
    @ObservationIgnored private var finishWorkoutTask: Task<Void, Never>? = nil
    
    // MARK: - Services
    private let workoutService: WorkoutService
    private let analyticsService: AnalyticsService
    private let exerciseCatalogService: ExerciseCatalogService
    private let appState: AppStateManager
    init(workoutService: WorkoutService,
           analyticsService: AnalyticsService,
           exerciseCatalogService: ExerciseCatalogService,
           appState: AppStateManager) { // ✅ ИЗМЕНЕНО
          
          self.workoutService = workoutService
          self.analyticsService = analyticsService
          self.exerciseCatalogService = exerciseCatalogService
          self.appState = appState // ✅ ДОБАВЛЕНО
          
          self.aiCoach = InWorkoutAICoachViewModel(
              workoutService: workoutService,
              aiLogicService: workoutService.aiLogicService,
              analyticsService: analyticsService,
              exerciseCatalogService: exerciseCatalogService
          )
      }
    
    // MARK: - Data Loading
    
    func loadCaches(from dashboard: DashboardViewModel) {
        self.personalRecordsCache = dashboard.personalRecordsCache
        self.lastPerformancesCache = dashboard.lastPerformancesCache
    }
    
    func updateWorkoutAnalytics(for workout: Workout) {
           var counts = [String: Int]()
           var volume = 0.0
           var chartExercises: [ExerciseChartDTO] = []
           
           // Читаем данные напрямую из оперативной памяти (мгновенно и безопасно для Main Thread)
           for exercise in workout.exercises {
               let targets = exercise.isSuperset ? exercise.subExercises : [exercise]
               for sub in targets {
                   // Если есть хотя бы один выполненный сет, засчитываем мышцы
                   if sub.type != .cardio && sub.setsList.contains(where: { $0.isCompleted }) {
                       let muscles = MuscleMapping.getMuscles(for: sub.name, group: sub.muscleGroup)
                       for muscleSlug in muscles { counts[muscleSlug, default: 0] += 1 }
                   }
               }
               // exerciseVolume сам разрулит кэш или пересчет
               volume += exercise.exerciseVolume
           }
           
           // Собираем упражнения для графика
           let flattened = workout.exercises.flatMap { $0.isSuperset ? $0.subExercises : [$0] }
           let forChart = flattened.filter { ex in
               ex.type == .strength && ex.setsList.contains(where: { $0.isCompleted && ($0.weight ?? 0) > 0 })
           }
           
           for ex in forChart {
               let maxW = ex.setsList.filter { $0.isCompleted && $0.type != .warmup }.compactMap { $0.weight }.max() ?? 0
               if maxW > 0 {
                   chartExercises.append(ExerciseChartDTO(id: UUID(), name: ex.name, maxWeight: maxW))
               }
           }
           
           // Мгновенное обновление UI и данных для генерации видео
           self.workoutAnalytics = WorkoutAnalyticsDataDTO(intensity: counts, volume: volume, chartExercises: chartExercises)
       }
    
    // MARK: - Set & Exercise Management
    
    // ✅ FIX: Выполняем добавление напрямую на MainActor
    func addSet(to exercise: Exercise, context: ModelContext) {
        let lastSet = exercise.sortedSets.last
        let newIndex = (lastSet?.index ?? 0) + 1
        
        let newSet = WorkoutSet(
            index: newIndex,
            weight: lastSet?.weight,
            reps: lastSet?.reps,
            distance: lastSet?.distance,
            time: lastSet?.time,
            isCompleted: false,
            type: .normal
        )
        
        context.insert(newSet)
        exercise.setsList.append(newSet)
        self.newlyAddedSetId = newSet.id
        try? context.save()
    }
    
    // ✅ FIX: Выполняем удаление напрямую на MainActor
    func removeSet(_ set: WorkoutSet, from exercise: Exercise, context: ModelContext) {
        exercise.setsList.removeAll(where: { $0.id == set.id })
        context.delete(set)
        
        // Пересчет индексов
        for (i, s) in exercise.sortedSets.enumerated() {
            s.index = i + 1
        }
        try? context.save()
    }
    
    func removeExercise(_ exercise: Exercise, from workout: Workout) {
        Task { await workoutService.removeExercise(exercise, from: workout) }
    }
    
    func addExercise(_ newExercise: Exercise, workout: Workout, scrollToExerciseId: @escaping (UUID) -> Void) {
        withAnimation { workout.exercises.insert(newExercise, at: 0) }
        Task {
            try? await Task.sleep(for: .seconds(0.3))
            guard !Task.isCancelled else { return }
            scrollToExerciseId(newExercise.id)
        }
    }

    func performSwap(old: Exercise, new: Exercise, workout: Workout) {
            Task {
                await workoutService.swapExercise(old: old, new: new, workout: workout)
            }
        }
    
    func deleteEmptyWorkout(workout: Workout) async {
        await workoutService.deleteWorkout(workout)
    }
    
    // MARK: - Workout Flow Logic
    
    func startTimerIfNeeded(shouldStartTimer: Bool, suggestedDuration: Int?) {
        guard shouldStartTimer else { return }
        NotificationCenter.default.post(
            name: NSNotification.Name("ForceStartRestTimer"),
            object: nil,
            userInfo: ["duration": suggestedDuration as Any]
        )
    }
    
    func handleSetCompleted(set: WorkoutSet, isLast: Bool, exerciseName: String, workout: Workout, weightUnit: String) {
        updateWorkoutAnalytics(for: workout)
        
        // ✅ НОВАЯ ЛОГИКА: ПРОВЕРКА ЦЕЛИ ПРЯМО ПОСЛЕ СЕТА (REAL-TIME)
        if set.isCompleted, let context = workout.modelContext {
                  let goalDesc = FetchDescriptor<UserGoal>(predicate: #Predicate { $0.isCompleted == false })
                  let activeGoals = (try? context.fetch(goalDesc)) ?? []
                  var achieved = false
                  
                  for goal in activeGoals {
                      if goal.type == .strength, goal.exerciseName == exerciseName {
                          let w = set.weight ?? 0.0
                          let r = set.reps ?? 0
                          
                          if w >= goal.targetValue && r >= goal.targetReps {
                              goal.isCompleted = true
                              achieved = true
                          }
                      }
                  }
                  
                  if achieved {
                      try? context.save()
                      let goalAchieved = Achievement(
                          title: "Goal Crushed! 🎯",
                          description: "You've successfully hit your target. Time to set a new one!",
                          icon: "target",
                          tier: .diamond,
                          progress: "100%"
                      )
                      self.activeEvent = .showAchievement(goalAchieved)
                  }
              }

        
        Task {
            await aiCoach.triggerProactiveFeedback(
                for: set,
                isLastSet: isLast,
                isPR: false,
                prLevel: nil,
                in: exerciseName,
                currentWorkout: workout,
                weightUnit: weightUnit
            )
        }
    }

    func handleExerciseFinished(exerciseId: UUID, workout: Workout, weightUnit: String, onExpandNext: @escaping (UUID) -> Void) {
            guard let exercise = workout.exercises.first(where: { $0.id == exerciseId }) else { return }

            if exercise.isSuperset {
                finishSuperset(exercise, workout: workout, weightUnit: weightUnit)
            } else {
                finishExercise(exercise, workout: workout, weightUnit: weightUnit)
            }

            // ✅ FIX: Находим следующее невыполненное упражнение логически, а не по индексам массива
            let remainingUncompleted = workout.exercises.filter { !$0.isCompleted && $0.id != exerciseId }
            if let nextExercise = remainingUncompleted.first {
                onExpandNext(nextExercise.id)
            }
        }
    private func finishExercise(_ exercise: Exercise, workout: Workout, weightUnit: String) {
        guard !exercise.isCompleted && workout.isActive else { return }
        
        let uncompletedSets = exercise.setsList.filter { !$0.isCompleted }
        if !uncompletedSets.isEmpty {
            Task { await workoutService.deleteSets(uncompletedSets, from: exercise) }
        }
        
        exercise.isCompleted = true
        
        if let prLevel = calculatePRLevel(for: exercise, prCache: self.personalRecordsCache) {
            handlePRSet(level: prLevel, exerciseName: exercise.name, workout: workout, weightUnit: weightUnit)
        }
    }
        
    private func finishSuperset(_ superset: Exercise, workout: Workout, weightUnit: String) {
        guard !superset.isCompleted && workout.isActive else { return }
        
        for sub in superset.subExercises {
            let uncompleted = sub.setsList.filter { !$0.isCompleted }
            if !uncompleted.isEmpty {
                Task { await workoutService.deleteSets(uncompleted, from: sub) }
            }
            sub.isCompleted = true
        }
        
        superset.isCompleted = true
   
        var highestPR: PRLevel? = nil
        for sub in superset.subExercises {
            if let pr = calculatePRLevel(for: sub, prCache: self.personalRecordsCache) {
                if highestPR == nil || pr.rank > highestPR!.rank { highestPR = pr }
            }
        }
        
        if let pr = highestPR {
            handlePRSet(level: pr, exerciseName: superset.name, workout: workout, weightUnit: weightUnit)
        }
    }
    
    private func handlePRSet(level: PRLevel, exerciseName: String, workout: Workout, weightUnit: String) {
        self.activeEvent = .showPR(level)
        Task {
            await self.aiCoach.triggerProactiveFeedback(for: nil, isLastSet: false, isPR: true, prLevel: level.title, in: exerciseName, currentWorkout: workout, weightUnit: weightUnit)
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func generateAndShare(workout: Workout) {
        let renderer = ImageRenderer(content: WorkoutShareCard(workout: workout))
        renderer.scale = 3.0
        if let uiImage = renderer.uiImage {
            self.activeEvent = .showShareSheet(uiImage)
        }
    }
    
    // MARK: - Finish Workout (Snackbar Flow)
    
    func requestFinishWorkout(workout: Workout, progressManager: ProgressManager) {
        let hasAnyCompletedSet = workout.exercises.contains { exercise in
            let targets = exercise.isSuperset ? exercise.subExercises : [exercise]
            return targets.contains { sub in sub.setsList.contains { $0.isCompleted } }
        }
        
        guard hasAnyCompletedSet else {
            self.activeEvent = .showEmptyAlert
            return
        }
        
        workout.endTime = Date()
        
        withAnimation {
            self.isShowingSnackbar = true
        }
        
        finishWorkoutTask?.cancel()
        finishWorkoutTask = Task {
            try? await Task.sleep(for: .seconds(3.5))
            guard !Task.isCancelled else { return }
            await commitFinishWorkout(workout: workout, progressManager: progressManager)
        }
    }
    
    func undoFinishWorkout(workout: Workout) {
        finishWorkoutTask?.cancel()
        finishWorkoutTask = nil
        
        withAnimation {
            self.isShowingSnackbar = false
        }
        workout.endTime = nil
    }
    
    private func commitFinishWorkout(workout: Workout, progressManager: ProgressManager) async {
            withAnimation {
                self.isShowingSnackbar = false
            }
            
            // Остановка Live Activity
            workoutService.stopLiveActivity()
            
            progressManager.addXP(for: workout)
            
            // Принудительно сбрасываем UI-данные в SQLite перед фоновой обработкой
            try? workout.modelContext?.save()
            
            let workoutID = workout.persistentModelID
            let wTitle = workout.title
            let wStart = workout.date
            let wEnd = workout.endTime ?? Date()
            let wDuration = workout.durationSeconds > 0 ? workout.durationSeconds : Int(wEnd.timeIntervalSince(wStart))
            let userWeight = UserDefaults.standard.double(forKey: Constants.UserDefaultsKeys.userBodyWeight.rawValue)
            
            print("🚀 ViewModel: Начинаем завершение тренировки. Длительность: \(wDuration) сек.")
            
            // 1. ЗАПУСК HEALTHKIT
            Task {
                do {
                    try await HealthKitManager.shared.saveWorkout(
                        title: wTitle,
                        startDate: wStart,
                        endDate: wEnd,
                        durationSeconds: wDuration,
                        userWeightKg: userWeight
                    )
                } catch {
                    print("❌ ViewModel: Ошибка вызова HealthKit - \(error)")
                }
            }
            
            // 2. ОБНОВЛЕНИЕ ЛОКАЛЬНОЙ БАЗЫ И АЧИВОК
            do {
                let result = try await analyticsService.finishWorkoutAndCalculateAchievements(workoutID: workoutID)
                print("✅ ViewModel: Локальная статистика обновлена успешно")
                
                var goalAchievementToShow: Achievement? = nil
                       
                       if let context = workout.modelContext {
                           let goalDesc = FetchDescriptor<UserGoal>(predicate: #Predicate { $0.isCompleted == false })
                           let activeGoals = (try? context.fetch(goalDesc)) ?? []
                           
                           for goal in activeGoals {
                               var goalAchieved = false
                               
                               if goal.type == .strength, let exName = goal.exerciseName {
                                   let maxLifted = workout.exercises
                                       .filter { $0.name == exName && $0.type == .strength }
                                       .flatMap { $0.setsList }
                                       .filter { $0.isCompleted && $0.type != .warmup && ($0.reps ?? 0) >= goal.targetReps }
                                       .compactMap { $0.weight }
                                       .max() ?? 0.0
                                       
                                   if maxLifted >= goal.targetValue { goalAchieved = true }
                                   
                               } else if goal.type == .consistency {
                                   let desc = FetchDescriptor<Workout>(predicate: #Predicate { $0.endTime != nil }, sortBy: [SortDescriptor(\.date, order: .reverse)])
                                   let allWorkouts = (try? context.fetch(desc)) ?? []
                                   let workoutDates = allWorkouts.map { $0.date }
                                   
                                   let maxRestDays = UserDefaults.standard.integer(forKey: Constants.UserDefaultsKeys.streakRestDays.rawValue) > 0 ? UserDefaults.standard.integer(forKey: Constants.UserDefaultsKeys.streakRestDays.rawValue) : 2
                                   let currentStreak = StreakCalculator.calculate(from: workoutDates, maxRestDays: maxRestDays)
                                   
                                   if Double(currentStreak) >= goal.targetValue { goalAchieved = true }
                               }
                               
                               if goalAchieved {
                                   goal.isCompleted = true
                                   goalAchievementToShow = Achievement(
                                       title: "Goal Crushed! 🎯",
                                       description: "You've successfully hit your target. Time to set a new one!",
                                       icon: "target",
                                       tier: .diamond,
                                       progress: "100%"
                                   )
                               }
                           }
                           try? context.save()
                       }
                
                
                // Отправляем уведомление ТОЛЬКО ПОСЛЕ ТОГО, как статистика полностью рассчитана и сохранена
                NotificationCenter.default.post(
                    name: .workoutCompletedEvent,
                    object: workout.persistentModelID,
                    userInfo: ["modelContainer": analyticsService.modelContainer]
                )
                
                self.updateWorkoutAnalytics(for: workout)
                self.activeEvent = .workoutSuccessfullyFinished
                
                // Вывод Попапа: Приоритет отдаем Цели, затем стандартным Ачивкам
                if let goalAchieved = goalAchievementToShow {
                    try? await Task.sleep(for: .seconds(0.5))
                    self.activeEvent = .showAchievement(goalAchieved)
                } else if let firstUnlock = result.newUnlocks.first {
                    try? await Task.sleep(for: .seconds(0.5))
                    self.activeEvent = .showAchievement(firstUnlock)
                }
                
            } catch {
                print("❌ ViewModel: Ошибка обновления локальной статистики - \(error)")
                self.updateWorkoutAnalytics(for: workout)
                self.activeEvent = .workoutSuccessfullyFinished
            }
        }
    // MARK: - Math Logic
    
    private func calculatePRLevel(for exercise: Exercise, prCache: [String: Double]) -> PRLevel? {
        guard exercise.type == .strength else { return nil }
        let maxWeight = exercise.setsList.filter { $0.isCompleted }.compactMap { $0.weight }.max() ?? 0.0
        let oldRecord = prCache[exercise.name] ?? 0.0
        
        if maxWeight > oldRecord && oldRecord > 0 {
            let increase = (maxWeight - oldRecord) / oldRecord
            if increase >= 0.20 { return .diamond }
            if increase >= 0.10 { return .gold }
            if increase >= 0.05 { return .silver }
            return .bronze
        }
        return nil
    }
}
extension WorkoutDetailViewModel {
    
    // MARK: - AI Roast Generation
    
    func generateRoast(for workout: Workout) {
        guard let topExercise = workout.exercises.max(by: { $0.exerciseVolume < $1.exerciseVolume }) else {
            appState.showError(title: "Error", message: "Complete an exercise first to get roasted.")
            return
        }
        
        let reps = topExercise.setsList.filter { $0.isCompleted }.compactMap { $0.reps }.reduce(0, +)
        let exName = topExercise.name
        
        self.isShowingSnackbar = true // Используем как лоадер (блокируем UI)
        
        Task {
            do {
                let lang = Locale.current.language.languageCode?.identifier == "ru" ? "Russian" : "English"
                let roast = try await workoutService.aiLogicService.generateFormRoast(exercise: exName, reps: reps, language: lang)
                
                await MainActor.run {
                    self.isShowingSnackbar = false
                    
                    // Генерируем UIImage на MainActor
                    let renderer = ImageRenderer(content: AIRoastShareCard(roastText: roast, exerciseName: exName))
                    renderer.scale = 3.0
                    if let uiImage = renderer.uiImage {
                        self.activeEvent = .showShareSheet(uiImage)
                    }
                }
            } catch {
                await MainActor.run {
                    self.isShowingSnackbar = false
                    appState.showError(title: "Roast Failed", message: error.localizedDescription)
                }
            }
        }
    }
    
    // MARK: - Dynamic Heatmap Video Generation
    
    func generateHeatmapVideo(workout: Workout, gender: String) {
        self.isShowingSnackbar = true // Индикатор загрузки
        
        // ✅ ГЛАВНЫЙ ФИКС ВИДЕО: Принудительно собираем аналитику в память перед проверкой
        self.updateWorkoutAnalytics(for: workout)
        
        let intensities = self.workoutAnalytics.intensity
        guard !intensities.isEmpty else {
            self.isShowingSnackbar = false
            appState.showError(title: "Error", message: "Complete exercises to generate heatmap.")
            return
        }
        
        Task { @MainActor in
            var frames: [CGImage] = []
            let totalFrames = 30 // 1 секунда анимации (от 0 до 100%)
            
            for frame in 0...totalFrames {
                let progress = Double(frame) / Double(totalFrames)
                
                var currentIntensities: [String: Int] = [:]
                for (muscle, targetValue) in intensities {
                    currentIntensities[muscle] = Int(Double(targetValue) * progress)
                }
                
                let view = BodyHeatmapView(
                    muscleIntensities: currentIntensities,
                    isRecoveryMode: false,
                    isCompactMode: false,
                    defaultToBack: false,
                    userGender: gender
                )
                    .frame(width: 740, height: 1450)
                    .background(Color.black)
                
                let renderer = ImageRenderer(content: view)
                renderer.scale = 1.0
                
                if let cgImage = renderer.cgImage {
                    frames.append(cgImage)
                }
                
                try? await Task.sleep(nanoseconds: 5_000_000) // Yield Main Thread
            }
            
            let videoService = VideoExportService()
            do {
                let videoURL = try await videoService.createVideo(from: frames, fps: 30, audioName: nil)
                self.isShowingSnackbar = false
                self.activeEvent = .showShareSheet(videoURL)
            } catch {
                self.isShowingSnackbar = false
                appState.showError(title: "Export Failed", message: error.localizedDescription)
            }
        }
    }
    
    
    func toggleFavorite(workout: Workout, presetService: PresetService) {
        let isNowFavorite = !workout.isFavorite
        workout.isFavorite = isNowFavorite // Оптимистичное обновление UI
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        Task {
            // 1. Сохраняем статус тренировки в БД
            await workoutService.updateWorkoutFavoriteStatus(workout: workout, isFavorite: isNowFavorite)
            
            // 2. Если добавили в избранное - создаем шаблон
            if isNowFavorite {
                let folderName = String(localized: "Favorites")
                
                // Функция для рекурсивной очистки DTO (сброс галочек isCompleted)
                func cleanExerciseDTO(_ dto: ExerciseDTO) -> ExerciseDTO {
                    let cleanSets = dto.setsList.map { set in
                        WorkoutSetDTO(index: set.index, weight: set.weight, reps: set.reps, distance: set.distance, time: set.time, isCompleted: false, type: set.type)
                    }
                    let cleanSubs = dto.subExercises.map { cleanExerciseDTO($0) }
                    return ExerciseDTO(name: dto.name, muscleGroup: dto.muscleGroup, type: dto.type, category: dto.category, effort: dto.effort, isCompleted: false, setsList: cleanSets, subExercises: cleanSubs)
                }
                
                // Конвертируем текущие упражнения в чистые шаблоны
                let cleanExercises = workout.exercises.map { cleanExerciseDTO($0.toDTO()) }.map { Exercise(from: $0) }
                
                // Сохраняем как шаблон в папку
                await presetService.savePreset(
                    preset: nil,
                    name: workout.title,
                    icon: "star.fill",
                    folderName: folderName,
                    exercises: cleanExercises
                )
                
                // Обновляем AppStorage, чтобы папка мгновенно появилась в HubView
                await MainActor.run {
                    let currentFolders = UserDefaults.standard.string(forKey: "customPresetFolders") ?? ""
                    var foldersArray = currentFolders.isEmpty ? [] : currentFolders.components(separatedBy: "|")
                    
                    if !foldersArray.contains(folderName) {
                        foldersArray.insert(folderName, at: 0)
                        UserDefaults.standard.set(foldersArray.joined(separator: "|"), forKey: "customPresetFolders")
                    }
                }
            }
        }
    }
}
