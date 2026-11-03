import Foundation
import SwiftData

struct MuscleReadinessItem: Identifiable, Sendable {
    var id: String { name }
    let name: String
    let percentage: Int
    let hoursRemaining: Int
}

/// Personalized coach advice for the next training session based on previous muscle strain.
struct NextWorkoutAdvice: Sendable {
    let recentStrainSummary: String
    let recommendedSplitTitle: String
    let physiologicalRationale: String
    let actionableTips: [String]
    let cautionNotes: String
    let recommendedExercises: [String]
}

/// Physiological analysis model representing deep readiness evaluation.
struct BodyAnalysisReport: Sendable {
    let overallReadiness: Int
    let cnsStatusTitle: String
    let executiveAssessment: String
    let recommendedTargetTitle: String
    let recommendedRestrictions: String
    let primeMuscles: [MuscleReadinessItem]
    let recoveringMuscles: [MuscleReadinessItem]
    let nextWorkoutAdvice: NextWorkoutAdvice
    let date: Date
}

enum BodyAnalysisEngine {
    
    /// Generates a comprehensive, sports-science evaluation without emojis or superficial text.
    static func generateReport(
        cnsScore: Double,
        recoveryDict: [String: Int],
        recentWorkouts: [Workout],
        fullRecoveryHours: Double = 48.0
    ) -> BodyAnalysisReport {
        let hasRecoveryData = !recoveryDict.isEmpty
        // Empty map = unknown — never invent 100% prime readiness (ADR honesty).
        let avgReadiness = hasRecoveryData
            ? (recoveryDict.values.reduce(0, +) / max(1, recoveryDict.count))
            : -1
        
        // Group muscles into prime (>= 80%) and recovering (< 80%)
        var prime: [MuscleReadinessItem] = []
        var recovering: [MuscleReadinessItem] = []
        
        let displayOrder = [
            "chest", "upper-back", "deltoids", "biceps", "triceps", 
            "quadriceps", "hamstring", "gluteal", "lower-back", "abs", "calves"
        ]
        
        for slug in displayOrder {
            // Only measured muscles — missing slug is unmeasured, not invented 100%.
            guard let pct = recoveryDict[slug] else { continue }
            let name = MuscleDisplayHelper.getDisplayName(for: slug)
            let remainingHours = max(0, Int(Double(100 - pct) / 100.0 * fullRecoveryHours))
            let item = MuscleReadinessItem(name: name, percentage: pct, hoursRemaining: remainingHours)

            if pct >= 80 {
                prime.append(item)
            } else {
                recovering.append(item)
            }
        }

        func pct(_ key: String) -> Int {
            recoveryDict[key] ?? -1
        }
        let chestPct = pct("chest")
        let backPct = pct("upper-back")
        let quadsPct = pct("quadriceps")
        let hamsPct = pct("hamstring")
        let lowBackPct = pct("lower-back")
        let tricepsPct = pct("triceps")
        let bicepsPct = pct("biceps")

        // Determine Next Workout Advice based on recent muscle strain
        let advice: NextWorkoutAdvice
        if recentWorkouts.isEmpty {
            let cnsNote: String
            if cnsScore < 0 {
                cnsNote = String(localized: "No workouts logged yet. CNS readiness has not been measured.")
            } else {
                cnsNote = String(localized: "No workouts logged yet. CNS readiness is \(Int(cnsScore))% from vitals — start a first session within that budget.")
            }
            advice = NextWorkoutAdvice(
                recentStrainSummary: cnsNote,
                recommendedSplitTitle: String(localized: "Next session: Full-body introduction"),
                physiologicalRationale: String(localized: "Without training history, muscle recovery cannot be estimated. Start with a balanced full-body session and build a recovery map from logged sets."),
                actionableTips: [
                    String(localized: "Log every working set so recovery estimates can unlock"),
                    String(localized: "Keep intensity moderate (RPE 7–8) on the first sessions"),
                    String(localized: "Warm up joints for 7–10 minutes before working sets")
                ],
                cautionNotes: String(localized: "Treat readiness as not measured until HealthKit vitals and workout history exist."),
                recommendedExercises: ["Barbell Squat", "Bench Press", "Pull-ups", "Overhead Press"]
            )
        } else if !hasRecoveryData {
            // Workouts exist but recovery map missing — never interpolate "-1%" fatigue copy.
            advice = NextWorkoutAdvice(
                recentStrainSummary: String(localized: "Recent sessions are logged, but muscle recovery percentages are not available yet."),
                recommendedSplitTitle: String(localized: "Next session: Balanced full-body or preferred split"),
                physiologicalRationale: String(localized: "Without a recovery map, default to technique-focused work and moderate volume."),
                actionableTips: [
                    "Keep intensity around RPE 7.0–7.5",
                    "Favor compounds you know well",
                    "Stop short of failure until readiness data returns"
                ],
                cautionNotes: "Re-open Overview after a completed workout to refresh recovery estimates.",
                recommendedExercises: ["Barbell Squat", "Bench Press", "Pull-ups", "Overhead Press"]
            )
        } else if (avgReadiness >= 0 && avgReadiness < 60) || (cnsScore >= 0 && cnsScore < 70) {
            let readinessNote = avgReadiness >= 0
                ? "average readiness \(avgReadiness)%"
                : "CNS \(Int(cnsScore))%"
            advice = NextWorkoutAdvice(
                recentStrainSummary: "Significant systemic muscle and CNS fatigue detected (\(readinessNote)).",
                recommendedSplitTitle: "Next session: Active recovery or deload",
                physiologicalRationale: "Tissues need time to replenish glycogen and stabilize autonomic tone.",
                actionableTips: [
                    "Swap heavy strength sets for light cardio (heart rate 110–125 bpm)",
                    "Do myofascial release (foam rolling) and stretch major muscle groups",
                    "Intensity: RPE no higher than 5.0"
                ],
                cautionNotes: "Avoid training to failure and forced reps entirely.",
                recommendedExercises: ["Incline Walk", "Foam Rolling", "Joint Mobility", "Chest Stretch"]
            )
        } else if chestPct >= 0 && tricepsPct >= 0 && (chestPct < 75 || tricepsPct < 75) {
            // Push was strained recently -> recommend Pull
            advice = NextWorkoutAdvice(
                recentStrainSummary: "Recent session heavily loaded chest and triceps (recovery ~\(chestPct)%). Muscle fibers are in active regeneration.",
                recommendedSplitTitle: "Next session: Pull split (Back & Biceps)",
                physiologicalRationale: "Lats and elbow flexors are at \(backPct)% recovery with peak contractile capacity.",
                actionableTips: [
                    "Prioritize rows to the hips and pull-ups with varied grips",
                    "Target volume: 12–15 quality working sets for back and biceps",
                    "Intensity: RPE 7.5–8.0 without burning out in early sets"
                ],
                cautionNotes: "Skip incline pressing and deep push-ups for ~24 h to protect shoulder joints.",
                recommendedExercises: ["Pull-ups", "Barbell Row", "Lat Pulldown", "Dumbbell Curl"]
            )
        } else if backPct >= 0 && bicepsPct >= 0 && (backPct < 75 || bicepsPct < 75) {
            // Pull was strained recently -> recommend Push or Legs
            advice = NextWorkoutAdvice(
                recentStrainSummary: "Recent session loaded back, lats, and biceps (recovery ~\(backPct)%).",
                recommendedSplitTitle: "Next session: Push day (Chest & Shoulders)",
                physiologicalRationale: "Chest and front delts have fully replenished glycogen (\(chestPct)%) and are ready for volume.",
                actionableTips: [
                    "Priority: flat bench press and incline dumbbell press",
                    "Keep scapulae neutral and control tempo",
                    "Intensity: RPE 7.5–8.0 with emphasis on chest stretch"
                ],
                cautionNotes: "Avoid deadlifts and bent-over rows to let long back muscles recover.",
                recommendedExercises: ["Barbell Bench Press", "Seated Dumbbell Press", "Lateral Raises", "Skull Crushers"]
            )
        } else if quadsPct >= 0 && hamsPct >= 0 && (quadsPct < 75 || hamsPct < 75) {
            // Legs strained -> recommend Upper
            advice = NextWorkoutAdvice(
                recentStrainSummary: "Recent session loaded quads and hamstrings (recovery ~\(quadsPct)%).",
                recommendedSplitTitle: "Next session: Upper body",
                physiologicalRationale: "Shoulders, chest, and back are fully rested and ready for the main training volume.",
                actionableTips: [
                    "Balance push and pull exercises in equal proportion",
                    "Use supersets to save time and increase session density",
                    "Intensity: RPE 7.0–8.0"
                ],
                cautionNotes: "Exclude axial leg loading entirely: no squats or lunges.",
                recommendedExercises: ["Bench Press", "One-Arm Dumbbell Row", "Standing Overhead Press", "Hammer Curls"]
            )
        } else {
            // Balanced
            advice = NextWorkoutAdvice(
                recentStrainSummary: "All major muscle groups are above 85% recovered. Tissue has adapted to prior training.",
                recommendedSplitTitle: "Next session: Targeted strength work",
                physiologicalRationale: "Skeletal muscle and the autonomic nervous system are ready for intense work without overload risk.",
                actionableTips: [
                    "Pick a split aligned with your weekly priorities",
                    "Focus on technique in the 6–10 rep range",
                    "Intensity: RPE 8.0"
                ],
                cautionNotes: "Stay hydrated and rest 90–120 seconds between sets.",
                recommendedExercises: ["Barbell Bench Press", "Weighted Pull-ups", "Squats", "Overhead Press"]
            )
        }

        // Fallback if no workouts logged yet — readiness unknown, not invented 100%.
        if recentWorkouts.isEmpty {
            return BodyAnalysisReport(
                overallReadiness: -1,
                cnsStatusTitle: cnsScore < 0
                    ? String(localized: "CNS not measured")
                    : String(localized: "CNS from vitals"),
                executiveAssessment: String(localized: "No training history yet, so muscular readiness cannot be estimated. Log workouts and sync Health data to unlock recovery analysis."),
                recommendedTargetTitle: String(localized: "Base strength training / Full Body"),
                recommendedRestrictions: String(localized: "Readiness not measured — start light and log sets to build a recovery map."),
                primeMuscles: prime,
                recoveringMuscles: [],
                nextWorkoutAdvice: advice,
                date: Date()
            )
        }
        
        // Executive assessment synthesis
        let cnsNarrative: String
        if cnsScore < 0 {
            cnsNarrative = String(localized: "CNS readiness has not been measured from HealthKit vitals yet.")
        } else if cnsScore >= 85 {
            cnsNarrative = String(localized: "The autonomic nervous system shows high parasympathetic tone and optimal central recovery.")
        } else if cnsScore >= 70 {
            cnsNarrative = String(localized: "The central nervous system is under moderate cumulative load from recent training sessions.")
        } else {
            cnsNarrative = String(localized: "Marked sympathetic activation and accumulated neuromuscular fatigue detected.")
        }
        
        let muscularNarrative: String
        if !hasRecoveryData {
            muscularNarrative = String(localized: "Muscle-group recovery percentages are unavailable, so intensity should stay conservative until the map refreshes.")
        } else if lowBackPct < 70 || hamsPct < 70 {
            muscularNarrative = String(localized: "The posterior chain is actively regenerating fiber microstructure after pulling work. The anterior chain has fully restored glycogen stores.")
        } else if chestPct < 70 {
            muscularNarrative = String(localized: "Chest and front delt bundles are in protein synthesis and supercompensation. Back and legs are fully ready to train.")
        } else {
            muscularNarrative = String(localized: "Major muscle groups and stabilizers maintain high cellular readiness across movement planes.")
        }
        
        let assessment = "\(cnsNarrative) \(muscularNarrative)"
        
        // Determine recommended focus
        let targetTitle: String
        let restrictions: String
        
        if !hasRecoveryData {
            targetTitle = String(localized: "Moderate technique work / preferred split")
            restrictions = String(localized: "Keep volume moderate until muscle recovery data is available.")
        } else if chestPct >= 85, let tri = recoveryDict["triceps"], tri >= 80 {
            targetTitle = String(localized: "Push complex (Chest, Shoulders, Triceps)")
            if lowBackPct < 75 {
                restrictions = String(localized: "Avoid spinal axial loading and weighted bends for ~18 h.")
            } else {
                restrictions = String(localized: "Standard training volume. Focus on a controlled eccentric phase.")
            }
        } else if backPct >= 85, let bi = recoveryDict["biceps"], bi >= 80 {
            targetTitle = String(localized: "Pull complex (Lats, Back, Biceps)")
            restrictions = String(localized: "Keep a neutral lumbar spine; avoid fatiguing spinal extensors.")
        } else if quadsPct >= 85 {
            targetTitle = String(localized: "Lower body (Quads, Hamstrings)")
            restrictions = String(localized: "Prioritize machines with a stable path (leg press, hack squat).")
        } else {
            targetTitle = String(localized: "Active recovery and mobility")
            restrictions = String(localized: "Cap intensity at RPE 6; prioritize foam rolling and hydration.")
        }
        
        let cnsTitle: String
        if cnsScore < 0 {
            cnsTitle = String(localized: "CNS not measured")
        } else if cnsScore >= 85 {
            cnsTitle = String(localized: "Optimal balance")
        } else if cnsScore >= 70 {
            cnsTitle = String(localized: "Moderate load")
        } else {
            cnsTitle = String(localized: "CNS fatigue")
        }
        
        return BodyAnalysisReport(
            overallReadiness: avgReadiness,
            cnsStatusTitle: cnsTitle,
            executiveAssessment: assessment,
            recommendedTargetTitle: targetTitle,
            recommendedRestrictions: restrictions,
            primeMuscles: prime,
            recoveringMuscles: recovering,
            nextWorkoutAdvice: advice,
            date: Date()
        )
    }
}
