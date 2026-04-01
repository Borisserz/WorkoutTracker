//
//  WorkoutTrackerApp.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 24.12.25.
//
internal import SwiftUI
import SwiftData
import UserNotifications
import UIKit

@main
struct WorkoutTrackerApp: App {
    @Environment(\.scenePhase) private var scenePhase
    
    // ✅ DI Container State
    let sharedModelContainer: ModelContainer?
    let databaseLoadError: Error?
    
    // ViewModels (инициализируются лениво или через обертку)
    @State private var viewModel: WorkoutViewModel?
    @State private var userStatsViewModel: UserStatsViewModel?
    @State private var catalogViewModel: CatalogViewModel?
    @State private var aiCoachViewModel: AICoachViewModel?
    
    @StateObject private var tutorialManager = TutorialManager()
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
                   Group {
                       if let vm = viewModel, let usVm = userStatsViewModel, let catVm = catalogViewModel, let aiVm = aiCoachViewModel {
                           if hasCompletedOnboarding {
                               ContentView()
                                   .transition(.opacity)
                           } else {
                               OnboardingFlowView(isOnboardingCompleted: $hasCompletedOnboarding)
                           }
                       } else {
                           ProgressView("Initializing Systems...")
                               .onAppear {
                                   setupDependencies(container: container)
                               }
                       }
                   }
                   .environment(viewModel ?? WorkoutViewModel(modelContainer: container))
                   .environmentObject(userStatsViewModel ?? UserStatsViewModel(modelContainer: container))
                   .environmentObject(aiCoachViewModel ?? AICoachViewModel(modelContainer: container))
                   .environmentObject(catalogViewModel ?? CatalogViewModel(modelContainer: container))
                   .environmentObject(tutorialManager)
                   .environment(timerManager)
                   .environment(unitsManager)
                   .onOpenURL { url in
                       Task {
                           if await viewModel?.importPreset(from: url) == true {
                               await MainActor.run { showImportAlert = true }
                           }
                       }
                   }
                   .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { userActivity in
                       if let url = userActivity.webpageURL {
                           Task {
                               if await viewModel?.importPreset(from: url) == true {
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
                   .animation(.default, value: hasCompletedOnboarding)
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
    
    // ✅ Единая точка сборки зависимостей (DI) и миграций
    @MainActor
    private func setupDependencies(container: ModelContainer) {
        // 1. Создаем ViewModels передавая им контейнер (Strict DI)
        self.viewModel = WorkoutViewModel(modelContainer: container)
        self.userStatsViewModel = UserStatsViewModel(modelContainer: container)
        self.catalogViewModel = CatalogViewModel(modelContainer: container)
        self.aiCoachViewModel = AICoachViewModel(modelContainer: container)
        
        // 2. Выполняем стартовые задачи
        Task {
            LegacyDataMigrator.migrateAllIfNeeded(context: container.mainContext)
            self.viewModel?.checkAndGenerateDefaultPresets()
            MuscleColorManager.shared.load(context: container.mainContext)
            
            // Прогрев кэша SVG асинхронно
            let allMuscles = BodyData.frontMuscles + BodyData.backMuscles + BodyData.frontMusclesFemale + BodyData.backMusclesFemale
            for muscle in allMuscles {
                for pathStr in muscle.paths {
                    _ = SVGParser.path(from: pathStr)
                    try? await Task.sleep(nanoseconds: 1_000_000)
                }
            }
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
