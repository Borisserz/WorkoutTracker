import Testing
@testable import WorkoutTracker

@Suite("1RM Calculator Tests")
struct OneRepMaxCalculatorTests {

    @Test("Test 1RM for 1 rep returns original weight")
    func testOneRepMaxForOneRep() async throws {
        let max = OneRepMaxCalculator.calculate1RM(weight: 100, reps: 1, formula: .epley)
        #expect(max == 100.0)
    }

    @Test("Test Epley Formula")
    func testEpleyFormula() async throws {
        let max = OneRepMaxCalculator.calculate1RM(weight: 100, reps: 5, formula: .epley)
        // 100 * (1 + 5/30) = 116.666
        #expect(abs(max - 116.666) < 0.01)
    }

    @Test("Test Brzycki Formula")
    func testBrzyckiFormula() async throws {
        let max = OneRepMaxCalculator.calculate1RM(weight: 100, reps: 5, formula: .brzycki)
        // 100 * (36 / 32) = 112.5
        #expect(abs(max - 112.5) < 0.01)
    }

    @Test("Test Weight for Reps Epley")
    func testWeightForRepsEpley() async throws {
        let weight = OneRepMaxCalculator.calculateWeightForReps(oneRepMax: 116.666, targetReps: 5, formula: .epley)
        #expect(abs(weight - 100.0) < 0.01)
    }

    @Test("Test Invalid Inputs")
    func testInvalidInputs() async throws {
        let zeroReps = OneRepMaxCalculator.calculate1RM(weight: 100, reps: 0, formula: .average)
        #expect(zeroReps == 0)

        let zeroWeight = OneRepMaxCalculator.calculate1RM(weight: 0, reps: 5, formula: .average)
        #expect(zeroWeight == 0)
    }
}
