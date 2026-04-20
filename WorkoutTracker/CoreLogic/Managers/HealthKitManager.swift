import Foundation
import HealthKit
internal import SwiftUI
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
         
         // НОВЫЕ ТИПЫ ДЛЯ ЦНС
         let hrv = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
         let rhr = HKObjectType.quantityType(forIdentifier: .restingHeartRate)!
         let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
         
         let steps = HKObjectType.quantityType(forIdentifier: .stepCount)!
         let water = HKObjectType.quantityType(forIdentifier: .dietaryWater)!
         
         let typesToShare: Set = [bodyMass, workout, activeEnergy]
         let typesToRead: Set = [bodyMass, heartRate, activeEnergy, steps, water, hrv, rhr, sleep]
         
         do {
             try await healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead)
         } catch {
             throw HealthKitError.unauthorized
         }
     }

     // MARK: - Biometrics (HRV, RHR, Sleep)
     
     func fetchLatestHRV() async -> Double? {
         guard let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { return nil }
         let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
         
         return await withCheckedContinuation { continuation in
             let query = HKSampleQuery(sampleType: hrvType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, _ in
                 guard let sample = samples?.first as? HKQuantitySample else {
                     continuation.resume(returning: nil)
                     return
                 }
                 // HRV измеряется в миллисекундах
                 continuation.resume(returning: sample.quantity.doubleValue(for: HKUnit(from: "ms")))
             }
             healthStore.execute(query)
         }
     }
     
     func fetchLatestRHR() async -> Double? {
         guard let rhrType = HKObjectType.quantityType(forIdentifier: .restingHeartRate) else { return nil }
         let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
         
         return await withCheckedContinuation { continuation in
             let query = HKSampleQuery(sampleType: rhrType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, _ in
                 guard let sample = samples?.first as? HKQuantitySample else {
                     continuation.resume(returning: nil)
                     return
                 }
                 continuation.resume(returning: sample.quantity.doubleValue(for: HKUnit(from: "count/min")))
             }
             healthStore.execute(query)
         }
     }
     
     func fetchSleepDuration() async -> Double? {
         guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return nil }
         
         // Смотрим сон за последние 24 часа
         let now = Date()
         let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!
         let predicate = HKQuery.predicateForSamples(withStart: yesterday, end: now, options: .strictEndDate)
         let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
         
         return await withCheckedContinuation { continuation in
             let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, _ in
                 guard let sleepSamples = samples as? [HKCategorySample] else {
                     continuation.resume(returning: nil)
                     return
                 }
                 
                 // Суммируем только те фазы, где пользователь реально спал
                 let totalSleepSeconds = sleepSamples
                     .filter { $0.value == HKCategoryValueSleepAnalysis.asleep.rawValue ||
                               $0.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                               $0.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                               $0.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue }
                     .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
                 
                 if totalSleepSeconds > 0 {
                     continuation.resume(returning: totalSleepSeconds / 3600.0) // Переводим в часы
                 } else {
                     continuation.resume(returning: nil)
                 }
             }
             healthStore.execute(query)
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
    
    // MARK: - Heart Rate Monitoring
    func fetchLatestHeartRate() async throws -> (value: Double, date: Date)? {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            throw HealthKitError.notAvailable
        }
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: heartRateType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: HealthKitError.saveFailed(error))
                    return
                }
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let hrValue = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
                continuation.resume(returning: (value: hrValue, date: sample.endDate))
            }
            healthStore.execute(query)
        }
    }
    
    func startHeartRateObservation(onUpdate: @escaping @Sendable (Double, Date) -> Void) {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return }
        
        // Разрешаем фоновую доставку данных (будет будить приложение)
        healthStore.enableBackgroundDelivery(for: heartRateType, frequency: .immediate) { success, error in
            if success { print("✅ Фоновая доставка пульса включена") }
        }
        
        // Создаем наблюдателя
        let query = HKObserverQuery(sampleType: heartRateType, predicate: nil) { [weak self] _, completionHandler, error in
            guard error == nil else { return }
            
            Task {
                if let latestHR = try? await self?.fetchLatestHeartRate() {
                    onUpdate(latestHR.value, latestHR.date)
                }
                completionHandler()
            }
        }
        
        healthStore.execute(query)
    }
    
    // MARK: - Integration with FoodTracker (Steps & Water)
    func fetchSteps(for date: Date = Date()) async throws -> Int {
        guard isAvailable, let stepsType = HKObjectType.quantityType(forIdentifier: .stepCount) else { return 0 }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: stepsType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                let steps = Int(result?.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0)
                continuation.resume(returning: steps)
            }
            healthStore.execute(query)
        }
    }
    
    func fetchWaterLiters(for date: Date = Date()) async throws -> Double {
        guard isAvailable, let waterType = HKObjectType.quantityType(forIdentifier: .dietaryWater) else { return 0.0 }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: waterType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                let liters = result?.sumQuantity()?.doubleValue(for: HKUnit.liter()) ?? 0.0
                continuation.resume(returning: liters)
            }
            healthStore.execute(query)
        }
    }
}


struct CNSCalculator {
    /// Считает Индекс Готовности ЦНС (0 - убит, 100 - машина)
    static func calculate(sleepHours: Double, hrv: Double?, rhr: Double?, waterCups: Int = 8) -> Double {
        // 1. Сон (Макс 40 баллов). Идеал: 8 часов
        let sleepScore = min(40.0, max(0, (sleepHours / 8.0) * 40.0))
        
        // 2. Вода (Макс 10 баллов). Идеал: 8 стаканов
        let waterScore = min(10.0, max(0, (Double(waterCups) / 8.0) * 10.0))
        
        // 3. HRV (Макс 30 баллов)
        let hrvScore: Double
        if let hrv = hrv {
            // В среднем: меньше 20ms - плохо, 60ms+ - отлично
            hrvScore = min(30.0, max(0, ((hrv - 20.0) / 40.0) * 30.0))
        } else {
            hrvScore = 20.0 // Если нет часов, даем средний балл
        }
        
        // 4. RHR - Пульс в покое (Макс 20 баллов)
        let rhrScore: Double
        if let rhr = rhr {
            // В среднем: 50bpm - отлично, 80bpm - плохо
            rhrScore = min(20.0, max(0, 20.0 - (((rhr - 50.0) / 30.0) * 20.0)))
        } else {
            rhrScore = 15.0 // Если нет часов, даем средний балл
        }
        
        return sleepScore + waterScore + hrvScore + rhrScore
    }
    
    /// Возвращает текст и цвет на основе баллов
    static func getStatus(for score: Double) -> (text: String, color: Color) {
        if score >= 80 { return ("Оптимально для гипертрофии", .green) }
        if score >= 60 { return ("Легкая усталость (База)", .orange) }
        if score >= 40 { return ("Требуется восстановление", .orange) }
        return ("Истощение (Только отдых)", .red)
    }
}
