import Testing
@testable import WorkoutTracker
import Foundation
import SwiftData
import SwiftUI

@Suite("Muscle Color Manager Tests")
struct MuscleColorManagerTests {
    
    @Test("Test Default Colors")
    @MainActor
    func testDefaultColors() async throws {
        let manager = MuscleColorManager.shared
        
        let backColor = manager.getColor(for: "Back")
        #expect(backColor == Color.green)
        
        let armsColor = manager.getColor(for: "Arms")
        #expect(armsColor == Color.red)
        
        let unknownColor = manager.getColor(for: "Unknown")
        #expect(unknownColor == Color.gray)
    }
}
