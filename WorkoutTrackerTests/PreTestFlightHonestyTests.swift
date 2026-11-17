import XCTest
@testable import WorkoutTracker

final class PreTestFlightHonestyTests: XCTestCase {

    func testMissingBodyWeightDoesNotInventSeventyFiveKilograms() {
        let workout = Workout()
        workout.durationSeconds = 3600
        let exercise = Exercise(type: .strength, setsList: [
            WorkoutSet(index: 1, isCompleted: true),
            WorkoutSet(index: 2, isCompleted: true),
            WorkoutSet(index: 3, isCompleted: true)
        ])
        workout.exercises = [exercise]

        let unset = CalorieCalculator.calculate(for: workout, userWeight: 0)
        let known = CalorieCalculator.calculate(for: workout, userWeight: 75)
        XCTAssertEqual(unset, 0, "Unset body weight must not burn calories as a 75 kg athlete")
        XCTAssertGreaterThan(known, unset)
    }

    func testPartialRecoveryMapDoesNotClaimTheOtherChainIsReady() {
        let report = BodyAnalysisEngine.generateReport(
            cnsScore: 80,
            recoveryDict: ["chest": 40],
            recentWorkouts: [Workout(title: "Chest", date: Date().addingTimeInterval(-3600))]
        )
        let blob = [
            report.executiveAssessment,
            report.nextWorkoutAdvice.recentStrainSummary,
            report.nextWorkoutAdvice.physiologicalRationale,
            report.recommendedRestrictions
        ].joined(separator: " ")
        XCTAssertFalse(blob.localizedCaseInsensitiveContains("fully restored"))
        XCTAssertFalse(blob.localizedCaseInsensitiveContains("fully ready"))
        XCTAssertFalse(blob.localizedCaseInsensitiveContains("fully replenished"))
        XCTAssertFalse(blob.contains("-1"))
    }

    func testMeasuredEightyPercentIsNotCalledAboveEightyFive() {
        let keys = ["chest", "upper-back", "quadriceps", "hamstring", "lower-back", "triceps", "biceps"]
        let recovery = Dictionary(uniqueKeysWithValues: keys.map { ($0, 80) })
        let report = BodyAnalysisEngine.generateReport(
            cnsScore: 80,
            recoveryDict: recovery,
            recentWorkouts: [Workout(title: "Mixed", date: Date().addingTimeInterval(-3600))]
        )
        let blob = report.executiveAssessment + " " + report.nextWorkoutAdvice.recentStrainSummary
        XCTAssertFalse(blob.localizedCaseInsensitiveContains("above 85%"))
        XCTAssertFalse(blob.contains("-1"))
    }

    func testPullAdviceDoesNotQuoteUnmeasuredBackAsAPercent() {
        let report = BodyAnalysisEngine.generateReport(
            cnsScore: 82,
            recoveryDict: [
                "chest": 50, "triceps": 50,
                "quadriceps": 90, "hamstring": 90,
                "deltoids": 90, "abs": 90, "gluteal": 90, "calves": 90
            ],
            recentWorkouts: [Workout(title: "Push", date: Date().addingTimeInterval(-3600))]
        )
        let blob = report.nextWorkoutAdvice.physiologicalRationale + " " + report.executiveAssessment
        XCTAssertFalse(blob.contains("-1"))
        XCTAssertFalse(blob.localizedCaseInsensitiveContains("peak contractile"))
    }

    func testCardioMinutesStoreAsSeconds() {
        XCTAssertEqual(SetTimeCodec.storedSeconds(fromDisplay: 30, field: .minutes), 1800)
        XCTAssertEqual(SetTimeCodec.displayValue(fromStoredSeconds: 1800, field: .minutes), 30)
        XCTAssertEqual(SetTimeCodec.storedSeconds(fromDisplay: 45, field: .seconds), 45)
        XCTAssertEqual(SetTimeCodec.displayValue(fromStoredSeconds: 45, field: .seconds), 45)
    }

    func testRestButtonLabelMatchesTheDurationItStarts() {
        let hard = RestDurationPolicy.manualButtonSeconds(
            pendingTemplateRest: nil,
            pendingEffort: 9,
            pendingType: .strength,
            userDefaultRest: 0
        )
        XCTAssertEqual(hard, 180)

        let idle = RestDurationPolicy.manualButtonSeconds(
            pendingTemplateRest: nil,
            pendingEffort: nil,
            pendingType: nil,
            userDefaultRest: 0
        )
        XCTAssertEqual(idle, 60)

        let saved = RestDurationPolicy.manualButtonSeconds(
            pendingTemplateRest: nil,
            pendingEffort: nil,
            pendingType: nil,
            userDefaultRest: 75
        )
        XCTAssertEqual(saved, 75)
    }

