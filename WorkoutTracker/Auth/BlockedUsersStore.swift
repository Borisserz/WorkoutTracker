//
//  BlockedUsersStore.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 30.05.2026.
//

//
//  BlockedUsersStore.swift
//  WorkoutTracker
//
//  Local cache + Firestore-backed list of blocked creator UIDs. Used to hide
//  shared workouts from blocked creators in feeds and at deep-link import.
//
//  Subcollection layout: users/{uid}/blocked/{blockedUid}
//

import Foundation
import FirebaseFirestore
import OSLog

actor BlockedUsersStore {

    static let shared = BlockedUsersStore()

    private let log = Logger(subsystem: "com.borisdev.WorkoutTracker", category: "BlockedUsers")
    private var cache: Set<String> = []
    private var hydrated: Bool = false
    private var listener: ListenerRegistration?

    private init() {}

    /// Start listening for changes to the current user's blocked list. Idempotent.
    func startListening() async {
        guard let myUid = await MainActor.run(body: { AnonymousAuthBootstrap.shared.currentUid }) else {
            log.warning("No current user — skipping startListening")
            return
        }
        guard listener == nil else { return }

        let db = Firestore.firestore()
        let registration = db.collection("users").document(myUid).collection("blocked")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    Task { await self.handleError(error) }
                    return
                }
                let ids = snapshot?.documents.map { $0.documentID } ?? []
                Task { await self.replaceCache(with: Set(ids)) }
            }
        self.listener = registration
        log.info("Listening to blocked list for uid=\(myUid, privacy: .private)")
    }

    /// Stop listening. Call on sign-out.
    func stopListening() {
        listener?.remove()
        listener = nil
        cache.removeAll()
        hydrated = false
    }

    /// Block a creator. Writes users/{myUid}/blocked/{blockedUid}.
    func block(uid blockedUid: String) async throws {
        guard let myUid = await MainActor.run(body: { AnonymousAuthBootstrap.shared.currentUid }) else {
            throw BlockError.notAuthenticated
        }
        guard blockedUid != myUid else { return }
        let db = Firestore.firestore()
        try await db.collection("users").document(myUid)
            .collection("blocked").document(blockedUid)
            .setData([
                "blockedAt": FieldValue.serverTimestamp()
            ])
        cache.insert(blockedUid)
        log.info("Blocked uid=\(blockedUid, privacy: .private)")
    }

    /// Unblock a creator.
    func unblock(uid blockedUid: String) async throws {
        guard let myUid = await MainActor.run(body: { AnonymousAuthBootstrap.shared.currentUid }) else {
            throw BlockError.notAuthenticated
        }
        let db = Firestore.firestore()
        try await db.collection("users").document(myUid)
            .collection("blocked").document(blockedUid)
            .delete()
        cache.remove(blockedUid)
        log.info("Unblocked uid=\(blockedUid, privacy: .private)")
    }

    /// Check if a creator is blocked (uses cache if hydrated).
    func isBlocked(uid: String) -> Bool {
        cache.contains(uid)
    }

    /// Snapshot of currently blocked UIDs.
    func blockedUids() -> Set<String> {
        cache
    }

    // MARK: - Private

    private func replaceCache(with new: Set<String>) {
        cache = new
        hydrated = true
        log.debug("Cache refreshed — \(new.count) blocked uid(s)")
    }

    private func handleError(_ error: Error) {
        log.error("Block listener error: \(error.localizedDescription, privacy: .public)")
    }
}

enum BlockError: LocalizedError {
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You need to sign in to your account."
        }
    }
}
