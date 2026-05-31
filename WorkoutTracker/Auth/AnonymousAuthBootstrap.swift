//
//  AnonymousAuthBootstrap.swift
//  WorkoutTracker
//
//  Ensures every device has a stable anonymous Firebase identity before any
//  Firestore writes happen. UGC features (sharing workouts, reporting,
//  blocking) require request.auth.uid in Firestore rules.
//
//  Sign In with Apple is layered on top via Auth.auth().currentUser?.link(with:)
//  when the user explicitly upgrades — anonymous UIDs carry over.
//

import Foundation
import FirebaseAuth
import OSLog

/// Singleton bootstrap that guarantees a non-nil `Auth.auth().currentUser`
/// before any Firestore write happens.
@MainActor
final class AnonymousAuthBootstrap {

    static let shared = AnonymousAuthBootstrap()

    private let log = Logger(subsystem: "com.borisdev.WorkoutTracker", category: "AnonymousAuth")
    private var bootstrapTask: Task<Void, Error>?

    private init() {}

    /// Call once at app launch. Idempotent — multiple calls await the same task.
    @discardableResult
    func ensureSignedIn() async throws -> User {
        if let user = Auth.auth().currentUser {
            log.debug("Already signed in as \(user.uid, privacy: .private) (anonymous: \(user.isAnonymous))")
            return user
        }

        if let existing = bootstrapTask {
            try await existing.value
            guard let user = Auth.auth().currentUser else {
                throw AuthBootstrapError.noUserAfterSignIn
            }
            return user
        }

        let task = Task<Void, Error> { [log] in
            log.info("Signing in anonymously…")
            let result = try await Auth.auth().signInAnonymously()
            log.info("Anonymous sign-in OK uid=\(result.user.uid, privacy: .private)")
        }
        bootstrapTask = task

        do {
            try await task.value
        } catch {
            bootstrapTask = nil
            log.error("Anonymous sign-in failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }

        guard let user = Auth.auth().currentUser else {
            throw AuthBootstrapError.noUserAfterSignIn
        }
        return user
    }

    /// Synchronously returns the current UID if available (no I/O).
    var currentUid: String? {
        Auth.auth().currentUser?.uid
    }
}

enum AuthBootstrapError: LocalizedError {
    case noUserAfterSignIn

    var errorDescription: String? {
        switch self {
        case .noUserAfterSignIn:
            return "Unable to log in anonymously. Check your internet connection and try again."
        }
    }
}//