    func testUnsetProfileMetricsStayBlankAndPoundsConvert() {
        let defaults = UserDefaults(suiteName: "PreTestFlightHonestyTests.metrics")!
        defaults.removePersistentDomain(forName: "PreTestFlightHonestyTests.metrics")
        XCTAssertNil(BodyMetricStore.weightKilograms(in: defaults))
        XCTAssertNil(BodyMetricStore.heightCentimeters(in: defaults))

        let blankWeight = ProfileMetricsFormatter.weight(storedKg: nil, unit: .pounds)
        XCTAssertEqual(blankWeight.value, "—")
        XCTAssertEqual(blankWeight.unit, "")

        let pounds = ProfileMetricsFormatter.weight(storedKg: 75, unit: .pounds)
        XCTAssertEqual(pounds.unit, "lbs")
        XCTAssertEqual(pounds.value, String(format: "%.1f", 75 * 2.20462))

        let inches = ProfileMetricsFormatter.height(storedCm: 180, unit: .inches)
        XCTAssertEqual(inches.unit, "in")
        XCTAssertEqual(inches.value, String(format: "%.0f", (180 / 2.54).rounded()))

        defaults.set(80.0, forKey: Constants.UserDefaultsKeys.userBodyWeight.rawValue)
        XCTAssertEqual(BodyMetricStore.weightKilograms(in: defaults), 80)
    }

    func testWatchHealthPayloadSkipsASecondPhoneSave() throws {
        let saved = LiveSyncPayload(
            action: .saveToHistory,
            workoutID: "w1",
            healthKitSavedOnWatch: true
        )
        let data = try JSONEncoder().encode(saved)
        let decoded = try JSONDecoder().decode(LiveSyncPayload.self, from: data)
        XCTAssertEqual(decoded.healthKitSavedOnWatch, true)

        let legacy = #"{"action":"saveToHistory","workoutID":"w1"}"#.data(using: .utf8)!
        let old = try JSONDecoder().decode(LiveSyncPayload.self, from: legacy)
        XCTAssertNotEqual(old.healthKitSavedOnWatch, true)
    }

    func testWeeklyReviewPromptUsesTheSelectedFocusAndRealProfile() {
        let request = WeeklyReviewPromptBuilder.userRequest(focus: "Muscle balance", statsBlock: "Chest 40%")
        XCTAssertTrue(request.contains("Muscle balance"))
        XCTAssertFalse(request.contains("(selectedFocus)"))

        let profile = WeeklyReviewPromptBuilder.profile(
            userName: "Boris",
            weightKg: 0,
            weightUnit: "lbs",
            tone: "motivational",
            workoutsThisWeek: 3,
            currentStreak: 4,
            language: "Russian"
        )
        XCTAssertEqual(profile.aiCoachTone, "motivational")
        XCTAssertEqual(profile.weightUnit, "lbs")
        XCTAssertEqual(profile.weightKg, 0)
        XCTAssertEqual(profile.experienceLevel, "Not specified")
        XCTAssertEqual(profile.workoutsThisWeek, 3)
        XCTAssertEqual(profile.currentStreak, 4)
        XCTAssertNotEqual(profile.experienceLevel, "Pro")
    }

    func testWarmupSetDoesNotCloseAStrengthGoal() {
        XCTAssertFalse(
            StrengthGoalMatcher.isMet(
                setType: .warmup,
                isCompleted: true,
                weight: 100,
                reps: 5,
                targetWeight: 100,
                targetReps: 5
            )
        )
        XCTAssertTrue(
            StrengthGoalMatcher.isMet(
                setType: .normal,
                isCompleted: true,
                weight: 100,
                reps: 5,
                targetWeight: 100,
                targetReps: 5
            )
        )
    }

    func testAnalyticsEventsOmitBodyLoadAndExerciseNames() {
        let logged = TrackingManager.Event.setLogged(exerciseName: "Squat", weight: 100, reps: 5, setType: "normal").parameters
        XCTAssertEqual(logged?["set_type"] as? String, "normal")
        XCTAssertNil(logged?["weight"])
        XCTAssertNil(logged?["reps"])
        XCTAssertNil(logged?["exercise_name"])

        let weighed = TrackingManager.Event.weightLogged(value: 75, unit: "kg", source: "profile").parameters
        XCTAssertNil(weighed?["value"])
        XCTAssertEqual(weighed?["unit"] as? String, "kg")
    }

