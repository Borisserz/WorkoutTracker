import Foundation
import Testing
@testable import WorkoutTracker

@Suite("Wave 1 App Store Readiness Tests")
struct Wave1AppStoreReadinessTests {

    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    @Test("Xcode project links FirebaseAnalyticsCore instead of FirebaseAnalytics (no Ads/IDFA SDKs)")
    func testUsesFirebaseAnalyticsCore() throws {
        let pbx = try String(contentsOf: repoRoot.appendingPathComponent("WorkoutTracker.xcodeproj/project.pbxproj"), encoding: .utf8)
        #expect(pbx.contains("productName = FirebaseAnalyticsCore;"))
        #expect(!pbx.contains("productName = FirebaseAnalytics;"))
    }

    @Test("Usage descriptions have a single source of truth in Info.plist and match implemented features")
    func testBuiltInfoPlistUsageDescriptionsAreAccurate() throws {
        let pbx = try String(contentsOf: repoRoot.appendingPathComponent("WorkoutTracker.xcodeproj/project.pbxproj"), encoding: .utf8)
        let overrideMatches = pbx.matches(of: /INFOPLIST_KEY_NS[A-Za-z]+UsageDescription/)
        #expect(overrideMatches.isEmpty, "Usage descriptions must not be duplicated/overridden via INFOPLIST_KEY_* in project.pbxproj")

        let info = try #require(Bundle.main.infoDictionary)
        #expect(info["NSPhotoLibraryAddUsageDescription"] == nil)

        let mic = try #require(info["NSMicrophoneUsageDescription"] as? String)
        #expect(mic.localizedCaseInsensitiveContains("AI Coach"))
        #expect(!mic.localizedCaseInsensitiveContains("hands-free"))
        #expect(!mic.localizedCaseInsensitiveContains("rest timer"))
        #expect(!mic.localizedCaseInsensitiveContains("log sets"))

        let speech = try #require(info["NSSpeechRecognitionUsageDescription"] as? String)
        #expect(speech.localizedCaseInsensitiveContains("AI Coach"))
        #expect(!speech.localizedCaseInsensitiveContains("on-device"))
        #expect(!speech.localizedCaseInsensitiveContains("during workouts"))
        #expect(!speech.localizedCaseInsensitiveContains("log set"))

        let healthShare = try #require(info["NSHealthShareUsageDescription"] as? String)
        #expect(healthShare.localizedCaseInsensitiveContains("HRV"))
        #expect(healthShare.localizedCaseInsensitiveContains("water"))

        let healthUpdate = try #require(info["NSHealthUpdateUsageDescription"] as? String)
        #expect(healthUpdate.localizedCaseInsensitiveContains("water"))
        #expect(healthUpdate.localizedCaseInsensitiveContains("distance"))
    }

    @Test("Main app and Watch InfoPlist.xcstrings exist and cover all 7 locales")
    func testLocalizedInfoPlistStringsExistForAllLocales() throws {
        let shippedLocales = ["en", "ru", "de", "es", "fr", "it", "pt-PT"]
        let mainKeys = [
            "NSCameraUsageDescription",
            "NSHealthShareUsageDescription",
            "NSHealthUpdateUsageDescription",
            "NSMicrophoneUsageDescription",
            "NSPhotoLibraryUsageDescription",
            "NSSpeechRecognitionUsageDescription"
        ]
        try verifyInfoPlistCatalog(
            at: repoRoot.appendingPathComponent("WorkoutTracker/InfoPlist.xcstrings"),
            requiredKeys: mainKeys,
            locales: shippedLocales
        )
        try verifyInfoPlistCatalog(
            at: repoRoot.appendingPathComponent("WatchApp/InfoPlist.xcstrings"),
            requiredKeys: ["NSHealthShareUsageDescription", "NSHealthUpdateUsageDescription"],
            locales: shippedLocales
        )

        for lang in shippedLocales {
            let compiledPath = Bundle.main.path(forResource: "InfoPlist", ofType: "strings", inDirectory: nil, forLocalization: lang)
            #expect(compiledPath != nil, "Missing compiled InfoPlist.strings for locale \(lang)")
        }
    }

