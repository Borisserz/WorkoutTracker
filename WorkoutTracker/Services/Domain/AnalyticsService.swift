

import Foundation
import SwiftData

actor AnalyticsService {
    private let workoutStore: WorkoutStoreProtocol
    let modelContainer: ModelContainer

    init(workoutStore: WorkoutStoreProtocol, modelContainer: ModelContainer) {
        self.workoutStore = workoutStore
        self.modelContainer = modelContainer
    }

    func fetchDashboardCache() async throws -> DashboardCacheDTO {
           let bgContext = ModelContext(modelContainer)

           let exStats = (try? bgContext.fetch(FetchDescriptor<ExerciseStat>())) ?? []
           let mStats = (try? bgContext.fetch(FetchDescriptor<MuscleStat>())) ?? []

           var partialLastPerformances: [String: Data] = [:]
           var partialPRs: [String: Double] = [:]
           var exerciseCounts: [String: Int] = [:]
           var stats: [String: Int] = [:]

           for ex in exStats {
               partialPRs[ex.exerciseName] = ex.maxWeight
               exerciseCounts[ex.exerciseName] = ex.totalCount
               if let data = ex.lastPerformanceDTO { partialLastPerformances[ex.exerciseName] = data }
           }
        for m in mStats {
            let broadCategory = MuscleCategoryMapper.getBroadCategory(for: m.muscleName)
            if broadCategory != "Other" {
                stats[broadCategory, default: 0] += m.totalCount
            }
        }

           let threeMonthsAgo = Calendar.current.date(byAdding: .month, value: -3, to: Date())!
           var recentDesc = FetchDescriptor<Workout>(
               predicate: #Predicate<Workout> { $0.endTime != nil && $0.date >= threeMonthsAgo },
               sortBy: [SortDescriptor(\.date, order: .reverse)]
           )
           recentDesc.fetchLimit = 150

           let recentWorkouts = (try? bgContext.fetch(recentDesc)) ?? []

           let fullRecoveryHours = UserDefaults.standard.double(forKey: Constants.UserDefaultsKeys.userRecoveryHours.rawValue) > 0 ? UserDefaults.standard.double(forKey: Constants.UserDefaultsKeys.userRecoveryHours.rawValue) : 48.0
           let recoveryCutoffDate = Date().addingTimeInterval(-fullRecoveryHours * 3600)
           let recoveryWorkouts = recentWorkouts.filter { $0.date >= recoveryCutoffDate }

        let recovery = await calculateRecovery(hours: fullRecoveryHours, workouts: recoveryWorkouts)

           let sortedMuscleData = stats.map { MuscleCountDTO(muscle: $0.key, count: $0.value) }.filter { $0.count > 0 }.sorted { $0.count > $1.count }
           let totalExCount = sortedMuscleData.reduce(0) { $0 + $1.count }
           let topExercises = Array(exerciseCounts.sorted { $0.value > $1.value || ($0.value == $1.value && $0.key < $1.key) }.prefix(5)).map { ExerciseCountDTO(name: $0.key, count: $0.value) }

           let streak = calculateWorkoutStreak(workouts: recentWorkouts)
           let bWeek = getBestStats(for: .week, workouts: recentWorkouts)
           let bMonth = getBestStats(for: .month, workouts: recentWorkouts)
           let weakPts = getWeakPoints(recentWorkouts: recentWorkouts)
           let recs = getRecommendations(workouts: recentWorkouts, recoveryStatus: recovery)

           return DashboardCacheDTO(personalRecords: partialPRs, lastPerformances: partialLastPerformances, recoveryStatus: recovery, dashboardMuscleData: sortedMuscleData, dashboardTotalExercises: totalExCount, dashboardTopExercises: topExercises, streakCount: streak, bestWeekStats: bWeek, bestMonthStats: bMonth, weakPoints: weakPts, recommendations: recs)
       }

    func fetchStatsData(
        period: StatsView.Period,
        metric: StatsView.GraphMetric,
        currentInterval: DateInterval,
        previousInterval: DateInterval,
        prCache: [String: Double]
    ) async -> StatsDataResultDTO {
        let bgContext = ModelContext(modelContainer)
        let minDate = previousInterval.start
        let maxDate = currentInterval.end

        var descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate<Workout> { $0.date >= minDate && $0.date <= maxDate },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.relationshipKeyPathsForPrefetching = [\.exercises]

        let bgWorkouts = (try? bgContext.fetch(descriptor)) ?? []

        let currentStats = getStats(for: currentInterval, workouts: bgWorkouts)
        let previousStats = getStats(for: previousInterval, workouts: bgWorkouts)
        let recentPRs = getRecentPRs(in: currentInterval, workouts: bgWorkouts, allTimePRs: prCache)
        let detailedComparison = getDetailedComparison(workouts: bgWorkouts, period: period)
        let chartData = getChartData(for: period, metric: metric, workouts: bgWorkouts)

        return StatsDataResultDTO(
            currentStats: currentStats,
            previousStats: previousStats,
            recentPRs: recentPRs,
            detailedComparison: detailedComparison,
            chartData: chartData
        )
    }

    func fetchExerciseHistoryData(exerciseName: String) async -> ExerciseHistoryPayload? {
           let bgContext = ModelContext(modelContainer)
           let filter = #Predicate<Exercise> { ex in ex.name == exerciseName && ex.preset == nil }
           let descriptor = FetchDescriptor<Exercise>(predicate: filter)

           guard let fetchedExercises = try? bgContext.fetch(descriptor), !fetchedExercises.isEmpty else {
               return nil
           }

           var foundType: ExerciseType = .strength
           var foundCategory: ExerciseCategory = .other
           var foundMuscle: String = "Other"

           var workoutMap: [UUID: (workout: Workout, exercises: [Exercise])] = [:]

           for ex in fetchedExercises {
               let targetWorkout = ex.workout ?? ex.parentExercise?.workout
               if let w = targetWorkout, w.endTime != nil {
                   if workoutMap[w.id] == nil {
                       workoutMap[w.id] = (w, [ex])
                   } else {
                       workoutMap[w.id]?.exercises.append(ex)
                   }
               }
               foundType = ex.type
               foundCategory = ex.category
               foundMuscle = ex.muscleGroup
           }

           var filteredWorkouts: [Workout] = []
           var rawDataPoints: [ExerciseHistoryDataPoint] = []

           var globalMaxSetReps = 0
           var globalMaxWorkoutReps = 0
           var globalMaxSetVolume = 0.0
           var globalMaxWorkoutVolume = 0.0

           for (_, data) in workoutMap {
               let bestExercise = data.exercises.max { e1, e2 in
                   let max1 = e1.setsList.compactMap { $0.weight }.max() ?? 0
                   let max2 = e2.setsList.compactMap { $0.weight }.max() ?? 0
                   return max1 < max2
               } ?? data.exercises.first!

               filteredWorkouts.append(data.workout)

               var currentWorkoutReps = 0
                        var currentWorkoutVolume = 0.0

                        for exercise in data.exercises {
                            let validSets = exercise.setsList.filter { $0.isCompleted && $0.type != .warmup }

                            for set in validSets {
                                let r = set.reps ?? 0
                                let w = set.weight ?? 0.0
                                let v = w * Double(r)

                                currentWorkoutReps += r
                                currentWorkoutVolume += v

                                if r > globalMaxSetReps { globalMaxSetReps = r }
                                if v > globalMaxSetVolume { globalMaxSetVolume = v }
                            }
                        }

               if currentWorkoutReps > globalMaxWorkoutReps { globalMaxWorkoutReps = currentWorkoutReps }
               if currentWorkoutVolume > globalMaxWorkoutVolume { globalMaxWorkoutVolume = currentWorkoutVolume }

               var rawValue: Double = 0.0
               switch foundType {
               case .strength:
                   rawValue = bestExercise.setsList.filter { $0.isCompleted && $0.type != .warmup }.compactMap { $0.weight }.max() ?? 0.0
               case .cardio:
                   rawValue = bestExercise.setsList.filter { $0.isCompleted }.compactMap { $0.distance }.reduce(0, +)
               case .duration:
                   let sec = bestExercise.setsList.filter { $0.isCompleted }.compactMap { $0.time }.reduce(0, +)
                   rawValue = Double(sec)
               }

               if rawValue > 0 {
                   rawDataPoints.append(ExerciseHistoryDataPoint(date: data.workout.date, value: rawValue, rawWorkoutID: data.workout.persistentModelID))
               }
           }

           let trend = getExerciseTrends(workouts: filteredWorkouts, period: .month).first(where: { $0.exerciseName == exerciseName })
           let forecast = getProgressForecast(workouts: filteredWorkouts).first(where: { $0.exerciseName == exerciseName })

           var sortedPoints = rawDataPoints
           sortedPoints.sort { $0.date < $1.date }

           let recordsDTO = ExerciseRecordsDTO(
               maxSetReps: globalMaxSetReps,
               maxWorkoutReps: globalMaxWorkoutReps,
               maxSetVolume: globalMaxSetVolume,
               maxWorkoutVolume: globalMaxWorkoutVolume
           )

           return ExerciseHistoryPayload(
               type: foundType,
               category: foundCategory,
               muscleGroup: foundMuscle,
               dataPoints: sortedPoints,
               trend: trend,
               forecast: forecast,
               records: recordsDTO 
           )
       }

    func rebuildAllStats() async {
        let bgContext = ModelContext(modelContainer)

        try? bgContext.delete(model: UserStats.self)
        try? bgContext.delete(model: ExerciseStat.self)
        try? bgContext.delete(model: MuscleStat.self)
        try? bgContext.save()

        var totalWorkouts = 0
        var totalVolume = 0.0
        var totalDistance = 0.0
        var earlyWorkouts = 0
        var nightWorkouts = 0

        struct ExStatAccumulator {
            var count: Int = 0
            var maxWeight: Double = 0.0
            var lastDTO: Data? = nil
        }
        var exStatsDict: [String: ExStatAccumulator] = [:]
        var mStatsDict: [String: Int] = [:]

        let batchSize = 50
        var offset = 0
        var hasMoreData = true

        while hasMoreData {
            let batchContext = ModelContext(modelContainer)
            batchContext.autosaveEnabled = false

            var descriptor = FetchDescriptor<Workout>(
                predicate: #Predicate<Workout> { $0.endTime != nil },
                sortBy: [SortDescriptor(\.date, order: .forward)]
            )
            descriptor.fetchLimit = batchSize
            descriptor.fetchOffset = offset

            let batch = (try? batchContext.fetch(descriptor)) ?? []
            if batch.isEmpty {
                hasMoreData = false
                break
            }

            autoreleasepool {

                            let includeWarmups = UserDefaults.standard.bool(forKey: Constants.UserDefaultsKeys.includeWarmupsInStats.rawValue)

                            for workout in batch {
                                if let endTime = workout.endTime, workout.durationSeconds == 0 {
                                    workout.durationSeconds = Int(endTime.timeIntervalSince(workout.date))
                                }

                                var strVol = 0.0, carDist = 0.0, totEff = 0, exComp = 0

                                for exercise in workout.exercises {
                                    let targets = exercise.isSuperset ? exercise.subExercises : [exercise]
                                    var hasComp = false

                                    for sub in targets {
                                        let completedSets = sub.setsList.filter { $0.isCompleted }
                                        if !completedSets.isEmpty { hasComp = true }

                                        var currentVol = 0.0
                                        if sub.type == .strength {

                                            let validSets = completedSets.filter { includeWarmups || $0.type != .warmup }

                                            var tempVol = 0.0
                                            for set in validSets {
                                                let w = set.weight ?? 0.0
                                                let r = Double(set.reps ?? 0)
                                                tempVol += (w * r)
                                            }
                                            currentVol = tempVol
                                            strVol += currentVol
                                        } else if sub.type == .cardio {
                                            carDist += completedSets.compactMap { $0.distance }.reduce(0, +)
                                        }

                                        var exStat = exStatsDict[sub.name] ?? ExStatAccumulator()
                                        exStat.count += 1
                                        if let encodedData = try? JSONEncoder().encode(sub.toDTO()) {
                                            exStat.lastDTO = encodedData
                                        }
                                        if sub.type == .strength {

                                            let validSets = completedSets.filter { includeWarmups || $0.type != .warmup }
                                            let maxW = validSets.compactMap { $0.weight }.max() ?? 0
                                            if maxW > exStat.maxWeight { exStat.maxWeight = maxW }
                                        }
                                        exStatsDict[sub.name] = exStat

                                        if sub.type != .cardio && sub.type != .duration && sub.muscleGroup != "Cardio" {
                                            mStatsDict[sub.muscleGroup, default: 0] += 1
                                        }
                                    }

                                    if hasComp { totEff += exercise.effort; exComp += 1 }
                                }

                                workout.totalStrengthVolume = strVol
                                workout.totalCardioDistance = carDist
                                if exComp > 0 { workout.effortPercentage = Int((Double(totEff) / Double(exComp)) * 10) }

                                totalWorkouts += 1
                                totalVolume += strVol
                                totalDistance += carDist

                                let hour = Calendar.current.component(.hour, from: workout.date)
                                if hour < 9 { earlyWorkouts += 1 }
                                if hour >= 20 { nightWorkouts += 1 }
                            }
                            try? batchContext.save()
                        }
            offset += batchSize
        }

        let newUStats = UserStats(totalWorkouts: totalWorkouts, totalVolume: totalVolume, totalDistance: totalDistance, earlyWorkouts: earlyWorkouts, nightWorkouts: nightWorkouts)
        bgContext.insert(newUStats)

        for (name, data) in exStatsDict {
            bgContext.insert(ExerciseStat(exerciseName: name, maxWeight: data.maxWeight, totalCount: data.count, lastPerformanceDTO: data.lastDTO))
        }

        for (muscle, count) in mStatsDict {
            bgContext.insert(MuscleStat(muscleName: muscle, totalCount: count))
        }

        try? bgContext.save()
    }

    func getAllPersonalRecords(workouts: [Workout], unitsManager: UnitsManager) -> [BestResult] {

            var bests: [String: (result: Double, reps: Int, date: Date, type: ExerciseType, isBodyweight: Bool)] = [:]

            func typeRank(_ type: ExerciseType) -> Int {
                switch type {
                case .strength: return 3
                case .cardio: return 2
                case .duration: return 1
                }
            }

            for workout in workouts {
                for exercise in workout.exercises {
                    let targetExercises = exercise.isSuperset ? exercise.subExercises : [exercise]
                    for ex in targetExercises {
                        var currentValue: Double = 0
                        var currentReps: Int = 0
                        var isBW = false

                        switch ex.type {
                        case .strength:

                            let validSets = ex.setsList.filter { $0.isCompleted && $0.type != .warmup }

                            if let bestSet = validSets.max(by: {
                                let w1 = $0.weight ?? 0.0
                                let w2 = $1.weight ?? 0.0
                                if w1 == w2 { return ($0.reps ?? 0) < ($1.reps ?? 0) }
                                return w1 < w2
                            }) {
                                currentValue = bestSet.weight ?? 0.0
                                currentReps = bestSet.reps ?? 0
                                isBW = (currentValue <= 0.0)

                                if isBW {
                                    currentValue = Double(validSets.compactMap { $0.reps }.max() ?? 0)
                                    currentReps = Int(currentValue)
                                }
                            }

                        case .cardio:
                            currentValue = ex.setsList.filter { $0.isCompleted }.compactMap { $0.distance }.reduce(0, +)
                        case .duration:
                            currentValue = Double(ex.setsList.filter { $0.isCompleted }.compactMap { $0.time }.reduce(0, +))
                        }

                        let currentTypeRank = typeRank(ex.type)
                        let existing = bests[ex.name]

                        if let existingRecord = existing {
                            let existingRank = typeRank(existingRecord.type)

                            if currentTypeRank > existingRank {
                                if currentValue > 0 {
                                    bests[ex.name] = (result: currentValue, reps: currentReps, date: workout.date, type: ex.type, isBodyweight: isBW)
                                }
                            } else if currentTypeRank == existingRank {

                                if currentValue > existingRecord.result {
                                    bests[ex.name] = (result: currentValue, reps: currentReps, date: workout.date, type: ex.type, isBodyweight: isBW)
                                } else if currentValue == existingRecord.result && currentReps > existingRecord.reps {

                                    bests[ex.name] = (result: currentValue, reps: currentReps, date: workout.date, type: ex.type, isBodyweight: isBW)
                                }
                            }
                        } else {
                            if currentValue > 0 {
                                bests[ex.name] = (result: currentValue, reps: currentReps, date: workout.date, type: ex.type, isBodyweight: isBW)
                            }
                        }
                    }
                }
            }

            return bests.map { name, data in
                var valString = ""
                switch data.type {
                case .strength:
                    if data.isBodyweight {

                        valString = String(localized: "\(data.reps) reps")
                    } else {

                        let convertedWeight = unitsManager.convertFromKilograms(data.result)
                        let weightStr = LocalizationHelper.shared.formatFlexible(convertedWeight)
                        let unitStr = unitsManager.weightUnitString()
                        valString = "\(weightStr) \(unitStr) × \(data.reps)"
                    }
                case .cardio:
                    let convertedDist = unitsManager.convertFromMeters(data.result)
                    valString = String(localized: "\(LocalizationHelper.shared.formatTwoDecimals(convertedDist)) \(unitsManager.distanceUnitString())")
                case .duration:
                    let m = Int(data.result) / 60
                    let s = Int(data.result) % 60
                    let sStr = String(format: "%02d", s)
                    valString = String(localized: "\(m):\(sStr) min")
                }
                return BestResult(exerciseName: name, value: valString, date: data.date, type: data.type)
            }.sorted { $0.exerciseName < $1.exerciseName }
        }

        func calculateWorkoutStreak(workouts: [Workout]) -> Int {
            let maxRestDaysAllowed = UserDefaults.standard.integer(forKey: Constants.UserDefaultsKeys.streakRestDays.rawValue)
            let maxRestDays = maxRestDaysAllowed > 0 ? maxRestDaysAllowed : 2

            let workoutDates = workouts.map { $0.date }

            return StreakCalculator.calculate(from: workoutDates, maxRestDays: maxRestDays)
        }

    func getStats(for dateInterval: DateInterval, workouts: [Workout]) -> PeriodStats {
            var stats = PeriodStats()
            let relevantWorkouts = workouts.filter { dateInterval.contains($0.date) }
            stats.workoutCount = relevantWorkouts.count

            for workout in relevantWorkouts {
                stats.totalDuration += (workout.durationSeconds / 60)

                stats.totalVolume += workout.totalStrengthVolume
                stats.totalDistance += workout.totalCardioDistance
                stats.totalReps += workout.totalReps
            }
            return stats
        }
    func getBestStats(for periodType: StatsView.Period, workouts: [Workout]) -> PeriodStats {
        guard !workouts.isEmpty else { return PeriodStats() }
        var bestStats = PeriodStats()
        let calendar = Calendar.current
        let groupedWorkouts: [DateInterval: [Workout]]

        switch periodType {
        case .week: groupedWorkouts = Dictionary(grouping: workouts, by: { calendar.dateInterval(of: .weekOfYear, for: $0.date)! })
        case .month: groupedWorkouts = Dictionary(grouping: workouts, by: { calendar.dateInterval(of: .month, for: $0.date)! })
        case .year: groupedWorkouts = Dictionary(grouping: workouts, by: { calendar.dateInterval(of: .year, for: $0.date)! })
        }

        for (interval, _) in groupedWorkouts {
            let stats = getStats(for: interval, workouts: workouts)
            if stats.workoutCount > bestStats.workoutCount { bestStats = stats }
        }
        return bestStats
    }

    func getRecentPRs(in interval: DateInterval, workouts: [Workout], allTimePRs: [String: Double]) -> [PersonalRecord] {
            var records: [PersonalRecord] = []
            let workoutsInPeriod = workouts.filter { interval.contains($0.date) }.sorted(by: { $0.date < $1.date })

            for workout in workoutsInPeriod {
                for exercise in workout.exercises {
                    let targetExercises = exercise.isSuperset ? exercise.subExercises : [exercise]
                    for ex in targetExercises where ex.type == .strength {

                        let maxWeight = ex.cachedMaxWeight
                        if maxWeight > 0 {
                            let currentPR = allTimePRs[ex.name] ?? 0
                            if maxWeight >= currentPR {
                                let newPR = PersonalRecord(exerciseName: ex.name, weight: maxWeight, date: workout.date)
                                records.removeAll { $0.exerciseName == newPR.exerciseName }
                                records.append(newPR)
                            }
                        }
                    }
                }
            }
            return records.sorted(by: { $0.date > $1.date })
        }

    func getChartData(for period: StatsView.Period, metric: StatsView.GraphMetric, workouts: [Workout]) -> [ChartDataPoint] {
        let calendar = Calendar.current
        let now = Date()
        var data: [ChartDataPoint] = []

        switch period {
        case .week:
            guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now) else { return [] }
            let weekdays = [String(localized: "Sun"), String(localized: "Mon"), String(localized: "Tue"), String(localized: "Wed"), String(localized: "Thu"), String(localized: "Fri"), String(localized: "Sat")]
            for i in 0..<7 {
                guard let date = calendar.date(byAdding: .day, value: i, to: weekInterval.start) else { continue }
                let dayWorkouts = workouts.filter { calendar.isDate($0.date, inSameDayAs: date) }
                let weekdayIndex = calendar.component(.weekday, from: date) - 1
                let safeIndex = max(0, min(6, weekdayIndex))
                let label = weekdays[safeIndex]
                data.append(ChartDataPoint(label: label, value: calculateValue(for: dayWorkouts, metric: metric)))
            }
        case .month:
            guard let monthInterval = calendar.dateInterval(of: .month, for: now) else { return [] }
            let daysInMonth = calendar.range(of: .day, in: .month, for: monthInterval.start)?.count ?? 30
            var weeksData: [Int: [Workout]] = [:]
            for i in 0..<daysInMonth {
                guard let date = calendar.date(byAdding: .day, value: i, to: monthInterval.start) else { continue }
                let weekOfMonth = calendar.component(.weekOfMonth, from: date)
                let dayWorkouts = workouts.filter { calendar.isDate($0.date, inSameDayAs: date) }
                weeksData[weekOfMonth, default: []].append(contentsOf: dayWorkouts)
            }
            let sortedWeeks = weeksData.keys.sorted()
            for week in sortedWeeks {
                let wWorkouts = weeksData[week] ?? []
                data.append(ChartDataPoint(label: String(localized: "W\(week)"), value: calculateValue(for: wWorkouts, metric: metric)))
            }
            if data.isEmpty { for week in 1...4 { data.append(ChartDataPoint(label: String(localized: "W\(week)"), value: 0)) } }
        case .year:
            guard let yearInterval = calendar.dateInterval(of: .year, for: now) else { return [] }
            let symbols = calendar.shortMonthSymbols
            for month in 1...12 {
                let mWorkouts = workouts.filter { yearInterval.contains($0.date) && calendar.component(.month, from: $0.date) == month }
                data.append(ChartDataPoint(label: symbols[month - 1], value: calculateValue(for: mWorkouts, metric: metric)))
            }
        }
        return data
    }

    func calculateValue(for workouts: [Workout], metric: StatsView.GraphMetric) -> Double {
        switch metric {
        case .count: return Double(workouts.count)
        case .volume: return workouts.reduce(0.0) { $0 + $1.exercises.reduce(0.0) { $0 + $1.exerciseVolume } }
        case .time: return Double(workouts.reduce(0) { $0 + ($1.durationSeconds / 60) })
        case .distance:
            return workouts.reduce(0.0) { wSum, w in
                wSum + w.exercises.reduce(0.0) { eSum, e in
                    let subExs = e.isSuperset ? e.subExercises : [e]
                    let dist = subExs.reduce(0.0) { s, sub in s + sub.setsList.filter { $0.isCompleted }.compactMap { $0.distance }.reduce(0, +) }
                    return eSum + dist
                }
            }
        }
    }

    func getImbalanceRecommendation(recentWorkouts: [Workout]) -> (title: String, message: String)? {
        if recentWorkouts.isEmpty { return nil }
        var chestSets = 0, backSets = 0, legSets = 0, upperBodySets = 0
        for workout in recentWorkouts {
            for exercise in workout.exercises where exercise.type == .strength {
                let list = exercise.isSuperset ? exercise.subExercises : [exercise]
                for ex in list {
                    let completedSets = ex.setsList.filter { $0.isCompleted && $0.type != .warmup }.count
                    let count = ex.setsList.isEmpty ? ex.setsCount : completedSets
                    if ex.muscleGroup == "Chest" { chestSets += count }
                    if ex.muscleGroup == "Back" { backSets += count }
                    if ex.muscleGroup == "Legs" { legSets += count }
                    else if ["Chest", "Back", "Shoulders", "Arms"].contains(ex.muscleGroup) { upperBodySets += count }
                }
            }
        }
        if (chestSets + backSets) < 10 { return nil }
        if Double(chestSets) > Double(backSets) * 1.5 { return (String(localized: "⚠️ Imbalance Detected"), String(localized: "Last 30 days: \(chestSets) Chest sets vs \(backSets) Back sets.\nAdd more Rows or Pull-ups!")) }
        if legSets > 0 && Double(upperBodySets) > Double(legSets) * 3.0 { return (String(localized: "🦵 Don't skip Leg Day!"), String(localized: "Upper body: \(upperBodySets) sets vs Legs: \(legSets) sets.\nBalance your physique!")) }
        return nil
    }

    func getExerciseTrends(workouts: [Workout], period: StatsView.Period = .month) -> [ExerciseTrend] {
            let calendar = Calendar.current
            let now = Date()
            var currentInterval: DateInterval, previousInterval: DateInterval

            switch period {
            case .week:
                currentInterval = calendar.dateInterval(of: .weekOfYear, for: now)!
                previousInterval = calendar.dateInterval(of: .weekOfYear, for: calendar.date(byAdding: .day, value: -7, to: now)!)!
            case .month:
                currentInterval = calendar.dateInterval(of: .month, for: now)!
                previousInterval = calendar.dateInterval(of: .month, for: calendar.date(byAdding: .month, value: -1, to: now)!)!
            case .year:
                currentInterval = calendar.dateInterval(of: .year, for: now)!
                previousInterval = calendar.dateInterval(of: .year, for: calendar.date(byAdding: .year, value: -1, to: now)!)!
            }

            let currentWorkouts = workouts.filter { currentInterval.contains($0.date) }
            let previousWorkouts = workouts.filter { previousInterval.contains($0.date) }
            var exerciseData: [String: (current: Double, previous: Double, count: Int)] = [:]

            let processWorkouts = { (works: [Workout], isCurrent: Bool) in
                for workout in works {
                    for exercise in workout.exercises {
                        let targetExercises = exercise.isSuperset ? exercise.subExercises : [exercise]
                        for ex in targetExercises where ex.type == .strength {

                            let maxWeight = ex.cachedMaxWeight
                            if maxWeight > 0 {
                                let existing = exerciseData[ex.name] ?? (0, 0, 0)
                                if isCurrent {
                                    exerciseData[ex.name] = (max(existing.current, maxWeight), existing.previous, existing.count + 1)
                                } else {
                                    exerciseData[ex.name] = (existing.current, max(existing.previous, maxWeight), existing.count)
                                }
                            }
                        }
                    }
                }
            }

            processWorkouts(currentWorkouts, true)
            processWorkouts(previousWorkouts, false)

            var trends: [ExerciseTrend] = []
            for (name, data) in exerciseData where data.current > 0 || data.previous > 0 {
                let change: Double
                let direction: TrendDirection
                if data.previous == 0 { change = 100.0; direction = .growing }
                else if data.current == 0 { change = -100.0; direction = .declining }
                else {
                    change = ((data.current - data.previous) / data.previous) * 100.0
                    direction = abs(change) < 2.0 ? .stable : (change > 0 ? .growing : .declining)
                }
                trends.append(ExerciseTrend(exerciseName: name, trend: direction, changePercentage: change, currentValue: data.current, previousValue: data.previous, period: period.rawValue))
            }

            return trends.sorted { t1, t2 in
                if t1.trend == .growing && t2.trend != .growing { return true }
                if t1.trend != .growing && t2.trend == .growing { return false }
                return abs(t1.changePercentage) > abs(t2.changePercentage)
            }
        }
    func getProgressForecast(workouts: [Workout], daysAhead: Int = 30) -> [ProgressForecast] {
            let now = Date()
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -90, to: now)!
            let recentWorkouts = workouts.filter { $0.date >= cutoffDate }
            var history: [String: [(date: Date, maxWeight: Double)]] = [:]

            for workout in recentWorkouts {
                for exercise in workout.exercises {
                    let targetExercises = exercise.isSuperset ? exercise.subExercises : [exercise]
                    for ex in targetExercises where ex.type == .strength {

                        let maxWeight = ex.cachedMaxWeight
                        if maxWeight > 0 {
                            history[ex.name, default: []].append((date: workout.date, maxWeight: maxWeight))
                        }
                    }
                }
            }

            return history.compactMap { name, data -> ProgressForecast? in
                guard data.count >= 3 else { return nil }
                let sorted = data.sorted { $0.date < $1.date }
                let currentMax = sorted.last!.maxWeight
                let daysFromStart = sorted.map { now.timeIntervalSince($0.date) / 86400 }
                let weights = sorted.map { $0.maxWeight }

                var totalInc = 0.0, totalDays = 0.0, posChanges = 0, negChanges = 0
                for i in 1..<sorted.count {
                    let daysDiff = abs(daysFromStart[i] - daysFromStart[i-1])
                    if daysDiff > 0 {
                        let wDiff = weights[i] - weights[i-1]
                        totalInc += wDiff; totalDays += daysDiff
                        if wDiff > 0 { posChanges += 1 } else if wDiff < 0 { negChanges += 1 }
                    }
                }

                let avgInc = totalDays > 0 ? totalInc / totalDays : 0
                let predMax = max(currentMax, currentMax + (avgInc * Double(daysAhead)))
                let dataScore = min(70, max(30, sorted.count * 8))
                let trendBonus = avgInc > 0 ? 15 : 0
                let totalChanges = posChanges + negChanges
                let consistencyBonus = totalChanges > 0 ? (Double(posChanges)/Double(totalChanges) >= 0.7 ? 15 : (Double(posChanges)/Double(totalChanges) >= 0.5 ? 5 : -10)) : 0
                let timeSpanBonus = min(10, Int((daysFromStart.first! - daysFromStart.last!) / 30))

                let confidence = min(100, max(30, dataScore + trendBonus + consistencyBonus + timeSpanBonus))
                return ProgressForecast(exerciseName: name, currentMax: currentMax, predictedMax: predMax, confidence: confidence, timeframe: String(localized: "\(daysAhead) days"))
            }.sorted { $0.predictedMax > $1.predictedMax }
        }

    func getWeakPoints(recentWorkouts: [Workout]) -> [WeakPoint] {
            if recentWorkouts.isEmpty { return [] }

            var muscleMap: [String: (freq: Int, vol: Double)] = [:]

            for workout in recentWorkouts {
                var uniqueMusclesForWorkout = Set<String>()

                for exercise in workout.exercises {
                    let targets = exercise.isSuperset ? exercise.subExercises : [exercise]
                    for ex in targets where ex.type == .strength {
                        let muscles = MuscleMapping.getMuscles(for: ex.name, group: ex.muscleGroup)
                        for muscle in muscles {
                            uniqueMusclesForWorkout.insert(muscle)
                            let current = muscleMap[muscle] ?? (0, 0.0)
                            muscleMap[muscle] = (current.freq, current.vol + ex.cachedVolume)
                        }
                    }
                }

                for muscle in uniqueMusclesForWorkout {
                    let current = muscleMap[muscle] ?? (0, 0.0)
                    muscleMap[muscle] = (current.freq + 1, current.vol)
                }
            }

            let rawData = muscleMap.map {
                WeakPointCalculator.MuscleRawData(slug: $0.key, frequency: $0.value.freq, totalVolume: $0.value.vol)
            }

            return WeakPointCalculator.calculate(from: rawData)
        }

    func getRecommendations(workouts: [Workout], recoveryStatus: [MuscleRecoveryStatus]) -> [Recommendation] {
        var recs: [Recommendation] = []
        let now = Date()
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: now)!
        let recentWorkouts = workouts.filter { $0.date >= thirtyDaysAgo }

        let daysSince = recentWorkouts.isEmpty ? 999 : Calendar.current.dateComponents([.day], from: recentWorkouts[0].date, to: now).day ?? 0
        if daysSince > 7 { recs.append(Recommendation(id: UUID(), type: .frequency, title: String(localized: "Increase Training Frequency"), message: String(localized: "It's been \(daysSince) days since your last workout."), priority: 5)) }
        else if recentWorkouts.count < 8 { recs.append(Recommendation(id: UUID(), type: .frequency, title: String(localized: "Build Consistency"), message: String(localized: "You've trained \(recentWorkouts.count) times in 30 days. Aim for 3-4/week!"), priority: 4)) }

        if let imbalance = getImbalanceRecommendation(recentWorkouts: recentWorkouts) { recs.append(Recommendation(id: UUID(), type: .balance, title: imbalance.title, message: imbalance.message, priority: 4)) }
        let weak = getWeakPoints(recentWorkouts: recentWorkouts)
        if !weak.isEmpty { recs.append(Recommendation(id: UUID(), type: .volume, title: String(localized: "Focus on \(weak[0].muscleGroup)"), message: weak[0].recommendation, priority: 3)) }

        let declining = getExerciseTrends(workouts: workouts).filter { $0.trend == .declining && abs($0.changePercentage) > 10 }
        if let ex = declining.first { recs.append(Recommendation(id: UUID(), type: .progression, title: String(localized: "Review \(ex.exerciseName)"), message: String(localized: "Performance decreased by \(Int(abs(ex.changePercentage)))%."), priority: 3)) }

        let lowRecovery = recoveryStatus.filter { $0.recoveryPercentage < 50 }
        if !lowRecovery.isEmpty { recs.append(Recommendation(id: UUID(), type: .recovery, title: String(localized: "Allow More Recovery"), message: String(localized: "\(lowRecovery.count) muscle groups need rest."), priority: 2)) }

        if recs.isEmpty && !recentWorkouts.isEmpty { recs.append(Recommendation(id: UUID(), type: .positive, title: String(localized: "Great Progress! 💪"), message: String(localized: "Keep up the good work!"), priority: 5)) }
        return recs.sorted { $0.priority > $1.priority }
    }

    func getDetailedComparison(workouts: [Workout], period: StatsView.Period) -> [DetailedComparison] {
        let cal = Calendar.current; let now = Date()
        var curInt: DateInterval, prevInt: DateInterval
        switch period {
        case .week: curInt = cal.dateInterval(of: .weekOfYear, for: now)!; prevInt = cal.dateInterval(of: .weekOfYear, for: cal.date(byAdding: .day, value: -7, to: now)!)!
        case .month: curInt = cal.dateInterval(of: .month, for: now)!; prevInt = cal.dateInterval(of: .month, for: cal.date(byAdding: .month, value: -1, to: now)!)!
        case .year: curInt = cal.dateInterval(of: .year, for: now)!; prevInt = cal.dateInterval(of: .year, for: cal.date(byAdding: .year, value: -1, to: now)!)!
        }
        let cur = getStats(for: curInt, workouts: workouts)
        let prev = getStats(for: prevInt, workouts: workouts)

        func calc(_ c: Double, _ p: Double) -> (Double, Double, TrendDirection) {
            let pct = p == 0 ? (c > 0 ? 100.0 : 0.0) : ((c - p) / p) * 100.0
            return (c - p, pct, abs(pct) < 2 ? .stable : (pct > 0 ? .growing : .declining))
        }
        var comp: [DetailedComparison] = []
                let (wcC, wcP, wcT) = calc(Double(cur.workoutCount), Double(prev.workoutCount))

                comp.append(.init(metric: "Workouts", currentValue: Double(cur.workoutCount), previousValue: Double(prev.workoutCount), change: wcC, changePercentage: wcP, trend: wcT))
                let (volC, volP, volT) = calc(cur.totalVolume, prev.totalVolume)

                comp.append(.init(metric: "Total Volume", currentValue: cur.totalVolume, previousValue: prev.totalVolume, change: volC, changePercentage: volP, trend: volT))
                return comp
    }

    func calculateRecovery(hours: Double, workouts: [Workout]) async -> [MuscleRecoveryStatus] {
            var rawFatigueMap: [String: Double] = [:]

            for workout in workouts.filter({ !$0.isActive }).sorted(by: { $0.date < $1.date }) {
                let hoursSince = max(0, Date().timeIntervalSince(workout.date) / 3600)
                if hoursSince >= hours { continue }
                let timeDecay = hoursSince / hours

                for exercise in workout.exercises {
                    let targetExercises = exercise.isSuperset ? exercise.subExercises : [exercise]
                    for ex in targetExercises {
                        var initialFatigue = Double(ex.effort) / 10.0

                        let completedSets = ex.setsCount
                        if completedSets < 3 { initialFatigue *= 0.7 }

                        let currentFatigue = max(0.0, initialFatigue - timeDecay)

                        let activations = await ExerciseDatabaseService.shared.getMuscleActivations(
                            for: ex.name,
                            fallbackGroup: ex.muscleGroup
                        )

                        for activation in activations {

                            let appliedFatigue = currentFatigue * activation.multiplier
                            rawFatigueMap[activation.slug] = max(rawFatigueMap[activation.slug] ?? 0.0, appliedFatigue)
                        }
                    }
                }
            }

            let allSlugs = ["chest", "obliques", "abs", "biceps", "triceps", "neck", "trapezius", "deltoids", "adductors", "quadriceps", "knees", "tibialis", "calves", "forearm", "hands", "ankles", "feet", "head", "hair", "upper-back", "lower-back", "gluteal", "hamstring"]
            var displayFatigueMap: [String: Double] = [:]
            for slug in allSlugs { displayFatigueMap[slug] = rawFatigueMap[slug] ?? 0.0 }

            return displayFatigueMap.map { slug, fatigue in
                MuscleRecoveryStatus(muscleGroup: slug, recoveryPercentage: max(0, min(100, Int((1.0 - fatigue) * 100))))
            }
        }

    func fetchTrainingStyleStats(for interval: DateInterval?, workouts: [Workout]) async -> TrainingStyleDTO {
           let validWorkouts = interval != nil ? workouts.filter { interval!.contains($0.date) } : workouts

           var compound = 0
           var isolation = 0
           var equipmentStats: [EquipmentCategory: Int] = [.freeWeights: 0, .machines: 0, .bodyweight: 0, .other: 0]

           let dbItems = await ExerciseDatabaseService.shared.getAllExerciseItems()
           let dbDict = Dictionary(uniqueKeysWithValues: dbItems.map { ($0.name.lowercased(), $0) })
           let includeWarmups = UserDefaults.standard.bool(forKey: Constants.UserDefaultsKeys.includeWarmupsInStats.rawValue)

           for workout in validWorkouts {
               for exercise in workout.exercises {
                   let targets = exercise.isSuperset ? exercise.subExercises : [exercise]
                   for sub in targets where sub.type == .strength {
                       let completedSets = sub.setsList.filter { $0.isCompleted && (includeWarmups || $0.type != .warmup) }.count
                       guard completedSets > 0 else { continue }

                       let dbItem = dbDict[sub.name.lowercased()]

                       let mechanic = dbItem?.mechanic?.lowercased() ?? "compound"
                       if mechanic == "isolation" {
                           isolation += completedSets
                       } else {
                           compound += completedSets
                       }

                       let eq = dbItem?.equipment?.lowercased() ?? "bodyweight"
                       let category: EquipmentCategory

                       if eq.contains("barbell") || eq.contains("dumbbell1") || eq.contains("kettlebell") {
                           category = .freeWeights
                       } else if eq.contains("machine") || eq.contains("cable") || eq.contains("band") {
                           category = .machines
                       } else if eq.contains("body") || eq == "bodyweight" {
                           category = .bodyweight
                       } else {
                           category = .other
                       }

                       equipmentStats[category, default: 0] += completedSets
                   }
               }
           }

           return TrainingStyleDTO(
               compoundSets: compound,
               isolationSets: isolation,
               equipmentDistribution: equipmentStats
           )
       }

    func finishWorkoutAndCalculateAchievements(workoutID: PersistentIdentifier) async throws -> (newUnlocks: [Achievement], totalCount: Int) {

        let bgContext = ModelContext(modelContainer)
        try await workoutStore.processCompletedWorkout(workoutID: workoutID)

        let stats = (try? bgContext.fetch(FetchDescriptor<UserStats>()))?.first ?? UserStats()

        let descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate<Workout> { $0.endTime != nil },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let workouts = (try? bgContext.fetch(descriptor)) ?? []

        let oldWorkouts = workouts.count > 1 ? Array(workouts.dropFirst()) : []
        let oldStreak = calculateWorkoutStreak(workouts: oldWorkouts)

        let cal = Calendar.current
        let oldWeekendWorkouts = oldWorkouts.filter { cal.component(.weekday, from: $0.date) == 1 || cal.component(.weekday, from: $0.date) == 7 }.count
        let oldLunchWorkouts = oldWorkouts.filter { let h = cal.component(.hour, from: $0.date); return h >= 11 && h <= 14 }.count

        let oldAchievements = AchievementCalculator.calculateAchievements(
            totalWorkouts: stats.totalWorkouts - 1, totalVolume: stats.totalVolume - (workouts.first?.totalStrengthVolume ?? 0), totalDistance: stats.totalDistance - (workouts.first?.totalCardioDistance ?? 0),
            earlyWorkouts: stats.earlyWorkouts, nightWorkouts: stats.nightWorkouts, streak: oldStreak,
            weekendWorkouts: oldWeekendWorkouts, lunchWorkouts: oldLunchWorkouts, unitsManager: UnitsManager.shared
        )

        let newStreak = calculateWorkoutStreak(workouts: workouts)
        let newWeekendWorkouts = workouts.filter { cal.component(.weekday, from: $0.date) == 1 || cal.component(.weekday, from: $0.date) == 7 }.count
        let newLunchWorkouts = workouts.filter { let h = cal.component(.hour, from: $0.date); return h >= 11 && h <= 14 }.count

        let newAchievements = AchievementCalculator.calculateAchievements(
            totalWorkouts: stats.totalWorkouts, totalVolume: stats.totalVolume, totalDistance: stats.totalDistance,
            earlyWorkouts: stats.earlyWorkouts, nightWorkouts: stats.nightWorkouts, streak: newStreak,
            weekendWorkouts: newWeekendWorkouts, lunchWorkouts: newLunchWorkouts, unitsManager: UnitsManager.shared
        )

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
    func fetchRecentWorkoutsForAnalytics() async -> [Workout] {
           let bgContext = ModelContext(modelContainer)
           let descriptor = FetchDescriptor<Workout>(sortBy: [SortDescriptor(\.date, order: .reverse)])
           return (try? bgContext.fetch(descriptor)) ?? []
       }

        func fetchAnatomyStats(for interval: DateInterval, workouts: [Workout]) -> AnatomyStatsDTO {
            let filteredWorkouts = workouts.filter { interval.contains($0.date) }
            var muscleSets: [String: Int] = [:]

            for workout in filteredWorkouts {
                for exercise in workout.exercises {
                    let targets = exercise.isSuperset ? exercise.subExercises : [exercise]
                    for ex in targets where ex.type == .strength {
                        let completedSets = ex.setsList.filter { $0.isCompleted && $0.type != .warmup }.count
                        if completedSets > 0 {
                            let broadCategory = MuscleCategoryMapper.getBroadCategory(for: ex.muscleGroup)
                            if broadCategory != "Other" {
                                muscleSets[broadCategory, default: 0] += completedSets
                            }
                        }
                    }
                }
            }

            let maxSets = Double(muscleSets.values.max() ?? 1)

            let radarAxes = ["Chest", "Back", "Legs", "Shoulders", "Arms", "Core"]
            let radarData = radarAxes.map { axis -> RadarDataPoint in
                let sets = Double(muscleSets[axis] ?? 0)
                return RadarDataPoint(axis: axis, value: sets, maxValue: max(maxSets, 10.0))
            }

            var heatmapData: [String: Int] = [:]
            for (group, sets) in muscleSets {
                let slugs = MuscleMapping.getMuscles(for: "Unknown", group: group)
                for slug in slugs {
                    heatmapData[slug, default: 0] += sets
                }
            }

            let sortedSets = muscleSets.map { MuscleCountDTO(muscle: $0.key, count: $0.value) }.sorted { $0.count > $1.count }

            return AnatomyStatsDTO(radarData: radarData, heatmapIntensities: heatmapData, setsPerMuscle: sortedSets)
        }

        func fetchSetsOverTime(period: StatsView.Period, workouts: [Workout]) -> [SetsOverTimePoint] {
            let calendar = Calendar.current
            let now = Date()
            var data: [SetsOverTimePoint] = []

            let interval: DateInterval
            switch period {
            case .week: interval = calendar.dateInterval(of: .weekOfYear, for: now)!
            case .month: interval = calendar.dateInterval(of: .month, for: now)!
            case .year: interval = calendar.dateInterval(of: .year, for: now)!
            }

            let filteredWorkouts = workouts.filter { interval.contains($0.date) }

            for workout in filteredWorkouts {
                var dailySets: [String: Int] = [:]
                for ex in workout.exercises {
                    let targets = ex.isSuperset ? ex.subExercises : [ex]
                    for sub in targets where sub.type == .strength {
                        let sets = sub.setsList.filter { $0.isCompleted && $0.type != .warmup }.count
                        if sets > 0 {
                            let broadCategory = MuscleCategoryMapper.getBroadCategory(for: sub.muscleGroup)
                            if broadCategory != "Other" {
                                dailySets[broadCategory, default: 0] += sets
                            }
                        }
                    }
                }
                for (group, count) in dailySets {
                    data.append(SetsOverTimePoint(date: calendar.startOfDay(for: workout.date), muscleGroup: group, sets: count))
                }
            }

            return data.sorted { $0.date < $1.date }
        }
}
