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
    /// After sign-out or account deletion the cached task is finished and
    /// `currentUser` is nil, so a new anonymous session must start.
    @discardableResult
    func ensureSignedIn() async throws -> User {
        if let user = Auth.auth().currentUser {
            log.debug("Already signed in as \(user.uid, privacy: .private) (anonymous: \(user.isAnonymous))")
            return user
        }

        if AnonymousBootstrapPlan.next(hasCurrentUser: false, hasCachedTask: bootstrapTask != nil) == .awaitCachedTask,
           let existing = bootstrapTask {
            try await existing.value
            if AnonymousBootstrapPlan.afterCachedTask(hasCurrentUser: Auth.auth().currentUser != nil) == .useCurrentUser,
               let user = Auth.auth().currentUser {
                return user
            }
            bootstrapTask = nil
        }

        let task = Task<Void, Error> { [log] in
            // Re-check: social sign-in may have completed while this task was queued.
            if let existingUser = Auth.auth().currentUser {
                log.debug("Skip anonymous — already signed in as \(existingUser.uid, privacy: .private)")
                return
            }
            log.info("Signing in anonymously…")
            let result = try await Auth.auth().signInAnonymously()
            // If a non-anonymous user appeared mid-flight, prefer them.
            if let current = Auth.auth().currentUser, !current.isAnonymous, current.uid != result.user.uid {
                log.info("Social session won over anonymous — keeping \(current.uid, privacy: .private)")
                return
            }
            log.info("Anonymous sign-in OK uid=\(result.user.uid, privacy: .public)")
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

enum AnonymousBootstrapPlan: Equatable {
    case useCurrentUser
    case awaitCachedTask
    case beginAnonymousSignIn

    static func next(hasCurrentUser: Bool, hasCachedTask: Bool) -> Self {
        if hasCurrentUser { return .useCurrentUser }
        if hasCachedTask { return .awaitCachedTask }
        return .beginAnonymousSignIn
    }

    /// A finished bootstrap from launch must not block a new guest session
    /// after sign-out or account deletion.
    static func afterCachedTask(hasCurrentUser: Bool) -> Self {
        hasCurrentUser ? .useCurrentUser : .beginAnonymousSignIn
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
