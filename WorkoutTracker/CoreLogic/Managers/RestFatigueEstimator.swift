import Foundation

/// Pure Rest / Recovery sheet math — never writes AppStorage CNS.
/// Overview CNS must stay driven by `CNSCalculator` / HealthKit only.
/// UI labels this “Rest readiness” — not Overview CNS readiness.
enum RestFatigueEstimator {
    /// Approximate rest-fatigue load 0…100 from sleep + water inputs (local sheet only).
    static func cnsLoad(sleepHours: Double, waterCups: Int) -> Double {
        let sleepFactor = max(0, (8.0 - sleepHours) * 10)
        let waterFactor = max(0, (8 - waterCups) * 2)
        return min(100, 20 + sleepFactor + Double(waterFactor))
    }

    /// Tips and ring require measured sleep — water alone must not unlock or invent readiness.
    static func showsMeasuredFatigue(hasSleepData: Bool) -> Bool {
        hasSleepData
    }

    /// Display string for the fatigue ring — `nil` means show an em dash (unmeasured).
    static func displayLoadPercent(hasSleepData: Bool, sleepHours: Double, waterCups: Int) -> Int? {
        guard showsMeasuredFatigue(hasSleepData: hasSleepData) else { return nil }
        return Int(cnsLoad(sleepHours: sleepHours, waterCups: waterCups))
    }
}
