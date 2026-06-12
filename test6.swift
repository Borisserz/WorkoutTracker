import Foundation
struct ExerciseDBItem: Codable {
    public let name: String
    enum CodingKeys: String, CodingKey { case name }
}
let url = URL(fileURLWithPath: "./WorkoutTracker/DataLayer/LocalDB/exercises.json")
let data = try! Data(contentsOf: url)
let items = try! JSONDecoder().decode([ExerciseDBItem].self, from: data)
let names = items.map { $0.name.lowercased() }
print("Contains pushups?", names.contains("pushups"))
print("Contains pullups?", names.contains("pullups"))
print("Contains push-ups?", names.contains("push-ups"))
print("Push variants:", names.filter { $0.contains("pushup") || $0.contains("push-up") })
