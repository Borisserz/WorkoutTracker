//
//  BodyMeasurement.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 31.03.26.
//


import Foundation
import SwiftData

@Model
class BodyMeasurement {
    @Attribute(.unique) var id: UUID
    var date: Date
    
    var neck: Double?
    var shoulders: Double?
    var chest: Double?
    var waist: Double?
    var pelvis: Double?
    var biceps: Double?
    var thigh: Double?
    var calves: Double?
    
    init(id: UUID = UUID(), date: Date = Date(), neck: Double? = nil, shoulders: Double? = nil, chest: Double? = nil, waist: Double? = nil, pelvis: Double? = nil, biceps: Double? = nil, thigh: Double? = nil, calves: Double? = nil) {
        self.id = id
        self.date = date
        self.neck = neck
        self.shoulders = shoulders
        self.chest = chest
        self.waist = waist
        self.pelvis = pelvis
        self.biceps = biceps
        self.thigh = thigh
        self.calves = calves
    }
}
