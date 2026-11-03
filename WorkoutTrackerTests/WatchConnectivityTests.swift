import XCTest
@testable import WorkoutTracker

@MainActor
final class WatchConnectivityTests: XCTestCase {

    // MARK: - LiveSyncPayload encode/decode

    func testLiveSyncPayloadRoundTrip_startWorkout() throws {
        let id = UUID().uuidString
        let original = LiveSyncPayload(
            action: .startWorkout,
            workoutID: id,
            workoutTitle: "Watch Session",
            exercises: [
                ExerciseDTO(
                    name: "Squat",
                    muscleGroup: "Legs",
                    type: .strength,
                    category: .squat,
                    effort: 7,
                    isCompleted: false,
                    setsList: [],
                    subExercises: [],
                    sets: 3,
                    reps: 5,
                    recommendedWeightKg: 100
                )
            ]
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(LiveSyncPayload.self, from: data)
        XCTAssertEqual(decoded.action, .startWorkout)
        XCTAssertEqual(decoded.workoutID, id)
        XCTAssertEqual(decoded.workoutTitle, "Watch Session")
        XCTAssertEqual(decoded.exercises?.count, 1)
        XCTAssertEqual(decoded.exercises?.first?.name, "Squat")
    }

    func testLiveSyncPayloadRoundTrip_logSetAndFinish() throws {
        let log = LiveSyncPayload(
            action: .logSet,
            workoutID: "w1",
            exerciseName: "Bench",
            setIndex: 2,
            weight: 60,
            reps: 8,
            isCompleted: true
        )
        let finish = LiveSyncPayload(action: .finishWorkout, workoutID: "w1", activeEnergy: 180, durationSeconds: 1200)
        for payload in [log, finish] {
            let data = try JSONEncoder().encode(payload)
            let decoded = try JSONDecoder().decode(LiveSyncPayload.self, from: data)
            XCTAssertEqual(decoded.action, payload.action)
            XCTAssertEqual(decoded.workoutID, payload.workoutID)
        }
        let decodedLog = try JSONDecoder().decode(LiveSyncPayload.self, from: try JSONEncoder().encode(log))
        XCTAssertEqual(decodedLog.setIndex, 2)
        XCTAssertEqual(decodedLog.weight, 60)
        XCTAssertEqual(decodedLog.reps, 8)
    }

    func testLiveSyncPayload_allActionTypesEncode() throws {
        for action in [
            SyncActionType.startWorkout, .logSet, .addExercise, .updateEffort,
            .finishWorkout, .discardWorkout, .requestActiveState, .syncFullState,
            .saveToHistory, .updateHeartRate
        ] {
            let payload = LiveSyncPayload(action: action, workoutID: "x", heartRate: action == .updateHeartRate ? 140 : nil)
            let data = try JSONEncoder().encode(payload)
            let decoded = try JSONDecoder().decode(LiveSyncPayload.self, from: data)
            XCTAssertEqual(decoded.action, action)
        }
    }

    // MARK: - Phone gate (canStartWorkout reply)

    func testPhoneAllowsWatchStart_whenIdle() {
        XCTAssertTrue(
            WatchSessionPolicy.phoneAllowsWatchStart(
                isSessionStartBlocked: false,
                hasModelContainer: true,
                freshActiveWorkoutCount: 0
            )
        )
    }

    func testPhoneRefusesWatchStart_whenActiveOrBlockedOrNoStore() {
        XCTAssertFalse(
            WatchSessionPolicy.phoneAllowsWatchStart(
                isSessionStartBlocked: false,
                hasModelContainer: true,
                freshActiveWorkoutCount: 1
            )
        )
        XCTAssertFalse(
            WatchSessionPolicy.phoneAllowsWatchStart(
                isSessionStartBlocked: true,
                hasModelContainer: true,
                freshActiveWorkoutCount: 0
            )
        )
        XCTAssertFalse(
            WatchSessionPolicy.phoneAllowsWatchStart(
                isSessionStartBlocked: false,
                hasModelContainer: false,
                freshActiveWorkoutCount: 0
            )
        )
    }

    // MARK: - Watch fail-closed gate

    func testWatchRefuseWhenCompanionUnreachable() {
        XCTAssertEqual(
            WatchSessionPolicy.watchMayAttemptStart(
                sessionActivated: true,
                isReachable: false,
                hasCompanionApp: true
            ),
            .refuse
        )
    }

    func testWatchAllowStandaloneWhenNoCompanion() {
        XCTAssertEqual(
            WatchSessionPolicy.watchMayAttemptStart(
                sessionActivated: true,
                isReachable: false,
                hasCompanionApp: false
            ),
            .allowStandalone
        )
    }

    func testWatchAskPhoneWhenReachable() {
        XCTAssertEqual(
            WatchSessionPolicy.watchMayAttemptStart(
                sessionActivated: true,
                isReachable: true,
                hasCompanionApp: true
            ),
            .askPhone
        )
    }

    func testWatchRefuseWhenSessionNotActivated() {
        XCTAssertEqual(
            WatchSessionPolicy.watchMayAttemptStart(
                sessionActivated: false,
                isReachable: true,
                hasCompanionApp: true
            ),
            .refuse
        )
    }

    func testWatchHandshake_transportFailWithCompanion_refuses() {
        XCTAssertFalse(
            WatchSessionPolicy.watchMayStartAfterPhoneHandshake(
                phoneAllowed: nil,
                transportFailed: true,
                hasCompanionApp: true
            )
        )
    }

    func testWatchHandshake_transportFailStandalone_allows() {
        XCTAssertTrue(
            WatchSessionPolicy.watchMayStartAfterPhoneHandshake(
                phoneAllowed: nil,
                transportFailed: true,
                hasCompanionApp: false
            )
        )
    }

    func testWatchHandshake_phoneReplyHonored() {
        XCTAssertTrue(
            WatchSessionPolicy.watchMayStartAfterPhoneHandshake(
                phoneAllowed: true,
                transportFailed: false,
                hasCompanionApp: true
            )
        )
        XCTAssertFalse(
            WatchSessionPolicy.watchMayStartAfterPhoneHandshake(
                phoneAllowed: false,
                transportFailed: false,
                hasCompanionApp: true
            )
        )
        XCTAssertFalse(
            WatchSessionPolicy.watchMayStartAfterPhoneHandshake(
                phoneAllowed: nil,
                transportFailed: false,
                hasCompanionApp: true
            )
        )
    }

    func testHealthKitSessionFailureMessageIsUserFacing() {
        let message = WatchSessionPolicy.healthKitSessionFailureMessage
        XCTAssertFalse(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        XCTAssertTrue(
            message.localizedCaseInsensitiveContains("healthkit")
                || message.localizedCaseInsensitiveContains("session")
                || message.localizedCaseInsensitiveContains("failed"),
            "Mid-session HK failure copy must be explicit, not empty: \(message)"
        )
    }

    // MARK: - Dual-start (policy; full WC race = device smoke + ResidualPass concurrent create)

    func testDualStartGate_blocksWhenPhoneBusyOrActive() {
        // Mirror canStartWorkout reply: blocked start OR any fresh active → refuse Watch.
        XCTAssertFalse(
            WatchSessionPolicy.phoneAllowsWatchStart(
                isSessionStartBlocked: true,
                hasModelContainer: true,
                freshActiveWorkoutCount: 0
            )
        )
        XCTAssertFalse(
            WatchSessionPolicy.phoneAllowsWatchStart(
                isSessionStartBlocked: false,
                hasModelContainer: true,
                freshActiveWorkoutCount: 1
            )
        )
        XCTAssertTrue(
            WatchSessionPolicy.phoneAllowsWatchStart(
                isSessionStartBlocked: false,
                hasModelContainer: true,
                freshActiveWorkoutCount: 0
            )
        )
    }

    // MARK: - Sync envelope (key mismatch fix)

    func testWatchSyncEnvelope_readsSyncPayloadKey() {
        let data = Data([1, 2, 3])
        XCTAssertEqual(WatchSyncEnvelope.liveSyncData(from: ["syncPayload": data]), data)
    }

    func testWatchSyncEnvelope_readsGuaranteedSyncPayloadKey() {
        let data = Data([4, 5, 6])
        XCTAssertEqual(WatchSyncEnvelope.liveSyncData(from: ["guaranteedSyncPayload": data]), data)
    }

    func testWatchSyncEnvelope_prefersSyncPayloadWhenBothPresent() {
        let live = Data([7])
        let guaranteed = Data([8])
        let dict: [String: Any] = ["syncPayload": live, "guaranteedSyncPayload": guaranteed]
        XCTAssertEqual(WatchSyncEnvelope.liveSyncData(from: dict), live)
    }

    func testWatchSyncEnvelope_outboundCarriesBothKeys() {
        let data = Data([9, 10])
        let dict = WatchSyncEnvelope.userInfo(carrying: data)
        XCTAssertEqual(dict["syncPayload"] as? Data, data)
        XCTAssertEqual(dict["guaranteedSyncPayload"] as? Data, data)
    }

    // MARK: - Finish-orphan grace (snackbar undo window)

    func testFinishOrphanGrace_skipsRecentEndTime() {
        let end = Date()
        XCTAssertFalse(
            WatchSessionPolicy.shouldProcessFinishOrphan(
                endTime: end,
                now: end.addingTimeInterval(3),
                graceSeconds: 15
            )
        )
    }

    func testFinishOrphanGrace_processesAfterGrace() {
        let end = Date().addingTimeInterval(-60)
        XCTAssertTrue(
            WatchSessionPolicy.shouldProcessFinishOrphan(
                endTime: end,
                now: Date(),
                graceSeconds: 15
            )
        )
    }

    // MARK: - Watch start reservation TTL

    func testWatchStartReservation_activeWithinTTL() {
        let reservedUntil = Date().addingTimeInterval(5)
        XCTAssertTrue(WatchSessionPolicy.isWatchStartReservationActive(until: reservedUntil, now: Date()))
        XCTAssertFalse(
            WatchSessionPolicy.isWatchStartReservationActive(
                until: Date().addingTimeInterval(-1),
                now: Date()
            )
        )
        XCTAssertFalse(WatchSessionPolicy.isWatchStartReservationActive(until: nil, now: Date()))
    }
}
