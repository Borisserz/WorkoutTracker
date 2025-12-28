import Foundation
import Combine

class ExerciseNotesManager: ObservableObject {
    static let shared = ExerciseNotesManager()
    
    // Тут хранятся заметки в оперативной памяти, пока приложение работает
    @Published private(set) var notes: [String: String] = [:]
    
    // Ключ, по которому айфон находит наши данные на диске
    private let userDefaultsKey = "savedExerciseNotes"
    
    init() {
        // ПРИ ЗАПУСКЕ: Загружаем сохраненное с диска
        loadNotes()
    }
    
    // Получить заметку для конкретного упражнения
    func getNote(for exerciseName: String) -> String {
        return notes[exerciseName] ?? ""
    }
    
    // Сохранить заметку (вызывается, когда ты печатаешь)
    func setNote(_ note: String, for exerciseName: String) {
        if note.isEmpty {
            notes.removeValue(forKey: exerciseName)
        } else {
            notes[exerciseName] = note
        }
        // СРАЗУ СОХРАНЯЕМ В ПАМЯТЬ ТЕЛЕФОНА
        saveNotes()
    }
    
    // --- МАГИЯ СОХРАНЕНИЯ (UserDefaults) ---
    
    private func saveNotes() {
        // Превращаем словарь [String: String] в набор байтов (JSON)
        if let encoded = try? JSONEncoder().encode(notes) {
            // Записываем этот файл в память телефона
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
            print("💾 Note saved to disk!") // Для проверки в консоли
        }
    }
    
    private func loadNotes() {
        // Пытаемся найти файл в памяти телефона
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey) {
            // Пытаемся расшифровать его обратно в словарь
            if let decodedNotes = try? JSONDecoder().decode([String: String].self, from: data) {
                self.notes = decodedNotes
                print("📂 Notes loaded from disk: \(decodedNotes.count)")
                return
            }
        }
        self.notes = [:]
    }
}
