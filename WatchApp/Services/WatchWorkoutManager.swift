// ============================================================
// FILE: WatchApp/Services/WatchWorkoutManager.swift
// ============================================================
import Foundation
import HealthKit
internal import SwiftUI
import Observation

@Observable
@MainActor
final class WatchWorkoutManager: NSObject, Sendable {
    let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    
    var isRunning: Bool = false
    var heartRate: Double = 0.0
    var activeEnergy: Double = 0.0
    
    func requestAuthorization() async throws {
        let typesToShare: Set = [
            HKQuantityType.workoutType(),
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        ]
        let typesToRead: Set = [
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        ]
        try await healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead)
    }
    
    func startWorkout() async {
            // ✅ ИСПРАВЛЕНИЕ: Обнуляем значения перед стартом новой сессии
            self.activeEnergy = 0.0
            self.heartRate = 0.0
            
            let configuration = HKWorkoutConfiguration()
            configuration.activityType = .traditionalStrengthTraining
            configuration.locationType = .indoor
            
            do {
                session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
                builder = session?.associatedWorkoutBuilder()
                builder?.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
                
                session?.delegate = self
                builder?.delegate = self
                
                let startDate = Date()
                session?.startActivity(with: startDate)
                try await builder?.beginCollection(at: startDate)
                
                // 🛠️ FIX: Явное включение фонового режима (требует UIBackgroundModes в plist)
                self.isRunning = true
            } catch {
                print("WatchWorkoutManager: Failed to start session - \(error)")
            }
        }
    
    func endWorkout() async {
        guard let session = session, let builder = builder else { return }
        session.end()
        
        do {
            try await builder.endCollection(at: Date())
            _ = try await builder.finishWorkout()
            self.isRunning = false
            self.heartRate = 0.0
        } catch {
            print("WatchWorkoutManager: Failed to end workout - \(error)")
        }
    }
}

// MARK: - HK Delegates
extension WatchWorkoutManager: HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        Task { @MainActor in
            self.isRunning = (toState == .running)
        }
    }
    
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {}
    
    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType else { continue }
            guard let statistics = workoutBuilder.statistics(for: quantityType) else { continue }
            
            Task { @MainActor in
                if quantityType == HKQuantityType.quantityType(forIdentifier: .heartRate),
                   let hr = statistics.mostRecentQuantity()?.doubleValue(for: HKUnit(from: "count/min")) {
                    self.heartRate = hr
                } else if quantityType == HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
                          let energy = statistics.sumQuantity()?.doubleValue(for: .kilocalorie()) {
                    self.activeEnergy = energy // Обновляется реактивно!
                }
            }
        }
    }
    
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
}
