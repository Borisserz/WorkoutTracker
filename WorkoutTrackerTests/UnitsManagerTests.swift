import Testing
@testable import WorkoutTracker

@Suite("Units Manager Tests")
struct UnitsManagerTests {

    @Test("Test Kilograms to Pounds Conversion")
    @MainActor
    func testKgToLbs() async throws {
        let manager = UnitsManager.shared
        manager.setWeightUnit(.pounds)
        
        // When manager is set to pounds, reading a kg value from DB should convert to pounds
        let lbs = manager.convertFromKilograms(100.0)
        #expect(abs(lbs - 220.462) < 0.01)
        
        // When saving lbs to DB, it converts to kg
        let kg = manager.convertToKilograms(220.462)
        #expect(abs(kg - 100.0) < 0.01)
    }

    @Test("Test Meters to Miles Conversion")
    @MainActor
    func testMetersToMiles() async throws {
        let manager = UnitsManager.shared
        manager.setDistanceUnit(.miles)
        
        let miles = manager.convertFromMeters(1609.34)
        #expect(abs(miles - 1.0) < 0.01)
        
        let meters = manager.convertToMeters(1.0)
        #expect(abs(meters - 1609.34) < 1.0)
    }
    
    @Test("Test Centimeters to Inches Conversion")
    @MainActor
    func testCmToInches() async throws {
        let manager = UnitsManager.shared
        manager.setSizeUnit(.inches)
        
        let inches = manager.convertFromCentimeters(254)
        #expect(abs(inches - 100) < 0.01)
        
        let cm = manager.convertToCentimeters(100)
        #expect(abs(cm - 254) < 0.01)
    }
}
