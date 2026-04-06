//
//  WorkoutStore.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 2.04.26.
//

import Foundation
import SwiftData
import WidgetKit // WidgetKit тут, чтобы ModelActor мог работать с WidgetDataManager

// MARK: - WorkoutStore (@ModelActor)
@ModelActor
actor WorkoutStore: WorkoutStoreProtocol {
    
    
    func swapExercise(oldID: PersistentIdentifier, newExerciseDTO: ExerciseDTO, inWorkoutID: PersistentIdentifier) async throws {
            guard let workout = modelContext.model(for: inWorkoutID) as? Workout,
                  let oldExercise = modelContext.model(for: oldID) as? Exercise,
                  let index = workout.exercises.firstIndex(where: { $0.persistentModelID == oldID })
            else {
                throw WorkoutRepositoryError.modelNotFound
            }
            
            // Удаляем старое упражнение
            workout.exercises.remove(at: index)
            modelContext.delete(oldExercise)
            
            // Создаем и вставляем новое на то же место
            let newExercise = Exercise(from: newExerciseDTO)
            modelContext.insert(newExercise)
            for set in newExercise.setsList { modelContext.insert(set) } // Важно для SwiftData!
            
            newExercise.workout = workout
            workout.exercises.insert(newExercise, at: index)
            
            try modelContext.save()
        }
    
    
    
    
    // Добавьте этот метод внутрь actor WorkoutStore в файле WorkoutStore.swift
    func createWorkoutFromAI(generated: GeneratedWorkoutDTO) async throws -> PersistentIdentifier {
        let newWorkout = Workout(title: generated.title, date: Date())
        newWorkout.icon = "brain.head.profile"
        modelContext.insert(newWorkout)
        
        for exDTO in generated.exercises {
            let category = ExerciseCategory.determine(from: exDTO.name)
            let exercise = Exercise(
                name: exDTO.name,
                muscleGroup: exDTO.muscleGroup,
                type: ExerciseType(rawValue: exDTO.type) ?? .strength,
                category: category,
                sets: exDTO.sets,
                reps: exDTO.reps,
                weight: exDTO.recommendedWeightKg ?? 0
            )
            
            modelContext.insert(exercise)
            exercise.workout = newWorkout
            newWorkout.exercises.append(exercise)
            
            // Создаем сеты
            for i in 1...max(1, exDTO.sets) {
                let newSet = WorkoutSet(
                    index: i,
                    weight: exDTO.recommendedWeightKg,
                    reps: exDTO.reps,
                    isCompleted: false,
                    type: .normal
                )
                modelContext.insert(newSet)
                newSet.exercise = exercise
                exercise.setsList.append(newSet)
            }
     
        }
        
        try modelContext.save()
        return newWorkout.persistentModelID
    }
    // MARK: - Workout CRUD
    
    // MARK: - Workout CRUD
        
        func createWorkout(title: String, fromPresetID presetID: PersistentIdentifier?, isAIGenerated: Bool) async throws -> PersistentIdentifier {
            var exercises: [Exercise] = []
            
            if let pid = presetID, let preset = modelContext.model(for: pid) as? WorkoutPreset {
                for ex in preset.exercises {
                    // ✅ ИСПРАВЛЕНИЕ: Безопасное глубокое копирование через DTO прямо внутри контекста
                    let newEx = Exercise(from: ex.toDTO())
                    modelContext.insert(newEx)
                    
                    for set in newEx.setsList { modelContext.insert(set) }
                    for sub in newEx.subExercises {
                        modelContext.insert(sub)
                        for set in sub.setsList { modelContext.insert(set) }
                    }
                    exercises.append(newEx)
                }
            }
            
            let newWorkout = Workout(title: title, date: Date(), exercises: exercises)
            newWorkout.icon = isAIGenerated ? "brain.head.profile" : "figure.run"
            modelContext.insert(newWorkout)
            try modelContext.save()
            return newWorkout.persistentModelID
        }
    
    func addSet(toExerciseID exerciseID: PersistentIdentifier, index: Int, weight: Double?, reps: Int?, distance: Double?, time: Int?, type: SetType, isCompleted: Bool) async throws {
        guard let exercise = modelContext.model(for: exerciseID) as? Exercise else { throw WorkoutRepositoryError.modelNotFound }
        let newSet = WorkoutSet(index: index, weight: weight, reps: reps, distance: distance, time: time, isCompleted: isCompleted, type: type)
        
        modelContext.insert(newSet)
        exercise.addSafeSet(newSet)
        try modelContext.save()
    }
    
    func deleteSet(setID: PersistentIdentifier, fromExerciseID exerciseID: PersistentIdentifier) async throws {
        guard let exercise = modelContext.model(for: exerciseID) as? Exercise,
              let set = modelContext.model(for: setID) as? WorkoutSet else { throw WorkoutRepositoryError.modelNotFound }
        
        exercise.removeSafeSet(set)
        modelContext.delete(set)
        try modelContext.save()
    }
    
    func removeSubExercise(subID: PersistentIdentifier, fromSupersetID supersetID: PersistentIdentifier) async throws {
        guard let superset = modelContext.model(for: supersetID) as? Exercise,
              let subExercise = modelContext.model(for: subID) as? Exercise else { throw WorkoutRepositoryError.modelNotFound }
        
        if let index = superset.subExercises.firstIndex(where: { $0.persistentModelID == subID }) {
            superset.subExercises.remove(at: index)
        }
        modelContext.delete(subExercise)

        try modelContext.save()
    }
    
    func removeExercise(exerciseID: PersistentIdentifier, fromWorkoutID workoutID: PersistentIdentifier) async throws {
        guard let workout = modelContext.model(for: workoutID) as? Workout,
              let exercise = modelContext.model(for: exerciseID) as? Exercise else { throw WorkoutRepositoryError.modelNotFound }
        
        if let index = workout.exercises.firstIndex(where: { $0.persistentModelID == exerciseID }) {
            workout.exercises.remove(at: index)
        }
        modelContext.delete(exercise)
        try modelContext.save()
    }
    
    func deleteWorkout(workoutID: PersistentIdentifier) async throws {
        guard let workout = modelContext.model(for: workoutID) as? Workout else {
            throw WorkoutRepositoryError.modelNotFound
        }
        
        if let uStats = (try? modelContext.fetch(FetchDescriptor<UserStats>()))?.first {
            uStats.totalWorkouts = max(0, uStats.totalWorkouts - 1)
            uStats.totalVolume = max(0, uStats.totalVolume - workout.totalStrengthVolume)
            uStats.totalDistance = max(0, uStats.totalDistance - workout.totalCardioDistance)
            
            let hour = Calendar.current.component(.hour, from: workout.date)
            if hour < 9 { uStats.earlyWorkouts = max(0, uStats.earlyWorkouts - 1) }
            if hour >= 20 { uStats.nightWorkouts = max(0, uStats.nightWorkouts - 1) }
        }
        
        let exStatsDict = Dictionary(uniqueKeysWithValues: ((try? modelContext.fetch(FetchDescriptor<ExerciseStat>())) ?? []).map { ($0.exerciseName, $0) })
        let mStatsDict = Dictionary(uniqueKeysWithValues: ((try? modelContext.fetch(FetchDescriptor<MuscleStat>())) ?? []).map { ($0.muscleName, $0) })
        
        for exercise in workout.exercises {
            let targets = exercise.isSuperset ? exercise.subExercises : [exercise]
            for ex in targets {
                if let exStat = exStatsDict[ex.name] { exStat.totalCount = max(0, exStat.totalCount - 1) }
                if ex.type != .cardio && ex.type != .duration {
                    if let mStat = mStatsDict[ex.muscleGroup] { mStat.totalCount = max(0, mStat.totalCount - 1) }
                }
            }
        }
        
        modelContext.delete(workout)
        try modelContext.save()
    }

    func updateWorkoutFavoriteStatus(workoutID: PersistentIdentifier, isFavorite: Bool) async throws {
        guard let workout = modelContext.model(for: workoutID) as? Workout else { throw WorkoutRepositoryError.modelNotFound }
        workout.isFavorite = isFavorite
        try modelContext.save()
    }

    func updateExercise(exerciseID: PersistentIdentifier, newEffort: Int) async throws {
        guard let exercise = modelContext.model(for: exerciseID) as? Exercise else { throw WorkoutRepositoryError.modelNotFound }
        exercise.effort = newEffort
        try modelContext.save()
    }

    func updateWorkoutChatHistory(workoutID: PersistentIdentifier, history: [AIChatMessage]) async throws {
        guard let workout = modelContext.model(for: workoutID) as? Workout else { throw WorkoutRepositoryError.modelNotFound }
        workout.aiChatHistoryData = try JSONEncoder().encode(history)
        try modelContext.save()
    }
    
    // MARK: - Workout Lifecycle
    func deleteSets(setIDs: [PersistentIdentifier], fromExerciseID exerciseID: PersistentIdentifier) async throws {
          guard let exercise = modelContext.model(for: exerciseID) as? Exercise else { throw WorkoutRepositoryError.modelNotFound }
          
          var setsToRemove: [WorkoutSet] = []
          
          // Собираем все сеты
          for setID in setIDs {
              if let set = modelContext.model(for: setID) as? WorkoutSet {
                  setsToRemove.append(set)
              }
          }
          
          // Удаляем их из модели одним махом (пересчет индексов произойдет 1 раз)
          exercise.removeSafeSets(setsToRemove)
          
          // Удаляем объекты из базы
          for set in setsToRemove {
              modelContext.delete(set)
          }
          
          // Сохраняем транзакцию один раз
          try modelContext.save()
      }
    func processCompletedWorkout(workoutID: PersistentIdentifier) async throws {
            guard let workout = modelContext.model(for: workoutID) as? Workout else {
                throw WorkoutRepositoryError.modelNotFound
            }
            
            if workout.endTime == nil { workout.endTime = Date() }
            workout.durationSeconds = Int(workout.endTime!.timeIntervalSince(workout.date))
            
            var totalEffort = 0
            var exercisesWithCompletedSets = 0
            var strengthVol = 0.0
            var cardioDist = 0.0
            var totalWorkoutReps = 0 // ✅ ЛОКАЛЬНАЯ ПЕРЕМЕННАЯ
            
            // ✅ ЧИТАЕМ НАСТРОЙКУ РАЗМИНКИ ОДИН РАЗ ПЕРЕД ЦИКЛАМИ (Исключает лишние блокировки потока)
            let includeWarmups = UserDefaults.standard.bool(forKey: Constants.UserDefaultsKeys.includeWarmupsInStats.rawValue)
            
            for exercise in workout.exercises {
                let targets = exercise.isSuperset ? exercise.subExercises : [exercise]
                var hasCompletedSet = false
                var parentVol = 0.0
                
                for sub in targets {
                    if sub.setsList.contains(where: { $0.isCompleted }) {
                        hasCompletedSet = true
                    }
                    
                    var subVol = 0.0
                    var subMax = 0.0
                    
                    if sub.type == .strength {
                        // ✅ ИНТЕГРАЦИЯ ТУМБЛЕРА РАЗМИНКИ: Фильтруем сеты на лету
                        let validSets = sub.setsList.filter { $0.isCompleted && (includeWarmups || $0.type != .warmup) }
                        
                        subVol = validSets.reduce(0.0) { res, set in
                            res + ((set.weight ?? 0) * Double(set.reps ?? 0))
                        }
                        subMax = validSets.compactMap { $0.weight }.max() ?? 0.0
                        
                        // ✅ Считаем все повторения (учитывая или исключая разминку в зависимости от validSets)
                        let subReps = validSets.compactMap { $0.reps }.reduce(0, +)
                        totalWorkoutReps += subReps
                        
                        sub.cachedVolume = subVol
                        sub.cachedMaxWeight = subMax
                        
                        strengthVol += subVol
                        parentVol += subVol
                        
                    } else if sub.type == .cardio {
                        cardioDist += sub.setsList.filter { $0.isCompleted }.compactMap { $0.distance }.reduce(0.0, +)
                    }
                }

                if exercise.isSuperset {
                    exercise.cachedVolume = parentVol
                }

                if hasCompletedSet {
                    totalEffort += exercise.effort
                    exercisesWithCompletedSets += 1
                }
            }
            
            workout.effortPercentage = exercisesWithCompletedSets > 0 ? Int((Double(totalEffort) / Double(exercisesWithCompletedSets)) * 10) : 0
            workout.totalStrengthVolume = strengthVol
            workout.totalCardioDistance = cardioDist
            workout.totalReps = totalWorkoutReps // ✅ СОХРАНЯЕМ В БД
            
            // 4. Обновляем глобальную статистику пользователя (UserStats)
            let uStats = (try? modelContext.fetch(FetchDescriptor<UserStats>()))?.first ?? UserStats()
            if uStats.modelContext == nil { modelContext.insert(uStats) }
            
            uStats.totalWorkouts += 1
            uStats.totalVolume += workout.totalStrengthVolume
            uStats.totalDistance += workout.totalCardioDistance
            
            let hour = Calendar.current.component(.hour, from: workout.date)
            if hour < 9 { uStats.earlyWorkouts += 1 }
            if hour >= 20 { uStats.nightWorkouts += 1 }
            
            // 5. ВТОРОЙ ПРОХОД: Обновляем статистику по конкретным упражнениям и мышцам
            var exStatsDict = Dictionary(uniqueKeysWithValues: ((try? modelContext.fetch(FetchDescriptor<ExerciseStat>())) ?? []).map { ($0.exerciseName, $0) })
            var mStatsDict = Dictionary(uniqueKeysWithValues: ((try? modelContext.fetch(FetchDescriptor<MuscleStat>())) ?? []).map { ($0.muscleName, $0) })
            
            for exercise in workout.exercises {
                let targets = exercise.isSuperset ? exercise.subExercises : [exercise]
                
                for ex in targets {
                    // Получаем или создаем ExerciseStat
                    let exStat = exStatsDict[ex.name] ?? {
                        let newStat = ExerciseStat(exerciseName: ex.name)
                        modelContext.insert(newStat)
                        exStatsDict[ex.name] = newStat
                        return newStat
                    }()
                    
                    exStat.totalCount += 1
                    
                    // Сериализуем данные для истории (DTO)
                    if let encodedData = try? JSONEncoder().encode(ex.toDTO()) {
                        exStat.lastPerformanceDTO = encodedData
                    }
                    
                    if ex.type == .strength {
                        // ✅ ИСПОЛЬЗУЕМ КЭШ: Не фильтруем setsList заново, берем уже посчитанный maxWeight (с учетом/без учета разминки)!
                        let maxWeight = ex.cachedMaxWeight
                        if maxWeight > exStat.maxWeight {
                            exStat.maxWeight = maxWeight
                        }
                    }
                    
                    // Обновляем статистику по мышечным группам (MuscleStat)
                    let isCardio = ex.type == .cardio || ex.type == .duration || ex.muscleGroup == "Cardio"
                    if !isCardio {
                        let mStat = mStatsDict[ex.muscleGroup] ?? {
                            let newMStat = MuscleStat(muscleName: ex.muscleGroup)
                            modelContext.insert(newMStat)
                            mStatsDict[ex.muscleGroup] = newMStat
                            return newMStat
                        }()
                        mStat.totalCount += 1
                    }
                }
            }
            
            // 6. Сохраняем все изменения в БД одним коммитом
            try modelContext.save()
        }
    
    func findActiveWorkoutsAndCleanup() async throws -> [PersistentIdentifier] {
        let desc = FetchDescriptor<Workout>(predicate: #Predicate<Workout> { $0.endTime == nil })
        let activeWorkouts = (try? modelContext.fetch(desc)) ?? []
        var remainingActiveIDs: [PersistentIdentifier] = []
        
        for workout in activeWorkouts {
            let hoursSinceStart = Date().timeIntervalSince(workout.date) / 3600
            if hoursSinceStart > 12 {
                // Если тренировка висит дольше 12 часов, считаем её завершенной и процессим
                workout.endTime = workout.date.addingTimeInterval(3600) // Устанавливаем фиктивную длительность
                try await processCompletedWorkout(workoutID: workout.persistentModelID)
            } else {
                remainingActiveIDs.append(workout.persistentModelID)
            }
        }
        try modelContext.save()
        return remainingActiveIDs
    }
    
    
    // MARK: - User Stats & Health
   
    func deleteWeightEntry(_ entryID: PersistentIdentifier) async throws {
        guard let entry = modelContext.model(for: entryID) as? WeightEntry else { throw WorkoutRepositoryError.modelNotFound }
        modelContext.delete(entry)
        try modelContext.save()
    }

    func addBodyMeasurement(neck: Double?, shoulders: Double?, chest: Double?, waist: Double?, pelvis: Double?, biceps: Double?, thigh: Double?, calves: Double?, date: Date) async throws {
        let entry = BodyMeasurement(
            date: date, neck: neck, shoulders: shoulders, chest: chest,
            waist: waist, pelvis: pelvis, biceps: biceps, thigh: thigh, calves: calves
        )
        modelContext.insert(entry)
        try modelContext.save()
    }

    func deleteBodyMeasurement(_ measurementID: PersistentIdentifier) async throws {
        guard let measurement = modelContext.model(for: measurementID) as? BodyMeasurement else { throw WorkoutRepositoryError.modelNotFound }
        modelContext.delete(measurement)
        try modelContext.save()
    }

    func saveExerciseNote(exerciseName: String, text: String, existingNoteID: PersistentIdentifier?) async throws -> PersistentIdentifier? {
        var note: ExerciseNote?
        if let id = existingNoteID, let existing = modelContext.model(for: id) as? ExerciseNote {
            note = existing
        } else {
            let descriptor = FetchDescriptor<ExerciseNote>(predicate: #Predicate { $0.exerciseName == exerciseName })
            note = (try? modelContext.fetch(descriptor).first)
        }
        
        if let n = note {
            n.text = text
        } else if !text.isEmpty {
            let newNote = ExerciseNote(exerciseName: exerciseName, text: text)
            modelContext.insert(newNote)
            note = newNote
        }
        try modelContext.save()
        return note?.persistentModelID
    }

    func fetchExerciseNote(exerciseName: String) async throws -> ExerciseNote? {
        let descriptor = FetchDescriptor<ExerciseNote>(predicate: #Predicate { $0.exerciseName == exerciseName })
        return try modelContext.fetch(descriptor).first
    }

    func deleteAIChatSession(_ sessionID: PersistentIdentifier) async throws {
        guard let session = modelContext.model(for: sessionID) as? AIChatSession else { throw WorkoutRepositoryError.modelNotFound }
        modelContext.delete(session)
        try modelContext.save()
    }
    
    func fetchAIChatSessions() async throws -> [AIChatSession] {
        let descriptor = FetchDescriptor<AIChatSession>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        return try modelContext.fetch(descriptor)
    }

    
    // MARK: - Exercise Catalog
    

    func deleteCustomExercise(name: String, category: String) async throws {
        let desc = FetchDescriptor<ExerciseDictionaryItem>(predicate: #Predicate { $0.name == name && $0.isCustom })
        if let items = try? modelContext.fetch(desc), let item = items.first {
            item.isHidden = true
            try modelContext.save()
        }
    }

    func hideDefaultExercise(name: String, category: String) async throws {
        let item = ExerciseDictionaryItem(name: name, category: category, targetedMuscles: [], type: .strength, isCustom: false, isHidden: true)
        modelContext.insert(item)
        try modelContext.save()
    }
    
    func fetchCustomExercises() async throws -> [CustomExerciseDefinition] {
        let items = (try? modelContext.fetch(FetchDescriptor<ExerciseDictionaryItem>())) ?? []
        return items.filter { $0.isCustom && !$0.isHidden }.map { CustomExerciseDefinition(id: UUID(), name: $0.name, category: $0.category, targetedMuscles: $0.targetedMuscles, type: $0.type) }
    }

    func fetchDeletedDefaultExercises() async throws -> Set<String> {
        let items = (try? modelContext.fetch(FetchDescriptor<ExerciseDictionaryItem>())) ?? []
        return Set(items.filter { $0.isHidden && !$0.isCustom }.map { $0.name })
    }

    func checkAndGenerateDefaultPresets() async throws {
          let defaults = UserDefaults.standard
          let flagKey = Constants.UserDefaultsKeys.hasGeneratedDefaultPresets_v3.rawValue
          
          // Гарантируем, что полная база пресетов сгенерируется ровно один раз,
          // даже если пользователь уже создал свои шаблоны.
          guard !defaults.bool(forKey: flagKey) else { return }
          
          // Чистые DTO-подобные данные, независимые от контекста
          let templates: [(name: String, icon: String, exercises: [(n: String, g: String, s: Int, r: Int, w: Double)])] = [
              ("Push Day", "img_chest", [
                  ("Bench Press", "Chest", 4, 8, 60.0),
                  ("Overhead Press", "Shoulders", 3, 10, 40.0),
                  ("Triceps Extension", "Arms", 3, 12, 20.0)
              ]),
              ("Pull Day", "img_back", [
                  ("Pull-ups", "Back", 4, 8, 0.0),
                  ("Barbell Rows", "Back", 3, 10, 50.0),
                  ("Barbell Curl", "Arms", 3, 12, 25.0)
              ]),
              ("Legs Day", "img_legs", [
                  ("Squat", "Legs", 4, 8, 80.0),
                  ("Leg Press", "Legs", 3, 12, 120.0),
                  ("Calf Raises", "Legs", 4, 15, 60.0)
              ]),
              ("Full Body", "img_default", [
                  ("Squat", "Legs", 3, 10, 60.0),
                  ("Bench Press", "Chest", 3, 10, 50.0),
                  ("Deadlift", "Back", 3, 5, 80.0)
              ])
          ]
          
          // Безопасная сборка @Model прямо внутри активного контекста
          for template in templates {
              let preset = WorkoutPreset(
                  id: UUID(),
                  name: template.name,
                  icon: template.icon,
                  isSystem: true, // ✅ ДОБАВЛЕНО: Теперь они системные
                  exercises: []
              )
              modelContext.insert(preset)
              
              for exData in template.exercises {
                  // Инициализатор Exercise автоматически генерирует вложенный массив setsList
                  let exercise = Exercise(
                      name: exData.n,
                      muscleGroup: exData.g,
                      type: .strength,
                      sets: exData.s,
                      reps: exData.r,
                      weight: exData.w
                  )
                  
                  modelContext.insert(exercise)
                  
                  // Явно вставляем сеты в контекст для каскадного сохранения
                  for set in exercise.setsList {
                      modelContext.insert(set)
                  }
                  
                  // Устанавливаем двусторонние связи
                  exercise.preset = preset
                  preset.exercises.append(exercise)
              }
          }
          
          // Сохраняем транзакцию и ставим флаг
          try modelContext.save()
          defaults.set(true, forKey: flagKey)
      }
    func applyAIAdjustment(_ adjustment: InWorkoutResponseDTO, workoutID: PersistentIdentifier) async throws {
        guard let workout = modelContext.model(for: workoutID) as? Workout, workout.isActive else { return }
        
        switch adjustment.actionType {
        case .reduceRemainingLoad:
            let percentage = adjustment.valuePercentage ?? 10.0
            let multiplier = 1.0 - (percentage / 100.0)
            for ex in workout.exercises where !ex.isCompleted {
                for set in ex.setsList where !set.isCompleted {
                    if let currentW = set.weight, currentW > 0 {
                        set.weight = round((currentW * multiplier) / 2.5) * 2.5
                    }
                }

            }
            
        case .skipExercise:
            guard let targetName = adjustment.targetExerciseName,
                  let targetEx = workout.exercises.first(where: { $0.name.lowercased() == targetName.lowercased() && !$0.isCompleted }) else { break }
            
            if targetEx.setsList.contains(where: { $0.isCompleted }) {
                for set in targetEx.setsList where !set.isCompleted { modelContext.delete(set) }
                targetEx.setsList.removeAll(where: { !$0.isCompleted })
                targetEx.isCompleted = true
            } else {
                if let idx = workout.exercises.firstIndex(of: targetEx) {
                    workout.exercises.remove(at: idx)
                    modelContext.delete(targetEx)
                }
            }
            
        case .dropWeight:
            guard let targetName = adjustment.targetExerciseName,
                  let targetExercise = workout.exercises.first(where: { $0.name.lowercased() == targetName.lowercased() }) else { break }
            if let nextSet = targetExercise.setsList.sorted(by: { $0.index < $1.index }).first(where: { !$0.isCompleted }) {
                if let currentWeight = nextSet.weight, let percentage = adjustment.valuePercentage {
                    nextSet.weight = round((currentWeight * (1.0 - (percentage / 100.0))) / 2.5) * 2.5
                }
            }
 
            
        case .addSet:
            guard let targetName = adjustment.targetExerciseName,
                  let targetExercise = workout.exercises.first(where: { $0.name.lowercased() == targetName.lowercased() }) else { break }
            
            let newIndex = (targetExercise.setsList.map { $0.index }.max() ?? 0) + 1
            let newSet = WorkoutSet(
                index: newIndex, weight: adjustment.valueWeightKg ?? targetExercise.firstSetWeight,
                reps: adjustment.valueReps ?? targetExercise.firstSetReps, isCompleted: false, type: .failure
            )
            modelContext.insert(newSet)
            targetExercise.setsList.append(newSet)
 
            
        case .replaceExercise:
            guard let targetName = adjustment.targetExerciseName,
                  let targetExercise = workout.exercises.first(where: { $0.name.lowercased() == targetName.lowercased() }),
                  let newName = adjustment.replacementExerciseName else { break }
            
            let completedSetsCount = targetExercise.setsList.filter({ $0.isCompleted }).count
            let remainingSets = targetExercise.setsList.count - completedSetsCount
            let newExercise = Exercise(
                name: newName, muscleGroup: targetExercise.muscleGroup, type: targetExercise.type,
                sets: remainingSets > 0 ? remainingSets : 3,
                reps: adjustment.valueReps ?? targetExercise.firstSetReps,
                weight: adjustment.valueWeightKg ?? targetExercise.firstSetWeight
            )
            modelContext.insert(newExercise)
            
            if completedSetsCount == 0 {
                if let idx = workout.exercises.firstIndex(of: targetExercise) {
                    workout.exercises[idx] = newExercise
                    modelContext.delete(targetExercise)
                }
            } else {
                for set in targetExercise.setsList where !set.isCompleted { modelContext.delete(set) }
                targetExercise.setsList.removeAll(where: { !$0.isCompleted })
                targetExercise.isCompleted = true
                if let idx = workout.exercises.firstIndex(of: targetExercise) {
                    workout.exercises.insert(newExercise, at: idx + 1)
                }
            }
        case .none, .unknown:
            break
        }
        try modelContext.save()
    }
    
    func fetchLatestWorkout() async throws -> Workout? {
            var descriptor = FetchDescriptor<Workout>(sortBy: [SortDescriptor(\.date, order: .reverse)])
            descriptor.fetchLimit = 1
            return try modelContext.fetch(descriptor).first
        }
}
