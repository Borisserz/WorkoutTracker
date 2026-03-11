//
//  TestDataGenerator.swift
//  WorkoutTracker
//

import Foundation
import SwiftData

class TestDataGenerator {
    
    // MARK: - Configuration
    
    private static let exerciseCatalog: [String: [String]] = Exercise.catalog
    
    private static let workoutIcons = [
        "img_chest", "img_chest2", "img_back", "img_back2",
        "img_legs", "img_legs2", "img_arms", "img_shoulders", "img_default", "figure.run"
    ]
    
    // MARK: - Main Generation Methods
    
    static func generateAllData(container: ModelContainer) async {
        await clearAllDataAsync(container: container)
        
        var components = DateComponents()
        components.year = 2021; components.month = 1; components.day = 1
        guard let startDate = Calendar.current.date(from: components) else { return }
        
        components.year = 2026; components.month = 3; components.day = 1
        guard let endDate = Calendar.current.date(from: components) else { return }
        
        await generateWorkouts(from: startDate, to: endDate, container: container)
        await generateWeights(from: startDate, to: endDate, container: container)
    }
    
    static func clearAllDataAsync(container: ModelContainer) async {
        let context = ModelContext(container)
        do {
            try context.delete(model: Workout.self)
            try context.delete(model: WeightEntry.self) // ИСПРАВЛЕНИЕ: Удаляем веса через SwiftData
            try context.save()
        } catch {
            print("Ошибка массового удаления: \(error)")
            if let workouts = try? context.fetch(FetchDescriptor<Workout>()) {
                for workout in workouts { context.delete(workout) }
            }
            if let weights = try? context.fetch(FetchDescriptor<WeightEntry>()) {
                for weight in weights { context.delete(weight) }
            }
            try? context.save()
        }
    }
    
    // MARK: - Workouts Generation
    
    private static func generateWorkouts(from startDate: Date, to endDate: Date, container: ModelContainer) async {
        var currentDate = startDate
        var workoutNumber = 0
        let calendar = Calendar.current
        
        var context = ModelContext(container)
        
        while currentDate <= endDate {
            let weekday = calendar.component(.weekday, from: currentDate)
            let isWorkoutDay = (weekday == 2 || weekday == 4 || weekday == 6 || (weekday == 7 && workoutNumber % 4 == 0))
            
            if isWorkoutDay {
                let workout = generateWorkout(for: currentDate, workoutIndex: workoutNumber)
                context.insert(workout)
                workoutNumber += 1
                
                if workoutNumber % 50 == 0 {
                    try? context.save()
                    context = ModelContext(container)
                    await Task.yield()
                }
            }
            
            if let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) {
                currentDate = nextDate
            } else { break }
        }
        