    func testTemplateModeAlwaysPresentsThreeLaunchChoices() {
        XCTAssertEqual(
            TemplateLaunchChoice.allCases,
            [.myTemplates, .createTemplate, .openHistory],
            "Templates mode must always let the user choose between My Templates, Create Template, and History"
        )
        XCTAssertTrue(WorkoutModeDiscoveryPopup.shouldPresentTemplateOptions(for: .templates, hasTemplates: false))
        XCTAssertTrue(WorkoutModeDiscoveryPopup.shouldPresentTemplateOptions(for: .templates, hasTemplates: true))
        XCTAssertFalse(WorkoutModeDiscoveryPopup.shouldPresentTemplateOptions(for: .empty, hasTemplates: true))
        XCTAssertFalse(WorkoutModeDiscoveryPopup.shouldPresentTemplateOptions(for: .aiBuilder, hasTemplates: true))
    }

    func testAuthIdentitySnapshotRecognizesLinkedProvidersAndFallbackLabels() {
        let guest = AuthIdentitySnapshot.resolve(
            hasUser: true,
            firebaseIsAnonymous: true,
            providerIDs: [],
            email: nil,
            displayName: nil,
            cachedEmail: nil,
            cachedName: nil,
            cachedProviderID: nil,
            uid: "guest123456"
        )
        XCTAssertTrue(guest.isAnonymous)
        XCTAssertFalse(guest.isAuthenticated)

        // Even if Firebase user.isAnonymous was stale before reload after link(with:),
        // non-empty providerIDs (apple.com / google.com) prove the account is linked.
        let appleLinked = AuthIdentitySnapshot.resolve(
            hasUser: true,
            firebaseIsAnonymous: true,
            providerIDs: ["apple.com"],
            email: nil,
            displayName: nil,
            cachedEmail: "athlete@privaterelay.appleid.com",
            cachedName: "Boris",
            cachedProviderID: "apple.com",
            uid: "abc987654321"
        )
        XCTAssertFalse(appleLinked.isAnonymous)
        XCTAssertTrue(appleLinked.isAuthenticated)
        XCTAssertEqual(appleLinked.providerDisplayName, "Apple ID")
        XCTAssertEqual(appleLinked.providerIconName, "apple.logo")
        XCTAssertEqual(appleLinked.primaryLabel, "Boris")
        XCTAssertEqual(appleLinked.secondaryLabel, "athlete@privaterelay.appleid.com")

        let googleLinked = AuthIdentitySnapshot.resolve(
            hasUser: true,
            firebaseIsAnonymous: false,
            providerIDs: ["google.com"],
            email: "boris@gmail.com",
            displayName: nil,
            cachedEmail: nil,
            cachedName: nil,
            cachedProviderID: nil,
            uid: "goog123456"
        )
        XCTAssertFalse(googleLinked.isAnonymous)
        XCTAssertTrue(googleLinked.isAuthenticated)
        XCTAssertEqual(googleLinked.providerDisplayName, "Google")
        XCTAssertEqual(googleLinked.providerIconName, "globe")
        XCTAssertEqual(googleLinked.primaryLabel, "boris@gmail.com")
    }

    func testTemplateOptionsSheetDefersNavigationUntilSheetDismisses() {
        var state = TemplateOptionsSheetState()
        state.present()
        XCTAssertTrue(state.isPresented)
        XCTAssertNil(state.pendingChoice)

        // Selecting "My Templates" dismisses the sheet first and defers navigation until onDismiss.
        state.select(.myTemplates)
        XCTAssertFalse(state.isPresented)
        XCTAssertEqual(state.pendingChoice, .myTemplates)

        // When UIKit finishes dismissing the sheet, onDismiss consumes the choice exactly once.
        XCTAssertEqual(state.consumeOnDismiss(), .myTemplates)
        XCTAssertNil(state.pendingChoice)
        XCTAssertNil(state.consumeOnDismiss())

        // Dismissing via Stay / swipe-down must clear any pending choice.
        state.present()
        state.stayOnPopup()
        XCTAssertFalse(state.isPresented)
        XCTAssertNil(state.consumeOnDismiss())
    }

