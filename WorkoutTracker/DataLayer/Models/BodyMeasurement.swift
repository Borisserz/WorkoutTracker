import Foundation
import SwiftData

@Model
class BodyMeasurement {
    var id: UUID = UUID()
    var date: Date = Date()
    
    // Body Composition
    var bodyFat: Double? = nil
    
    // Core & Torso
    var neck: Double? = nil
    var shoulders: Double? = nil
    var chest: Double? = nil
    var waist: Double? = nil
    var abdomen: Double? = nil // New
    var hips: Double? = nil    // New
    var pelvis: Double? = nil  // Legacy compatibility
    
    // Arms
    var leftBicep: Double? = nil
    var rightBicep: Double? = nil
    var biceps: Double? = nil  // Legacy compatibility
    var leftForearm: Double? = nil
    var rightForearm: Double? = nil
    
    // Legs
    var leftThigh: Double? = nil
    var rightThigh: Double? = nil
    var thigh: Double? = nil   // Legacy compatibility
    var leftCalf: Double? = nil
    var rightCalf: Double? = nil
    var calves: Double? = nil  // Legacy compatibility
    
    init(
        id: UUID = UUID(), date: Date = Date(), bodyFat: Double? = nil,
        neck: Double? = nil, shoulders: Double? = nil, chest: Double? = nil,
        waist: Double? = nil, abdomen: Double? = nil, hips: Double? = nil, pelvis: Double? = nil,
        leftBicep: Double? = nil, rightBicep: Double? = nil, biceps: Double? = nil,
        leftForearm: Double? = nil, rightForearm: Double? = nil,
        leftThigh: Double? = nil, rightThigh: Double? = nil, thigh: Double? = nil,
        leftCalf: Double? = nil, rightCalf: Double? = nil, calves: Double? = nil
    ) {
        self.id = id; self.date = date; self.bodyFat = bodyFat
        self.neck = neck; self.shoulders = shoulders; self.chest = chest
        self.waist = waist; self.abdomen = abdomen; self.hips = hips; self.pelvis = pelvis
        self.leftBicep = leftBicep; self.rightBicep = rightBicep; self.biceps = biceps
        self.leftForearm = leftForearm; self.rightForearm = rightForearm
        self.leftThigh = leftThigh; self.rightThigh = rightThigh; self.thigh = thigh
        self.leftCalf = leftCalf; self.rightCalf = rightCalf; self.calves = calves
    }
}
