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
    
    // MARK: - Debounce для сохранения
    
    private var saveCancellable: AnyCancellable?
    private let saveSubject = PassthroughSubject<Void, Never>()
    
    // MARK: - Init
    
    init() {
        loadNotes()
        
        // Настраиваем debounce для сохранения (500ms задержка)
        saveCancellable = saveSubject
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.performSave()
            }
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
        // Обновляем локальное состояние сразу (для UI)
        if note.isEmpty {
            notes.removeValue(forKey: exerciseName)
        } else {
            notes[exerciseName] = note
        }
        
        // Сохраняем на диск с debounce (не блокируем UI)
        saveSubject.send()
    }
    
    /// Принудительное сохранение (например, при закрытии view)
    func saveImmediately() {
        // Отменяем отложенное сохранение и выполняем сразу
        saveCancellable?.cancel()
        performSave()
        
        // Восстанавливаем подписку для будущих изменений
        saveCancellable = saveSubject
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.performSave()
            }
    }
    
    // MARK: - Persistence (UserDefaults)
    
    private func performSave() {
        // Выполняем сохранение асинхронно в фоновой очереди
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            
            do {
                let encoded = try JSONEncoder().encode(self.notes)
                UserDefaults.standard.set(encoded, forKey: self.userDefaultsKey)
            } catch {
                // Error saving notes
            }
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
        } catch {
            self.notes = [:]
        }
    }
}
