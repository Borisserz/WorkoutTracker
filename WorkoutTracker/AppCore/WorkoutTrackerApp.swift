//
//  WorkoutTrackerApp.swift
//  WorkoutTracker
//

internal import SwiftUI
import SwiftData
import UserNotifications

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
    
    // Удален @AppStorage("hasCompletedOnboarding")
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
                    ProgressView("Инициализация...")
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
        // Убраны проверки OnboardingFlowView. Сразу показываем ContentView.
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
            .alert("Template Imported!", isPresented: $showImportAlert) {
                Button("OK", role: .cancel) { }
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
             
             let modelConfiguration = ModelConfiguration(
                 schema: schema,
                 isStoredInMemoryOnly: false,
                 cloudKitDatabase: .automatic
             )
             
             let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
             let di = DIContainer(modelContainer: container)
             
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
             
             // ❌ УДАЛЕНО: Запрос HealthKit при старте приложения
             
         } catch {
             self.databaseLoadError = error
             print("❌ SwiftData Initialization Failed: \(error)")
         }
     }
    
    struct DatabaseErrorView: View {
        let error: Error?
        var body: some View {
            VStack(spacing: 24) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.red)
                Text("Database Error")
                    .font(.title).fontWeight(.bold).multilineTextAlignment(.center)
                Text("There was an issue loading your data. Please do not delete the app, as this could result in permanent data loss.\n\nTry restarting the app or contact support.")
                    .multilineTextAlignment(.center).foregroundColor(.secondary).padding(.horizontal)
                if let error = error {
                    ScrollView {
                        Text(error.localizedDescription).font(.caption).foregroundColor(.primary).padding()
                    }
                    .frame(maxHeight: 150)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12).padding(.horizontal)
                }
            }
            .padding()
        }
    }
}
