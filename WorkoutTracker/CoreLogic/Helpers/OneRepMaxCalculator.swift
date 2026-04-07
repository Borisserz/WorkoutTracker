//
//  OneRepMaxCalculator.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 7.04.26.
//

import Foundation

public enum RMFormula: String, CaseIterable, Identifiable, Sendable {
    case epley = "Epley"
    case brzycki = "Brzycki"
    case lander = "Lander"
    case oconnor = "O'Connor"
    case average = "Average"
    
    public var id: String { self.rawValue }
}

public struct OneRepMaxCalculator: Sendable {
    
    /// Рассчитывает 1RM на основе веса и повторений
    public static func calculate1RM(weight: Double, reps: Int, formula: RMFormula) -> Double {
        guard reps > 0, weight > 0 else { return 0 }
        if reps == 1 { return weight }
        
        let r = Double(reps)
        let w = weight
        
        switch formula {
        case .epley:
            return w * (1.0 + (r / 30.0))
        case .brzycki:
            return w * (36.0 / (37.0 - r))
        case .lander:
            return (100.0 * w) / (101.3 - 2.67123 * r)
        case .oconnor:
            return w * (1.0 + 0.025 * r)
        case .average:
            let e = w * (1.0 + (r / 30.0))
            let b = w * (36.0 / (37.0 - r))
            let l = (100.0 * w) / (101.3 - 2.67123 * r)
            let o = w * (1.0 + 0.025 * r)
            return (e + b + l + o) / 4.0
        }
    }
    
    /// Рассчитывает вес для N повторений на основе известного 1RM
    public static func calculateWeightForReps(oneRepMax: Double, targetReps: Int, formula: RMFormula) -> Double {
        guard targetReps > 0, oneRepMax > 0 else { return 0 }
        if targetReps == 1 { return oneRepMax }
        
        let r = Double(targetReps)
        
        switch formula {
        case .epley:
            return oneRepMax / (1.0 + (r / 30.0))
        case .brzycki:
            return oneRepMax / (36.0 / (37.0 - r))
        case .lander:
            return (oneRepMax * (101.3 - 2.67123 * r)) / 100.0
        case .oconnor:
            return oneRepMax / (1.0 + 0.025 * r)
        case .average:
            // Для Average используем обратную Epley как самую универсальную и безопасную
            return oneRepMax / (1.0 + (r / 30.0))
        }
    }
}
