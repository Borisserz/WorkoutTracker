// ============================================================
// FILE: WorkoutTracker/DataLayer/Models/WeightEntry.swift
// ============================================================
import Foundation
import SwiftData

@Model
class WeightEntry {
    var id: UUID = UUID()
    var date: Date = Date()
    var weight: Double = 0.0
    
    init(id: UUID = UUID(), date: Date = Date(), weight: Double = 0.0) {
        self.id = id
        self.date = date
        self.weight = weight
    }
}
