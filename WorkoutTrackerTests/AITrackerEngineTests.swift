import Testing
import CoreGraphics
@testable import WorkoutTracker

@Suite("AITracker Engine Tests")
struct AITrackerEngineTests {

    @Test("BiomechanicsMath distance calculation")
    func testDistanceCalculation() {
        let p1 = CGPoint(x: 0, y: 0)
        let p2 = CGPoint(x: 3, y: 4)
        
        let dist = BiomechanicsMath.distance(p1: p1, p2: p2)
        #expect(dist == 5.0)
    }

    @Test("BiomechanicsMath angle calculation")
    func testAngleCalculation() {
        let p1 = CGPoint(x: 0, y: 1)
        let p2 = CGPoint(x: 0, y: 0)
        let p3 = CGPoint(x: 1, y: 0)
        
        let angle = BiomechanicsMath.angleBetween(p1: p1, p2: p2, p3: p3)
        #expect(angle > 89.0 && angle < 91.0)
    }
    
    @Test("Amplitude percentage calculation")
    func testAmplitude() {
        let percent = BiomechanicsMath.amplitudePercentage(current: 100, relaxed: 150, contracted: 50)
        #expect(percent == 50.0)
    }
}
