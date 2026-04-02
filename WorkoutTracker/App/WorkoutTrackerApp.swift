//
//  WorkoutTrackerApp.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 24.12.25.
//
internal import SwiftUI
import SwiftData
import UserNotifications
import ActivityKit

@main
struct WorkoutTrackerApp: App {
    @Environment(\.scenePhase) private var scenePhase
    
    let sharedModelContainer: ModelContainer?
    let databaseLoadError: Error?
    
    // ViewModels
    @State private var viewModel: WorkoutViewModel?
    @State private var userStatsViewModel: UserStatsViewModel?
    @State private var catalogViewModel: CatalogViewModel?
    @State private var aiCoachViewModel: AICoachViewModel?
    @State private var dashboardViewModel: DashboardViewModel?
    
    @State private var tutorialManager = TutorialManager()
    @State private var timerManager = RestTimerManager()
    @State private var unitsManager = UnitsManager.shared
    
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @AppStorage("appearanceMode") private var appearanceMode: String = "system"
    @State private var showImportAlert = false
    
    private var colorScheme: ColorScheme? {
        switch appearanceMode {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }
    
    init() {
        do {
            let container = try ModelContainer(for: Workout.self, WorkoutPreset.self, ExerciseNote.self, UserStats.self, ExerciseStat.self, MuscleStat.self, WeightEntry.self, MuscleColorPreference.self, AIChatSession.self, BodyMeasurement.self)
            sharedModelContainer = container
            databaseLoadError = nil
        } catch {
            print("Could not create ModelContainer: \(error)")
            sharedModelContainer = nil
            databaseLoadError = error
        }
    }
    
    
    var body: some Scene {
        WindowGroup {
            if let container = sharedModelContainer {
                mainContent(container: container)
                    .onOpenURL { url in
                        Task {
                            // ✅ ИЗМЕНЕНИЕ: Безопасно распаковываем dashVm перед импортом
                            if let dashVm = dashboardViewModel {
                                if await viewModel?.importPreset(from: url) == true {
                                    await MainActor.run { showImportAlert = true }
                                }
                            }
                        }
                    }
                    .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { userActivity in
                        if let url = userActivity.webpageURL {
                            Task {
                                // ✅ ИЗМЕНЕНИЕ: Безопасно распаковываем dashVm перед импортом
                                if let dashVm = dashboardViewModel {
                                    if await viewModel?.importPreset(from: url) == true {
                                        await MainActor.run { showImportAlert = true }
                                    }
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
                    .modelContainer(container)
            } else {
                DatabaseErrorView(error: databaseLoadError)
                    .preferredColorScheme(colorScheme)
            }
        }
    }
    
    @ViewBuilder
       private func mainContent(container: ModelContainer) -> some View {
           if let vm = viewModel,
              let usVm = userStatsViewModel,
              let catVm = catalogViewModel,
              let aiVm = aiCoachViewModel,
              let dashVm = dashboardViewModel {
               
               Group {
                   if hasCompletedOnboarding {
                       ContentView().transition(.opacity)
                   } else {
                       OnboardingFlowView(isOnboardingCompleted: $hasCompletedOnboarding)
                   }
               }
               .animation(.default, value: hasCompletedOnboarding)
               .environment(vm)
               .environment(usVm)
               .environment(catVm)
               .environment(aiVm)
               .environment(dashVm)
               .environment(tutorialManager)
               .environment(timerManager)
               .environment(unitsManager)
               
           } else {
               ProgressView("Initializing Systems...")
                   .onAppear { setupDependencies(container: container) }
           }
       }
       
       @MainActor
       private func setupDependencies(container: ModelContainer) {
           // ✅ ВНЕДРЕНИЕ ЗАВИСИМОСТЕЙ (DI)
           // 1. Создаем абстракцию репозитория
           let repository = WorkoutRepository(modelContainer: container)
           
           // 2. Инжектируем репозиторий в ViewModels
           let dashVM = DashboardViewModel(repository: repository)
           self.dashboardViewModel = dashVM
           
           // Передаем dashboardViewModel прямо сюда, чтобы не прокидывать его в каждый метод!
           self.viewModel = WorkoutViewModel(modelContainer: container, repository: repository, dashboardViewModel: dashVM)
           
           // Остальные ViewModels (позже тоже переведем на RepositoryProtocol)
           self.userStatsViewModel = UserStatsViewModel(modelContainer: container)
           self.catalogViewModel = CatalogViewModel(modelContainer: container)
           self.aiCoachViewModel = AICoachViewModel(modelContainer: container)
           
           Task {
               LegacyDataMigrator.migrateAllIfNeeded(context: container.mainContext)
               self.viewModel?.checkAndGenerateDefaultPresets()
               MuscleColorManager.shared.load(context: container.mainContext)
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
