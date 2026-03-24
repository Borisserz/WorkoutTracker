//
//  WorkoutServices.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 24.12.25.
//
//  Сервисы для вынесения бизнес-логики из WorkoutViewModel.
//

import Foundation
internal import SwiftUI
internal import UniformTypeIdentifiers

// MARK: - Statistics Manager

struct StatisticsManager {
    
    static func getAllPersonalRecords(workouts: [Workout]) -> [WorkoutViewModel.BestResult] {
        var bests: [String: (result: Double, date: Date, type: ExerciseType)] = [:]
        
        for workout in workouts {
            for exercise in workout.exercises {
                let targetExercises = exercise.isSuperset ? exercise.subExercises : [exercise]
                
                for ex in targetExercises {
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
        
        return bests.map { name, data in
            var valString = ""
            switch data.type {
            case .strength: valString = String(localized: "\(Int(data.result)) \(UnitsManager.shared.weightUnitString())")
            case .cardio:
                let converted = UnitsManager.shared.convertFromMeters(data.result)
                valString = String(localized: "\(LocalizationHelper.shared.formatTwoDecimals(converted)) \(UnitsManager.shared.distanceUnitString())")
            case .duration:
                let m = Int(data.result) / 60
                let s = Int(data.result) % 60
                let sStr = String(format: "%02d", s)
                valString = String(localized: "\(m):\(sStr) min")
            }
            return WorkoutViewModel.BestResult(exerciseName: name, value: valString, date: data.date, type: data.type)
        }.sorted { $0.exerciseName < $1.exerciseName }
    }
    
    static func calculateWorkoutStreak(workouts: [Workout]) -> Int {
        guard !workouts.isEmpty else { return 0 }
        
        let maxRestDaysAllowed = UserDefaults.standard.integer(forKey: "streakRestDays")
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
        if calendar.dateComponents([.day], from: mostRecentWorkoutDate, to: Date()).day ?? 0 > maxRestDays { return 0 }
        
        var currentStreak = 1
        var lastDate = mostRecentWorkoutDate
        guard uniqueWorkoutDays.count > 1 else { return 1 }
        
        for i in 1..<uniqueWorkoutDays.count {
            let currentDate = uniqueWorkoutDays[i]
            let daysBetween = calendar.dateComponents([.day], from: currentDate, to: lastDate).day ?? 0
            if daysBetween <= maxRestDays + 1 {
                currentStreak += 1
                lastDate = currentDate
            } else { break }
        }
        return currentStreak
    }
    
    static func getStats(for dateInterval: DateInterval, workouts: [Workout]) -> WorkoutViewModel.PeriodStats {
        var stats = WorkoutViewModel.PeriodStats()
        let relevantWorkouts = workouts.filter { dateInterval.contains($0.date) }
        stats.workoutCount = relevantWorkouts.count
        
        for workout in relevantWorkouts {
            stats.totalDuration += (workout.durationSeconds / 60)
            for exercise in workout.exercises {
                stats.totalVolume += exercise.exerciseVolume
                let targetExercises = exercise.isSuperset ? exercise.subExercises : [exercise]
                for ex in targetExercises {
                    let reps = ex.setsList.filter { $0.isCompleted && $0.type != .warmup }.compactMap { $0.reps }.reduce(0, +)
                    stats.totalReps += reps
                    let dist = ex.setsList.filter { $0.isCompleted }.compactMap { $0.distance }.reduce(0, +)
                    stats.totalDistance += dist
                }
            }
        }
        return stats
    }
    
    static func getBestStats(for periodType: StatsView.Period, workouts: [Workout]) -> WorkoutViewModel.PeriodStats {
        guard !workouts.isEmpty else { return WorkoutViewModel.PeriodStats() }
        var bestStats = WorkoutViewModel.PeriodStats()
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
    
    static func getPersonalRecord(for exerciseName: String, onlyCompleted: Bool, cachedPR: Double, workouts: [Workout]) -> Double {
        if onlyCompleted { return cachedPR }
        var maxWeight = cachedPR
        for workout in workouts where workout.isActive {
            for exercise in workout.exercises {
                let targetExercises = exercise.isSuperset ? exercise.subExercises : [exercise]
                for ex in targetExercises where ex.name == exerciseName && ex.type == .strength {
                    if let maxSetWeight = ex.setsList.compactMap({ $0.weight }).max(), maxSetWeight > maxWeight {
                        maxWeight = maxSetWeight
                    }
                }
            }
        }
        return maxWeight
    }
    
    static func getRecentPRs(in interval: DateInterval, workouts: [Workout], allTimePRs: [String: Double]) -> [WorkoutViewModel.PersonalRecord] {
        var records: [WorkoutViewModel.PersonalRecord] = []
        let workoutsInPeriod = workouts.filter { interval.contains($0.date) }.sorted(by: { $0.date < $1.date })
        
        for workout in workoutsInPeriod {
            for exercise in workout.exercises {
                let targetExercises = exercise.isSuperset ? exercise.subExercises : [exercise]
                for ex in targetExercises where ex.type == .strength {
                    let maxWeight = ex.setsList.filter { $0.type != .warmup && $0.isCompleted }.compactMap { $0.weight }.max() ?? 0
                    if maxWeight > 0 {
                        let currentPR = allTimePRs[ex.name] ?? 0
                        if maxWeight >= currentPR {
                            let newPR = WorkoutViewModel.PersonalRecord(exerciseName: ex.name, weight: maxWeight, date: workout.date)
                            records.removeAll { $0.exerciseName == newPR.exerciseName }
                            records.append(newPR)
                        }
                    }
                }
            }
        }
        return records.sorted(by: { $0.date > $1.date })
    }
    
    static func getChartData(for period: StatsView.Period, metric: StatsView.GraphMetric, workouts: [Workout]) -> [WorkoutViewModel.ChartDataPoint] {
        let calendar = Calendar.current
        let now = Date()
        var data: [WorkoutViewModel.ChartDataPoint] = []
        
        switch period {
        case .week:
            guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now) else { return [] }
            let weekdays = [
                String(localized: "Вс"),
                String(localized: "Пн"),
                String(localized: "Вт"),
                String(localized: "Ср"),
                String(localized: "Чт"),
                String(localized: "Пт"),
                String(localized: "Сб")
            ]
            for i in 0..<7 {
                guard let date = calendar.date(byAdding: .day, value: i, to: weekInterval.start) else { continue }
                let dayWorkouts = workouts.filter { calendar.isDate($0.date, inSameDayAs: date) }
                let weekdayIndex = calendar.component(.weekday, from: date) - 1
                let safeIndex = max(0, min(6, weekdayIndex))
                let label = weekdays[safeIndex]
                data.append(WorkoutViewModel.ChartDataPoint(label: label, value: calculateValue(for: dayWorkouts, metric: metric)))
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
                let labelText = String(localized: "W\(week)")
                data.append(WorkoutViewModel.ChartDataPoint(label: labelText, value: calculateValue(for: wWorkouts, metric: metric)))
            }
            
            if data.isEmpty {
                for week in 1...4 {
                    data.append(WorkoutViewModel.ChartDataPoint(label: String(localized: "W\(week)"), value: 0))
                }
            }
            
        case .year:
            guard let yearInterval = calendar.dateInterval(of: .year, for: now) else { return [] }
            let symbols = calendar.shortMonthSymbols
            for month in 1...12 {
                let mWorkouts = workouts.filter {
                    yearInterval.contains($0.date) &&
                    calendar.component(.month, from: $0.date) == month
                }
                let label = symbols[month - 1]
                data.append(WorkoutViewModel.ChartDataPoint(label: label, value: calculateValue(for: mWorkouts, metric: metric)))
            }
        }
        return data
    }
    
    static func calculateValue(for workouts: [Workout], metric: StatsView.GraphMetric) -> Double {
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
}

// MARK: - Analytics Manager

struct AnalyticsManager {
    
    static func getImbalanceRecommendation(recentWorkouts: [Workout]) -> (title: String, message: String)? {
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
        if Double(chestSets) > Double(backSets) * 1.5 {
            return (String(localized: "⚠️ Imbalance Detected"), String(localized: "Last 30 days: \(chestSets) Chest sets vs \(backSets) Back sets.\nAdd more Rows or Pull-ups!"))
        }
        if legSets > 0 && Double(upperBodySets) > Double(legSets) * 3.0 {
            return (String(localized: "🦵 Don't skip Leg Day!"), String(localized: "Upper body: \(upperBodySets) sets vs Legs: \(legSets) sets.\nBalance your physique!"))
        }
        return nil
    }
    
    static func getExerciseTrends(workouts: [Workout], period: StatsView.Period = .month) -> [WorkoutViewModel.ExerciseTrend] {
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
                        let maxWeight = ex.setsList.filter { $0.isCompleted && $0.type != .warmup }.compactMap { $0.weight }.max() ?? 0
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
        
        var trends: [WorkoutViewModel.ExerciseTrend] = []
        for (name, data) in exerciseData where data.current > 0 || data.previous > 0 {
            let change: Double
            let direction: WorkoutViewModel.TrendDirection
            if data.previous == 0 { change = 100.0; direction = .growing }
            else if data.current == 0 { change = -100.0; direction = .declining }
            else {
                change = ((data.current - data.previous) / data.previous) * 100.0
                direction = abs(change) < 2.0 ? .stable : (change > 0 ? .growing : .declining)
            }
            trends.append(WorkoutViewModel.ExerciseTrend(exerciseName: name, trend: direction, changePercentage: change, currentValue: data.current, previousValue: data.previous, period: period.rawValue))
        }
        
        return trends.sorted { t1, t2 in
            if t1.trend == .growing && t2.trend != .growing { return true }
            if t1.trend != .growing && t2.trend == .growing { return false }
            return abs(t1.changePercentage) > abs(t2.changePercentage)
        }
    }
    
    static func getProgressForecast(workouts: [Workout], daysAhead: Int = 30) -> [WorkoutViewModel.ProgressForecast] {
        let now = Date()
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -90, to: now)!
        let recentWorkouts = workouts.filter { $0.date >= cutoffDate }
        var history: [String: [(date: Date, maxWeight: Double)]] = [:]
        
        for workout in recentWorkouts {
            for exercise in workout.exercises {
                let targetExercises = exercise.isSuperset ? exercise.subExercises : [exercise]
                for ex in targetExercises where ex.type == .strength {
                    let maxWeight = ex.setsList.filter { $0.isCompleted && $0.type != .warmup }.compactMap { $0.weight }.max() ?? 0
                    if maxWeight > 0 { history[ex.name, default: []].append((date: workout.date, maxWeight: maxWeight)) }
                }
            }
        }
        
        return history.compactMap { name, data -> WorkoutViewModel.ProgressForecast? in
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
            return WorkoutViewModel.ProgressForecast(exerciseName: name, currentMax: currentMax, predictedMax: predMax, confidence: confidence, timeframe: String(localized: "\(daysAhead) days"))
        }.sorted { $0.predictedMax > $1.predictedMax }
    }
    
    static func getWeakPoints(recentWorkouts: [Workout]) -> [WorkoutViewModel.WeakPoint] {
        if recentWorkouts.isEmpty { return [] }
        
        var muscleData: [String: (frequency: Int, totalVolume: Double)] = [:]
        for workout in recentWorkouts {
            var uniqueMuscles = Set<String>()
            for exercise in workout.exercises {
                let targetExercises = exercise.isSuperset ? exercise.subExercises : [exercise]
                for ex in targetExercises where ex.type == .strength {
                    let muscles = MuscleMapping.getMuscles(for: ex.name, group: ex.muscleGroup)
                    for muscle in muscles {
                        uniqueMuscles.insert(muscle)
                        let existing = muscleData[muscle] ?? (0, 0)
                        muscleData[muscle] = (existing.frequency, existing.totalVolume + ex.exerciseVolume)
                    }
                }
            }
            for muscle in uniqueMuscles {
                let existing = muscleData[muscle] ?? (0, 0)
                muscleData[muscle] = (existing.frequency + 1, existing.totalVolume)
            }
        }
        
        let count = Double(max(muscleData.count, 1))
        let avgFreq = muscleData.values.map { Double($0.frequency) }.reduce(0, +) / count
        let avgVol = muscleData.values.map { $0.totalVolume }.reduce(0, +) / count
        
        let names: [String: String] = [
            "chest": String(localized: "Chest"),
            "upper-back": String(localized: "Back"),
            "lower-back": String(localized: "Lower Back"),
            "deltoids": String(localized: "Shoulders"),
            "biceps": String(localized: "Biceps"),
            "triceps": String(localized: "Triceps"),
            "abs": String(localized: "Abs"),
            "gluteal": String(localized: "Glutes"),
            "hamstring": String(localized: "Hamstrings"),
            "quadriceps": String(localized: "Legs"),
            "calves": String(localized: "Calves")
        ]
        
        var weakPoints: [WorkoutViewModel.WeakPoint] = []
        for (slug, data) in muscleData {
            let freq = data.frequency
            let vol = data.totalVolume / Double(max(freq, 1))
            if Double(freq) < avgFreq * 0.7 || vol < avgVol * 0.7 {
                let rec = freq == 0 ? String(localized: "Start training this muscle group") : (Double(freq) < avgFreq * 0.5 ? String(localized: "Increase training frequency") : String(localized: "Increase training volume"))
                weakPoints.append(WorkoutViewModel.WeakPoint(muscleGroup: names[slug] ?? slug.capitalized, frequency: freq, averageVolume: vol, recommendation: rec))
            }
        }
        return weakPoints.sorted { $0.frequency < $1.frequency }
    }
    
    static func getRecommendations(workouts: [Workout], recoveryStatus: [WorkoutViewModel.MuscleRecoveryStatus]) -> [WorkoutViewModel.Recommendation] {
        var recs: [WorkoutViewModel.Recommendation] = []
        let now = Date()
        
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: now)!
        let recentWorkouts = workouts.filter { $0.date >= thirtyDaysAgo }
        
        let daysSince = recentWorkouts.isEmpty ? 999 : Calendar.current.dateComponents([.day], from: recentWorkouts[0].date, to: now).day ?? 0
        if daysSince > 7 {
            recs.append(WorkoutViewModel.Recommendation(type: .frequency, title: String(localized: "Increase Training Frequency"), message: String(localized: "It's been \(daysSince) days since your last workout."), priority: 5))
        } else if recentWorkouts.count < 8 {
            recs.append(WorkoutViewModel.Recommendation(type: .frequency, title: String(localized: "Build Consistency"), message: String(localized: "You've trained \(recentWorkouts.count) times in 30 days. Aim for 3-4/week!"), priority: 4))
        }
        
        if let imbalance = getImbalanceRecommendation(recentWorkouts: recentWorkouts) {
            recs.append(WorkoutViewModel.Recommendation(type: .balance, title: imbalance.title, message: imbalance.message, priority: 4))
        }
        
        let weak = getWeakPoints(recentWorkouts: recentWorkouts)
        if !weak.isEmpty {
            recs.append(WorkoutViewModel.Recommendation(type: .volume, title: String(localized: "Focus on \(weak[0].muscleGroup)"), message: weak[0].recommendation, priority: 3))
        }
        
        let declining = getExerciseTrends(workouts: workouts).filter { $0.trend == .declining && abs($0.changePercentage) > 10 }
        if let ex = declining.first {
            recs.append(WorkoutViewModel.Recommendation(type: .progression, title: String(localized: "Review \(ex.exerciseName)"), message: String(localized: "Performance decreased by \(Int(abs(ex.changePercentage)))%."), priority: 3))
        }
        
        let lowRecovery = recoveryStatus.filter { $0.recoveryPercentage < 50 }
        if !lowRecovery.isEmpty {
            recs.append(WorkoutViewModel.Recommendation(type: .recovery, title: String(localized: "Allow More Recovery"), message: String(localized: "\(lowRecovery.count) muscle groups need rest."), priority: 2))
        }
        
        if recs.isEmpty && !recentWorkouts.isEmpty {
            recs.append(WorkoutViewModel.Recommendation(type: .positive, title: String(localized: "Great Progress! 💪"), message: String(localized: "Keep up the good work!"), priority: 5))
        }
        return recs.sorted { $0.priority > $1.priority }
    }
    
    static func getDetailedComparison(workouts: [Workout], period: StatsView.Period) -> [WorkoutViewModel.DetailedComparison] {
        let cal = Calendar.current
        let now = Date()
        var curInt: DateInterval, prevInt: DateInterval
        
        switch period {
        case .week:
            curInt = cal.dateInterval(of: .weekOfYear, for: now)!
            prevInt = cal.dateInterval(of: .weekOfYear, for: cal.date(byAdding: .day, value: -7, to: now)!)!
        case .month:
            curInt = cal.dateInterval(of: .month, for: now)!
            prevInt = cal.dateInterval(of: .month, for: cal.date(byAdding: .month, value: -1, to: now)!)!
        case .year:
            curInt = cal.dateInterval(of: .year, for: now)!
            prevInt = cal.dateInterval(of: .year, for: cal.date(byAdding: .year, value: -1, to: now)!)!
        }
        
        let cur = StatisticsManager.getStats(for: curInt, workouts: workouts)
        let prev = StatisticsManager.getStats(for: prevInt, workouts: workouts)
        
        func calc(_ c: Double, _ p: Double) -> (Double, Double, WorkoutViewModel.TrendDirection) {
            let pct = p == 0 ? (c > 0 ? 100.0 : 0.0) : ((c - p) / p) * 100.0
            return (c - p, pct, abs(pct) < 2 ? .stable : (pct > 0 ? .growing : .declining))
        }
        
        var comp: [WorkoutViewModel.DetailedComparison] = []
        let (wcC, wcP, wcT) = calc(Double(cur.workoutCount), Double(prev.workoutCount))
        comp.append(.init(metric: String(localized: "Workouts"), currentValue: Double(cur.workoutCount), previousValue: Double(prev.workoutCount), change: wcC, changePercentage: wcP, trend: wcT))
        
        let (volC, volP, volT) = calc(cur.totalVolume, prev.totalVolume)
        comp.append(.init(metric: String(localized: "Total Volume"), currentValue: cur.totalVolume, previousValue: prev.totalVolume, change: volC, changePercentage: volP, trend: volT))
        
        return comp
    }
}

// MARK: - Recovery Calculator

struct RecoveryCalculator {
    static func calculate(hours: Double?, workouts: [Workout]) -> [WorkoutViewModel.MuscleRecoveryStatus] {
        var rawFatigueMap: [String: Double] = [:]
        let fullRecoveryHours = hours ?? (UserDefaults.standard.double(forKey: "userRecoveryHours") > 0 ? UserDefaults.standard.double(forKey: "userRecoveryHours") : 48.0)
        let cutoffDate = Date().addingTimeInterval(-fullRecoveryHours * 3600)
        
        for workout in workouts.filter({ $0.date >= cutoffDate && !$0.isActive }).sorted(by: { $0.date < $1.date }) {
            let hoursSince = max(0, Date().timeIntervalSince(workout.date) / 3600)
            if hoursSince >= fullRecoveryHours { continue }
            
            // Соотношение прошедшего времени к полному времени восстановления
            let timeDecay = hoursSince / fullRecoveryHours
            
            for exercise in workout.exercises {
                let targetExercises = exercise.isSuperset ? exercise.subExercises : [exercise]
                
                for ex in targetExercises { // УБРАНО ограничение where ex.type == .strength
                    
                    // 1. Базовая усталость зависит от RPE (effort 1-10 -> 0.1 - 1.0)
                    var initialFatigue = Double(ex.effort) / 10.0
                    
                    // 2. Учет объема: легкая разминка (менее 3 сетов) дает меньше усталости
                    let completedSets = ex.setsList.filter { $0.isCompleted }.count
                    let actualSetsCount = completedSets > 0 ? completedSets : ex.setsCount
                    
                    if actualSetsCount < 3 {
                        initialFatigue *= 0.7
                    }
                    
                    // 3. Вычисление текущей остаточной усталости (линейный распад)
                    let currentFatigue = max(0.0, initialFatigue - timeDecay)
                    
                    for slug in MuscleMapping.getMuscles(for: ex.name, group: ex.muscleGroup) {
                        rawFatigueMap[slug] = max(rawFatigueMap[slug] ?? 0.0, currentFatigue)
                    }
                }
            }
        }
        
        let names: [String: String] = [
            "chest": String(localized: "Chest"),
            "upper-back": String(localized: "Back"),
            "lower-back": String(localized: "Lower Back"),
            "deltoids": String(localized: "Shoulders"),
            "biceps": String(localized: "Biceps"),
            "triceps": String(localized: "Triceps"),
            "abs": String(localized: "Abs"),
            "gluteal": String(localized: "Glutes"),
            "hamstring": String(localized: "Hamstrings"),
            "quadriceps": String(localized: "Legs"),
            "calves": String(localized: "Calves")
        ]
        
        var displayFatigueMap: [String: Double] = [:]
        for (slug, fatigue) in rawFatigueMap {
            if let name = names[slug] { displayFatigueMap[name] = max(displayFatigueMap[name] ?? 0.0, fatigue) }
        }
        for name in Set(names.values) where displayFatigueMap[name] == nil { displayFatigueMap[name] = 0.0 }
        
        return displayFatigueMap.map { name, fatigue in
            WorkoutViewModel.MuscleRecoveryStatus(muscleGroup: name, recoveryPercentage: max(0, min(100, Int((1.0 - fatigue) * 100))))
        }
    }
}

// MARK: - Import Export Service

struct ImportExportService {
    enum ExportError: LocalizedError {
        case noInternet, invalidData, encodingFailed
        var errorDescription: String? { self == .noInternet ? String(localized: "Internet connection required.") : String(localized: "Data processing failed.") }
    }
    
    private static func escapeCSV(_ string: String) -> String {
        return string.contains(",") || string.contains("\"") || string.contains("\n") ? string.replacingOccurrences(of: "\"", with: "\"\"") : string
    }
    
    static func generateShareLink(for preset: WorkoutPreset) throws -> URL {
        let dto = preset.toDTO()
        let jsonData = try JSONEncoder().encode(dto)
        let compressedData = try (jsonData as NSData).compressed(using: .zlib) as Data
        var comp = URLComponents(string: "https://borisserz.github.io/workout-share/")!
        comp.queryItems = [URLQueryItem(name: "data", value: compressedData.base64EncodedString())]
        return comp.url!
    }
    
    static func exportPresetToFile(_ preset: WorkoutPreset) throws -> URL {
        let dto = preset.toDTO()
        let jsonData = try JSONEncoder().encode(dto)
        let name = preset.name.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(name).workouttemplate")
        try jsonData.write(to: tempURL)
        return tempURL
    }
    
    static func exportPresetToCSV(_ preset: WorkoutPreset) throws -> URL {
        var csvLines: [String] = []
        csvLines.append("# Workout Template Export")
        csvLines.append("# Preset Name: \(preset.name)")
        csvLines.append("# Icon: \(preset.icon)")
        csvLines.append("# Exercise Count: \(preset.exercises.count)")
        csvLines.append("")
        csvLines.append("## PRESET INFO")
        csvLines.append("Preset ID,Name,Icon,Exercise Count")
        csvLines.append("\(preset.id.uuidString),\"\(escapeCSV(preset.name))\",\(preset.icon),\(preset.exercises.count)")
        csvLines.append("")
        csvLines.append("## EXERCISES")
        csvLines.append("Exercise ID,Name,Muscle Group,Type,Effort,Is Completed,Set Count")
        for exercise in preset.exercises {
            csvLines.append("\(exercise.id.uuidString),\"\(escapeCSV(exercise.name))\",\(exercise.muscleGroup),\(exercise.type.rawValue),\(exercise.effort),\(exercise.isCompleted),\(exercise.setsList.count)")
        }
        csvLines.append("")
        csvLines.append("## SETS")
        csvLines.append("Set ID,Exercise ID,Exercise Name,Set Index,Weight,Reps,Distance (m),Time (sec),Is Completed,Set Type")
        for exercise in preset.exercises {
            for set in exercise.setsList {
                let weightStr = set.weight != nil ? String(set.weight!) : ""
                let repsStr = set.reps != nil ? String(set.reps!) : ""
                let distanceStr = set.distance != nil ? String(set.distance!) : ""
                let timeStr = set.time != nil ? String(set.time!) : ""
                csvLines.append("\(set.id.uuidString),\(exercise.id.uuidString),\"\(escapeCSV(exercise.name))\",\(set.index),\(weightStr),\(repsStr),\(distanceStr),\(timeStr),\(set.isCompleted),\(set.type.rawValue)")
            }
        }
        
        let csvContent = csvLines.joined(separator: "\n")
        guard let csvData = csvContent.data(using: .utf8) else {
            throw ExportError.encodingFailed
        }
        
        let sanitizedName = preset.name.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: "\\", with: "-").replacingOccurrences(of: ":", with: "-")
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(sanitizedName).csv")
        try csvData.write(to: tempURL)
        return tempURL
    }
    
    static func processImportedData(_ jsonData: Data) throws -> WorkoutPreset {
        let dto = try JSONDecoder().decode(WorkoutPresetDTO.self, from: jsonData)
        let preset = WorkoutPreset(from: dto)
        preset.name += " (Imported)"
        return preset
    }
    
    static func importPreset(from url: URL) throws -> WorkoutPreset {
        if url.isFileURL {
            return try processImportedData(try Data(contentsOf: url))
        } else {
            guard let comp = URLComponents(url: url, resolvingAgainstBaseURL: true),
                  let b64 = comp.queryItems?.first(where: { $0.name == "data" })?.value?.replacingOccurrences(of: " ", with: "+"),
                  let raw = Data(base64Encoded: b64, options: .ignoreUnknownCharacters) else { throw ExportError.invalidData }
            return try processImportedData((try? (raw as NSData).decompressed(using: .zlib) as Data) ?? raw)
        }
    }
}
