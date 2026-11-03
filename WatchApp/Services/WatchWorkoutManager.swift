import Foundation
import OSLog
import HealthKit
internal import SwiftUI
import Observation

@Observable
@MainActor
final class WatchWorkoutManager: NSObject {
    let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    var isRunning: Bool = false
    var heartRate: Double = 0.0
    var activeEnergy: Double = 0.0
    /// Set when HK session fails to start — UI must surface this (no silent soft-fail).
    var startFailureMessage: String? = nil

    func requestAuthorization() async throws {
        guard
            let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
            let heartType = HKQuantityType.quantityType(forIdentifier: .heartRate)
        else {
            throw NSError(
                domain: "WatchWorkoutManager",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: String(localized: "HealthKit types unavailable on this device.")]
            )
        }
        let typesToShare: Set = [
            HKQuantityType.workoutType(),
            energyType
        ]
        let typesToRead: Set = [
            heartType,
            energyType
        ]
        try await healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead)
    }

    func startWorkout() async {
        self.activeEnergy = 0.0
        self.heartRate = 0.0
        self.startFailureMessage = nil
        self.isRunning = false

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

            self.isRunning = true
        } catch {
            self.isRunning = false
            self.session = nil
            self.builder = nil
            self.startFailureMessage = String(localized: "Could not start HealthKit workout. Try again.")
            WatchAppLog.workout.error("WatchWorkoutManager: Failed to start session - \(error.localizedDescription, privacy: .public)")
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
            WatchAppLog.workout.error("WatchWorkoutManager: Failed to end workout - \(error.localizedDescription, privacy: .public)")
        }
    }
}

extension WatchWorkoutManager: HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        // HKWorkoutSessionState is a Sendable enum → safe to capture.
        Task { @MainActor in
            self.isRunning = (toState == .running)
        }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        let detail = error.localizedDescription
        Task { @MainActor in
            self.isRunning = false
            self.session = nil
            self.builder = nil
            self.startFailureMessage = WatchSessionPolicy.healthKitSessionFailureMessage
            WatchAppLog.workout.error(
                "WatchWorkoutManager: HK session failed — \(detail, privacy: .public)"
            )
        }
    }

    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        // Do all HealthKit reads here (nonisolated). Extract only Sendable Doubles
        // before hopping to the main actor — never capture HKStatistics/HKQuantityType.
        let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate)
        let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)

        var newHeartRate: Double?
        var newEnergy: Double?

        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType else { continue }
            guard let statistics = workoutBuilder.statistics(for: quantityType) else { continue }

            if quantityType == hrType,
               let hr = statistics.mostRecentQuantity()?.doubleValue(for: HKUnit(from: "count/min")) {
                newHeartRate = hr
            } else if quantityType == energyType,
                      let energy = statistics.sumQuantity()?.doubleValue(for: .kilocalorie()) {
                newEnergy = energy
            }
        }

        let hrToSend = newHeartRate
        let energyToSet = newEnergy

        Task { @MainActor in
            if let hr = hrToSend {
                self.heartRate = hr
                let payload = LiveSyncPayload(
                    action: .updateHeartRate,
                    workoutID: "",
                    heartRate: hr
                )
                WatchSyncManager.shared.sendLiveAction(payload)
            }
            if let energy = energyToSet {
                self.activeEnergy = energy
            }
        }
    }

    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
}
