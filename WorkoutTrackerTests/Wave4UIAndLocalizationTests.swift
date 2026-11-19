import Foundation
import SwiftUI
import UIKit
import Testing
@testable import WorkoutTracker

@Suite("Wave 4 UI, Contrast, Localization & Hygiene Tests")
struct Wave4UIAndLocalizationTests {

    private func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func readSource(_ relativePath: String) throws -> String {
        let url = repoRoot().appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func contrastRatio(between c1: Color, and c2: Color) -> CGFloat {
        func luminance(_ color: Color) -> CGFloat {
            let ui = UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))
            var r: CGFloat = 0
            var g: CGFloat = 0
            var b: CGFloat = 0
            var a: CGFloat = 0
            ui.getRed(&r, green: &g, blue: &b, alpha: &a)
            func adjust(_ c: CGFloat) -> CGFloat {
                c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * adjust(r) + 0.7152 * adjust(g) + 0.0722 * adjust(b)
        }
        let l1 = luminance(c1)
        let l2 = luminance(c2)
        return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05)
    }

    // MARK: - Localization & Data Parity

    @Test("exercises_ru.json has 100% ID parity with exercises.json (Clean & Snatch)")
    func exercisesRuMatchesCanonicalIDs() throws {
        let enURL = repoRoot().appendingPathComponent("WorkoutTracker/DataLayer/LocalDB/exercises.json")
        let ruURL = repoRoot().appendingPathComponent("WorkoutTracker/DataLayer/LocalDB/exercises_ru.json")

        let enItems = try JSONSerialization.jsonObject(with: Data(contentsOf: enURL)) as? [[String: Any]] ?? []
        let ruItems = try JSONSerialization.jsonObject(with: Data(contentsOf: ruURL)) as? [[String: Any]] ?? []

        let enIDs = Set(enItems.compactMap { $0["id"] as? String })
        let ruIDs = Set(ruItems.compactMap { $0["id"] as? String })

        #expect(enIDs.count == ruIDs.count)
        #expect(enIDs == ruIDs)
        #expect(ruIDs.contains("Clean"))
        #expect(ruIDs.contains("Snatch"))
    }

    @Test("Localizable.xcstrings has zero broken format specifiers and fixes known bad translations")
    func localizableCatalogHasValidFormatSpecifiersAndFixedCopy() throws {
        let catalogURL = repoRoot().appendingPathComponent("WorkoutTracker/Localizable.xcstrings")
        let root = try JSONSerialization.jsonObject(with: Data(contentsOf: catalogURL)) as? [String: Any] ?? [:]
        let strings = root["strings"] as? [String: Any] ?? [:]

        let specPattern = #"%((?:\d+)\$)?(?:[+\-#0]+)?(?:\d+|\*)?(?:\.(?:\d+|\*))?(?:hh|ll|h|l|q|L|z|j|t)?(?:[@dDuUxXoOfeEgGcCsSaApn]|%)"#
        let specRegex = try NSRegularExpression(pattern: specPattern)
        let brokenTokenRegex = try NSRegularExpression(pattern: #"%,\d*[fFeEgG]|%\d+\$ll(?![dDuUxXoO])|%ll(?![dDuUxXoO])|%ld\b|%lu\b|%li\b"#)

        func normalizedSpecs(in text: String) -> [String] {
            let masked = text.replacingOccurrences(of: "%%", with: "\u{0000}")
            let ns = masked as NSString
            let matches = specRegex.matches(in: masked, range: NSRange(location: 0, length: ns.length))
            var indexed: [(Int?, String)] = []
            for m in matches {
                let raw = ns.substring(with: m.range)
                if raw == "%" { continue }
                let posRange = m.range(at: 1)
                let pos: Int? = posRange.location != NSNotFound ? Int(ns.substring(with: posRange).replacingOccurrences(of: "$", with: "")) : nil
                let stripped = raw.replacingOccurrences(of: #"^%\d+\$"#, with: "%", options: .regularExpression)
                indexed.append((pos, stripped))
            }
            if !indexed.isEmpty && indexed.allSatisfy({ $0.0 != nil }) {
                return indexed.sorted { ($0.0 ?? 0) < ($1.0 ?? 0) }.map(\.1)
            }
            return indexed.map(\.1)
        }

        let shipped = ["de", "en", "es", "fr", "it", "pt-PT", "ru"]
        var failures: [String] = []

        for (key, raw) in strings {
            guard let entry = raw as? [String: Any],
                  entry["shouldTranslate"] as? Bool != false,
                  let locs = entry["localizations"] as? [String: Any], !locs.isEmpty else { continue }
            let enVal = ((locs["en"] as? [String: Any])?["stringUnit"] as? [String: Any])?["value"] as? String ?? key
            let enSpecs = normalizedSpecs(in: enVal)

            for lang in shipped {
                guard let unit = (locs[lang] as? [String: Any])?["stringUnit"] as? [String: Any],
                      let val = unit["value"] as? String else { continue }
                let valSpecs = normalizedSpecs(in: val)
                if enSpecs != valSpecs {
                    failures.append("[\(lang)] \(key): expected \(enSpecs), got \(valSpecs) in '\(val)'")
                } else {
                    let nsVal = val as NSString
                    if brokenTokenRegex.firstMatch(in: val, range: NSRange(location: 0, length: nsVal.length)) != nil && !enSpecs.contains("%ld") {
                        failures.append("[\(lang)] \(key): broken format token in '\(val)'")
                    }
                }
                if lang == "ru" && (val.contains("Тыб") || val.contains("Тыр")) {
                    failures.append("[ru] \(key): typo '\(val)'")
                }
            }
        }

        #expect(failures.isEmpty, "Localization issues: \(failures.prefix(10).joined(separator: " | "))")

        func locValue(_ key: String, _ lang: String) -> String? {
            let locs = (strings[key] as? [String: Any])?["localizations"] as? [String: Any]
            return ((locs?[lang] as? [String: Any])?["stringUnit"] as? [String: Any])?["value"] as? String
        }

        #expect(locValue("Close", "es") == "Cerrar")
        #expect(locValue("Close", "it") == "Chiudi")
        #expect(locValue("Cancel", "de") == "Abbrechen")
        #expect(locValue("Cancel", "it") == "Annulla")
        #expect(locValue("Chest: 85% Active", "ru") == "Грудь: 85% активна")
        #expect(locValue("Previous: %d sets × %dm %ds", "ru") == "Предыдущее: %d подходов × %dm %ds")
        #expect(locValue("Previous: %d sets × %dm %ds", "de")?.hasPrefix("Zurück:") == false)
        #expect(locValue("Previous: %d sets × %d reps", "de")?.hasPrefix("Zurück:") == false)
        #expect(locValue("Previous: %d sets × %d reps @ %.1f kg", "de")?.hasPrefix("Zurück:") == false)
    }

    // MARK: - Root Hygiene

    @Test("Repository root contains no stray .tmp-sim-*.png screenshots")
    func repoRootHasNoTempScreenshots() throws {
        let items = try FileManager.default.contentsOfDirectory(atPath: repoRoot().path)
        let tempPNGs = items.filter { $0.hasPrefix(".tmp-sim-") && $0.hasSuffix(".png") }
        #expect(tempPNGs.isEmpty, "Found stray screenshots: \(tempPNGs)")
    }

    // MARK: - Contrast & Theme

    @Test("LuxuryPastelTheme deepPremiumAccent has strong contrast against dark cardSurface and canvas")
    @MainActor
    func themeDeepPremiumAccentHasAccessibleContrast() {
        let theme = LuxuryPastelTheme()
        let onCanvas = contrastRatio(between: theme.deepPremiumAccent, and: PastelTheme.canvas)
        let onCard = contrastRatio(between: theme.deepPremiumAccent, and: PastelTheme.cardSurface)
        let textOnOat = contrastRatio(between: PastelTheme.textOnOat, and: theme.primaryAccent)
        #expect(onCanvas >= 4.5, "deepPremiumAccent on canvas contrast too low: \(onCanvas)")
        #expect(onCard >= 4.5, "deepPremiumAccent on cardSurface contrast too low: \(onCard)")
        #expect(textOnOat >= 4.5, "textOnOat on primaryAccent contrast too low: \(textOnOat)")
    }

    @Test("Dark overlays and bright Oat buttons avoid invisible foreground/background combinations")
    func viewsFixContrastMistakes() throws {
        let prView = try readSource("WorkoutTracker/SharedUI/Components/PRCelebrationView.swift")
        #expect(!prView.contains(".foregroundColor(themeManager.current.background)"))

        let smartCapture = try readSource("WorkoutTracker/Features/Profile/SmartCaptureView.swift")
        #expect(!smartCapture.contains("themeManager.current.background"))

        let explore = try readSource("WorkoutTracker/Features/Explore/ExploreRoutinesView.swift")
        #expect(!explore.contains(".foregroundColor(themeManager.current.background)"))

        let onboarding = try readSource("WorkoutTracker/Features/Onboarding/OnboardingFlow.swift")
        let primaryStyleBlock = onboarding.components(separatedBy: "struct OnboardingPrimaryButtonStyle").last ?? ""
        #expect(!primaryStyleBlock.prefix(600).contains(".foregroundStyle(.white)"))

        let addWeight = try readSource("WorkoutTracker/Features/Profile/AddWeightSheet.swift")
        let saveButtonBlock = addWeight.components(separatedBy: "private var floatingSaveButton").last ?? ""
        #expect(!saveButtonBlock.prefix(600).contains(".foregroundColor(.white)"))

        let aiBuilder = try readSource("WorkoutTracker/Features/Explore/AIProgramBuilderSheet.swift")
        #expect(!aiBuilder.contains(".foregroundColor(.white)\n                .clipShape(Capsule())"))
        #expect(!aiBuilder.contains(".foregroundColor(.white)\n            .frame(maxWidth: .infinity)"))

        let chatComponents = try readSource("WorkoutTracker/Features/AICoach/Views/AICoachComponents.swift")
        #expect(!chatComponents.contains("message.isUser ? .white"))
    }

    // MARK: - Workout Share & Detail Flow

    @Test("WorkoutDetailView includes Share/actionButtonSection and WorkoutShareCard respects PR & units")
    func workoutDetailAndShareCard() throws {
        let detailView = try readSource("WorkoutTracker/Features/Workout/Views/WorkoutDetailView.swift")
        let mainLayoutSection = detailView.components(separatedBy: "private func mainLayout").last?
            .components(separatedBy: "private func handleViewModelEvent").first ?? ""
        #expect(mainLayoutSection.contains("actionButtonSection"))

        let shareCard = try readSource("WorkoutTracker/SharedUI/Components/WorkoutShareCard.swift")
        #expect(!shareCard.contains("Text(\"Personal record\")\n                        .font(.caption2)"))
        #expect(!shareCard.contains("kg lifted"))
        #expect(shareCard.contains("unitsManager"))
    }

    // MARK: - Broken Interactive Flows & Spinners

    @Test("OnboardingFlow identifies saved slide by UUID rather than optional targetTab == nil")
    func onboardingSlideIdentityAvoidsNilEquality() throws {
        let onboarding = try readSource("WorkoutTracker/Features/Onboarding/OnboardingFlow.swift")
        #expect(!onboarding.contains("savedTargetTab == item.targetTab"))
        #expect(!onboarding.contains("ForEach([CGPoint(x: midX"))
    }

    @Test("FutureSelfCommitmentSheet schedules local notifications instead of being a no-op")
    func futureSelfCommitmentSchedulesNotifications() throws {
        let overview = try readSource("WorkoutTracker/Features/Overview/OverviewView.swift")
        let sheetSection = overview.components(separatedBy: "struct FutureSelfCommitmentSheet").last ?? ""
        #expect(sheetSection.contains("NotificationManager") || sheetSection.contains("UNUserNotificationCenter") || sheetSection.contains("FutureSelfCommitmentScheduler"))
    }

    @Test("PulseExplanationSheet uses explicit hasPulseData boolean and OverviewDailyFocusCard handles localized prefix")
    func localeIndependentHealthStrings() throws {
        let pulse = try readSource("WorkoutTracker/Features/Overview/Components/PulseExplanationSheet.swift")
        #expect(!pulse.contains("timeAgoText == \"No data\""))

        let dailyCard = try readSource("WorkoutTracker/Features/Overview/Components/OverviewDailyFocusCard.swift")
        let detailSheet = try readSource("WorkoutTracker/Features/Overview/Components/DailyFocusDetailSheet.swift")
        #expect(!dailyCard.contains(".replacingOccurrences(of: \"Next session: \""))
        #expect(!detailSheet.contains(".replacingOccurrences(of: \"Next session: \""))
    }

    @Test("Infinite ProgressView spinners, missing destinations, deep links, iPad popover, UIScreen, and Accessibility are fixed")
    func navigationSpinnersAndPlatformPolish() throws {
        let programDetail = try readSource("WorkoutTracker/Features/Explore/ProgramDetailView.swift")
        #expect(programDetail.contains("ExerciseHistoryView(exerciseName:") && programDetail.contains(".sheet(item:"))

        let exHistory = try readSource("WorkoutTracker/Features/ExerciseCatalog/Views/ExerciseHistoryView.swift")
        let wrapperSection = exHistory.components(separatedBy: "struct WorkoutDetailWrapperView").last ?? ""
        #expect(wrapperSection.contains("ContentUnavailableView") || wrapperSection.contains("EmptyStateView") || wrapperSection.contains("Workout not found"))

        let weightHistory = try readSource("WorkoutTracker/Features/Profile/WeightHistoryView.swift")
        let weightHistoryMain = weightHistory.components(separatedBy: "struct WeightPhotoGalleryView").first ?? weightHistory
        #expect(!weightHistoryMain.contains("NavigationStack {"))
        let gallerySection = weightHistory.components(separatedBy: "struct WeightPhotoGalleryView").last ?? ""
        #expect(gallerySection.contains("ContentUnavailableView") || gallerySection.contains("EmptyStateView") || gallerySection.contains("No photos") || gallerySection.contains("Photos unavailable"))

        let progressView = try readSource("WorkoutTracker/Features/Stats/ProgressView.swift")
        let deepLinkOnAppear = progressView.components(separatedBy: "showAchievementsFolder = true").last?.prefix(250) ?? ""
        #expect(deepLinkOnAppear.contains("showProfileSheet"))

        let activityView = try readSource("WorkoutTracker/SharedUI/Components/ActivityView.swift")
        #expect(activityView.contains("popoverPresentationController"))

        let restTimer = try readSource("WorkoutTracker/SharedUI/Components/RestTimerView.swift")
        #expect(!restTimer.contains("UIScreen.main.bounds"))

        let designer = try readSource("WorkoutTracker/SharedUI/Components/DesignerComponents.swift")
        let chromeBlock = designer.components(separatedBy: "struct ChromeDismissMark").last?.prefix(450) ?? ""
        #expect(chromeBlock.contains("accessibilityLabel"))

        let aiCoach = try readSource("WorkoutTracker/Features/AICoach/Views/AICoachView.swift")
        let progressSheetHeader = aiCoach.components(separatedBy: "private var floatingHeader: some View").last?.prefix(500) ?? ""
        #expect(progressSheetHeader.contains("dismiss()"))
        let restSheet = aiCoach.components(separatedBy: "struct RestAnalysisSheet").last ?? ""
        #expect(restSheet.contains("dismiss()"))

        let myLibrary = try readSource("WorkoutTracker/Features/Workout/Views/MyLibraryView.swift")
        #expect(myLibrary.contains("showCatalogSheet = false"))

        let profileView = try readSource("WorkoutTracker/Features/Profile/ProfileView.swift")
        #expect(profileView.contains("showSisterAppsPromo"))
        let settingsView = try readSource("WorkoutTracker/Features/Settings/SettingsView.swift")
        #expect(settingsView.contains("showSisterAppsPromo"))
    }

    // MARK: - Behavioral Runtime Tests for Wave 4 Helpers

    @Test("NextWorkoutAdvice.stripSessionPrefix removes localized prefixes cleanly")
    func nextWorkoutAdviceStripsLocalizedPrefixes() {
        #expect(NextWorkoutAdvice.stripSessionPrefix(from: "Next session: Push day (Chest & Shoulders)") == "Push day (Chest & Shoulders)")
        #expect(NextWorkoutAdvice.stripSessionPrefix(from: "Следующая сессия: верх тела") == "Верх тела")
        #expect(NextWorkoutAdvice.stripSessionPrefix(from: "Nächste Einheit: Ganzkörper-Einstieg") == "Ganzkörper-Einstieg")
        #expect(NextWorkoutAdvice.stripSessionPrefix(from: "Prochaine séance : récupération active ou deload") == "Récupération active ou deload")
        #expect(NextWorkoutAdvice.stripSessionPrefix(from: "Upper body") == "Upper body")
    }

    @Test("WorkoutShareCard respects UnitsManager and hides Personal record badge without PR")
    @MainActor
    func workoutShareCardUnitsAndPersonalRecordLogic() {
        let workout = Workout(title: "Push", date: Date())
        let bench = Exercise(name: "Bench Press", muscleGroup: "Chest", type: .strength, effort: 8, isCompleted: true)
        bench.setsList = [WorkoutSet(index: 1, weight: 80, reps: 8, isCompleted: true, type: .normal)]
        workout.exercises = [bench]

        // Prior PR was 100 kg, today lifted 80 kg -> NO PR
        #expect(WorkoutShareCard.shouldShowPersonalRecordBadge(workout: workout, recordsCache: ["Bench Press": 100.0], recordedPRCount: 0) == false)
        // First time exercise with 0 prior record -> NO false PR badge unless recordedPRCount > 0
        #expect(WorkoutShareCard.shouldShowPersonalRecordBadge(workout: workout, recordsCache: [:], recordedPRCount: 0) == false)
        // Lifted 80 kg over 75 kg previous record -> PR!
        #expect(WorkoutShareCard.shouldShowPersonalRecordBadge(workout: workout, recordsCache: ["Bench Press": 75.0], recordedPRCount: 0) == true)
        // Explicitly recorded PR count -> PR!
        #expect(WorkoutShareCard.shouldShowPersonalRecordBadge(workout: workout, recordsCache: ["Bench Press": 100.0], recordedPRCount: 1) == true)

        let units = UnitsManager.shared
        let savedUnit = units.weightUnit
        defer { units.setWeightUnit(savedUnit) }

        units.setWeightUnit(.kilograms)
        #expect(WorkoutShareCard.convertedVolume(kilograms: 1000.0, unitsManager: units) == 1000)

        units.setWeightUnit(.pounds)
        let lbs = WorkoutShareCard.convertedVolume(kilograms: 100.0, unitsManager: units)
        #expect(lbs == 220)
    }

    @Test("FutureSelfCommitmentScheduler computes future dates and persists reminder selection")
    @MainActor
    func commitmentSchedulerComputesDatesAndSchedules() throws {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = try #require(TimeZone(secondsFromGMT: 0))

        // Monday 2026-11-16 at 10:00 UTC
        let mondayMorning = try #require(cal.date(from: DateComponents(year: 2026, month: 11, day: 16, hour: 10, minute: 0)))

        let suiteName = "Wave4Commitment.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var capturedDates: [Date] = []

        let tonightDate = FutureSelfCommitmentScheduler.schedule(
            option: .tonight,
            referenceDate: mondayMorning,
            calendar: cal,
            userDefaults: defaults,
            scheduleNotification: { capturedDates.append($0) }
        )
        #expect(cal.component(.hour, from: tonightDate) == 20)
        #expect(cal.isDate(tonightDate, inSameDayAs: mondayMorning))
        #expect(defaults.string(forKey: FutureSelfCommitmentScheduler.optionKey) == "tonight")

        let tomorrowDate = FutureSelfCommitmentScheduler.schedule(
            option: .tomorrowMorning,
            referenceDate: mondayMorning,
            calendar: cal,
            userDefaults: defaults,
            scheduleNotification: { capturedDates.append($0) }
        )
        #expect(cal.component(.day, from: tomorrowDate) == 17)
        #expect(cal.component(.hour, from: tomorrowDate) == 9)

        let weekendDate = FutureSelfCommitmentScheduler.schedule(
            option: .thisWeekend,
            referenceDate: mondayMorning,
            calendar: cal,
            userDefaults: defaults,
            scheduleNotification: { capturedDates.append($0) }
        )
        #expect(cal.component(.weekday, from: weekendDate) == 7) // Saturday
        #expect(cal.component(.hour, from: weekendDate) == 10)
        #expect(capturedDates.count == 3)
        #expect(defaults.double(forKey: FutureSelfCommitmentScheduler.dateKey) == weekendDate.timeIntervalSince1970)
    }

    @Test("Pre-App Store: SmartCapture, Speech, Watch empty start, discard sync, and Vision feedback tone are wired")
    func preAppStoreAuditRemediationChecks() throws {
        let smartCaptureView = try readSource("WorkoutTracker/Features/Profile/SmartCaptureView.swift")
        #expect(smartCaptureView.contains("viewModel.stopSession()"))
        #expect(smartCaptureView.contains("scenePhase"))

        let aiCoachView = try readSource("WorkoutTracker/Features/AICoach/Views/AICoachView.swift")
        #expect(aiCoachView.contains("speechRecognizer.stopTranscribing()"))
        let aiChatBotView = try readSource("WorkoutTracker/Features/AICoach/Views/AIChatBotView.swift")
        #expect(aiChatBotView.contains("speechRecognizer.stopTranscribing()"))

        let aiTrackerView = try readSource("WorkoutTracker/MlVision/AITrackerView.swift")
        #expect(aiTrackerView.contains("engine.feedbackTone"))
        #expect(!aiTrackerView.contains("lowercased.contains(\"occluded\")"))

        let watchHub = try readSource("WatchApp/Views/WatchWorkoutHubView.swift")
        #expect(watchHub.contains("Start Empty Workout"))

        let workoutService = try readSource("WorkoutTracker/Services/Domain/WorkoutService.swift")
        #expect(workoutService.contains("sendDiscardWorkoutToWatch"))

        let settingsView = try readSource("WorkoutTracker/Features/Settings/SettingsView.swift")
        #expect(settingsView.contains("BlockedUsersSettingsView"))

        let bodyHeatmap = try readSource("WorkoutTracker/SharedUI/Components/BodyHeatmapView.swift")
        #expect(bodyHeatmap.contains("if showLabels && isCompactMode"))
        #expect(bodyHeatmap.contains("1 exercise"))
    }

    @Test("Crashlytics preserves original error domain, covers CloudKit/HealthKit/AI paths, and declares dSYM inputs")
    func crashlyticsAndCloudKitReadinessChecks() throws {
        let tracking = try readSource("WorkoutTracker/Services/Analytics/TrackingManager.swift")
        #expect(tracking.contains("record(error: error, userInfo:"))
        #expect(!tracking.contains("NSError(domain: \"WorkoutTracker\", code: 1"))

        let appSource = try readSource("WorkoutTracker/AppCore/WorkoutTrackerApp.swift")
        #expect(appSource.contains("CloudKit_SwiftData_fallback"))
        #expect(appSource.contains("AnonymousAuthBootstrap"))

        let hkManager = try readSource("WorkoutTracker/CoreLogic/Managers/HealthKitManager.swift")
        #expect(hkManager.contains("HealthKit_saveWorkout"))
        #expect(hkManager.contains("authorizationStatus(for:"))

        let geminiClient = try readSource("WorkoutTracker/Services/AI/GeminiNetworkClient.swift")
        #expect(geminiClient.contains("TrackingManager.shared.recordError"))

        let templatePreview = try readSource("WorkoutTracker/Features/Workout/Views/TemplatePreviewSheetView.swift")
        #expect(templatePreview.contains("TrackingManager.shared.recordError"))

        let pbxproj = try readSource("WorkoutTracker.xcodeproj/project.pbxproj")
        #expect(pbxproj.contains("${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}/Contents/Resources/DWARF/${PRODUCT_NAME}"))

        // Verify none of the SwiftData models use @Attribute(.unique) which breaks CloudKit sync.
        let modelFiles = [
            "WorkoutTracker/DataLayer/Models/Workout.swift",
            "WorkoutTracker/DataLayer/Models/WeightEntry.swift",
            "WorkoutTracker/DataLayer/Models/MuscleColorPreference.swift",
            "WorkoutTracker/DataLayer/Models/BodyMeasurement.swift",
            "WorkoutTracker/DataLayer/Models/CustomExerciseModels.swift",
            "WorkoutTracker/DataLayer/Models/UserGoal.swift",
            "WorkoutTracker/DataLayer/Models/AIChatModels.swift"
        ]
        for file in modelFiles {
            let content = try readSource(file)
            #expect(!content.contains(".unique"), "CloudKit forbids @Attribute(.unique) in \(file)")
        }
    }
}
