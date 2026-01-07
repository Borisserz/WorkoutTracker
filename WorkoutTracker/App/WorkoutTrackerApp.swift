//  WorkoutTrackerApp.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 24.12.25.
//

internal import SwiftUI
import UserNotifications
import UIKit

@main
struct WorkoutTrackerApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = WorkoutViewModel()
    @StateObject private var notesManager = ExerciseNotesManager.shared
    @StateObject private var tutorialManager = TutorialManager()    // Флаг: прошел ли пользователь анбординг?
    
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @AppStorage("appearanceMode") private var appearanceMode: String = "system"
    
    @State private var showImportAlert = false
    
    // Вычисляемое свойство для цветовой схемы
    private var colorScheme: ColorScheme? {
        switch appearanceMode {
        case "light":
            return .light
        case "dark":
            return .dark
        default:
            return nil // nil означает системная тема
        }
    }
    
    init() {

    }

    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    // Основное приложение
                    ContentView()
                        .environmentObject(viewModel)
                        .environmentObject(notesManager)
                        .environmentObject(tutorialManager) // <-- Передаем вниз
                        .transition(.opacity) // Плавное появление
                } else {
                    // Анбординг
                    OnboardingFlowView(isOnboardingCompleted: $hasCompletedOnboarding)
                        .environmentObject(tutorialManager) 
                }
            }
            // --- ЛОВИМ ССЫЛКУ ИЛИ ФАЙЛ ---
            .onOpenURL { url in
                if viewModel.importPreset(from: url) {
                    showImportAlert = true
                }
            }
            // Обработка открытия файлов через систему
            .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { userActivity in
                if let url = userActivity.webpageURL {
                    if viewModel.importPreset(from: url) {
                        showImportAlert = true
                    }
                }
            }
            // Алерт для пользователя
            .alert(Text(LocalizedStringKey("Template Imported! 🎉")), isPresented: $showImportAlert) {
                Button(LocalizedStringKey("OK"), role: .cancel) { }
            } message: {
                Text(LocalizedStringKey("A new workout template has been added to your collection."))
            }
            // Анимация смены рутового экрана
            .animation(.default, value: hasCompletedOnboarding)
            // Применяем выбранную тему
            .preferredColorScheme(colorScheme)
            // Сбрасываем бейдж и очищаем доставленные уведомления при входе в приложение
            .onChange(of: scenePhase) { newPhase in
                if newPhase == .active {
                    UIApplication.shared.applicationIconBadgeNumber = 0
                    UNUserNotificationCenter.current().removeAllDeliveredNotifications()
                }
            }
        }
    }
}
