import Foundation
import HealthKit

enum HealthKitError: LocalizedError {
    case notAvailable
    case unauthorized
    case dataNotFound
    case saveFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .notAvailable: return "HealthKit is not available on this device."
        case .unauthorized: return "Missing permissions to access HealthKit data."
        case .dataNotFound: return "Requested data was not found."
        case .saveFailed(let error): return "Failed to save data: \(error.localizedDescription)"
        }
    }
}

actor HealthKitManager: Sendable {
    static let shared = HealthKitManager()
    private let healthStore = HKHealthStore()
    
    private init() {}
    
    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }
    
    // MARK: - Authorization
    func requestAuthorization() async throws {
        guard isAvailable else { throw HealthKitError.notAvailable }
        
        let bodyMass = HKObjectType.quantityType(forIdentifier: .bodyMass)!
        let workout = HKObjectType.workoutType()
        let activeEnergy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
        let heartRate = HKObjectType.quantityType(forIdentifier: .heartRate)!
        
        let typesToShare: Set = [bodyMass, workout, activeEnergy]
        let typesToRead: Set = [bodyMass, heartRate, activeEnergy]
        
        do {
            try await healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead)
        } catch {
            throw HealthKitError.unauthorized
        }
    }
    
    // MARK: - Weight Sync (2-Way)
    func fetchLatestWeight() async throws -> Double {
        guard let bodyMassType = HKObjectType.quantityType(forIdentifier: .bodyMass) else {
            throw HealthKitError.notAvailable
        }
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: bodyMassType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: HealthKitError.saveFailed(error))
                    return
                }
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(throwing: HealthKitError.dataNotFound)
                    return
                }
                continuation.resume(returning: sample.quantity.doubleValue(for: .gramUnit(with: .kilo)))
            }
            healthStore.execute(query)
        }
    }
    
    func saveWeight(_ weightKg: Double, date: Date) async throws {
        guard let bodyMassType = HKObjectType.quantityType(forIdentifier: .bodyMass) else { throw HealthKitError.notAvailable }
        
        let quantity = HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: weightKg)
        let sample = HKQuantitySample(type: bodyMassType, quantity: quantity, start: date, end: date)
        
        do {
            try await healthStore.save(sample)
        } catch {
            throw HealthKitError.saveFailed(error)
        }
    }
    
    // MARK: - Workout Sync
    
    // ✅ FIX: Renamed back to `saveWorkout` and using direct HKWorkout initialization instead of WatchOS Builder
    /// Saves workout and estimated active energy to HealthKit to close Activity Rings
    // MARK: - Workout Sync
    
    /// Saves workout and estimated active energy to HealthKit to close Activity Rings
    func saveWorkout(title: String, startDate: Date, endDate: Date, durationSeconds: Int, calories: Int) async throws {
        print("🔄 HealthKitManager: Initiating save...")
        guard isAvailable else {
            print("❌ HealthKit: Not available on this device")
            return
        }
        
        let actualDuration = max(Double(durationSeconds), endDate.timeIntervalSince(startDate))
        print("📊 Data: Duration = \(actualDuration) sec, Calories = \(calories) kcal")
        
        guard actualDuration >= 60 else {
            print("⚠️ Cancelled: Workout is under 60 seconds. Apple Health will ignore it.")
            return
        }
        
        let activityType: HKWorkoutActivityType = title.lowercased().contains("cardio") ? .running : .traditionalStrengthTraining
        let energyQuantity = HKQuantity(unit: .kilocalorie(), doubleValue: Double(calories))
        
        let workout = HKWorkout(
            activityType: activityType,
            start: startDate,
            end: endDate,
            workoutEvents: nil,
            totalEnergyBurned: energyQuantity,
            totalDistance: nil,
            metadata: [
                HKMetadataKeyWorkoutBrandName: "WorkoutTracker",
                "CustomTitle": title
            ]
        )
        
        do {
            try await healthStore.save(workout)
            print("✅ SUCCESS: HKWorkout written to DB!")
            
            // Explicitly save Active Energy Burned sample to ensure Move Ring closes
            if let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
                let energySample = HKQuantitySample(type: energyType, quantity: energyQuantity, start: startDate, end: endDate)
                try await healthStore.save(energySample)
                print("✅ SUCCESS: Calories added to Move Ring!")
            }
        } catch {
            print("❌ HealthKit save ERROR: \(error.localizedDescription)")
            throw HealthKitError.saveFailed(error)
        }
    }
}
