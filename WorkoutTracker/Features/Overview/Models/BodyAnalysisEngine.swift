import Foundation
import SwiftData

/// Physiological analysis model representing deep readiness evaluation.
struct BodyAnalysisReport: Sendable {
    let overallReadiness: Int
    let cnsStatusTitle: String
    let executiveAssessment: String
    let recommendedTargetTitle: String
    let recommendedRestrictions: String
    let primeMuscles: [MuscleReadinessItem]
    let recoveringMuscles: [MuscleReadinessItem]
    let date: Date
}

struct MuscleReadinessItem: Identifiable, Sendable {
    var id: String { name }
    let name: String
    let percentage: Int
    let hoursRemaining: Int
}

enum BodyAnalysisEngine {
    
    /// Generates a comprehensive, sports-science evaluation without emojis or superficial text.
    static func generateReport(
        cnsScore: Double,
        recoveryDict: [String: Int],
        recentWorkouts: [Workout],
        fullRecoveryHours: Double = 48.0
    ) -> BodyAnalysisReport {
        let avgReadiness = recoveryDict.isEmpty ? 100 : (recoveryDict.values.reduce(0, +) / recoveryDict.count)
        
        // Group muscles into prime (>= 80%) and recovering (< 80%)
        var prime: [MuscleReadinessItem] = []
        var recovering: [MuscleReadinessItem] = []
        
        let displayOrder = [
            "chest", "upper-back", "deltoids", "biceps", "triceps", 
            "quadriceps", "hamstring", "gluteal", "lower-back", "abs", "calves"
        ]
        
        for slug in displayOrder {
            let pct = recoveryDict[slug] ?? 100
            let name = MuscleDisplayHelper.getDisplayName(for: slug)
            let remainingHours = max(0, Int(Double(100 - pct) / 100.0 * fullRecoveryHours))
            let item = MuscleReadinessItem(name: name, percentage: pct, hoursRemaining: remainingHours)
            
            if pct >= 80 {
                prime.append(item)
            } else {
                recovering.append(item)
            }
        }
        
        // Fallback if no workouts logged yet
        if recentWorkouts.isEmpty {
            return BodyAnalysisReport(
                overallReadiness: 100,
                cnsStatusTitle: "Baseline Homeostasis",
                executiveAssessment: "Muscular tissue is fully rested with zero residual neuromuscular fatigue. All kinetic chains are primed for maximum volume and progressive overload.",
                recommendedTargetTitle: "Full Body Foundation or Upper Split",
                recommendedRestrictions: "None. Systemic capacity is at peak readiness.",
                primeMuscles: prime,
                recoveringMuscles: [],
                date: Date()
            )
        }
        
        // Assess anterior vs posterior chains
        let chestPct = recoveryDict["chest"] ?? 100
        let backPct = recoveryDict["upper-back"] ?? 100
        let quadsPct = recoveryDict["quadriceps"] ?? 100
        let hamsPct = recoveryDict["hamstring"] ?? 100
        let lowBackPct = recoveryDict["lower-back"] ?? 100
        
        // Executive assessment synthesis
        let cnsNarrative: String
        if cnsScore >= 85 {
            cnsNarrative = "Autonomic nervous system shows high vagal tone and optimal central recovery."
        } else if cnsScore >= 70 {
            cnsNarrative = "Central nervous system indicates moderate cumulative strain from recent training bouts."
        } else {
            cnsNarrative = "Elevated sympathetic activation and accumulated neural fatigue detected."
        }
        
        let muscularNarrative: String
        if lowBackPct < 70 || hamsPct < 70 {
            muscularNarrative = "The posterior chain is actively repairing micro-trauma from prior pulling volume. Meanwhile, the anterior chain shows high glycogen replenishment."
        } else if chestPct < 70 {
            muscularNarrative = "Pectoral and anterior deltoid fibers are undergoing active supercompensation. Back and lower-body structures are fully recovered."
        } else {
            muscularNarrative = "Primary stabilizers and major muscle groups maintain high cellular recovery across all kinetic planes."
        }
        
        let assessment = "\(cnsNarrative) \(muscularNarrative)"
        
        // Determine recommended focus
        let targetTitle: String
        let restrictions: String
        
        if chestPct >= 85 && (recoveryDict["triceps"] ?? 100) >= 80 {
            targetTitle = "Push Protocol (Chest, Deltoids, Triceps)"
            if lowBackPct < 75 {
                restrictions = "Avoid direct axial loading or unsupported spinal bending for 18h."
            } else {
                restrictions = "Standard volume tolerated. Focus on controlled eccentric tempo."
            }
        } else if backPct >= 85 && (recoveryDict["biceps"] ?? 100) >= 80 {
            targetTitle = "Pull Protocol (Lats, Upper Back, Biceps)"
            restrictions = "Maintain neutral lumbar position; avoid compounding lower-back fatigue."
        } else if quadsPct >= 85 {
            targetTitle = "Lower Body Hypertrophy (Quad-Dominant)"
            restrictions = "Prioritize machine stability (Leg Press, Hack Squat) to spare systemic energy."
        } else {
            targetTitle = "Active Recovery & Core Stabilization"
            restrictions = "Limit intensity to RPE 6; focus on tissue mobility and hydration replenishment."
        }
        
        let cnsTitle: String
        if cnsScore >= 85 {
            cnsTitle = "Optimal Autonomic Balance"
        } else if cnsScore >= 70 {
            cnsTitle = "Moderate Neural Recovery"
        } else {
            cnsTitle = "High Fatigue State"
        }
        
        return BodyAnalysisReport(
            overallReadiness: avgReadiness,
            cnsStatusTitle: cnsTitle,
            executiveAssessment: assessment,
            recommendedTargetTitle: targetTitle,
            recommendedRestrictions: restrictions,
            primeMuscles: prime,
            recoveringMuscles: recovering,
            date: Date()
        )
    }
}
