//
//  UserStatsViewModel.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 1.04.26.
//

internal import SwiftUI
import SwiftData
import Observation

@Observable
@MainActor
final class UserStatsViewModel {
    
    private let modelContainer: ModelContainer
    private var context: ModelContext { modelContainer.mainContext }
    
    // @Published удалено
    var progressManager = ProgressManager()
    
    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }
    
    // MARK: - Weight Tracking
    
    func addWeightEntry(weight: Double, date: Date = Date()) {
        // guard let context = mainContext else { return } <-- УДАЛИТЬ, ИСПОЛЬЗОВАТЬ ПРОСТО context
        let newEntry = WeightEntry(date: date, weight: weight)
        context.insert(newEntry)
        try? context.save()
        UserDefaults.standard.set(weight, forKey: Constants.UserDefaultsKeys.userBodyWeight.rawValue)
    }
    
    func deleteWeightEntry(_ entry: WeightEntry) {
        context.delete(entry)
        try? context.save()
    }
    
    // MARK: - Body Measurements
    
    func addBodyMeasurement(
        neck: Double?, shoulders: Double?, chest: Double?, waist: Double?,
        pelvis: Double?, biceps: Double?, thigh: Double?, calves: Double?,
        date: Date = Date()
    ) {
        let entry = BodyMeasurement(
            date: date, neck: neck, shoulders: shoulders, chest: chest,
            waist: waist, pelvis: pelvis, biceps: biceps, thigh: thigh, calves: calves
        )
        context.insert(entry)
        try? context.save()
    }
    
    func deleteBodyMeasurement(_ measurement: BodyMeasurement) {
        context.delete(measurement)
        try? context.save()
    }
    
    // MARK: - Notes
    
    func deleteChatSession(_ session: AIChatSession) {
        context.delete(session)
        try? context.save()
    }
    func saveExerciseNote(exerciseName: String, text: String, existingNote: ExerciseNote?) {
        if let note = existingNote {
            note.text = text
        } else if !text.isEmpty {
            let newNote = ExerciseNote(exerciseName: exerciseName, text: text)
            context.insert(newNote)
        }
        try? context.save()
    }
}
