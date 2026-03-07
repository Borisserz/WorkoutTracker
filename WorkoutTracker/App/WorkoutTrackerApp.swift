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
    @StateObject private var tutorialManager = TutorialManager()    // прошел ли пользователь анбординг?
    
    // НОВЫЙ МЕНЕДЖЕР ТАЙМЕРА
    @StateObject private var timerManager = RestTimerManager()
    
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @AppStorage("appearanceMode") private var appearanceMode: String = "system"
    
    @State private var showImportAlert = false
    
    // Создаем контейнер вручную, чтобы иметь доступ к context прямо в App
    let sharedModelContainer: ModelContainer
    
    // Вычисляемое свойство для цветовой схемы
    private var colorScheme: ColorScheme? {
        switch appearanceMode {
        case "light":
            return .light
        case "dark":
            return .dark
        default:
            return nil
        }
    }
    
    init() {
        // Инициализируем SwiftData
        do {
            sharedModelContainer = try ModelContainer(for: Workout.self, WorkoutPreset.self, ExerciseNote.self)
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
        
        // Проверяем и создаем дефолтные шаблоны при первом запуске
        viewModel.checkAndGenerateDefaultPresets(context: sharedModelContainer.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    // Основное приложение
                    ContentView()
                        .environmentObject(viewModel)
                        .environmentObject(tutorialManager)
                        .environmentObject(timerManager) // <-- ПЕРЕДАЕМ В ОКРУЖЕНИЕ
                        .transition(.opacity)
                } else {
                    // Анбординг
                    OnboardingFlowView(isOnboardingCompleted: $hasCompletedOnboarding)
                        .environmentObject(tutorialManager) 
                }
            }
            .onOpenURL { url in
                // Передаем контекст в метод импорта
                if viewModel.importPreset(from: url, context: sharedModelContainer.mainContext) {
                    showImportAlert = true
                }
            }
            // Обработка открытия файлов через систему
            .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { userActivity in
                if let url = userActivity.webpageURL {
                    if viewModel.importPreset(from: url, context: sharedModelContainer.mainContext) {
                        showImportAlert = true
                    }
                }
            }
            // Алерт для пользователя
            .alert(Text(LocalizedStringKey("Template Imported!")), isPresented: $showImportAlert) {
                Button(LocalizedStringKey("OK"), role: .cancel) { }
            } message: {
                Text(LocalizedStringKey("A new workout template has been added to your collection."))
            }
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
        // Подключаем наш созданный контейнер
        .modelContainer(sharedModelContainer)
    }
}
