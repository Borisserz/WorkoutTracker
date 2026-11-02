import Foundation
import SwiftData

@Model
class BodyMeasurement {
    var id: UUID = UUID()
    var date: Date = Date()

    var bodyFat: Double? = nil

    var neck: Double? = nil
    var shoulders: Double? = nil
    var chest: Double? = nil
    var waist: Double? = nil
    var abdomen: Double? = nil 
    var hips: Double? = nil    
    var pelvis: Double? = nil  

    var leftBicep: Double? = nil
    var rightBicep: Double? = nil
    var biceps: Double? = nil  
    var leftForearm: Double? = nil
    var rightForearm: Double? = nil

    var leftThigh: Double? = nil
    var rightThigh: Double? = nil
    var thigh: Double? = nil   
    var leftCalf: Double? = nil
    var rightCalf: Double? = nil
    var calves: Double? = nil  

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

    convenience init(from dto: BodyMeasurementDTO) {
        self.init(
            id: dto.id, date: dto.date, bodyFat: dto.bodyFat,
            neck: dto.neck, shoulders: dto.shoulders, chest: dto.chest,
            waist: dto.waist, abdomen: dto.abdomen, hips: dto.hips, pelvis: dto.pelvis,
            leftBicep: dto.leftBicep, rightBicep: dto.rightBicep, biceps: dto.biceps,
            leftForearm: dto.leftForearm, rightForearm: dto.rightForearm,
            leftThigh: dto.leftThigh, rightThigh: dto.rightThigh, thigh: dto.thigh,
            leftCalf: dto.leftCalf, rightCalf: dto.rightCalf, calves: dto.calves
        )
    }
}

public struct BodyMeasurementDTO: Sendable {
    public var id: UUID
    public var date: Date
    public var bodyFat: Double?
    public var neck: Double?
    public var shoulders: Double?
    public var chest: Double?
    public var waist: Double?
    public var abdomen: Double?
    public var hips: Double?
    public var pelvis: Double?
    public var leftBicep: Double?
    public var rightBicep: Double?
    public var biceps: Double?
    public var leftForearm: Double?
    public var rightForearm: Double?
    public var leftThigh: Double?
    public var rightThigh: Double?
    public var thigh: Double?
    public var leftCalf: Double?
    public var rightCalf: Double?
    public var calves: Double?

    public init(
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
