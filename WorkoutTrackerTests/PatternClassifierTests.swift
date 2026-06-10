import Testing
@testable import WorkoutTracker

@Suite("Pattern Classifier Tests")
struct PatternClassifierTests {

    @Test("Classifies curl correctly")
    func testElbowFlexion() {
        let pattern = PatternClassifier.classify(
            name: "Bicep Curl",
            force: "pull",
            mechanic: "isolation",
            primaryMuscles: ["biceps"]
        )
        #expect(pattern == .elbowFlexion)
    }

    @Test("Classifies squat correctly")
    func testSquat() {
        let pattern = PatternClassifier.classify(
            name: "Barbell Squat",
            force: "push",
            mechanic: "compound",
            primaryMuscles: ["quadriceps"]
        )
        #expect(pattern == .squat)
    }

    @Test("Classifies deadlift correctly")
    func testHinge() {
        let pattern = PatternClassifier.classify(
            name: "Romanian Deadlift",
            force: "pull",
            mechanic: "compound",
            primaryMuscles: ["hamstrings"]
        )
        #expect(pattern == .hinge)
    }

    @Test("Classifies bench press correctly")
    func testHorizontalPress() {
        let pattern = PatternClassifier.classify(
            name: "Bench Press",
            force: "push",
            mechanic: "compound",
            primaryMuscles: ["chest"]
        )
        #expect(pattern == .horizontalPress)
    }
}
