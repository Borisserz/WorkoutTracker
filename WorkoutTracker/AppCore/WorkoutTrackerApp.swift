internal import SwiftUI
import OSLog
import SwiftData
import UserNotifications
import AppIntents
import FirebaseCore
import FirebaseAppCheck
import GoogleSignIn
// MARK: - App Check provider
final class AppCheckFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        #if DEBUG
        return AppCheckDebugProvider(app: app)
        #else
        return AppAttestProvider(app: app)
        #endif
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {

        UITestLaunchConfiguration.applyIfNeeded()

        AppCheck.setAppCheckProviderFactory(AppCheckFactory())
        FirebaseApp.configure()

        return true
    }

func application(_ app: UIApplication,
                    open url: URL,
                    options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
       return GIDSignIn.sharedInstance.handle(url)
   }
}
@main
struct WorkoutTrackerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    @Environment(\.scenePhase) private var scenePhase

    @State private var diContainer: DIContainer?
    @State private var databaseLoadError: Error?

    @State private var dashboardViewModel: DashboardViewModel?
    @State private var userStatsViewModel: UserStatsViewModel?
    @State private var aiCoachViewModel: AICoachViewModel?
    @State private var catalogViewModel: CatalogViewModel?
    @State private var profileViewModel: ProfileViewModel?

    @AppStorage(Constants.UserDefaultsKeys.appearanceMode.rawValue) private var appearanceMode: String = AppearanceMode.lockedRawValue
    @State private var showImportAlert = false
    @State private var showImportError = false
    @State private var importErrorMessage: String = ""
    @State private var showReportSheet = false
    @State private var lastImportedWorkoutId: String?
    @State private var lastImportedCreatorUid: String?
    @State private var lastImportedWorkoutName: String = ""
    @State private var restTimerManager = RestTimerManager()
    @State private var tutorialManager = TutorialManager()
    @State private var versionManager = VersionManager.shared

    @AppStorage("hasCompletedGodModeOnboarding_v1") private var hasCompletedGodModeOnboarding = false
    @State private var showSisterAppsPromo = false
    /// Survives DI bootstrap: cold open before `diContainer` exists.
    @State private var queuedOpenURL: URL?

    private var colorScheme: ColorScheme? {
        _ = appearanceMode
        return AppearanceMode.preferredColorScheme
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let error = databaseLoadError {
                    DatabaseErrorView(error: error)
                        .preferredColorScheme(colorScheme)
                } else if let di = diContainer,
                          let dvm = dashboardViewModel,
                          let usvm = userStatsViewModel,
                          let aicvm = aiCoachViewModel,
                          let cvm = catalogViewModel,
                          let pvm = profileViewModel {

                    if versionManager.updateRequirement == .hardUpdate {
                        ForceUpdateView()
                            .environment(ThemeManager.shared)
                            .preferredColorScheme(colorScheme)
                    } else if !hasCompletedGodModeOnboarding {
                        RootGodModeOnboarding(onFinish: { targetTab in
                            withAnimation(.easeInOut(duration: 0.8)) {
                                hasCompletedGodModeOnboarding = true
                            }
                            if let tab = targetTab {
                                di.appState.selectedTab = tab
                            }
                        })
                        .preferredColorScheme(.dark)
                        .environment(ThemeManager.shared)
                        .environment(di.appState)
                    } else {
                        mainContent(di: di, dvm: dvm, usvm: usvm, aicvm: aicvm, cvm: cvm, pvm: pvm)
                    }

                } else {
                    ProgressView("Initializing...")
                        .controlSize(.large)
                        .preferredColorScheme(colorScheme)
                }
            }
            .task {
                AppearanceMode.enforceLockedModeInUserDefaults()
                appearanceMode = AppearanceMode.lockedRawValue
                await setupDependencies()
                if let queued = queuedOpenURL, let di = diContainer {
                    queuedOpenURL = nil
                    di.appState.pendingOpenURL = queued
                }
                if let pending = diContainer?.appState.pendingOpenURL,
                   hasCompletedGodModeOnboarding,
                   databaseLoadError == nil,
                   versionManager.updateRequirement != .hardUpdate {
                    diContainer?.appState.pendingOpenURL = nil
                    NotificationCenter.default.post(name: Notification.Name("pendingOpenURLReady"), object: pending)
                }
            }
            .onOpenURL { url in
                // R14: handle warm deep links here too — nested ContentView handler can miss them.
                let mainContentReady = diContainer != nil
                    && hasCompletedGodModeOnboarding
                    && databaseLoadError == nil
                    && versionManager.updateRequirement != .hardUpdate
                if mainContentReady, let di = diContainer {
                    handleIncomingURL(url, di: di)
                    return
                }
                if let di = diContainer {
                    di.appState.pendingOpenURL = url
                } else {
                    queuedOpenURL = url
                }
            }
            .onChange(of: scenePhase) { newPhase in
                if newPhase == .active {
                    TrackingManager.shared.track(.appOpened(source: "scene_active"))
                    UNUserNotificationCenter.current().setBadgeCount(0)
                    UNUserNotificationCenter.current().removeAllDeliveredNotifications()
                    // Re-evaluate force/soft update when returning to foreground (I16).
                    Task { await versionManager.checkForUpdates() }
                }
            }
            .onChange(of: hasCompletedGodModeOnboarding) { completed in
                guard completed, let di = diContainer, let url = di.appState.pendingOpenURL else { return }
                di.appState.pendingOpenURL = nil
                NotificationCenter.default.post(name: Notification.Name("pendingOpenURLReady"), object: url)
            }
        }
    }

    @ViewBuilder
    private func mainContent(
        di: DIContainer,
        dvm: DashboardViewModel,
        usvm: UserStatsViewModel,
        aicvm: AICoachViewModel,
        cvm: CatalogViewModel,
        pvm: ProfileViewModel
    ) -> some View {
        ContentView()
            .transition(.opacity)
            .animation(.default, value: true)
            .modelContainer(di.modelContainer)
            .environment(di)
            .environment(di.workoutService)
            .environment(di.presetService)
            .environment(di.authManager)
            .environment(restTimerManager)
            .environment(tutorialManager)
            .environment(UnitsManager.shared)
            .environment(ThemeManager.shared)
            .environment(dvm)
            .environment(usvm)
            .environment(aicvm)
            .environment(cvm)
            .environment(pvm)
            .environment(di.appState)
            .preferredColorScheme(colorScheme)
            .alert("Update Available", isPresented: Binding(
                get: { versionManager.updateRequirement == .softUpdate && !versionManager.hasDismissedSoftUpdate },
                set: { if !$0 { versionManager.hasDismissedSoftUpdate = true } }
            )) {
                Button("Update Now") {
                    AppReviewManager.openAppStoreProductPage()
                }
                Button("Later", role: .cancel) {
                    versionManager.hasDismissedSoftUpdate = true
                }
            } message: {
                Text("A new version of the app is available. Update now to get the latest features and fixes.")
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("pendingOpenURLReady"))) { note in
                if let url = note.object as? URL {
                    handleIncomingURL(url, di: di)
                }
            }
            .onOpenURL { url in
                handleIncomingURL(url, di: di)
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("widgetActionTriggered"))) { notification in
                if let action = notification.object as? String {
                    handleWidgetAction(action, appState: di.appState)
                }
            }
            .confirmationDialog("Template Imported!", isPresented: $showImportAlert, titleVisibility: .visible) {
                Button("OK", role: .cancel) { }
                if lastImportedWorkoutId != nil, lastImportedCreatorUid != nil {
                    Button("Report this workout", role: .destructive) {
                        showReportSheet = true
                    }
                }
            } message: {
                Text(lastImportedWorkoutName.isEmpty
                     ? "Added to Saved Routines."
                     : "\"\(lastImportedWorkoutName)\" added to Saved Routines.")
            }
            .sheet(isPresented: $showReportSheet) {
                if let workoutId = lastImportedWorkoutId,
                   let creatorUid = lastImportedCreatorUid {
                    ReportSheet(workoutId: workoutId, creatorUid: creatorUid)
                }
            }
            .alert("Failed to import", isPresented: $showImportError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(importErrorMessage)
            }
            .fullScreenCover(isPresented: $showSisterAppsPromo) {
                SisterAppsPromoView()
                    .environment(ThemeManager.shared)
                    .preferredColorScheme(.dark)
            }
            .task {
                for _ in 0..<10 {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    let showPromo = await RemoteConfigManager.shared.showSisterAppsPromo
                    if showPromo && !SisterAppsPromoFlags.hasSeenPromo() {
                        await MainActor.run {
                            SisterAppsPromoFlags.markSeen()
                            self.showSisterAppsPromo = true
                        }
                        break
                    } else if showPromo && SisterAppsPromoFlags.hasSeenPromo() {
                        break
                    }
                }
            }
    }

    private func handleIncomingURL(_ url: URL, di: DIContainer) {
        if url.scheme == "workouttracker" {
            if url.host == "tab",
               let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
               let indexStr = components.queryItems?.first(where: { $0.name == "index" })?.value,
               let index = Int(indexStr) {
                di.appState.showCalendarSheet = false
                di.appState.showSmartBuilderSheet = false
                di.appState.showAISettingsSheet = false
                di.appState.selectedTab = index
                return
            }
            if url.host == "discovery" {
                di.appState.selectedTab = 2
                di.appState.showWorkoutModeDiscovery = true
                return
            }
            if url.host == "smartbuilder" {
                di.appState.selectedTab = 3
                di.appState.showSmartBuilderSheet = true
                return
            }
            if url.host == "aisettings" {
                di.appState.selectedTab = 3
                di.appState.showAISettingsSheet = true
                return
            }
            if url.host == "profile" {
                di.appState.selectedTab = 4
                di.appState.showProfileSheet = true
                return
            }
            if url.host == "calendar" {
                di.appState.showCalendarSheet = true
                return
            }
            if url.host == "achievements" {
                di.appState.selectedTab = 4
                di.appState.showAchievementsSheet = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    di.appState.showAchievementsSheet = true
                }
                return
            }
            if url.host == "shared" {
                guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
                      let id = components.queryItems?.first(where: { $0.name == "id" })?.value else { return }
                Task {
                    do {
                        let (presetDTO, creatorUid) = try await FirestoreProgramService.shared.downloadSharedPresetWithCreator(id: id)
                        let newExercises = presetDTO.exercises.map { Exercise(from: $0) }
                        await di.presetService.savePreset(
                            preset: nil,
                            name: presetDTO.name + " (Shared)",
                            icon: presetDTO.icon,
                            folderName: PresetService.savedRoutinesFolderName,
                            exercises: newExercises
                        )
                        await MainActor.run {
                            self.lastImportedWorkoutId = id
                            self.lastImportedCreatorUid = creatorUid
                            self.lastImportedWorkoutName = presetDTO.name
                            showImportAlert = true
                        }
                    } catch let error as SharedWorkoutError {
                        await MainActor.run {
                            importErrorMessage = error.localizedDescription
                            showImportError = true
                        }
                    } catch {
                        await MainActor.run {
                            importErrorMessage = "Failed to load workout. Check your internet connection."
                            showImportError = true
                        }
                    }
                }
                return
            }
        }

        Task {
            if await di.presetService.importPreset(from: url) {
                await MainActor.run {
                    self.lastImportedWorkoutName = url.deletingPathExtension().lastPathComponent
                    self.lastImportedWorkoutId = nil
                    self.lastImportedCreatorUid = nil
                    showImportAlert = true
                }
            }
        }
    }

    private func handleWidgetAction(_ action: String, appState: AppStateManager) {
        appState.requestedWidgetAction = action
        let key = Constants.UserDefaultsKeys.pendingWidgetAction.rawValue
        UserDefaults(suiteName: "group.com.borisdev.WorkoutTracker")?.set(action, forKey: key)
        UserDefaults.standard.set(action, forKey: key)

        switch action {
        case "empty_workout":
            appState.selectedTab = 2
            appState.showWorkoutModeDiscovery = true
        case "smart_builder":
            appState.selectedTab = 2
            appState.showSmartBuilder = true
        case "log_weight":
            appState.selectedTab = 0
            appState.showWeightLog = true
        default:
            break
        }
    }

    @MainActor
    private func setupDependencies() async {
        do {
            let schema = Schema([
                Workout.self, WorkoutPreset.self, ExerciseNote.self, UserStats.self,
                ExerciseStat.self, MuscleStat.self, WeightEntry.self, MuscleColorPreference.self,
                AIChatSession.self, BodyMeasurement.self, ExerciseDictionaryItem.self, UserGoal.self
            ])

            let dbURL: URL
            if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.borisdev.WorkoutTracker") {
                dbURL = groupURL.appendingPathComponent("WorkoutDatabase.sqlite")
            } else {
                AppLog.app.error("⚠️ CRITICAL: App Group container not found. Falling back to local Documents directory. Widgets and Apple Watch may not be able to access the database.")
                let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
                dbURL = paths[0].appendingPathComponent("WorkoutDatabase.sqlite")
            }

            let container: ModelContainer
            #if targetEnvironment(simulator)
            let localConfig = ModelConfiguration(schema: schema, url: dbURL, cloudKitDatabase: .none)
            container = try ModelContainer(for: schema, configurations: [localConfig])
            #else
            do {
                let cloudConfig = ModelConfiguration(
                    schema: schema,
                    url: dbURL,
                    cloudKitDatabase: .private("iCloud.com.borisdev.WorkoutTracker")
                )
                container = try ModelContainer(for: schema, configurations: [cloudConfig])
            } catch {
                AppLog.app.warning("⚠️ CloudKit didn't open, local rollback: \(error.localizedDescription, privacy: .public)")
                let localConfig = ModelConfiguration(schema: schema, url: dbURL, cloudKitDatabase: .none)
                container = try ModelContainer(for: schema, configurations: [localConfig])
            }
            #endif

            let di = DIContainer(modelContainer: container)

            PhoneWatchManager.shared.start(with: container)
            PhoneWatchManager.shared.isSessionStartBlocked = { [weak di] in
                di?.workoutService.isFinishTransitionPending == true
            }
            MuscleColorManager.shared.initialize(modelContainer: container)

            self.dashboardViewModel = di.makeDashboardViewModel()
            self.userStatsViewModel = di.makeUserStatsViewModel()
            self.aiCoachViewModel = di.makeAICoachViewModel()
            self.catalogViewModel = di.makeCatalogViewModel()
            self.profileViewModel = di.makeProfileViewModel()

            self.diContainer = di

            Task {
                do {
                    _ = try await AnonymousAuthBootstrap.shared.ensureSignedIn()
                    await BlockedUsersStore.shared.startListening()
                } catch {
                    AppLog.app.error("⚠️ Anonymous auth bootstrap failed: \(error.localizedDescription)")
                    // Maestro / UITestMode: keep chrome unobstructed; cloud is optional for smoke.
                    if !UITestLaunchConfiguration.isUITestMode {
                        await MainActor.run {
                            di.appState.showError(
                                title: String(localized: "Sign-in unavailable"),
                                message: String(localized: "Cloud features may be limited until you reconnect. Pull to refresh or relaunch the app.")
                            )
                        }
                    }
                }

                await RemoteConfigManager.shared.fetchCloudValues()
                await versionManager.checkForUpdates()
                await ExerciseDatabaseService.shared.loadDatabase()

                let migrator = LegacyDataMigrator(modelContainer: container)
                await migrator.migrateAllIfNeeded()
                
                try? await di.exerciseCatalogService.checkAndGenerateDefaultPresets()
                
                await self.catalogViewModel?.loadDictionary()
            }

        } catch {
            TrackingManager.shared.track(.errorOccurred(errorType: "database_load_failed", screen: "WorkoutTrackerApp"))
            self.databaseLoadError = error
            AppLog.app.error("❌ SwiftData Initialization Failed: \(error.localizedDescription, privacy: .public)")
            TrackingManager.shared.recordError(error: error, additionalInfo: ["context": "SwiftData_init"])
            // Keep DatabaseErrorView reachable — do not crash after setting the error.
        }
    }

    struct DatabaseErrorView: View {
        private let themeManager = ThemeManager.shared
        let error: Error?
        var body: some View {
            VStack(spacing: 24) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.red)
                Text("Database Error")
                    .font(.title).fontWeight(.bold).multilineTextAlignment(.center)
                Text("There was an issue loading your data. Please do not delete the app, as this could result in permanent data loss.\n\nTry restarting the app or contact support.")
                    .multilineTextAlignment(.center).foregroundColor(themeManager.current.secondaryText).padding(.horizontal)
                if let error = error {
                    ScrollView {
                        Text(error.localizedDescription).font(.caption).foregroundColor(themeManager.current.primaryText).padding()
                    }
                    .frame(maxHeight: 150)
                    .background(themeManager.current.surface)
                    .cornerRadius(12).padding(.horizontal)
                }
            }
            .padding()
        }
    }
}
