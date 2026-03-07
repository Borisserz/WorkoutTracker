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
            // ИСПРАВЛЕНИЕ: Вместо fatalError лучше удалять поврежденную базу в случае фатального сбоя миграции,
            // но для простоты оставим как есть, однако в проде fatalError нежелателен.
            fatalError("Could not create ModelContainer: \(error)")
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

