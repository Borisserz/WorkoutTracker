//
//  UserRepository.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 3.04.26.
//

// ============================================================
// FILE: WorkoutTracker/Views/Profile/UserRepository.swift
// ============================================================

import Foundation
import SwiftData

protocol UserRepositoryProtocol: Sendable {
    func addWeightEntry(weight: Double, date: Date) async throws
    func deleteWeightEntry(_ entryID: PersistentIdentifier) async throws
    func addBodyMeasurement(neck: Double?, shoulders: Double?, chest: Double?, waist: Double?, pelvis: Double?, biceps: Double?, thigh: Double?, calves: Double?, date: Date) async throws
    func deleteBodyMeasurement(_ measurementID: PersistentIdentifier) async throws
    func saveExerciseNote(exerciseName: String, text: String, existingNoteID: PersistentIdentifier?) async throws -> PersistentIdentifier?
    func fetchExerciseNote(exerciseName: String) async throws -> ExerciseNote?
    func deleteAIChatSession(_ sessionID: PersistentIdentifier) async throws
    func fetchAIChatSessions() async throws -> [AIChatSession]
    func saveAIChatSession(_ session: AIChatSession) async throws
}

@ModelActor
actor UserRepository: UserRepositoryProtocol {
    
    func addWeightEntry(weight: Double, date: Date) async throws {
        let newEntry = WeightEntry(date: date, weight: weight)
        modelContext.insert(newEntry)
        try modelContext.save()
    }

    func deleteWeightEntry(_ entryID: PersistentIdentifier) async throws {
        guard let entry = modelContext.model(for: entryID) as? WeightEntry else { throw WorkoutRepositoryError.modelNotFound }
        modelContext.delete(entry)
        try modelContext.save()
    }

    func addBodyMeasurement(neck: Double?, shoulders: Double?, chest: Double?, waist: Double?, pelvis: Double?, biceps: Double?, thigh: Double?, calves: Double?, date: Date) async throws {
        let entry = BodyMeasurement(
            date: date, neck: neck, shoulders: shoulders, chest: chest,
            waist: waist, pelvis: pelvis, biceps: biceps, thigh: thigh, calves: calves
        )
        modelContext.insert(entry)
        try modelContext.save()
    }

    func deleteBodyMeasurement(_ measurementID: PersistentIdentifier) async throws {
        guard let measurement = modelContext.model(for: measurementID) as? BodyMeasurement else { throw WorkoutRepositoryError.modelNotFound }
        modelContext.delete(measurement)
        try modelContext.save()
    }

    func saveExerciseNote(exerciseName: String, text: String, existingNoteID: PersistentIdentifier?) async throws -> PersistentIdentifier? {
        var note: ExerciseNote?
        if let id = existingNoteID, let existing = modelContext.model(for: id) as? ExerciseNote {
            note = existing
        } else {
            let descriptor = FetchDescriptor<ExerciseNote>(predicate: #Predicate { $0.exerciseName == exerciseName })
            note = (try? modelContext.fetch(descriptor).first)
        }
        
        if let n = note {
            n.text = text
        } else if !text.isEmpty {
            let newNote = ExerciseNote(exerciseName: exerciseName, text: text)
            modelContext.insert(newNote)
            note = newNote
        }
        try modelContext.save()
        return note?.persistentModelID
    }

    func fetchExerciseNote(exerciseName: String) async throws -> ExerciseNote? {
        let descriptor = FetchDescriptor<ExerciseNote>(predicate: #Predicate { $0.exerciseName == exerciseName })
        return try modelContext.fetch(descriptor).first
    }

    func deleteAIChatSession(_ sessionID: PersistentIdentifier) async throws {
        guard let session = modelContext.model(for: sessionID) as? AIChatSession else { throw WorkoutRepositoryError.modelNotFound }
        modelContext.delete(session)
        try modelContext.save()
    }
    
    func fetchAIChatSessions() async throws -> [AIChatSession] {
        let descriptor = FetchDescriptor<AIChatSession>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        return try modelContext.fetch(descriptor)
    }

    func saveAIChatSession(_ session: AIChatSession) async throws {
        modelContext.insert(session)
        try modelContext.save()
    }
}
