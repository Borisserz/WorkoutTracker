import FirebaseAuth
import FirebaseRemoteConfig
import Foundation
import Testing
@testable import WorkoutTracker

@Suite("Wave 2 Security, Backend Integration & Account Deletion Tests")
struct Wave2SecurityAndDeletionTests {

    private func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    @Test("AIProxyEndpoint restricts overrides to trusted ecosystem Cloud Run / Cloud Functions hosts")
    func aiProxyEndpointRestrictsUntrustedHosts() {
        let fallback = AIProxyEndpoint.fallbackURL
        #expect(AIProxyEndpoint.resolve(configured: "https://evil.example/proxy") == fallback)
        #expect(AIProxyEndpoint.resolve(configured: "https://attacker.com:8443/steal") == fallback)
        #expect(AIProxyEndpoint.resolve(configured: "https://user:pass@vertexproxy-ryy2hh2k3a-uc.a.run.app") == fallback)

        let cloudRunAlt = URL(string: "https://vertexproxy-ryy2hh2k3a-ew.a.run.app")!
        #expect(AIProxyEndpoint.resolve(configured: "https://vertexproxy-ryy2hh2k3a-ew.a.run.app") == cloudRunAlt)

        let cloudFn = URL(string: "https://us-central1-serzhanovich-ecosystem-ce700.cloudfunctions.net/vertexProxy")!
        #expect(AIProxyEndpoint.resolve(configured: "https://us-central1-serzhanovich-ecosystem-ce700.cloudfunctions.net/vertexProxy") == cloudFn)
    }

    @Test("RemoteConfigManager provides sensible in-app defaults before cloud fetch")
    @MainActor
    func remoteConfigManagerHasDefaults() async {
        let defaults = RemoteConfigManager.defaultValues
        #expect((defaults[AIProxyEndpoint.remoteConfigKey] as? String) == AIProxyEndpoint.fallbackURLString)
        #expect((defaults["minimum_ios_version"] as? String)?.isEmpty == false)
        #expect((defaults["recommended_ios_version"] as? String)?.isEmpty == false)

        _ = await RemoteConfigManager.shared
        let proxyDefault = RemoteConfig.remoteConfig().defaultValue(forKey: AIProxyEndpoint.remoteConfigKey)?.stringValue
        #expect(proxyDefault == AIProxyEndpoint.fallbackURLString)
    }

    @Test("remote_config.json does not leak fatsecret_secret and declares no blank secrets")
    func remoteConfigDoesNotContainFatSecretSecret() throws {
        let url = repoRoot().appendingPathComponent("remote_config.json")
        let data = try Data(contentsOf: url)
        let root = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let parameters = try #require(root["parameters"] as? [String: Any])
        #expect(parameters["fatsecret_secret"] == nil)
    }

    @Test("storage.rules exists, is wired into firebase.json, and locks bucket down to read-only exercises JSON")
    func storageRulesConfiguredAndLockedDown() throws {
        let firebaseURL = repoRoot().appendingPathComponent("firebase.json")
        let firebaseData = try Data(contentsOf: firebaseURL)
        let firebaseJSON = try #require(try JSONSerialization.jsonObject(with: firebaseData) as? [String: Any])
        let storageConfig = firebaseJSON["storage"] as? [String: Any]
        #expect((storageConfig?["rules"] as? String) == "storage.rules")

        let rulesURL = repoRoot().appendingPathComponent("storage.rules")
        let rules = try String(contentsOf: rulesURL, encoding: .utf8)
        #expect(rules.contains("exercises"))
        #expect(rules.contains("allow write: if false"))
        #expect(rules.contains("allow read, write: if false"))
    }

    @Test("firestore.rules closes unauthenticated UGC reads, moderation field bypasses, report flooding, and self-blocking")
    func firestoreRulesTightened() throws {
        let rulesURL = repoRoot().appendingPathComponent("firestore.rules")
        let rules = try String(contentsOf: rulesURL, encoding: .utf8)

        // shared_workouts read must require request.auth != null unconditionally
        #expect(rules.contains("allow read: if request.auth != null"))
        // shared_workouts create must enforce strict keys, name == title, and exercises list size
        #expect(rules.contains("keys().hasOnly(["))
        #expect(rules.contains("request.resource.data.title == request.resource.data.name"))
        #expect(rules.contains("request.resource.data.exercises is list"))
        #expect(rules.contains("request.resource.data.exercises.size() <= 200"))

        // reports create must use deterministic workoutId_uid ID and verify workout exists
        #expect(rules.contains("reportId == request.resource.data.workoutId + \"_\" + request.auth.uid"))
        #expect(rules.contains("exists(/databases/$(database)/documents/shared_workouts/$(request.resource.data.workoutId))"))

        // blocked list must prevent self-block and arbitrary field dumps
        #expect(rules.contains("blockedUid != userId"))
        #expect(rules.contains("keys().hasOnly([\"blockedAt\"])"))
    }

    @Test("FirestoreProgramService writes deterministic report document ID matching rules")
    func reportWorkoutUsesDeterministicDocID() throws {
        let url = repoRoot().appendingPathComponent("WorkoutTracker/AppCore/FirestoreProgramService.swift")
        let source = try String(contentsOf: url, encoding: .utf8)
        #expect(source.contains(#"let reportDocId = "\(id)_\(user.uid)""#))
        #expect(source.contains(".document(reportDocId)"))
        #expect(!source.contains(".collection(\"reports\").addDocument("))
    }

