

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

    public static func calculate1RM(weight: Double, reps: Int, formula: RMFormula) -> Double {
        guard reps > 0, weight > 0 else { return 0 }
        if reps == 1 { return weight }

        // Brzycki hits 0 denominator at 37 and Lander turns negative at 38; clamp to safe physiological range.
        let r = Double(min(reps, 36))
        let w = weight

        let epley = w * (1.0 + (r / 30.0))
        let brzycki = w * (36.0 / max(1.0, 37.0 - r))
        let lander = (100.0 * w) / max(5.0, 101.3 - 2.67123 * r)
        let oconnor = w * (1.0 + 0.025 * r)

        switch formula {
        case .epley: return epley
        case .brzycki: return brzycki
        case .lander: return lander
        case .oconnor: return oconnor
        case .average: return (epley + brzycki + lander + oconnor) / 4.0
        }
    }

    public static func calculateWeightForReps(oneRepMax: Double, targetReps: Int, formula: RMFormula) -> Double {
        guard targetReps > 0, oneRepMax > 0 else { return 0 }
        if targetReps == 1 { return oneRepMax }

        let r = Double(min(targetReps, 36))

        switch formula {
        case .epley:
            return oneRepMax / (1.0 + (r / 30.0))
        case .brzycki:
            return max(oneRepMax * 0.05, oneRepMax / (36.0 / max(1.0, 37.0 - r)))
        case .lander:
            return max(oneRepMax * 0.05, (oneRepMax * (101.3 - 2.67123 * r)) / 100.0)
        case .oconnor:
            return oneRepMax / (1.0 + 0.025 * r)
        case .average:
            return oneRepMax / (1.0 + (r / 30.0))
        }
    }
}
