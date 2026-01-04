//
//  ExerciseNotesManager.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 24.12.25.
//
//  Менеджер заметок к упражнениям.
//  Отвечает за:
//  1. Хранение текстовых заметок для каждого упражнения (ключ = название упражнения).
//  2. Синхронизацию данных с UserDefaults (персистентность).
//  3. Предоставление данных UI через @Published свойство.
//

import Foundation
import Combine

class ExerciseNotesManager: ObservableObject {
    
    // MARK: - Singleton
    static let shared = ExerciseNotesManager()
    
    // MARK: - Published State
    
    /// Словарь с заметками: [Название упражнения : Текст заметки]
    @Published private(set) var notes: [String: String] = [:]
    
    // MARK: - Constants
    
    private let userDefaultsKey = "savedExerciseNotes"
    
    // MARK: - Init
    
    init() {
        loadNotes()
    }
    
    // MARK: - Public Methods
    
    /// Получить заметку для конкретного упражнения
    func getNote(for exerciseName: String) -> String {
        return notes[exerciseName] ?? ""
    }
    
    /// Сохранить (или удалить) заметку для упражнения
    /// - Parameters:
    ///   - note: Текст заметки. Если пустой — запись удаляется.
    ///   - exerciseName: Название упражнения (ключ).
    func setNote(_ note: String, for exerciseName: String) {
        if note.isEmpty {
            notes.removeValue(forKey: exerciseName)
        } else {
            notes[exerciseName] = note
        }
        
        // Сразу сохраняем изменения на диск
        saveNotes()
    }
    
    // MARK: - Persistence (UserDefaults)
    
    private func saveNotes() {
        do {
            let encoded = try JSONEncoder().encode(notes)
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
            // print("💾 Note saved to disk!")
        } catch {
            print("❌ Error saving notes: \(error.localizedDescription)")
        }
    }
    
    private func loadNotes() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            self.notes = [:]
            return
        }
        
        do {
            let decodedNotes = try JSONDecoder().decode([String: String].self, from: data)
            self.notes = decodedNotes
            print("📂 Notes loaded from disk: \(decodedNotes.count)")
        } catch {
            print("❌ Error loading notes: \(error.localizedDescription)")
            self.notes = [:]
        }
    }
}
