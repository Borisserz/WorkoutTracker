import Foundation

// 1. Добавили Hashable
struct Exercise: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var muscleGroup: String
    var sets: Int
    var reps: Int
    var weight: Double
    var effort: Int = 5
    
    var subExercises: [Exercise] = []
       
       // Вычисляемое свойство: Супер-сет это или нет?
       var isSuperset: Bool {
           return !subExercises.isEmpty
       }
    // --- ДОБАВЛЯЕМ ЭТОТ БЛОК ---
       // Это нужно, чтобы старые JSON файлы (где нет subExercises) не ломали приложение
       enum CodingKeys: String, CodingKey {
           case id, name, muscleGroup, sets, reps, weight, effort, subExercises
       }
       
       init(id: UUID = UUID(), name: String, muscleGroup: String, sets: Int, reps: Int, weight: Double, effort: Int = 5, subExercises: [Exercise] = []) {
           self.id = id
           self.name = name
           self.muscleGroup = muscleGroup
           self.sets = sets
           self.reps = reps
           self.weight = weight
           self.effort = effort
           self.subExercises = subExercises
       }

       init(from decoder: Decoder) throws {
           let container = try decoder.container(keyedBy: CodingKeys.self)
           id = try container.decode(UUID.self, forKey: .id)
           name = try container.decode(String.self, forKey: .name)
           muscleGroup = try container.decode(String.self, forKey: .muscleGroup)
           sets = try container.decode(Int.self, forKey: .sets)
           reps = try container.decode(Int.self, forKey: .reps)
           weight = try container.decode(Double.self, forKey: .weight)
           effort = try container.decode(Int.self, forKey: .effort)
           // Безопасная загрузка: если поля нет, ставим пустой массив
           subExercises = try container.decodeIfPresent([Exercise].self, forKey: .subExercises) ?? []
       }
       
       func encode(to encoder: Encoder) throws {
           var container = encoder.container(keyedBy: CodingKeys.self)
           try container.encode(id, forKey: .id)
           try container.encode(name, forKey: .name)
           try container.encode(muscleGroup, forKey: .muscleGroup)
           try container.encode(sets, forKey: .sets)
           try container.encode(reps, forKey: .reps)
           try container.encode(weight, forKey: .weight)
           try container.encode(effort, forKey: .effort)
           try container.encode(subExercises, forKey: .subExercises)
       }
   }


// 2. Новая структура для Пресета
struct WorkoutPreset: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var icon: String // Иконка, например "figure.strengthtraining.traditional"
    var exercises: [Exercise] // Список упражнений, которые скопируются в тренировку
}

struct Workout: Identifiable, Codable {
    var id = UUID()
    var title: String
    var date: Date
    var endTime: Date? = nil
    
    var exercises: [Exercise]
    
    var icon: String { return "figure.run" }
    
    var isActive: Bool {
        return endTime == nil
    }
    
    var duration: Int {
        let end = endTime ?? Date()
        let diff = end.timeIntervalSince(date)
        return Int(diff / 60)
    }
    
    var effortPercentage: Int {
        if exercises.isEmpty { return 0 }
        let totalEffort = exercises.reduce(0) { $0 + $1.effort }
        let average = Double(totalEffort) / Double(exercises.count)
        return Int(average * 10)
    }
}

// КАТАЛОГ (Без изменений)
extension Exercise {
    static let catalog: [String: [String]] = [
        "Chest": ["Bench Press", "Push Ups", "Incline Dumbbell Press", "Dips"],
        "Back": ["Pull-ups", "Deadlift", "Barbell Rows", "Lat Pulldown"],
        "Legs": ["Squat", "Leg Press", "Lunges", "Calf Raises"],
        "Shoulders": ["Overhead Press", "Lateral Raises", "Face Pulls"],
        "Arms": ["Barbell Curl", "Triceps Extension", "Hammer Curls"],
        "Core": ["Plank", "Crunches", "Leg Raises"]
    ]
}

// ПРИМЕРЫ
extension Workout {
    static let examples = [
        Workout(title: "Push Day", date: Date(), endTime: Date().addingTimeInterval(3600), exercises: [
            Exercise(name: "Bench Press", muscleGroup: "Chest", sets: 3, reps: 10, weight: 80, effort: 9),
            Exercise(name: "Overhead Press", muscleGroup: "Shoulders", sets: 3, reps: 12, weight: 40, effort: 7)
        ]),
        Workout(title: "Leg Day", date: Date().addingTimeInterval(-86400), endTime: Date().addingTimeInterval(-86400 + 5400), exercises: [
            Exercise(name: "Squat", muscleGroup: "Legs", sets: 5, reps: 5, weight: 100, effort: 10)
        ])
    ]
}