        try? context.save()
        print("✅ Сгенерировано \(workoutNumber) разнообразных тренировок.")
    }
    
    // MARK: - Weights Generation
    
    private static func generateWeights(from startDate: Date, to endDate: Date, container: ModelContainer) async {
        let startWeight = 95.0, targetWeight = 78.0
        let totalDays = Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 1
        var currentDate = startDate
        var dayOffset = 0
        
        let context = ModelContext(container)
        var count = 0
        
        while currentDate <= endDate {
            let rawProgress = Double(dayOffset) / Double(max(totalDays, 1))
            let plateauEffect = sin(rawProgress * .pi * 4) * 0.1
            let progressFactor = min(1.0, max(0.0, rawProgress + plateauEffect))
            
            let expectedWeight = startWeight - (startWeight - targetWeight) * progressFactor
            let dailyVariation = Double.random(in: -0.4...0.4)
            let weeklyVariation = sin(Double(dayOffset) / 7.0 * 2 * .pi) * 0.6
            
            let currentWeight = max(60.0, min(120.0, expectedWeight + dailyVariation + weeklyVariation))
            
            // ИСПРАВЛЕНИЕ: Вставляем в БД
            context.insert(WeightEntry(date: currentDate, weight: currentWeight))
            count += 1
            
            let jump = Int.random(in: 2...5)
            dayOffset += jump
            if let nextDate = Calendar.current.date(byAdding: .day, value: jump, to: currentDate) {
                currentDate = nextDate
            } else { break }
        }
        
        try? context.save()
        print("✅ Сгенерировано \(count) записей о весе.")
    }
    
    // MARK: - Workout Generation Details
    
    private enum WorkoutType: String, CaseIterable {
        case push = "Push Day"
        case pull = "Pull Day"
        case legs = "Legs Day"
        case upper = "Upper Body"
        case lower = "Lower Body"
        case fullBody = "Full Body"
        case chestAndTri = "Chest & Triceps"
        case backAndBi = "Back & Biceps"
        case shouldersArms = "Shoulders & Arms"
        case cardio = "Cardio & Core"
        case hiit = "HIIT Blast"
    }
    
    private static func determineWorkoutType(index: Int) -> WorkoutType {
        let cycle: [WorkoutType] = [
            .push, .pull, .legs,
            .upper, .lower, .cardio,
            .chestAndTri, .backAndBi, .shouldersArms,
            .fullBody, .hiit
        ]
        return cycle[index % cycle.count]
    }
    
    private static func generateWorkout(for date: Date, workoutIndex: Int) -> Workout {
        let type = determineWorkoutType(index: workoutIndex)
        var exercises = generateExercises(for: type, workoutIndex: workoutIndex)
        
        if Bool.random() && Bool.random() && exercises.count >= 3 {
            exercises = createRandomSuperset(from: exercises)
        }
        
        let duration = Int.random(in: 40...100) * 60
        let endTime = date.addingTimeInterval(TimeInterval(duration))
        let icon = workoutIcons[workoutIndex % workoutIcons.count]
        
        return Workout(title: type.rawValue, date: date, endTime: endTime, icon: icon, exercises: exercises)
    }
    
    private static func generateExercises(for type: WorkoutType, workoutIndex: Int) -> [Exercise] {
        var ex: [Exercise] = []
        
        switch type {
        case .push:
            ex += fetchStrength(group: "Chest", count: Int.random(in: 2...3), index: workoutIndex)
            ex += fetchStrength(group: "Shoulders", count: 2, index: workoutIndex)
            ex += fetchStrength(group: "Arms", count: 1, subFilter: "Tricep", index: workoutIndex)
        case .pull:
            ex += fetchStrength(group: "Back", count: Int.random(in: 3...4), index: workoutIndex)
            ex += fetchStrength(group: "Arms", count: 2, subFilter: "Bicep", index: workoutIndex)
        case .legs:
            ex += fetchStrength(group: "Legs", count: Int.random(in: 4...5), index: workoutIndex)
            ex += fetchDuration(group: "Core", count: 1, index: workoutIndex)
        case .upper:
            ex += fetchStrength(group: "Chest", count: 2, index: workoutIndex)
            ex += fetchStrength(group: "Back", count: 2, index: workoutIndex)
            ex += fetchStrength(group: "Shoulders", count: 1, index: workoutIndex)
            ex += fetchStrength(group: "Arms", count: 1, index: workoutIndex)
        case .lower:
            ex += fetchStrength(group: "Legs", count: 4, index: workoutIndex)
            ex += fetchDuration(group: "Core", count: 2, index: workoutIndex)
        case .fullBody:
            for g in ["Legs", "Back", "Chest", "Shoulders", "Arms"] {
                ex += fetchStrength(group: g, count: 1, index: workoutIndex)
            }
        case .chestAndTri:
            ex += fetchStrength(group: "Chest", count: 4, index: workoutIndex)
            ex += fetchStrength(group: "Arms", count: 3, subFilter: "Tricep", index: workoutIndex)
        case .backAndBi:
            ex += fetchStrength(group: "Back", count: 4, index: workoutIndex)
            ex += fetchStrength(group: "Arms", count: 3, subFilter: "Bicep", index: workoutIndex)
        case .shouldersArms:
            ex += fetchStrength(group: "Shoulders", count: 3, index: workoutIndex)
            ex += fetchStrength(group: "Arms", count: 2, subFilter: "Bicep", index: workoutIndex)
            ex += fetchStrength(group: "Arms", count: 2, subFilter: "Tricep", index: workoutIndex)
        case .cardio:
            ex += fetchCardio(count: 2, index: workoutIndex)
            ex += fetchDuration(group: "Core", count: 2, index: workoutIndex)
        case .hiit:
            ex += fetchCardio(count: 1, index: workoutIndex)
            ex += fetchDuration(group: "Core", count: 1, index: workoutIndex)
            ex += fetchDuration(group: "Legs", count: 1, index: workoutIndex)
        }
        return ex
    }
    
    private static func fetchStrength(group: String, count: Int, subFilter: String? = nil, index: Int) -> [Exercise] {
        var pool = exerciseCatalog[group] ?? []
        if let filter = subFilter {
            let filtered = pool.filter { $0.localizedCaseInsensitiveContains(filter) || $0.localizedCaseInsensitiveContains(filter.replacingOccurrences(of: "p", with: "ps")) || $0.localizedCaseInsensitiveContains("extension") }
            if !filtered.isEmpty { pool = filtered }
        }
        var result: [Exercise] = []
        let shuffled = pool.shuffled()
        for i in 0..<min(count, shuffled.count) {
            result.append(buildStrength(name: shuffled[i], group: group, index: index))
        }
        return result
    }
    
    private static func fetchCardio(count: Int, index: Int) -> [Exercise] {
        let pool = (exerciseCatalog["Cardio"] ?? []).shuffled()
        var result: [Exercise] = []
        for i in 0..<min(count, pool.count) {
            result.append(buildCardio(name: pool[i], index: index))
        }
        return result
    }
    
    private static func fetchDuration(group: String, count: Int, index: Int) -> [Exercise] {
        let pool = (exerciseCatalog[group] ?? []).shuffled()
        var result: [Exercise] = []
        for i in 0..<min(count, pool.count) {
            result.append(buildDuration(name: pool[i], group: group, index: index))
        }
        return result
    }
    
    private static func buildStrength(name: String, group: String, index: Int) -> Exercise {
        let baseGroupWeight: Double
        switch group {
        case "Legs": baseGroupWeight = 70.0
        case "Back": baseGroupWeight = 55.0
        case "Chest": baseGroupWeight = 50.0
        case "Shoulders": baseGroupWeight = 25.0
        case "Arms": baseGroupWeight = 15.0
        default: baseGroupWeight = 20.0
        }
        var actualWeight = baseGroupWeight
        var actualReps = 10
        let n = name.lowercased()
        
        if n.contains("squat") || n.contains("deadlift") || n.contains("press") {
            actualWeight *= 1.4
            actualReps = Int.random(in: 5...8)
        } else if n.contains("curl") || n.contains("raise") || n.contains("fly") || n.contains("extension") {
            actualWeight *= 0.6
            actualReps = Int.random(in: 10...15)
        }
        
        let cappedIndex = min(Double(index), 600.0)
        let fatigueWave = sin(cappedIndex / 15.0) * 0.1
        let progressFactor = 1.0 + (cappedIndex / 600.0) + fatigueWave
        let finalWeight = actualWeight * progressFactor + Double.random(in: -2...4)
        let setsCount = Int.random(in: 3...5)
        var setsList: [WorkoutSet] = []
        
        for i in 1...setsCount {
            let isWarmup = (i == 1 && setsCount > 3)
            let isFailure = (i == setsCount && Bool.random())
            let setType: SetType = isWarmup ? .warmup : (isFailure ? .failure : .normal)
            let setW = isWarmup ? finalWeight * 0.6 : finalWeight + Double.random(in: -2...2)
            let setR = isWarmup ? actualReps + 4 : actualReps + Int.random(in: -2...1)
            
            setsList.append(WorkoutSet(index: i, weight: max(2.5, setW), reps: max(1, setR), isCompleted: true, type: setType))
        }
        let effort = Int.random(in: 6...10)
        return Exercise(name: name, muscleGroup: group, type: .strength, sets: setsCount, reps: actualReps, weight: finalWeight, effort: effort, setsList: setsList, isCompleted: true)
    }
    
    private static func buildCardio(name: String, index: Int) -> Exercise {
        let distance = 3.0 + (Double(index) / 200.0) + Double.random(in: -1...2)
        let timeMinutes = Int(15 + (distance * 5) + Double.random(in: -5...5))
        let set = WorkoutSet(index: 1, distance: max(1.0, distance), time: timeMinutes * 60, isCompleted: true, type: .normal)
        return Exercise(name: name, muscleGroup: "Cardio", type: .cardio, sets: 1, reps: 0, weight: 0, distance: max(1.0, distance), timeSeconds: timeMinutes * 60, effort: Int.random(in: 5...9), setsList: [set], isCompleted: true)
    }
    
    private static func buildDuration(name: String, group: String, index: Int) -> Exercise {
        let time = 45 + Int.random(in: -15...45)
        let setsCount = Int.random(in: 2...4)
        var setsList: [WorkoutSet] = []
        for i in 1...setsCount {
            setsList.append(WorkoutSet(index: i, time: time + Int.random(in: -5...10), isCompleted: true, type: .normal))
        }
        return Exercise(name: name, muscleGroup: group, type: .duration, sets: setsCount, reps: 0, weight: 0, timeSeconds: time, effort: Int.random(in: 6...9), setsList: setsList, isCompleted: true)
    }
    
    private static func createRandomSuperset(from exercises: [Exercise]) -> [Exercise] {
        guard exercises.count >= 2 else { return exercises }
        var result = exercises
        let idx = Int.random(in: 0..<(result.count - 1))
        let ex1 = result[idx]
        let ex2 = result[idx + 1]
        
        let superset = Exercise(
            name: "Superset",
            muscleGroup: "Multiple",
            type: .strength,
            effort: max(ex1.effort, ex2.effort),
            subExercises: [ex1, ex2],
            isCompleted: true
        )
        
        result.remove(at: idx + 1)
        result.remove(at: idx)
        result.insert(superset, at: idx)
        return result
    }
}

