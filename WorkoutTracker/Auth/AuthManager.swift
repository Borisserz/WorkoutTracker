//
//  AuthManager.swift
//  WorkoutTracker
//
//  Global authentication state manager.
//

import Foundation
import FirebaseAuth
import Observation

extension Notification.Name {
    static let authSessionDidChange = Notification.Name("WorkoutTracker.authSessionDidChange")
}

/// Resolved identity snapshot for UI and tests.
/// Distinguishes anonymous guest sessions from linked Apple/Google accounts even
/// before `User.reload()` refreshes Firebase's cached `isAnonymous` flag.
struct AuthIdentitySnapshot: Equatable, Sendable {
    let isAnonymous: Bool
    let isAuthenticated: Bool
    let providerID: String?
    let providerDisplayName: String?
    let providerIconName: String
    let email: String?
    let displayName: String?
    let primaryLabel: String
    let secondaryLabel: String?
    let uid: String?

    static let guest = AuthIdentitySnapshot(
        isAnonymous: true,
        isAuthenticated: false,
        providerID: nil,
        providerDisplayName: nil,
        providerIconName: "person.crop.circle",
        email: nil,
        displayName: nil,
        primaryLabel: "Guest",
        secondaryLabel: nil,
        uid: nil
    )

    static func resolve(
        hasUser: Bool,
        firebaseIsAnonymous: Bool,
        providerIDs: [String],
        email: String?,
        displayName: String?,
        cachedEmail: String?,
        cachedName: String?,
        cachedProviderID: String?,
        uid: String?
    ) -> AuthIdentitySnapshot {
        guard hasUser else { return .guest }

        let linkedProviders = providerIDs.filter { !$0.isEmpty && $0 != "anonymous" && $0 != "firebase" }
        let resolvedProvider = linkedProviders.first
            ?? (firebaseIsAnonymous ? nil : clean(cachedProviderID))
        let isAuthenticated = !firebaseIsAnonymous || !linkedProviders.isEmpty

        guard isAuthenticated else {
            return AuthIdentitySnapshot(
                isAnonymous: true,
                isAuthenticated: false,
                providerID: nil,
                providerDisplayName: nil,
                providerIconName: "person.crop.circle",
                email: nil,
                displayName: nil,
                primaryLabel: "Guest",
                secondaryLabel: nil,
                uid: uid
            )
        }

        let resolvedEmail = clean(email) ?? clean(cachedEmail)
        let resolvedName = clean(displayName) ?? clean(cachedName)

        let providerName: String
        let providerIcon: String
        switch resolvedProvider {
        case "apple.com":
            providerName = "Apple ID"
            providerIcon = "apple.logo"
        case "google.com":
            providerName = "Google"
            providerIcon = "globe"
        case "password":
            providerName = "Email"
            providerIcon = "envelope.fill"
        default:
            providerName = "Account"
            providerIcon = "person.crop.circle.fill"
        }

        let primary = resolvedName ?? resolvedEmail ?? providerName
        let secondary: String?
        if let resolvedName, let resolvedEmail, resolvedName != resolvedEmail {
            secondary = resolvedEmail
        } else if resolvedEmail != nil && primary == resolvedEmail {
            secondary = providerName
        } else if resolvedName != nil && primary == resolvedName {
            secondary = providerName
        } else {
            secondary = nil
        }

        return AuthIdentitySnapshot(
            isAnonymous: false,
            isAuthenticated: true,
            providerID: resolvedProvider,
            providerDisplayName: providerName,
            providerIconName: providerIcon,
            email: resolvedEmail,
            displayName: resolvedName,
            primaryLabel: primary,
            secondaryLabel: secondary,
            uid: uid
        )
    }

    private static func clean(_ raw: String?) -> String? {
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}

/// Persists non-empty provider metadata (Apple only returns name/email on first auth).
enum AuthIdentityCache {
    private static func key(_ suffix: String, uid: String) -> String {
        "authIdentity.\(uid).\(suffix)"
    }

    static func save(uid: String, email: String?, displayName: String?, providerID: String?) {
        guard !uid.isEmpty else { return }
        let defaults = UserDefaults.standard
        if let email = nonEmpty(email) {
            defaults.set(email, forKey: key("email", uid: uid))
        }
        if let displayName = nonEmpty(displayName) {
            defaults.set(displayName, forKey: key("name", uid: uid))
        }
        if let providerID = nonEmpty(providerID) {
            defaults.set(providerID, forKey: key("provider", uid: uid))
        }
    }

    static func load(uid: String) -> (email: String?, displayName: String?, providerID: String?) {
        guard !uid.isEmpty else { return (nil, nil, nil) }
        let defaults = UserDefaults.standard
        return (
            defaults.string(forKey: key("email", uid: uid)),
            defaults.string(forKey: key("name", uid: uid)),
            defaults.string(forKey: key("provider", uid: uid))
        )
    }

    static func clear(uid: String?) {
        guard let uid, !uid.isEmpty else { return }
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: key("email", uid: uid))
        defaults.removeObject(forKey: key("name", uid: uid))
        defaults.removeObject(forKey: key("provider", uid: uid))
    }

    private static func nonEmpty(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}

@Observable
@MainActor
final class AuthManager {
    var isAnonymous: Bool = true
    var isAuthenticated: Bool = false
    var currentUser: User?
    var identity: AuthIdentitySnapshot = .guest

    private var authHandle: AuthStateDidChangeListenerHandle?
    private var tokenHandle: IDTokenDidChangeListenerHandle?
    private var notificationObserver: NSObjectProtocol?

    init() {
        refresh(user: Auth.auth().currentUser)

        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor [weak self] in
                self?.refresh(user: user)
            }
        }

        // Linking an anonymous user keeps the same UID so state listener alone can miss it.
        tokenHandle = Auth.auth().addIDTokenDidChangeListener { [weak self] _, user in
            Task { @MainActor [weak self] in
                self?.refresh(user: user)
            }
        }

        notificationObserver = NotificationCenter.default.addObserver(
            forName: .authSessionDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh(user: Auth.auth().currentUser)
            }
        }
    }

    func refresh(user: User? = Auth.auth().currentUser) {
        let activeUser = user ?? Auth.auth().currentUser
        let uid = activeUser?.uid
        let cached: (email: String?, displayName: String?, providerID: String?) =
            uid.map { AuthIdentityCache.load(uid: $0) } ?? (nil, nil, nil)

        let providerInfos = activeUser?.providerData ?? []
        let providerIDs = providerInfos.map(\.providerID)
        let resolvedEmail = activeUser?.email ?? providerInfos.compactMap(\.email).first
        let resolvedName = activeUser?.displayName ?? providerInfos.compactMap(\.displayName).first

        if let uid, !providerIDs.filter({ $0 != "anonymous" && !$0.isEmpty }).isEmpty {
            AuthIdentityCache.save(
                uid: uid,
                email: resolvedEmail,
                displayName: resolvedName,
                providerID: providerIDs.first(where: { $0 != "anonymous" && !$0.isEmpty })
            )
        }

        let snapshot = AuthIdentitySnapshot.resolve(
            hasUser: activeUser != nil,
            firebaseIsAnonymous: activeUser?.isAnonymous ?? true,
            providerIDs: providerIDs,
            email: resolvedEmail,
            displayName: resolvedName,
            cachedEmail: cached.email,
            cachedName: cached.displayName,
            cachedProviderID: cached.providerID,
            uid: uid
        )

        self.currentUser = activeUser
        self.identity = snapshot
        self.isAnonymous = snapshot.isAnonymous
        self.isAuthenticated = snapshot.isAuthenticated
    }
}
