// ============================================================
// FILE: WorkoutTracker/AppCore/WorkoutTrackerApp.swift
// ============================================================

internal import SwiftUI
import SwiftData
import UserNotifications
import AppIntents

@main
struct WorkoutTrackerApp: App {
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
    
    @State private var restTimerManager = RestTimerManager()
    @State private var tutorialManager = TutorialManager()
    
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
                    // Сразу запускаем главный контент
                    mainContent(di: di, dvm: dvm, usvm: usvm, aicvm: aicvm, cvm: cvm, pvm: pvm)
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
                Task {
                    if await di.presetService.importPreset(from: url) {
                        await MainActor.run { showImportAlert = true }
                    }
                }
            }
            // ✅ ЛОВИМ НАЖАТИЯ ИЗ ВИДЖЕТА
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("widgetActionTriggered"))) { notification in
                if let action = notification.object as? String {
                    handleWidgetAction(action, appState: di.appState)
                }
            }
            .alert("Template Imported!", isPresented: $showImportAlert) {
                Button("OK", role: .cancel) { }
            }
    }
    
    // ✅ ЛОГИКА МАРШРУТИЗАЦИИ ВИДЖЕТОВ
    private func handleWidgetAction(_ action: String, appState: AppStateManager) {
        appState.requestedWidgetAction = action
        
        if action == "empty_workout" || action == "smart_builder" {
            appState.selectedTab = 2 // Переходим на WorkoutHub
        } else if action == "log_weight" {
            appState.selectedTab = 0 // Переходим на Overview (где профиль с весом)
        }
    }
    
    @MainActor
        private func setupDependencies() async {
            do {
                await ExerciseDatabaseService.shared.loadDatabase()
                
                let schema = Schema([
                    Workout.self, WorkoutPreset.self, ExerciseNote.self, UserStats.self,
                    ExerciseStat.self, MuscleStat.self, WeightEntry.self, MuscleColorPreference.self,
                    AIChatSession.self, BodyMeasurement.self, ExerciseDictionaryItem.self, UserGoal.self
                ])
                
                let modelConfiguration = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: false,
                    cloudKitDatabase: .automatic
                )
                
                let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
                let di = DIContainer(modelContainer: container)
                
                // 👇 ДОБАВИТЬ ЭТУ СТРОКУ 👇
                PhoneWatchManager.shared.start(with: container)
                // 👆 ======================= 👆
                
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
        @Environment(ThemeManager.self) private var themeManager
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
