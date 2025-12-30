import Foundation
internal import SwiftUI

struct Achievement: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let icon: String // Имя SF Symbol
    let color: Color
    
    // Статус
    var isUnlocked: Bool = false
    var progress: String = "" // Например "5/10"
}

class AchievementCalculator {
    
    // Главная функция: берет все тренировки и выдает список ачивок со статусами
    static func calculateAchievements(workouts: [Workout], streak: Int) -> [Achievement] {
        var list: [Achievement] = []
        
        // --- 1. АЧИВКИ НА КОЛИЧЕСТВО ---
        let count = workouts.count
        list.append(Achievement(
            title: "First Step",
            description: "Complete your first workout.",
            icon: "figure.walk",
            color: .green,
            isUnlocked: count >= 1,
            progress: "\(count)/1"
        ))
        
        list.append(Achievement(
            title: "Consistent",
            description: "Complete 10 workouts.",
            icon: "figure.run",
            color: .blue,
            isUnlocked: count >= 10,
            progress: "\(min(count, 10))/10"
        ))
        
        list.append(Achievement(
            title: "Gym Rat",
            description: "Complete 50 workouts.",
            icon: "dumbbell.fill",
            color: .purple,
            isUnlocked: count >= 50,
            progress: "\(min(count, 50))/50"
        ))
        
        // --- 2. СТРИКИ ---
        list.append(Achievement(
            title: "On Fire",
            description: "Maintain a 3-day streak.",
            icon: "flame.fill",
            color: .orange,
            isUnlocked: streak >= 3,
            progress: "\(min(streak, 3))/3 days"
        ))
        
        list.append(Achievement(
            title: "Unstoppable",
            description: "Maintain a 7-day streak.",
            icon: "bolt.fill",
            color: .yellow,
            isUnlocked: streak >= 7,
            progress: "\(min(streak, 7))/7 days"
        ))
        
        // --- 3. ОБЪЕМ (ТОННАЖ) ---
        // Считаем общий поднятый вес за все время (только силовые)
        let totalVolume = workouts.reduce(0.0) { wSum, w in
            wSum + w.exercises.reduce(0.0) { eSum, e in
                if e.type == .strength {
                    return eSum + e.computedVolume
                }
                return eSum
            }
        }
        
        list.append(Achievement(
            title: "Moving Furniture",
            description: "Lift a total of 500 kg.",
            icon: "sofa.fill",
            color: .brown,
            isUnlocked: totalVolume >= 500,
            progress: "\(Int(totalVolume))/500 kg"
        ))
        
        list.append(Achievement(
            title: "Lift a Car",
            description: "Lift a total of 1,500 kg (Toyota Camry).",
            icon: "car.fill",
            color: .red,
            isUnlocked: totalVolume >= 1500,
            progress: "\(Int(totalVolume))/1500 kg"
        ))
        
        list.append(Achievement(
            title: "Lift an Elephant",
            description: "Lift a total of 6,000 kg.",
            icon: "tortoise.fill", // Слона нет в SF Symbols, черепаха тоже тяжелая :) Или используем circle.grid.3x3.fill
            color: .gray,
            isUnlocked: totalVolume >= 6000,
            progress: "\(Int(totalVolume))/6000 kg"
        ))
        
        // --- 4. ВРЕМЯ СУТОК ---
        // "Ранняя пташка" (тренировка между 4 и 8 утра)
        let hasEarlyWorkout = workouts.contains {
            let hour = Calendar.current.component(.hour, from: $0.date)
            return hour >= 4 && hour < 8
        }
        list.append(Achievement(
            title: "Early Bird",
            description: "Complete a workout before 8 AM.",
            icon: "sunrise.fill",
            color: .yellow,
            isUnlocked: hasEarlyWorkout
        ))
        
        // "Ночной качок" (тренировка после 22:00)
        let hasNightWorkout = workouts.contains {
            let hour = Calendar.current.component(.hour, from: $0.date)
            return hour >= 22 || hour < 4
        }
        list.append(Achievement(
            title: "Night Owl",
            description: "Complete a workout after 10 PM.",
            icon: "moon.stars.fill",
            color: .indigo,
            isUnlocked: hasNightWorkout
        ))
        
        // --- 5. СПЕЦИФИЧЕСКИЕ ---
        // "Марафонец" (Общая дистанция кардио > 42 км)
        let totalDistance = workouts.reduce(0.0) { wSum, w in
            wSum + w.exercises.reduce(0.0) { eSum, e in
                e.type == .cardio ? eSum + (e.distance ?? 0) : eSum
            }
        }
        list.append(Achievement(
            title: "Marathoner",
            description: "Run/Cycle a total of 42 km.",
            icon: "figure.run.circle.fill",
            color: .green,
            isUnlocked: totalDistance >= 42.0,
            progress: String(format: "%.1f/42 km", totalDistance)
        ))
        
        // "Жим 100" (Поднять 100кг в жиме лежа хотя бы 1 раз)
        let bench100 = workouts.contains { w in
            w.exercises.contains { e in
                // Ищем Bench Press c весом >= 100
                (e.name.contains("Bench Press") && e.weight >= 100)
            }
        }
        list.append(Achievement(
            title: "100kg Club",
            description: "Bench Press 100kg in a single set.",
            icon: "trophy.circle.fill",
            color: .gold, // Сделаем расширение ниже или используем .yellow
            isUnlocked: bench100
        ))
        
        // "Не пропускай день ног" (Тренировка где > 50% упражнений на ноги)
        let legDayMaster = workouts.contains { w in
            let legs = w.exercises.filter { $0.muscleGroup == "Legs" }.count
            return legs > 0 && Double(legs) / Double(w.exercises.count) > 0.5
        }
        list.append(Achievement(
            title: "Leg Day Lover",
            description: "Complete a workout focused mostly on legs.",
            icon: "figure.walk.motion",
            color: .orange,
            isUnlocked: legDayMaster
        ))
        
        // "Выходной воин" (Тренировка в Субботу или Воскресенье)
        let weekendWarrior = workouts.contains {
            let weekday = Calendar.current.component(.weekday, from: $0.date)
            return weekday == 1 || weekday == 7 // 1-Sun, 7-Sat
        }
        list.append(Achievement(
            title: "Weekend Warrior",
            description: "Complete a workout on a weekend.",
            icon: "calendar.badge.clock",
            color: .teal,
            isUnlocked: weekendWarrior
        ))
        
        return list
    }
}

// Добавляем золотой цвет для красоты
extension Color {
    static let gold = Color(red: 1.0, green: 0.84, blue: 0.0)
}
