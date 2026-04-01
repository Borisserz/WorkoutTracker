import Foundation
import SwiftData
import WidgetKit
internal import SwiftUI

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

struct StatsDataResultDTO: Sendable {
    let currentStats: WorkoutViewModel.PeriodStats
    let previousStats: WorkoutViewModel.PeriodStats
    let recentPRs: [WorkoutViewModel.PersonalRecord]
    let detailedComparison: [WorkoutViewModel.DetailedComparison]
    let chartData: [WorkoutViewModel.ChartDataPoint]
}

// MARK: - Workout Repository (@ModelActor)
@ModelActor
actor WorkoutRepository {
    
    // MARK: - Explicit CRUD Operations for WorkoutViewModel
    
    func addSet(toExerciseID: PersistentIdentifier, index: Int, weight: Double?, reps: Int?, distance: Double?, time: Int?, type: SetType, isCompleted: Bool) throws {
        guard let exercise = modelContext.model(for: toExerciseID) as? Exercise else { throw WorkoutRepositoryError.modelNotFound }
        let newSet = WorkoutSet(index: index, weight: weight, reps: reps, distance: distance, time: time, isCompleted: isCompleted, type: type)
        modelContext.insert(newSet)
        exercise.setsList.append(newSet)
        exercise.updateAggregates()
        try modelContext.save()
    }
    
    func deleteSet(setID: PersistentIdentifier, fromExerciseID: PersistentIdentifier) throws {
        guard let exercise = modelContext.model(for: fromExerciseID) as? Exercise,
              let set = modelContext.model(for: setID) as? WorkoutSet else { throw WorkoutRepositoryError.modelNotFound }
        
        if let index = exercise.setsList.firstIndex(where: { $0.persistentModelID == setID }) {
            exercise.setsList.remove(at: index)
        }
        modelContext.delete(set)
        
        let remainingSets = exercise.sortedSets
        for (i, remainingSet) in remainingSets.enumerated() {
            remainingSet.index = i + 1
        }
        exercise.updateAggregates()
        try modelContext.save()
    }
    
    func removeSubExercise(subID: PersistentIdentifier, fromSupersetID: PersistentIdentifier) throws {
        guard let superset = modelContext.model(for: fromSupersetID) as? Exercise,
              let subExercise = modelContext.model(for: subID) as? Exercise else { throw WorkoutRepositoryError.modelNotFound }
        
        if let index = superset.subExercises.firstIndex(where: { $0.persistentModelID == subID }) {
            superset.subExercises.remove(at: index)
        }
        modelContext.delete(subExercise)
        superset.updateAggregates()
        try modelContext.save()
    }
    
    func removeExercise(exerciseID: PersistentIdentifier, fromWorkoutID: PersistentIdentifier) throws {
        guard let workout = modelContext.model(for: fromWorkoutID) as? Workout,
              let exercise = modelContext.model(for: exerciseID) as? Exercise else { throw WorkoutRepositoryError.modelNotFound }
        
        if let index = workout.exercises.firstIndex(where: { $0.persistentModelID == exerciseID }) {
            workout.exercises.remove(at: index)
        }
        modelContext.delete(exercise)
        try modelContext.save()
    }
    
    // MARK: - Data Fetching (Background Safe)
    
    func fetchStatsData(
        period: StatsView.Period,
        metric: StatsView.GraphMetric,
        currentInterval: DateInterval,
        previousInterval: DateInterval,
        prCache: [String: Double]
    ) async -> StatsDataResultDTO {
        let minDate = previousInterval.start
        let maxDate = currentInterval.end
        
        var descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate<Workout> { $0.date >= minDate && $0.date <= maxDate },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.relationshipKeyPathsForPrefetching = [\.exercises]
        
        let bgWorkouts = (try? modelContext.fetch(descriptor)) ?? []
        
        // Считаем все прямо в ModelActor, это безопасно и не фризит UI
        let currentStats = StatisticsManager.getStats(for: currentInterval, workouts: bgWorkouts)
        let previousStats = StatisticsManager.getStats(for: previousInterval, workouts: bgWorkouts)
        let recentPRs = StatisticsManager.getRecentPRs(in: currentInterval, workouts: bgWorkouts, allTimePRs: prCache)
        let detailedComparison = AnalyticsManager.getDetailedComparison(workouts: bgWorkouts, period: period)
        let chartData = StatisticsManager.getChartData(for: period, metric: metric, workouts: bgWorkouts)
        
        return StatsDataResultDTO(
            currentStats: currentStats,
            previousStats: previousStats,
            recentPRs: recentPRs,
            detailedComparison: detailedComparison,
            chartData: chartData
        )
    }

    // MARK: - Core Database Mutations
    
    func processCompletedWorkout(workoutID: PersistentIdentifier) async throws {
        guard let workout = modelContext.model(for: workoutID) as? Workout else { throw WorkoutRepositoryError.modelNotFound }
        if let endTime = workout.endTime { workout.durationSeconds = Int(endTime.timeIntervalSince(workout.date)) } else { workout.durationSeconds = 0 }
        
        var totalEffort = 0, exercisesWithCompletedSets = 0, strengthVol = 0.0, cardioDist = 0.0
        
        for exercise in workout.exercises {
            let targets = exercise.isSuperset ? exercise.subExercises : [exercise]
            var hasCompletedSet = false
            
            // 1. UPDATE CHILDREN FIRST
            for sub in targets {
                sub.updateAggregates()
                if sub.setsList.contains(where: { $0.isCompleted }) { hasCompletedSet = true }
                if sub.type == .strength { strengthVol += sub.exerciseVolume }
                else if sub.type == .cardio { cardioDist += sub.setsList.filter { $0.isCompleted }.compactMap { $0.distance }.reduce(0.0, +) }
            }
            
            // 2. UPDATE PARENT SECOND (so it can read children's correct volumes)
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
                
                // Кодируем DTO прямо в контексте ModelActor
                let encodedData = try? JSONEncoder().encode(ex.toDTO())
                if let encodedData { exStat.lastPerformanceDTO = encodedData }
                
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
        guard let workout = modelContext.model(for: workoutID) as? Workout else {
            throw WorkoutRepositoryError.modelNotFound
        }
        
        // 1. Deduct stats from UserStats BEFORE deleting the workout
        if let uStats = (try? modelContext.fetch(FetchDescriptor<UserStats>()))?.first {
            uStats.totalWorkouts = max(0, uStats.totalWorkouts - 1)
            uStats.totalVolume = max(0, uStats.totalVolume - workout.totalStrengthVolume)
            uStats.totalDistance = max(0, uStats.totalDistance - workout.totalCardioDistance)
            
            let hour = Calendar.current.component(.hour, from: workout.date)
            if hour < 9 { uStats.earlyWorkouts = max(0, uStats.earlyWorkouts - 1) }
            if hour >= 20 { uStats.nightWorkouts = max(0, uStats.nightWorkouts - 1) }
        }
        
        // 2. Deduct from MuscleStats and ExerciseStats
        let exStatsDict = Dictionary(uniqueKeysWithValues: ((try? modelContext.fetch(FetchDescriptor<ExerciseStat>())) ?? []).map { ($0.exerciseName, $0) })
        let mStatsDict = Dictionary(uniqueKeysWithValues: ((try? modelContext.fetch(FetchDescriptor<MuscleStat>())) ?? []).map { ($0.muscleName, $0) })
        
        for exercise in workout.exercises {
            let targets = exercise.isSuperset ? exercise.subExercises : [exercise]
            for ex in targets {
                if let exStat = exStatsDict[ex.name] {
                    exStat.totalCount = max(0, exStat.totalCount - 1)
                }
                if ex.type != .cardio && ex.type != .duration {
                    if let mStat = mStatsDict[ex.muscleGroup] {
                        mStat.totalCount = max(0, mStat.totalCount - 1)
                    }
                }
            }
        }
        
        // 3. Delete and save
        modelContext.delete(workout)
        try modelContext.save()
    }

    func cleanupAndFindActiveWorkouts() async throws -> Bool {
        let desc = FetchDescriptor<Workout>(predicate: #Predicate<Workout> { $0.endTime == nil })
        let activeWorkouts = (try? modelContext.fetch(desc)) ?? []
        var hasActive = false
        for workout in activeWorkouts {
            let hoursSinceStart = Date().timeIntervalSince(workout.date) / 3600
            if hoursSinceStart > 12 {
                workout.endTime = workout.date.addingTimeInterval(3600)
                try await processCompletedWorkout(workoutID: workout.persistentModelID)
            } else {
                hasActive = true
            }
        }
        try modelContext.save()
        return hasActive
    }
    
    // MARK: - Caching
    
    func fetchDashboardCache() async throws -> DashboardCacheDTO {
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
        
        // Считаем тяжелую математику в фоне ModelActor, без MainActor
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
    
    // MARK: - Dictionary Management
    
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
                try? modelContext.save()
                
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
                try? modelContext.save()
            }
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

    func updateWidgetData() async throws {
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
    
    // MARK: - Stats Rebuild
    
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
                    
                    // Кодируем прямо в ModelActor
                    let encodedData = try? JSONEncoder().encode(sub.toDTO())
                    if let encodedData { exStat.lastPerformanceDTO = encodedData }
                    
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
    
    // MARK: - Safe Backend Operations
        
    func finishWorkoutAndCalculateAchievements(workoutID: PersistentIdentifier) async throws -> (newUnlocks: [Achievement], totalCount: Int) {
        // 1. Процессим тренировку (сохраняем время, тоннаж и тд)
        try await processCompletedWorkout(workoutID: workoutID)
        
        // 2. Достаем статистику
        let stats = (try? modelContext.fetch(FetchDescriptor<UserStats>()))?.first ?? UserStats()
        
        let descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate<Workout> { $0.endTime != nil },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let workouts = (try? modelContext.fetch(descriptor)) ?? []
        
        // 3. Считаем ДО (прямо здесь, без MainActor)
        let oldWorkouts = workouts.count > 1 ? Array(workouts.dropFirst()) : []
        let oldStreak = StatisticsManager.calculateWorkoutStreak(workouts: oldWorkouts)
        
        let cal = Calendar.current
        let oldWeekendWorkouts = oldWorkouts.filter { cal.component(.weekday, from: $0.date) == 1 || cal.component(.weekday, from: $0.date) == 7 }.count
        let oldLunchWorkouts = oldWorkouts.filter { let h = cal.component(.hour, from: $0.date); return h >= 11 && h <= 14 }.count
        
        let oldAchievements = AchievementCalculator.calculateAchievements(
            totalWorkouts: stats.totalWorkouts - 1, totalVolume: stats.totalVolume - (workouts.first?.totalStrengthVolume ?? 0), totalDistance: stats.totalDistance - (workouts.first?.totalCardioDistance ?? 0),
            earlyWorkouts: stats.earlyWorkouts, nightWorkouts: stats.nightWorkouts, streak: oldStreak,
            weekendWorkouts: oldWeekendWorkouts, lunchWorkouts: oldLunchWorkouts, unitsManager: UnitsManager.shared
        )
        
        // 4. Считаем ПОСЛЕ
        let newStreak = StatisticsManager.calculateWorkoutStreak(workouts: workouts)
        let newWeekendWorkouts = workouts.filter { cal.component(.weekday, from: $0.date) == 1 || cal.component(.weekday, from: $0.date) == 7 }.count
        let newLunchWorkouts = workouts.filter { let h = cal.component(.hour, from: $0.date); return h >= 11 && h <= 14 }.count
        
        let newAchievements = AchievementCalculator.calculateAchievements(
            totalWorkouts: stats.totalWorkouts, totalVolume: stats.totalVolume, totalDistance: stats.totalDistance,
            earlyWorkouts: stats.earlyWorkouts, nightWorkouts: stats.nightWorkouts, streak: newStreak,
            weekendWorkouts: newWeekendWorkouts, lunchWorkouts: newLunchWorkouts, unitsManager: UnitsManager.shared
        )
        
        // 5. Ищем разницу
        var newUnlocks: [Achievement] = []
        for i in 0..<newAchievements.count {
            guard i < oldAchievements.count else { break }
            if newAchievements[i].tier != oldAchievements[i].tier && newAchievements[i].tier != .none {
                newUnlocks.append(newAchievements[i])
            }
        }
        
        let currentUnlockedCount = newAchievements.filter { $0.isUnlocked }.count
        return (newUnlocks, currentUnlockedCount)
    }

    func applyAIAdjustment(_ adjustment: InWorkoutResponseDTO, workoutID: PersistentIdentifier) throws {
        guard let workout = modelContext.model(for: workoutID) as? Workout, workout.isActive else { return }
        
        switch adjustment.actionType {
        case "reduceRemainingLoad":
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
            
        case "skipExercise":
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
            
        case "dropWeight":
            guard let targetName = adjustment.targetExerciseName,
                  let targetExercise = workout.exercises.first(where: { $0.name.lowercased() == targetName.lowercased() }) else { break }
            if let nextSet = targetExercise.setsList.sorted(by: { $0.index < $1.index }).first(where: { !$0.isCompleted }) {
                if let currentWeight = nextSet.weight, let percentage = adjustment.valuePercentage {
                    nextSet.weight = round((currentWeight * (1.0 - (percentage / 100.0))) / 2.5) * 2.5
                }
            }
            targetExercise.updateAggregates()
            
        case "addSet":
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
            
        case "replaceExercise":
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
        default: break
        }
        try modelContext.save()
    }
}
