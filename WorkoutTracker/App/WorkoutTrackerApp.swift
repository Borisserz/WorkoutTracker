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
    @StateObject private var viewModel = WorkoutViewModel()
    @StateObject private var tutorialManager = TutorialManager()
    
    // НОВЫЙ МЕНЕДЖЕР ТАЙМЕРА
    @StateObject private var timerManager = RestTimerManager()
    
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @AppStorage("appearanceMode") private var appearanceMode: String = "system"
    
    @State private var showImportAlert = false
    
    let sharedModelContainer: ModelContainer
    
    private var colorScheme: ColorScheme? {
        switch appearanceMode {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }
    
    init() {
        do {
            sharedModelContainer = try ModelContainer(for: Workout.self, WorkoutPreset.self, ExerciseNote.self)
        } catch {
            print("Could not create ModelContainer, attempting to delete corrupted database: \(error)")
            
            // Удаляем поврежденные файлы базы данных
            let fileManager = FileManager.default
            let storeURL = URL.applicationSupportDirectory.appending(path: "default.store")
            let shmURL = URL.applicationSupportDirectory.appending(path: "default.store-shm")
            let walURL = URL.applicationSupportDirectory.appending(path: "default.store-wal")
            
            try? fileManager.removeItem(at: storeURL)
            try? fileManager.removeItem(at: shmURL)
            try? fileManager.removeItem(at: walURL)
            
            do {
                // Пробуем создать чистую базу данных
                sharedModelContainer = try ModelContainer(for: Workout.self, WorkoutPreset.self, ExerciseNote.self)
            } catch {
                print("Failed to recreate ModelContainer, falling back to in-memory store: \(error)")
                // Запасной вариант (Fallback): база в оперативной памяти, чтобы избежать 100% крэшей
                let fallbackConfig = ModelConfiguration(isStoredInMemoryOnly: true)
                do {
                    sharedModelContainer = try ModelContainer(for: Workout.self, WorkoutPreset.self, ExerciseNote.self, configurations: fallbackConfig)
                } catch {
                    fatalError("Critical failure: Could not create even an in-memory ModelContainer: \(error)")
                }
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    ContentView()
                        .transition(.opacity)
                } else {
                    OnboardingFlowView(isOnboardingCompleted: $hasCompletedOnboarding)
                }
            }
            // ИСПРАВЛЕНИЕ: environmentObject должны быть ЗДЕСЬ, чтобы избежать крэша во время transition
            .environmentObject(viewModel)
            .environmentObject(tutorialManager)
            .environmentObject(timerManager)
            .onAppear {
                viewModel.checkAndGenerateDefaultPresets(context: sharedModelContainer.mainContext)
            }
            .onOpenURL { url in
                if viewModel.importPreset(from: url, context: sharedModelContainer.mainContext) {
                    showImportAlert = true
                }
            }
            .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { userActivity in
                if let url = userActivity.webpageURL {
                    if viewModel.importPreset(from: url, context: sharedModelContainer.mainContext) {
                        showImportAlert = true
                    }
                }
            }
            .alert(Text(LocalizedStringKey("Template Imported!")), isPresented: $showImportAlert) {
                Button(LocalizedStringKey("OK"), role: .cancel) { }
            } message: {
                Text(LocalizedStringKey("A new workout template has been added to your collection."))
            }
            .animation(.default, value: hasCompletedOnboarding)
            .preferredColorScheme(colorScheme)
            .onChange(of: scenePhase) { newPhase in
                if newPhase == .active {
                    UIApplication.shared.applicationIconBadgeNumber = 0
                    UNUserNotificationCenter.current().removeAllDeliveredNotifications()
                }
            }
        }
        .modelContainer(sharedModelContainer)
    }
}

