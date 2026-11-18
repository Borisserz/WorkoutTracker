//
//  AccountDeletionCoordinator.swift
//  WorkoutTracker
//

import FirebaseAuth
import Foundation

/// Coordinates full App Store Guideline 5.1.1(v) account deletion in a safe order:
/// 1) Re-authenticate (and obtain fresh Apple authorizationCode if signed in with Apple)
/// 2) Wipe server-side Firestore user data BEFORE revoking Apple refresh token
/// 3) Revoke Apple token (while Firebase Auth user & ID token are still valid)
/// 4) Delete Firebase Auth user (with server-side fallback if recent-login check triggers)
/// 5) Sign out social/auth providers & clear all local storage unconditionally
/// 6) Best-effort re-bootstrap anonymous session for local app continuity
enum AccountDeletionCoordinator {

    static func execute(
        reauthenticate: () async throws -> String?,
        wipeServerData: () async throws -> Void,
        revokeAppleToken: (String) async throws -> Void,
        deleteAuthUser: () async throws -> Void,
        fallbackServerDeleteAuth: () async throws -> Void,
        signOutProviders: () async -> Void,
        wipeLocalState: () async -> Void,
        bootstrapAnonymous: () async throws -> Void
    ) async throws {
        let pendingAppleAuthCode = try await reauthenticate()

        // Delete Firestore UGC/profile data BEFORE revoking Apple tokens so a
        // network failure here never leaves Apple revoked while cloud data remains.
        try await wipeServerData()

        if let pendingAppleAuthCode, !pendingAppleAuthCode.isEmpty {
            try await revokeAppleToken(pendingAppleAuthCode)
        }

        do {
            try await deleteAuthUser()
        } catch let error where isAuthSessionAlreadyCleared(error) {
            // Firebase Auth record is already gone or invalidated — safe to proceed.
        } catch let error where isRequiresRecentLogin(error) {
            try await fallbackServerDeleteAuth()
        }

        await signOutProviders()
        await wipeLocalState()
        try? await bootstrapAnonymous()
    }

    static func isAuthSessionAlreadyCleared(_ error: Error) -> Bool {
        let nsError = error as NSError
        guard nsError.domain == AuthErrorDomain else { return false }
        return nsError.code == AuthErrorCode.userNotFound.rawValue
            || nsError.code == AuthErrorCode.userTokenExpired.rawValue
            || nsError.code == AuthErrorCode.invalidUserToken.rawValue
    }

    static func isRequiresRecentLogin(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == AuthErrorDomain
            && nsError.code == AuthErrorCode.requiresRecentLogin.rawValue
    }
}