    @Test("BlockedUsersStore automatically rebinds listener on .authSessionDidChange")
    func blockedUsersStoreObservesAuthSessionDidChange() throws {
        let url = repoRoot().appendingPathComponent("WorkoutTracker/Auth/BlockedUsersStore.swift")
        let source = try String(contentsOf: url, encoding: .utf8)
        #expect(source.contains(".authSessionDidChange"))
    }

    @Test("TemplatePreviewSheetView surfaces share failure alerts instead of failing silently")
    func templatePreviewSheetShowsShareErrorAlert() throws {
        let url = repoRoot().appendingPathComponent("WorkoutTracker/Features/Workout/Views/TemplatePreviewSheetView.swift")
        let source = try String(contentsOf: url, encoding: .utf8)
        #expect(source.contains("shareErrorMessage"))
        #expect(source.contains(".alert("))
    }

    @Test("SocialAuthService does not revoke Apple token during pre-deletion reauthentication")
    func socialAuthServiceDefersAppleRevocationUntilAfterServerWipe() throws {
        let url = repoRoot().appendingPathComponent("WorkoutTracker/Auth/SocialAuthService.swift")
        let source = try String(contentsOf: url, encoding: .utf8)

        let appleStart = try #require(source.range(of: "private func reauthenticateWithApple"))
        let tail = String(source[appleStart.lowerBound...])
        let appleEnd = try #require(tail.range(of: "private func reauthenticateWithGoogle"))
        let reauthAppleSection = String(tail[..<appleEnd.lowerBound])

        #expect(!reauthAppleSection.contains("revokeToken(withAuthorizationCode:"))
        #expect(source.contains("func revokeAppleToken(authorizationCode: String)"))
    }

    @Test("AccountDeletionCoordinator wipes Firestore before Apple token revocation, handles requiresRecentLogin fallback, and always cleans local state once deleted")
    func accountDeletionOrderingInvariants() async throws {
        enum TestErr: Error { case firestoreFailed, bootstrapFailed }

        // 1) Server Firestore wipe failure MUST NOT revoke Apple token or wipe local state.
        var events1: [String] = []
        do {
            try await AccountDeletionCoordinator.execute(
                reauthenticate: {
                    events1.append("reauth")
                    return "apple-code-123"
                },
                wipeServerData: {
                    events1.append("wipeServerData")
                    throw TestErr.firestoreFailed
                },
                revokeAppleToken: { _ in events1.append("revokeApple") },
                deleteAuthUser: { events1.append("deleteAuth") },
                fallbackServerDeleteAuth: { events1.append("fallbackDeleteAuth") },
                signOutProviders: { events1.append("signOut") },
                wipeLocalState: { events1.append("wipeLocal") },
                bootstrapAnonymous: { events1.append("bootstrap") }
            )
            Issue.record("Expected firestoreFailed error to propagate")
        } catch TestErr.firestoreFailed {
            // Expected
        }
        #expect(events1 == ["reauth", "wipeServerData"])

        // 2) Full happy path runs in strict safe sequence and completes local cleanup even if anonymous re-bootstrap throws.
        var events2: [String] = []
        try await AccountDeletionCoordinator.execute(
            reauthenticate: {
                events2.append("reauth")
                return "apple-code-456"
            },
            wipeServerData: { events2.append("wipeServerData") },
            revokeAppleToken: { code in
                #expect(code == "apple-code-456")
                events2.append("revokeApple")
            },
            deleteAuthUser: { events2.append("deleteAuth") },
            fallbackServerDeleteAuth: { events2.append("fallbackDeleteAuth") },
            signOutProviders: { events2.append("signOut") },
            wipeLocalState: { events2.append("wipeLocal") },
            bootstrapAnonymous: {
                events2.append("bootstrap")
                throw TestErr.bootstrapFailed
            }
        )
        #expect(events2 == ["reauth", "wipeServerData", "revokeApple", "deleteAuth", "signOut", "wipeLocal", "bootstrap"])

        // 3) Client requiresRecentLogin triggers server-side auth deletion fallback cleanly.
        var events3: [String] = []
        let recentLoginErr = NSError(
            domain: AuthErrorDomain,
            code: AuthErrorCode.requiresRecentLogin.rawValue
        )
        try await AccountDeletionCoordinator.execute(
            reauthenticate: { return nil },
            wipeServerData: { events3.append("wipeServerData") },
            revokeAppleToken: { _ in events3.append("revokeApple") },
            deleteAuthUser: {
                events3.append("deleteAuth")
                throw recentLoginErr
            },
            fallbackServerDeleteAuth: { events3.append("fallbackDeleteAuth") },
            signOutProviders: { events3.append("signOut") },
            wipeLocalState: { events3.append("wipeLocal") },
            bootstrapAnonymous: { events3.append("bootstrap") }
        )
        #expect(events3 == ["wipeServerData", "deleteAuth", "fallbackDeleteAuth", "signOut", "wipeLocal", "bootstrap"])
    }
}
