//
//  WeightEntry.swift
//  WorkoutTracker
//
//  Модель для записи веса пользователя с датой
//

import Foundation

struct WeightEntry: Identifiable, Codable {
    var id = UUID()
    var date: Date
    var weight: Double // Вес в килограммах
    
    init(id: UUID = UUID(), date: Date, weight: Double) {
        self.id = id
        self.date = date
        self.weight = weight
    }
}

