// ============================================================
// FILE: WorkoutTracker/App/WorkoutTrackerApp.swift
// ============================================================

internal import SwiftUI
import SwiftData
import UserNotifications
import ActivityKit

@main
struct WorkoutTrackerApp: App {
    @Environment(\.scenePhase) private var scenePhase
    
    // DIContainer теперь единственный источник правды для сервисов
    let diContainer: DIContainer
    
    @State private var databaseLoadError: Error?
    
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @AppStorage("appearanceMode") private var appearanceMode: String = "system"
    @State private var showImportAlert = false
    
    // ViewModels & Managers needed globally in Environment
    @State private var dashboardViewModel: DashboardViewModel
    @State private var userStatsViewModel: UserStatsViewModel
    @State private var catalogViewModel: CatalogViewModel
    @State private var restTimerManager = RestTimerManager()
    @State private var tutorialManager = TutorialManager()
    @State private var unitsManager = UnitsManager.shared
    
    private var colorScheme: ColorScheme? {
        switch appearanceMode {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }
    
    init() {
        do {
            let container = try ModelContainer(for: Workout.self, WorkoutPreset.self, ExerciseNote.self, UserStats.self, ExerciseStat.self, MuscleStat.self, WeightEntry.self, MuscleColorPreference.self, AIChatSession.self, BodyMeasurement.self, ExerciseDictionaryItem.self)
            let di = DIContainer(modelContainer: container)
            self.diContainer = di
            
            // Инициализируем ViewModels используя DIContainer
            self._dashboardViewModel = State(wrappedValue: di.makeDashboardViewModel())
            self._userStatsViewModel = State(wrappedValue: di.makeUserStatsViewModel())
            self._catalogViewModel = State(wrappedValue: di.makeCatalogViewModel())
            self.databaseLoadError = nil
        } catch {
            print("Could not create ModelContainer: \(error)")
            // Fallback: Создаем временный контейнер в памяти чтобы избежать краша инициализации
            let tempConfig = ModelConfiguration(isStoredInMemoryOnly: true)
            let tempContainer = try! ModelContainer(for: Workout.self, WorkoutPreset.self, ExerciseNote.self, UserStats.self, ExerciseStat.self, MuscleStat.self, WeightEntry.self, MuscleColorPreference.self, AIChatSession.self, BodyMeasurement.self, ExerciseDictionaryItem.self, configurations: tempConfig)
            let tempDi = DIContainer(modelContainer: tempContainer)
            
            self.diContainer = tempDi
            self._dashboardViewModel = State(wrappedValue: tempDi.makeDashboardViewModel())
            self._userStatsViewModel = State(wrappedValue: tempDi.makeUserStatsViewModel())
            self._catalogViewModel = State(wrappedValue: tempDi.makeCatalogViewModel())
            self.databaseLoadError = error
        }
    }
    
    var body: some Scene {
        WindowGroup {
            if databaseLoadError == nil {
                mainContent()
                    .onOpenURL { url in
                        Task {
                            if await diContainer.workoutService.importPreset(from: url) {
                                await MainActor.run { showImportAlert = true }
                            }
                        }
                    }
                    .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { userActivity in
                        if let url = userActivity.webpageURL {
                            Task {
                                if await diContainer.workoutService.importPreset(from: url) {
                                    await MainActor.run { showImportAlert = true }
                                }
                            }
                        }
                    }
                    .alert("Template Imported!", isPresented: $showImportAlert) {
                        Button("OK", role: .cancel) { }
                    } message: {
                        Text("A new workout template has been added to your collection.")
                    }
                    .preferredColorScheme(colorScheme)
                    .onChange(of: scenePhase) { _, newPhase in
                        if newPhase == .active {
                            UNUserNotificationCenter.current().setBadgeCount(0)
                            UNUserNotificationCenter.current().removeAllDeliveredNotifications()
                        }
                    }
                    .modelContainer(diContainer.modelContainer)
                    // 👇 ПРОБРАСЫВАЕМ ВСЕ НЕОБХОДИМЫЕ ЗАВИСИМОСТИ В ENVIRONMENT
                    .environment(diContainer)
                    .environment(diContainer.workoutService)
                    .environment(dashboardViewModel)
                    .environment(userStatsViewModel)
                    .environment(catalogViewModel)
                    .environment(restTimerManager)
                    .environment(tutorialManager)
                    .environment(unitsManager)
            } else {
                DatabaseErrorView(error: databaseLoadError)
                    .preferredColorScheme(colorScheme)
            }
        }
    }
    
    @ViewBuilder
    private func mainContent() -> some View {
        Group {
            if hasCompletedOnboarding {
                ContentView().transition(.opacity)
            } else {
                OnboardingFlowView(isOnboardingCompleted: $hasCompletedOnboarding)
            }
        }
        .animation(.default, value: hasCompletedOnboarding)
        .onAppear { setupDependencies() }
    }
    
    @MainActor
    private func setupDependencies() {
        Task {
            let migrator = LegacyDataMigrator(modelContainer: diContainer.modelContainer)
            await migrator.migrateAllIfNeeded()
            
            try? await diContainer.exerciseCatalogService.checkAndGenerateDefaultPresets()
            MuscleColorManager.shared.load(context: diContainer.modelContainer.mainContext)
            
            await catalogViewModel.loadDictionary()
        }
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
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            Text("There was an issue loading your data. Please do not delete the app, as this could result in permanent data loss.\n\nTry restarting the app or contact support.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            if let error = error {
                ScrollView {
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundColor(.primary)
                        .padding()
                }
                .frame(maxHeight: 150)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal)
            }
        }
        .padding()
    }
}