    func testTemplateIconResolverDistinguishesAssetsSymbolsAndFallbacks() {
        XCTAssertEqual(
            TemplateIconResolver.resolve("dumbbell.fill"),
            .systemSymbol("dumbbell.fill")
        )
        XCTAssertEqual(
            TemplateIconResolver.resolve("img_default"),
            .assetTemplate("img_default")
        )
        XCTAssertEqual(
            TemplateIconResolver.resolve("battle-rope"),
            .assetTemplate("battle-rope")
        )
        XCTAssertEqual(
            TemplateIconResolver.resolve(""),
            .fallback("dumbbell.fill")
        )
        XCTAssertEqual(
            TemplateIconResolver.resolve("nonexistent_icon_xyz"),
            .fallback("dumbbell.fill")
        )
    }

    func testBundleContainsNoForeignLocalizationOrPythonArtifacts() throws {
        let appURL = Bundle(for: PreTestFlightHonestyTests.self).bundleURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let contents = try FileManager.default.contentsOfDirectory(
            at: appURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        let forbidden = contents.map(\.lastPathComponent).filter { name in
            name.hasSuffix(".xcloc")
                || name.localizedCaseInsensitiveContains("FoodTracker")
                || name.hasSuffix(".py")
        }
        XCTAssertTrue(
            forbidden.isEmpty,
            "App bundle must not ship .xcloc, FoodTracker artifacts, or Python scripts: \(forbidden)"
        )
    }

    func testExtensionsMatchMainAppBundleVersionAndShortVersion() throws {
        let mainBundle = Bundle.main
        let expectedShort = try XCTUnwrap(mainBundle.infoDictionary?["CFBundleShortVersionString"] as? String)
        let expectedBuild = try XCTUnwrap(mainBundle.infoDictionary?["CFBundleVersion"] as? String)

        let appURL = mainBundle.bundleURL
        let embeddedURLs = [
            appURL.appendingPathComponent("PlugIns/StatsWidgetExtension.appex"),
            appURL.appendingPathComponent("PlugIns/WorkoutTimerWidgetExtension.appex"),
            appURL.appendingPathComponent("Watch/WorkoutTrackerWatch Watch App.app"),
        ].filter { FileManager.default.fileExists(atPath: $0.appendingPathComponent("Info.plist").path) }

        for extURL in embeddedURLs {
            let plistData = try Data(contentsOf: extURL.appendingPathComponent("Info.plist"))
            let plist = try XCTUnwrap(
                PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any]
            )
            XCTAssertEqual(
                plist["CFBundleShortVersionString"] as? String,
                expectedShort,
                "\(extURL.lastPathComponent) MARKETING_VERSION mismatch"
            )
            XCTAssertEqual(
                plist["CFBundleVersion"] as? String,
                expectedBuild,
                "\(extURL.lastPathComponent) CURRENT_PROJECT_VERSION mismatch"
            )
        }

        // Verify all Debug/Release build settings across iOS, Watch, and Widget targets in project.pbxproj stay aligned.
        let pbxprojURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("WorkoutTracker.xcodeproj/project.pbxproj")
        if FileManager.default.fileExists(atPath: pbxprojURL.path) {
            let contents = try String(contentsOf: pbxprojURL, encoding: .utf8)
            let marketingMatches = contents.matches(of: /MARKETING_VERSION = ([^;]+);/).map { String($0.1) }
            let buildMatches = contents.matches(of: /CURRENT_PROJECT_VERSION = ([^;]+);/).map { String($0.1) }
            XCTAssertEqual(marketingMatches.count, 8, "Expected 8 MARKETING_VERSION entries across 4 shipped targets (Debug+Release)")
            XCTAssertEqual(buildMatches.count, 8, "Expected 8 CURRENT_PROJECT_VERSION entries across 4 shipped targets (Debug+Release)")
            for value in marketingMatches {
                XCTAssertEqual(value, expectedShort, "All target MARKETING_VERSIONs must match main app \(expectedShort)")
            }
            for value in buildMatches {
                XCTAssertEqual(value, expectedBuild, "All target CURRENT_PROJECT_VERSIONs must match main app \(expectedBuild)")
            }
        }
    }

