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
            exercise.updateAggregates()
        }
        
        try modelContext.save()
        return newWorkout.persistentModelID
    }
    // MARK: - Workout CRUD
    
    func createWorkout(title: String, fromPresetID presetID: PersistentIdentifier?, isAIGenerated: Bool) async throws -> PersistentIdentifier {
        var exercises: [Exercise] = []
        
        if let pid = presetID, let preset = modelContext.model(for: pid) as? WorkoutPreset {
            for ex in preset.exercises {
                let dup = ex.duplicate()
                modelContext.insert(dup)
                for set in dup.setsList { modelContext.insert(set) }
                for sub in dup.subExercises {
                    modelContext.insert(sub)
                    for set in sub.setsList { modelContext.insert(set) }
                }
                exercises.append(dup)
            }
        }
        
        let newWorkout = Workout(title: title, date: Date(), exercises: exercises)
        newWorkout.icon = isAIGenerated ? "brain.head.profile" : "figure.run" // Устанавливаем иконку
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
        superset.updateAggregates()
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
    
    func processCompletedWorkout(workoutID: PersistentIdentifier) async throws {
        guard let workout = modelContext.model(for: workoutID) as? Workout else { throw WorkoutRepositoryError.modelNotFound }
        
        if workout.endTime == nil { workout.endTime = Date() } // Убедимся, что время завершения установлено
        workout.durationSeconds = Int(workout.endTime!.timeIntervalSince(workout.date))
        
        var totalEffort = 0, exercisesWithCompletedSets = 0, strengthVol = 0.0, cardioDist = 0.0
        
        for exercise in workout.exercises {
            let targets = exercise.isSuperset ? exercise.subExercises : [exercise]
            var hasCompletedSet = false
            
            for sub in targets {
                sub.updateAggregates() // Обновляем агрегаты в SwiftData
                if sub.setsList.contains(where: { $0.isCompleted }) { hasCompletedSet = true }
                if sub.type == .strength { strengthVol += sub.exerciseVolume }
                else if sub.type == .cardio { cardioDist += sub.setsList.filter { $0.isCompleted }.compactMap { $0.distance }.reduce(0.0, +) }
            }
            
            exercise.updateAggregates()
            if hasCompletedSet { totalEffort += exercise.effort; exercisesWithCompletedSets += 1 }
        }
        
        workout.effortPercentage = exercisesWithCompletedSets > 0 ? Int((Double(totalEffort) / Double(exercisesWithCompletedSets)) * 10) : 0
        workout.totalStrengthVolume = strengthVol
        workout.totalCardioDistance = cardioDist
        
        let uStats = (try? modelContext.fetch(FetchDescriptor<UserStats>()))?.first ?? UserStats()
        if uStats.modelContext == nil { modelContext.insert(uStats) }
        
        uStats.totalWorkouts += 1; uStats.totalVolume += workout.totalStrengthVolume; uStats.totalDistance += workout.totalCardioDistance
        let hour = Calendar.current.component(.hour, from: workout.date)
        if hour < 9 { uStats.earlyWorkouts += 1 }
        if hour >= 20 { uStats.nightWorkouts += 1 }
        
        var exStatsDict = Dictionary(uniqueKeysWithValues: ((try? modelContext.fetch(FetchDescriptor<ExerciseStat>())) ?? []).map { ($0.exerciseName, $0) })
        var mStatsDict = Dictionary(uniqueKeysWithValues: ((try? modelContext.fetch(FetchDescriptor<MuscleStat>())) ?? []).map { ($0.muscleName, $0) })
        
        for exercise in workout.exercises {
            let targets = exercise.isSuperset ? exercise.subExercises : [exercise]
            for ex in targets {
                let exStat = exStatsDict[ex.name] ?? { let newStat = ExerciseStat(exerciseName: ex.name); modelContext.insert(newStat); exStatsDict[ex.name] = newStat; return newStat }()
                exStat.totalCount += 1
                
                if let encodedData = try? JSONEncoder().encode(ex.toDTO()) { exStat.lastPerformanceDTO = encodedData }
                
                if ex.type == .strength {
                    let maxWeight = ex.setsList.filter { $0.isCompleted && $0.type != .warmup }.compactMap { $0.weight }.max() ?? 0
                    if maxWeight > exStat.maxWeight { exStat.maxWeight = maxWeight }
                }
                let isCardio = ex.type == .cardio || ex.type == .duration || ex.muscleGroup == "Cardio"
                if !isCardio {
                    let mStat = mStatsDict[ex.muscleGroup] ?? { let newMStat = MuscleStat(muscleName: ex.muscleGroup); modelContext.insert(newMStat); mStatsDict[ex.muscleGroup] = newMStat; return newMStat }()
                    mStat.totalCount += 1
                }
            }
        }
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
    
    // MARK: - Presets
    
    func createPreset(name: String, icon: String, exercises: [Exercise]) async throws {
        let newPreset = WorkoutPreset(id: UUID(), name: name, icon: icon, exercises: [])
        modelContext.insert(newPreset)
        
        for ex in exercises {
            let dup = ex.duplicate() // Дублируем упражнение для нового пресета
            modelContext.insert(dup)
            dup.preset = newPreset
            newPreset.exercises.append(dup)
            
            for set in dup.setsList { modelContext.insert(set) } // Вставляем сеты
            for subEx in dup.subExercises { // Вставляем суб-упражнения
                modelContext.insert(subEx)
                subEx.preset = newPreset
                for set in subEx.setsList { modelContext.insert(set) }
            }
        }
        try modelContext.save()
    }

    func updatePreset(presetID: PersistentIdentifier, name: String, icon: String, exercises: [Exercise]) async throws {
        guard let existingPreset = modelContext.model(for: presetID) as? WorkoutPreset else { throw WorkoutRepositoryError.modelNotFound }
        
        existingPreset.name = name
        existingPreset.icon = icon
        
        // Удаляем старые упражнения, которые были привязаны к этому пресету
        for oldEx in existingPreset.exercises {
            modelContext.delete(oldEx)
        }
        existingPreset.exercises.removeAll()
        
        // Добавляем новые упражнения
        for ex in exercises {
            let dup = ex.duplicate()
            modelContext.insert(dup)
            dup.preset = existingPreset
            existingPreset.exercises.append(dup)
            
            for set in dup.setsList { modelContext.insert(set) }
            for subEx in dup.subExercises {
                modelContext.insert(subEx)
                subEx.preset = existingPreset
                for set in subEx.setsList { modelContext.insert(set) }
            }
        }
        try modelContext.save()
    }

    func deletePreset(presetID: PersistentIdentifier) async throws {
        guard let preset = modelContext.model(for: presetID) as? WorkoutPreset else { throw WorkoutRepositoryError.modelNotFound }
        modelContext.delete(preset)
        try modelContext.save()
    }

    func fetchPreset(by id: PersistentIdentifier) async throws -> WorkoutPreset? {
        return modelContext.model(for: id) as? WorkoutPreset
    }
    
    // MARK: - User Stats & Health
    
    func addWeightEntry(weight: Double, date: Date) async throws {
        let newEntry = WeightEntry(date: date, weight: weight)
        modelContext.insert(newEntry)
        try modelContext.save()
    }

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

    func saveAIChatSession(_ session: AIChatSession) async throws {
        modelContext.insert(session)
        try modelContext.save()
    }

    // MARK: - Exercise Catalog
    
    func addCustomExercise(name: String, category: String, targetedMuscles: [String], type: ExerciseType) async throws {
        let item = ExerciseDictionaryItem(name: name, category: category, targetedMuscles: targetedMuscles, type: type, isCustom: true, isHidden: false)
        modelContext.insert(item)
        try modelContext.save()
    }

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
        let count = (try? modelContext.fetchCount(FetchDescriptor<WorkoutPreset>())) ?? 0
        if count == 0 {
            for example in Workout.examples {
                let preset = WorkoutPreset(id: UUID(), name: example.title, icon: example.icon, exercises: [])
                modelContext.insert(preset)
                try? modelContext.save() // Save after inserting preset itself
                
                for exercise in example.exercises {
                    let dup = exercise.duplicate()
                    
                    for set in dup.setsList {
                        modelContext.insert(set)
                    }
                    
                    for sub in dup.subExercises {
                        for s in sub.setsList {
                            modelContext.insert(s)
                        }
                        modelContext.insert(sub)
                    }
                    
                    modelContext.insert(dup)
                    dup.preset = preset
                    preset.exercises.append(dup)
                }
                try? modelContext.save() // Save after adding exercises to preset
            }
        }
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
                ex.updateAggregates()
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
            targetExercise.updateAggregates()
            
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
            targetExercise.updateAggregates()
            
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
                targetExercise.updateAggregates()
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
