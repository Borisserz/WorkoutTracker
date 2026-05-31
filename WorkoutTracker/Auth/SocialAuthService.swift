//
//  SocialAuthService.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 30.05.2026.
//

import Foundation
import AuthenticationServices
import CryptoKit
import FirebaseAuth
import FirebaseCore
import GoogleSignIn
import UIKit

@MainActor
final class SocialAuthService {

    static let shared = SocialAuthService()
    private init() {}

    private var currentNonce: String?

    // MARK: - Apple

    func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = Self.randomNonce()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)
    }

    func handleAppleAuthorization(_ result: Result<ASAuthorization, Error>) async throws {
        let authorization = try result.get()

        guard
            let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
            let nonce = currentNonce,
            let tokenData = credential.identityToken,
            let idToken = String(data: tokenData, encoding: .utf8)
        else {
            throw AuthError.invalidAppleCredential
        }

        let firebaseCredential = OAuthProvider.appleCredential(
            withIDToken: idToken,
            rawNonce: nonce,
            fullName: credential.fullName
        )
        try await linkOrSignIn(with: firebaseCredential)
        currentNonce = nil
    }

    // MARK: - Google

    func signInWithGoogle() async throws {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw AuthError.missingGoogleClientID
        }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        guard let presenter = Self.topViewController() else {
            throw AuthError.noPresentingController
        }

        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
        guard let idToken = result.user.idToken?.tokenString else {
            throw AuthError.invalidGoogleCredential
        }

        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: result.user.accessToken.tokenString
        )
        try await linkOrSignIn(with: credential)
    }

    // MARK: - Linking core


    private func linkOrSignIn(with credential: AuthCredential) async throws {
        if let user = Auth.auth().currentUser, user.isAnonymous {
            do {
                _ = try await user.link(with: credential)
            } catch {
                let nsError = error as NSError
                let code = AuthErrorCode(rawValue: nsError.code)
                if code == .credentialAlreadyInUse || code == .emailAlreadyInUse {
                    let updated = nsError
                        .userInfo[AuthErrorUserInfoUpdatedCredentialKey] as? AuthCredential
                    _ = try await Auth.auth().signIn(with: updated ?? credential)
                } else {
                    throw error
                }
            }
        } else {
            _ = try await Auth.auth().signIn(with: credential)
        }
    }

    // MARK: - Helpers

    private static func randomNonce(length: Int = 32) -> String {
        var bytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        precondition(status == errSecSuccess, "SecRandomCopyBytes failed: \(status)")
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(bytes.map { charset[Int($0) % charset.count] })
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .first { $0.activationState == .foregroundActive } as? UIWindowScene
        var top = scene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
    // MARK: - Account deletion support (Guideline 5.1.1(v))

    /// Re-authenticates the current user immediately before deletion and,
    /// for Sign in with Apple, revokes the Apple refresh token.
    /// MUST be called BEFORE any destructive server-side deletion.
    func reauthenticateForDeletion() async throws {
        guard let user = Auth.auth().currentUser else {
            throw AuthError.notSignedIn
        }

        // Anonymous users never linked a provider: no recent-login requirement,
        // and nothing to revoke.
        if user.isAnonymous { return }

        let providerIDs = user.providerData.map { $0.providerID }

        if providerIDs.contains("apple.com") {
            try await reauthenticateWithApple(user: user)
        } else if providerIDs.contains("google.com") {
            try await reauthenticateWithGoogle(user: user)
        }
        // If you add email/password later, handle it here.
    }

    private func reauthenticateWithApple(user: User) async throws {
        let nonce = Self.randomNonce()
        currentNonce = nonce
        defer { currentNonce = nil }

        let appleIDCredential = try await performAppleAuthorization(nonce: nonce)

        guard
            let tokenData = appleIDCredential.identityToken,
            let idToken = String(data: tokenData, encoding: .utf8)
        else {
            throw AuthError.invalidAppleCredential
        }

        let firebaseCredential = OAuthProvider.appleCredential(
            withIDToken: idToken,
            rawNonce: nonce,
            fullName: appleIDCredential.fullName
        )

        // 1) Satisfy requiresRecentLogin.
        try await user.reauthenticate(with: firebaseCredential)

        // 2) Revoke the Apple refresh token — this is the part Apple requires.
        if let codeData = appleIDCredential.authorizationCode,
           let authCode = String(data: codeData, encoding: .utf8) {
            try await Auth.auth().revokeToken(withAuthorizationCode: authCode)
        }
    }

    private func reauthenticateWithGoogle(user: User) async throws {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw AuthError.missingGoogleClientID
        }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        guard let presenter = Self.topViewController() else {
            throw AuthError.noPresentingController
        }

        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
        guard let idToken = result.user.idToken?.tokenString else {
            throw AuthError.invalidGoogleCredential
        }
        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: result.user.accessToken.tokenString
        )
        try await user.reauthenticate(with: credential)
        // Google does not require token revocation for App Store account deletion.
    }

    /// Programmatic Sign in with Apple (no SwiftUI button), bridged to async.
    private func performAppleAuthorization(
        nonce: String
    ) async throws -> ASAuthorizationAppleIDCredential {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)

        return try await withCheckedThrowingContinuation { continuation in
            let delegate = AppleAuthorizationDelegate(continuation: continuation)
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = delegate
            controller.presentationContextProvider = delegate
            delegate.retainSelf()          // keep alive until the callback fires
            controller.performRequests()
        }
    }
}

enum AuthError: LocalizedError {
    case invalidAppleCredential
    case invalidGoogleCredential
    case missingGoogleClientID
    case noPresentingController
    case notSignedIn

    var errorDescription: String? {
        switch self {
        case .invalidAppleCredential:  return "Unable to retrieve Apple ID information."
        case .invalidGoogleCredential: return "Failed to obtain Google token."
        case .missingGoogleClientID:   return "Google sign-in is not configured (no clientID)."
        case .noPresentingController:  return "Failed to open login window."
        case .notSignedIn:             return "You are not signed in."
        }
    }
}
@MainActor
private final class AppleAuthorizationDelegate: NSObject,
    ASAuthorizationControllerDelegate,
    ASAuthorizationControllerPresentationContextProviding {

    private let continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>
    private var selfRef: AppleAuthorizationDelegate?

    init(continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>) {
        self.continuation = continuation
    }

    func retainSelf() { selfRef = self }
    private func releaseSelf() { selfRef = nil }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        defer { releaseSelf() }
        guard let credential = authorization.credential
                as? ASAuthorizationAppleIDCredential else {
            continuation.resume(throwing: AuthError.invalidAppleCredential)
            return
        }
        continuation.resume(returning: credential)
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        defer { releaseSelf() }
        continuation.resume(throwing: error)
    }

    func presentationAnchor(
        for controller: ASAuthorizationController
    ) -> ASPresentationAnchor {
        let scene = UIApplication.shared.connectedScenes
            .first { $0.activationState == .foregroundActive } as? UIWindowScene
        return scene?.keyWindow ?? ASPresentationAnchor()
    }
}
