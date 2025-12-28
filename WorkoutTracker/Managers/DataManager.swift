import Foundation

class DataManager {
    static let shared = DataManager()
    
    private let fileName = "workouts.json"
    
    private func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
    
    func saveWorkouts(_ workouts: [Workout]) {
        let url = getDocumentsDirectory().appendingPathComponent(fileName)
        do {
            let data = try JSONEncoder().encode(workouts)
            try data.write(to: url)
        } catch {
            print("Errorr saving: \(error.localizedDescription)")
        }
    }
    
    func loadWorkouts() -> [Workout] {
            let url = getDocumentsDirectory().appendingPathComponent(fileName)
            do {
                let data = try Data(contentsOf: url)
                // ИСПРАВЛЕНИЕ: Скобка переместилась. Было [Workout.self], стало [Workout].self
                let workouts = try JSONDecoder().decode([Workout].self, from: data)
                return workouts
            } catch {
                return []
            }
        }
}

extension Exercise {
    // Вычисляем объем: если это супер-сет, суммируем детей. Если нет — считаем свой.
    var computedVolume: Double {
        if isSuperset {
            return subExercises.reduce(0.0) { $0 + $1.computedVolume }
        } else {
            return weight * Double(sets * reps)
        }
    }
}
