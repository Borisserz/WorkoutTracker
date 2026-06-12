import Testing
@testable import WorkoutTracker

@Suite("CNS Calculator Tests")
struct CNSCalculatorTests {

    @Test("Optimal conditions yield max score")
    func optimalConditions() {
        let score = CNSCalculator.calculate(
            sleepHours: 8.0,
            hrv: 60.0,
            baselineHRV: 40.0,
            rhr: 50.0,
            baselineRHR: 60.0,
            waterCups: 8
        )
        
        #expect(score > 80.0, "Score should be optimal (>80)")
    }

    @Test("Poor conditions yield low score")
    func poorConditions() {
        let score = CNSCalculator.calculate(
            sleepHours: 4.0,
            hrv: 20.0,
            baselineHRV: 50.0,
            rhr: 80.0,
            baselineRHR: 60.0,
            waterCups: 2
        )
        
        #expect(score < 50.0, "Score should be low (<50)")
    }
}
