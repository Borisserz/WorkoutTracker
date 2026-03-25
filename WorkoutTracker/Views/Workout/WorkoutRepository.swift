import Foundation
import SwiftData
import WidgetKit

// MARK: - Errors
enum WorkoutRepositoryError: Error, Sendable {
    case modelNotFound
    case invalidData
    case saveFailed(String)
}

// MARK: - Sendable DTOs
struct DashboardCacheDTO: Sendable {
    let personalRecords: [String: Double]
    let lastPerformances: [String: Data]
    let recoveryStatus: [MuscleRecoveryStatusDTO]
    let dashboardMuscleData: [MuscleCountDTO]
    let dashboardTotalExercises: Int
    let dashboardTopExercises: [ExerciseCountDTO]
    let streakCount: Int
    let bestWeekStats: PeriodStatsDTO
    let bestMonthStats: PeriodStatsDTO
    let weakPoints: [WeakPointDTO]
    let recommendations: [RecommendationDTO]
}

struct MuscleCountDTO: Sendable {
    let muscle: String
    let count: Int
}

struct ExerciseCountDTO: Sendable {
    let name: String
    let count: Int
}

struct PeriodStatsDTO: Sendable {
    let workoutCount: Int
    let totalReps: Int
    let totalDuration: Int
    let totalVolume: Double
    let totalDistance: Double
}

struct MuscleRecoveryStatusDTO: Sendable {
    let muscleGroup: String
    let recoveryPercentage: Int
}

struct WeakPointDTO: Sendable {
    let muscleGroup: String
    let frequency: Int
    let averageVolume: Double
    let recommendation: String
}

struct RecommendationDTO: Sendable {
    let typeRawValue: String
    let title: String
    let message: String
    let priority: Int
}

struct WorkoutHeatmapDTO: Sendable {
    let intensityMap: [String: Int]
    let totalStrengthVolume: Double
}