    @Test("WorkoutTimerWidget contains no Xcode sample ConfigurationAppIntent")
    func testNoTemplateAppIntentLeftover() throws {
        let templateIntentURL = repoRoot.appendingPathComponent("WorkoutTimerWidget/AppIntent.swift")
        #expect(!FileManager.default.fileExists(atPath: templateIntentURL.path))

        let widgetDir = repoRoot.appendingPathComponent("WorkoutTimerWidget")
        let files = try FileManager.default.contentsOfDirectory(at: widgetDir, includingPropertiesForKeys: nil)
        for file in files where file.pathExtension == "swift" {
            let content = try String(contentsOf: file, encoding: .utf8)
            #expect(!content.contains("ConfigurationAppIntent"))
            #expect(!content.contains("Favorite Emoji"))
        }
    }

    @Test("Target-scoped PrivacyInfo.xcprivacy files match each target's actual data and API usage")
    func testTargetScopedPrivacyManifests() throws {
        let appManifest = try loadPlist(at: repoRoot.appendingPathComponent("PrivacyInfo.xcprivacy"))
        #expect((appManifest["NSPrivacyTracking"] as? Bool) == false)
        let appCollected = (appManifest["NSPrivacyCollectedDataTypes"] as? [[String: Any]] ?? [])
            .compactMap { $0["NSPrivacyCollectedDataType"] as? String }
        #expect(appCollected.contains("NSPrivacyCollectedDataTypeUserID"))
        #expect(appCollected.contains("NSPrivacyCollectedDataTypeEmailAddress"))
        #expect(appCollected.contains("NSPrivacyCollectedDataTypeHealth"))

        let watchManifest = try loadPlist(at: repoRoot.appendingPathComponent("PrivacyManifests/WatchApp/PrivacyInfo.xcprivacy"))
        let watchCollected = (watchManifest["NSPrivacyCollectedDataTypes"] as? [[String: Any]] ?? [])
            .compactMap { $0["NSPrivacyCollectedDataType"] as? String }
        #expect(Set(watchCollected) == Set(["NSPrivacyCollectedDataTypeHealth", "NSPrivacyCollectedDataTypeFitness"]))
        let watchReasons = apiReasons(in: watchManifest, apiType: "NSPrivacyAccessedAPICategoryUserDefaults")
        #expect(watchReasons == ["CA92.1"])

        let statsManifest = try loadPlist(at: repoRoot.appendingPathComponent("PrivacyManifests/StatsWidget/PrivacyInfo.xcprivacy"))
        let statsCollected = statsManifest["NSPrivacyCollectedDataTypes"] as? [[String: Any]] ?? []
        #expect(statsCollected.isEmpty)
        let statsReasons = apiReasons(in: statsManifest, apiType: "NSPrivacyAccessedAPICategoryUserDefaults")
        #expect(statsReasons == ["1C8F.1"])

        let timerManifest = try loadPlist(at: repoRoot.appendingPathComponent("PrivacyManifests/WorkoutTimerWidget/PrivacyInfo.xcprivacy"))
        #expect((timerManifest["NSPrivacyCollectedDataTypes"] as? [[String: Any]] ?? []).isEmpty)
        #expect((timerManifest["NSPrivacyAccessedAPITypes"] as? [[String: Any]] ?? []).isEmpty)
    }

    private func verifyInfoPlistCatalog(at url: URL, requiredKeys: [String], locales: [String]) throws {
        let data = try Data(contentsOf: url)
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try #require(json["strings"] as? [String: Any])
        for key in requiredKeys {
            let entry = try #require(strings[key] as? [String: Any], "Missing key \(key) in \(url.lastPathComponent)")
            let locs = try #require(entry["localizations"] as? [String: Any], "Missing localizations for \(key)")
            for lang in locales {
                let unit = (locs[lang] as? [String: Any])?["stringUnit"] as? [String: Any]
                let value = unit?["value"] as? String ?? ""
                #expect(!value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "Empty \(lang) translation for \(key)")
            }
        }
    }

    private func loadPlist(at url: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: url)
        return try #require(try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
    }

    private func apiReasons(in manifest: [String: Any], apiType: String) -> [String] {
        let apis = manifest["NSPrivacyAccessedAPITypes"] as? [[String: Any]] ?? []
        return apis.first(where: { ($0["NSPrivacyAccessedAPIType"] as? String) == apiType })?["NSPrivacyAccessedAPITypeReasons"] as? [String] ?? []
    }
}