    func testUserFacingAppNameAndUsageDescriptionsUseUnifiedAIWorkoutBranding() throws {
        let info = try XCTUnwrap(Bundle.main.infoDictionary)
        XCTAssertEqual(info["CFBundleDisplayName"] as? String, "AI Workout")

        let usageKeys = [
            "NSCameraUsageDescription",
            "NSHealthShareUsageDescription",
            "NSHealthUpdateUsageDescription",
            "NSMicrophoneUsageDescription",
            "NSPhotoLibraryUsageDescription",
            "NSPhotoLibraryAddUsageDescription",
            "NSSpeechRecognitionUsageDescription",
        ]
        for key in usageKeys {
            let desc = try XCTUnwrap(info[key] as? String, "Missing \(key)")
            XCTAssertTrue(desc.contains("AI Workout"), "\(key) must reference AI Workout: \(desc)")
            XCTAssertFalse(desc.localizedCaseInsensitiveContains("WorkoutTracker"), "\(key) still contains WorkoutTracker")
            XCTAssertFalse(desc.contains("Ai Workout"), "\(key) still contains Ai Workout")
            XCTAssertFalse(desc.localizedCaseInsensitiveContains("FoodTracker"), "\(key) contains FoodTracker")
        }

        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let pbxprojURL = repoRoot.appendingPathComponent("WorkoutTracker.xcodeproj/project.pbxproj")
        if FileManager.default.fileExists(atPath: pbxprojURL.path) {
            let pbx = try String(contentsOf: pbxprojURL, encoding: .utf8)
            XCTAssertFalse(pbx.contains("INFOPLIST_KEY_CFBundleDisplayName = \"Ai Workout\""), "Replace Ai Workout with AI Workout")
            XCTAssertFalse(pbx.contains("INFOPLIST_KEY_CFBundleDisplayName = WorkoutTrackerWatch"), "Align Watch display name with AI Workout")
            for match in pbx.matches(of: /INFOPLIST_KEY_NS[A-Za-z]+UsageDescription = "([^"]+)";/) {
                let text = String(match.1)
                XCTAssertTrue(text.contains("AI Workout"), "pbxproj usage description must reference AI Workout: \(text)")
                XCTAssertFalse(text.contains("WorkoutTracker"), "pbxproj usage description still mentions WorkoutTracker: \(text)")
            }
        }

        let catalogURL = repoRoot.appendingPathComponent("WorkoutTracker/Localizable.xcstrings")
        if FileManager.default.fileExists(atPath: catalogURL.path) {
            let data = try Data(contentsOf: catalogURL)
            let root = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
            let strings = try XCTUnwrap(root["strings"] as? [String: Any])
            for (key, raw) in strings {
                guard let entry = raw as? [String: Any], entry["extractionState"] as? String != "stale" else { continue }
                XCTAssertFalse(
                    key.localizedCaseInsensitiveContains("WorkoutTracker"),
                    "Active xcstrings key still mentions WorkoutTracker: \(key)"
                )
            }
        }
    }

    func testBuild8AndWatchPlusWidgetEmbeddingAreConfigured() throws {
        let mainInfo = try XCTUnwrap(Bundle.main.infoDictionary)
        XCTAssertEqual(mainInfo["CFBundleVersion"] as? String, "8", "Main app build number must be 8")

        let appURL = Bundle.main.bundleURL
        let requiredPlugins = [
            "PlugIns/StatsWidgetExtension.appex/Info.plist",
            "PlugIns/WorkoutTimerWidgetExtension.appex/Info.plist",
        ]
        for relPath in requiredPlugins {
            let plistURL = appURL.appendingPathComponent(relPath)
            XCTAssertTrue(
                FileManager.default.fileExists(atPath: plistURL.path),
                "Built app bundle must embed \(relPath)"
            )
        }

        let pbxprojURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("WorkoutTracker.xcodeproj/project.pbxproj")
        if FileManager.default.fileExists(atPath: pbxprojURL.path) {
            let pbx = try String(contentsOf: pbxprojURL, encoding: .utf8)
            let buildMatches = pbx.matches(of: /CURRENT_PROJECT_VERSION = ([^;]+);/).map { String($0.1) }
            XCTAssertEqual(buildMatches.count, 8)
            XCTAssertTrue(buildMatches.allSatisfy { $0 == "8" }, "All 8 target configs must use build 8, got \(buildMatches)")

            XCTAssertTrue(
                pbx.contains("StatsWidgetExtension.appex in Embed Foundation Extensions"),
                "StatsWidgetExtension.appex must be in Embed Foundation Extensions"
            )
            XCTAssertTrue(
                pbx.contains("WorkoutTimerWidgetExtension.appex in Embed Foundation Extensions"),
                "WorkoutTimerWidgetExtension.appex must be in Embed Foundation Extensions"
            )
            XCTAssertTrue(
                pbx.contains("WorkoutTrackerWatch Watch App.app in Embed Watch Content"),
                "WorkoutTrackerWatch Watch App.app must be in Embed Watch Content"
            )
            XCTAssertFalse(
                pbx.contains("CODE_SIGN_IDENTITY = \"Apple Development\";"),
                "Do not hardcode Apple Development signing identity on Release widget target"
            )
        }
    }
}