// MARK: - Workout Repository (@ModelActor)
@ModelActor
actor WorkoutRepository {
    
    func addSet(toExercise exerciseID: PersistentIdentifier, index: Int, weight: Double?, reps: Int?, distance: Double?, time: Int?, type: SetType, isCompleted: Bool) throws {
        guard let exercise = modelContext.model(for: exerciseID) as? Exercise else { throw WorkoutRepositoryError.modelNotFound }
        let newSet = WorkoutSet(index: index, weight: weight, reps: reps, distance: distance, time: time, isCompleted: isCompleted, type: type)
        modelContext.insert(newSet)
        exercise.setsList.append(newSet)
        exercise.updateAggregates()
        try modelContext.save()
    }
    
    func deleteSet(setID: PersistentIdentifier, fromExerciseID exerciseID: PersistentIdentifier) throws {
        guard let exercise = modelContext.model(for: exerciseID) as? Exercise, let set = modelContext.model(for: setID) as? WorkoutSet else { throw WorkoutRepositoryError.modelNotFound }
        if let index = exercise.setsList.firstIndex(where: { $0.id == set.id }) { exercise.setsList.remove(at: index) }
        modelContext.delete(set)
        let sortedSets = exercise.setsList.sorted { $0.index < $1.index }
        for (i, remainingSet) in sortedSets.enumerated() { remainingSet.index = i + 1 }
        exercise.updateAggregates()
        try modelContext.save()
    }

    func removeSubExercise(subExerciseID: PersistentIdentifier, fromSupersetID: PersistentIdentifier) throws {
        guard let superset = modelContext.model(for: fromSupersetID) as? Exercise, let sub = modelContext.model(for: subExerciseID) as? Exercise else { return }
        if let idx = superset.subExercises.firstIndex(where: { $0.id == sub.id }) { superset.subExercises.remove(at: idx) }
        modelContext.delete(sub)
        superset.updateAggregates()
        try modelContext.save()
    }
    
    func removeExercise(exerciseID: PersistentIdentifier, fromWorkoutID: PersistentIdentifier) throws {
        guard let workout = modelContext.model(for: fromWorkoutID) as? Workout, let exercise = modelContext.model(for: exerciseID) as? Exercise else { return }
        if let idx = workout.exercises.firstIndex(where: { $0.id == exercise.id }) { workout.exercises.remove(at: idx) }
        modelContext.delete(exercise)
        try modelContext.save()
    }
    
    func processCompletedWorkout(workoutID: PersistentIdentifier) throws {
        guard let workout = modelContext.model(for: workoutID) as? Workout else { throw WorkoutRepositoryError.modelNotFound }
        if let endTime = workout.endTime { workout.durationSeconds = Int(endTime.timeIntervalSince(workout.date)) } else { workout.durationSeconds = 0 }
        
        var totalEffort = 0, exercisesWithCompletedSets = 0, strengthVol = 0.0, cardioDist = 0.0
        
        for exercise in workout.exercises {
            exercise.updateAggregates()
            let targets = exercise.isSuperset ? exercise.subExercises : [exercise]
            var hasCompletedSet = false
            for sub in targets {
                sub.updateAggregates()
                if sub.setsList.contains(where: { $0.isCompleted }) { hasCompletedSet = true }
                if sub.type == .strength { strengthVol += sub.exerciseVolume }
                else if sub.type == .cardio { cardioDist += sub.setsList.filter { $0.isCompleted }.compactMap { $0.distance }.reduce(0.0, +) }
            }
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
                if let encoded = try? JSONEncoder().encode(ex.toDTO()) { exStat.lastPerformanceDTO = encoded }
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
    
    func deleteWorkout(workoutID: PersistentIdentifier) throws {
        guard let workout = modelContext.model(for: workoutID) as? Workout else { throw WorkoutRepositoryError.modelNotFound }
        modelContext.delete(workout)
        try modelContext.save()
    }

    func cleanupAndFindActiveWorkouts() throws -> Bool {
        let desc = FetchDescriptor<Workout>(predicate: #Predicate<Workout> { $0.endTime == nil })
        let activeWorkouts = (try? modelContext.fetch(desc)) ?? []
        var hasActive = false
        for workout in activeWorkouts {
            let hoursSinceStart = Date().timeIntervalSince(workout.date) / 3600
            if hoursSinceStart > 12 {
                workout.endTime = workout.date.addingTimeInterval(3600)
                try processCompletedWorkout(workoutID: workout.persistentModelID)
            } else {
                hasActive = true
            }
        }
        try modelContext.save()
        return hasActive
    }
    
    func fetchDashboardCache() throws -> DashboardCacheDTO {
        let exStats = (try? modelContext.fetch(FetchDescriptor<ExerciseStat>())) ?? []
        let mStats = (try? modelContext.fetch(FetchDescriptor<MuscleStat>())) ?? []
        
        var partialLastPerformances: [String: Data] = [:]
        var partialPRs: [String: Double] = [:]
        var exerciseCounts: [String: Int] = [:]
        var stats: [String: Int] = [:]
        
        for ex in exStats {
            partialPRs[ex.exerciseName] = ex.maxWeight
            exerciseCounts[ex.exerciseName] = ex.totalCount
            if let data = ex.lastPerformanceDTO { partialLastPerformances[ex.exerciseName] = data }
        }
        for m in mStats { stats[m.muscleName] = m.totalCount }
        
        let threeMonthsAgo = Calendar.current.date(byAdding: .month, value: -3, to: Date())!
        var recentDesc = FetchDescriptor<Workout>(predicate: #Predicate<Workout> { $0.endTime != nil && $0.date >= threeMonthsAgo }, sortBy: [SortDescriptor(\.date, order: .reverse)])
        recentDesc.fetchLimit = 150
        let recentWorkouts = (try? modelContext.fetch(recentDesc)) ?? []
        
        let recovery = RecoveryCalculator.calculate(hours: nil, workouts: recentWorkouts)
        let sortedMuscleData = stats.map { MuscleCountDTO(muscle: $0.key, count: $0.value) }.filter { $0.count > 0 }.sorted { $0.count > $1.count }
        let totalExCount = sortedMuscleData.reduce(0) { $0 + $1.count }
        let topExercises = Array(exerciseCounts.sorted { $0.value > $1.value || ($0.value == $1.value && $0.key < $1.key) }.prefix(5)).map { ExerciseCountDTO(name: $0.key, count: $0.value) }
        
        let streak = StatisticsManager.calculateWorkoutStreak(workouts: recentWorkouts)
        let bWeek = StatisticsManager.getBestStats(for: .week, workouts: recentWorkouts)
        let bMonth = StatisticsManager.getBestStats(for: .month, workouts: recentWorkouts)
        let weakPts = AnalyticsManager.getWeakPoints(recentWorkouts: recentWorkouts)
        let recs = AnalyticsManager.getRecommendations(workouts: recentWorkouts, recoveryStatus: recovery)
        
        let recoveryDTO = recovery.map { MuscleRecoveryStatusDTO(muscleGroup: $0.muscleGroup, recoveryPercentage: $0.recoveryPercentage) }
        let bestWeekDTO = PeriodStatsDTO(workoutCount: bWeek.workoutCount, totalReps: bWeek.totalReps, totalDuration: bWeek.totalDuration, totalVolume: bWeek.totalVolume, totalDistance: bWeek.totalDistance)
        let bestMonthDTO = PeriodStatsDTO(workoutCount: bMonth.workoutCount, totalReps: bMonth.totalReps, totalDuration: bMonth.totalDuration, totalVolume: bMonth.totalVolume, totalDistance: bMonth.totalDistance)
        let weakPtsDTO = weakPts.map { WeakPointDTO(muscleGroup: $0.muscleGroup, frequency: $0.frequency, averageVolume: $0.averageVolume, recommendation: $0.recommendation) }
        let recsDTO = recs.map { RecommendationDTO(typeRawValue: String(describing: $0.type), title: $0.title, message: $0.message, priority: $0.priority) }
        
        return DashboardCacheDTO(personalRecords: partialPRs, lastPerformances: partialLastPerformances, recoveryStatus: recoveryDTO, dashboardMuscleData: sortedMuscleData, dashboardTotalExercises: totalExCount, dashboardTopExercises: topExercises, streakCount: streak, bestWeekStats: bestWeekDTO, bestMonthStats: bestMonthDTO, weakPoints: weakPtsDTO, recommendations: recsDTO)
    }
    
    func fetchCustomExercises() throws -> [CustomExerciseDefinition] {
        let items = (try? modelContext.fetch(FetchDescriptor<ExerciseDictionaryItem>())) ?? []
        return items.filter { $0.isCustom && !$0.isHidden }.map { CustomExerciseDefinition(id: UUID(), name: $0.name, category: $0.category, targetedMuscles: $0.targetedMuscles, type: $0.type) }
    }

    func fetchDeletedDefaultExercises() throws -> Set<String> {
        let items = (try? modelContext.fetch(FetchDescriptor<ExerciseDictionaryItem>())) ?? []
        return Set(items.filter { $0.isHidden && !$0.isCustom }.map { $0.name })
    }

    public func checkAndGenerateDefaultPresets() throws {
            let count = (try? modelContext.fetchCount(FetchDescriptor<WorkoutPreset>())) ?? 0
            if count == 0 {
                for example in Workout.examples {
                    let preset = WorkoutPreset(id: UUID(), name: example.title, icon: example.icon, exercises: [])
                    modelContext.insert(preset)
                    for exercise in example.exercises {
                        let dup = exercise.duplicate()
                        modelContext.insert(dup)
                        dup.preset = preset // <--- ДОБАВИТЬ ЭТУ СТРОКУ
                        preset.exercises.append(dup)
                        for set in dup.setsList { modelContext.insert(set) }
                        for sub in dup.subExercises {
                            modelContext.insert(sub)
                            for s in sub.setsList { modelContext.insert(s) }
                        }
                    }
                }
                try modelContext.save()
            }
        }

    func addCustomExercise(name: String, category: String, muscles: [String], type: ExerciseType) throws {
        let item = ExerciseDictionaryItem(name: name, category: category, targetedMuscles: muscles, type: type, isCustom: true, isHidden: false)
        modelContext.insert(item)
        try modelContext.save()
    }

    func deleteCustomExercise(name: String, category: String) throws {
        let desc = FetchDescriptor<ExerciseDictionaryItem>(predicate: #Predicate { $0.name == name && $0.isCustom })
        if let items = try? modelContext.fetch(desc), let item = items.first {
            item.isHidden = true
            try modelContext.save()
        }
    }

    func hideDefaultExercise(name: String, category: String) throws {
        let item = ExerciseDictionaryItem(name: name, category: category, targetedMuscles: [], type: .strength, isCustom: false, isHidden: true)
        modelContext.insert(item)
        try modelContext.save()
    }

    func importPreset(dto: WorkoutPresetDTO) throws {
        let preset = WorkoutPreset(from: dto)
        modelContext.insert(preset)
        try modelContext.save()
    }

    func updateWidgetData() throws {
        let sixWeeksAgo = Calendar.current.date(byAdding: .weekOfYear, value: -6, to: Date())!
        var desc = FetchDescriptor<Workout>(predicate: #Predicate<Workout> { $0.endTime != nil && $0.date >= sixWeeksAgo }, sortBy: [SortDescriptor(\.date, order: .reverse)])
        desc.fetchLimit = 100
        guard let workouts = try? modelContext.fetch(desc) else { return }
        
        let currentStreak = StatisticsManager.calculateWorkoutStreak(workouts: workouts)
        var points: [WidgetData.WeeklyPoint] = []
        let cal = Calendar.current
        for i in (0...5).reversed() {
            if let date = cal.date(byAdding: .weekOfYear, value: -i, to: Date()) {
                let interval = cal.dateInterval(of: .weekOfYear, for: date)!
                let count = workouts.filter { interval.contains($0.date) }.count
                let fmt = DateFormatter()
                fmt.dateFormat = "M/d"
                points.append(WidgetData.WeeklyPoint(label: fmt.string(from: interval.start), count: count))
            }
        }
        WidgetDataManager.save(streak: currentStreak, weeklyStats: points)
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    func rebuildAllStats() async {
        try? modelContext.delete(model: UserStats.self)
        try? modelContext.delete(model: ExerciseStat.self)
        try? modelContext.delete(model: MuscleStat.self)
        
        guard let allWorkouts = try? modelContext.fetch(FetchDescriptor<Workout>(predicate: #Predicate<Workout> { $0.endTime != nil })) else { return }
        
        let uStats = UserStats()
        modelContext.insert(uStats)
        
        var exStatsDict: [String: ExerciseStat] = [:]
        var mStatsDict: [String: MuscleStat] = [:]
        
        for workout in allWorkouts {
            if let endTime = workout.endTime, workout.durationSeconds == 0 { workout.durationSeconds = Int(endTime.timeIntervalSince(workout.date)) }
            
            var strVol = 0.0, carDist = 0.0, totEff = 0, exComp = 0
            
            for exercise in workout.exercises {
                exercise.updateAggregates()
                let targets = exercise.isSuperset ? exercise.subExercises : [exercise]
                var hasComp = false
                
                for sub in targets {
                    sub.updateAggregates()
                    if sub.setsList.contains(where: { $0.isCompleted }) { hasComp = true }
                    if sub.type == .strength { strVol += sub.exerciseVolume }
                    else if sub.type == .cardio { carDist += sub.setsList.filter { $0.isCompleted }.compactMap { $0.distance }.reduce(0, +) }
                    
                    let exStat = exStatsDict[sub.name] ?? { let stat = ExerciseStat(exerciseName: sub.name); modelContext.insert(stat); exStatsDict[sub.name] = stat; return stat }()
                    exStat.totalCount += 1
                    if let encoded = try? JSONEncoder().encode(sub.toDTO()) { exStat.lastPerformanceDTO = encoded }
                    if sub.type == .strength {
                        let maxWeight = sub.setsList.filter { $0.isCompleted && $0.type != .warmup }.compactMap { $0.weight }.max() ?? 0
                        if maxWeight > exStat.maxWeight { exStat.maxWeight = maxWeight }
                    }
                    
                    if sub.type != .cardio && sub.type != .duration && sub.muscleGroup != "Cardio" {
                        let mStat = mStatsDict[sub.muscleGroup] ?? { let stat = MuscleStat(muscleName: sub.muscleGroup); modelContext.insert(stat); mStatsDict[sub.muscleGroup] = stat; return stat }()
                        mStat.totalCount += 1
                    }
                }
                if hasComp { totEff += exercise.effort; exComp += 1 }
            }
            workout.totalStrengthVolume = strVol; workout.totalCardioDistance = carDist
            if exComp > 0 { workout.effortPercentage = Int((Double(totEff) / Double(exComp)) * 10) }
            
            uStats.totalWorkouts += 1; uStats.totalVolume += workout.totalStrengthVolume; uStats.totalDistance += workout.totalCardioDistance
            let hour = Calendar.current.component(.hour, from: workout.date)
            if hour < 9 { uStats.earlyWorkouts += 1 }
            if hour >= 20 { uStats.nightWorkouts += 1 }
        }
        try? modelContext.save()
    }
}
