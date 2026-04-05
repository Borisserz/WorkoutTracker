// ============================================================
// FILE: WorkoutTracker/DataLayer/Models/MuscleColorPreference.swift
// ============================================================
import Foundation
import SwiftData

@Model
class MuscleColorPreference {
    var muscleName: String = ""
    var hexColor: String = ""
    
    init(muscleName: String = "", hexColor: String = "") {
        self.muscleName = muscleName
        self.hexColor = hexColor
    }
}
