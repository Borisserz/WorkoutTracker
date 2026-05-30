internal import SwiftUI
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

    @AppStorage(Constants.UserDefaultsKeys.appearanceMode.rawValue) private var appearanceMode: String = "system"
    @State private var showImportAlert = false
    @State private var showImportError = false
    @State private var importErrorMessage: String = ""
    @State private var showReportSheet = false
    @State private var lastImportedWorkoutId: String?
    @State private var lastImportedCreatorUid: String?
    @State private var lastImportedWorkoutName: String = ""
    @State private var restTimerManager = RestTimerManager()
    @State private var tutorialManager = TutorialManager()

    @AppStorage("hasCompletedGodModeOnboarding_v1") private var hasCompletedGodModeOnboarding = false

    private var colorScheme: ColorScheme? {
        switch appearanceMode {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
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

                    if !hasCompletedGodModeOnboarding {
                        RootGodModeOnboarding(onFinish: {
                            withAnimation(.easeInOut(duration: 0.8)) {
                                hasCompletedGodModeOnboarding = true
                            }
                        })
                        .preferredColorScheme(.dark)
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
                await setupDependencies()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    UNUserNotificationCenter.current().setBadgeCount(0)
                    UNUserNotificationCenter.current().removeAllDeliveredNotifications()
                }
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
            .environment(restTimerManager)
            .environment(tutorialManager)
            .environment(UnitsManager.shared)
            .environment(ThemeManager.shared)
            .environment(dvm)
            .environment(usvm)
            .environment(aicvm)
            .environment(cvm)
            .environment(pvm)
            .preferredColorScheme(colorScheme)
            .onOpenURL { url in
                if url.scheme == "workouttracker" && url.host == "shared" {
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
                            await MainActor.run { showImportAlert = true }
                        } catch let error as SharedWorkoutError {
                            await MainActor.run {
                                importErrorMessage = error.localizedDescription
                                showImportError = true
                            }
                            print("❌ Shared workout import rejected: \(error.localizedDescription)")
                        } catch {
                            await MainActor.run {
                                importErrorMessage = "Failed to load workout. Check your internet connection."
                                showImportError = true
                            }
                            print("❌ Import: \(error)")
                        }
                    }
                } else {
                    Task {
                        if await di.presetService.importPreset(from: url) {
                            await MainActor.run { showImportAlert = true }
                        }
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("widgetActionTriggered"))) { notification in
                if let action = notification.object as? String {
                    handleWidgetAction(action, appState: di.appState)
                }
            }
            .confirmationDialog("Template Imported!", isPresented: $showImportAlert, titleVisibility: .visible) {
                Button("OK", role: .cancel) { }
                Button("Report this workout", role: .destructive) {
                    showReportSheet = true
                }
            } message: {
                Text("\"\(lastImportedWorkoutName)\" added to Saved Routines.")
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
    }

    private func handleWidgetAction(_ action: String, appState: AppStateManager) {
        appState.requestedWidgetAction = action

        if action == "empty_workout" || action == "smart_builder" {
            appState.selectedTab = 2
        } else if action == "log_weight" {
            appState.selectedTab = 0
        }
    }

    @MainActor
    private func setupDependencies() async {
        do {
            // 🔐 Bootstrap anonymous Firebase Auth before any Firestore writes
            // (UGC features and reports require request.auth).
            do {
                _ = try await AnonymousAuthBootstrap.shared.ensureSignedIn()
                await BlockedUsersStore.shared.startListening()
            } catch {
                print("⚠️ Anonymous auth bootstrap failed: \(error.localizedDescription)")
                // Non-fatal — catalog reads still work; UGC writes will fail with a clear error.
            }

            await RemoteConfigManager.shared.fetchCloudValues()
            await ExerciseDatabaseService.shared.loadDatabase()

            let schema = Schema([
                Workout.self, WorkoutPreset.self, ExerciseNote.self, UserStats.self,
                ExerciseStat.self, MuscleStat.self, WeightEntry.self, MuscleColorPreference.self,
                AIChatSession.self, BodyMeasurement.self, ExerciseDictionaryItem.self, UserGoal.self
            ])

            let dbURL: URL
            if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.borisdev.WorkoutTracker") {
                dbURL = groupURL.appendingPathComponent("WorkoutDatabase.sqlite")
            } else {
                print("⚠️ CRITICAL: App Group container not found. Falling back to local Documents directory. Widgets and Apple Watch may not be able to access the database.")
                let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
                dbURL = paths[0].appendingPathComponent("WorkoutDatabase.sqlite")
            }

            let cloudConfig = ModelConfiguration(
                schema: schema,
                url: dbURL,
                cloudKitDatabase: .private("iCloud.com.borisdev.WorkoutTracker")
            )

            let container: ModelContainer
            do {
                container = try ModelContainer(for: schema, configurations: [cloudConfig])
            } catch {
                print("⚠️ CloudKit didn't open, local rollback: \(error)")
                let localConfig = ModelConfiguration(schema: schema, url: dbURL, cloudKitDatabase: .none)
                container = try ModelContainer(for: schema, configurations: [localConfig])
            }

            let di = DIContainer(modelContainer: container)

            PhoneWatchManager.shared.start(with: container)

            let migrator = LegacyDataMigrator(modelContainer: container)
            await migrator.migrateAllIfNeeded()
            try? await di.exerciseCatalogService.checkAndGenerateDefaultPresets()
            MuscleColorManager.shared.initialize(modelContainer: container)

            self.dashboardViewModel = di.makeDashboardViewModel()
            self.userStatsViewModel = di.makeUserStatsViewModel()
            self.aiCoachViewModel = di.makeAICoachViewModel()
            self.catalogViewModel = di.makeCatalogViewModel()
            self.profileViewModel = di.makeProfileViewModel()

            self.diContainer = di
            await self.catalogViewModel?.loadDictionary()

        } catch {
            self.databaseLoadError = error
            print("❌ SwiftData Initialization Failed: \(error)")
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
