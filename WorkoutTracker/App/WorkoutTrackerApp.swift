//  WorkoutTrackerApp.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 24.12.25.
//

internal import SwiftUI

@main
struct WorkoutTrackerApp: App {
    @StateObject private var viewModel = WorkoutViewModel()
    @StateObject private var notesManager = ExerciseNotesManager.shared
    @StateObject private var tutorialManager = TutorialManager()    // Флаг: прошел ли пользователь анбординг?
    
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    
    @State private var showImportAlert = false
    
    init() {
       // УДАЛИЛИ: NotificationManager.shared.requestPermission()
       // Теперь мы запрашиваем это вежливо на 3-м шаге анбординга
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
                print("🔗 Received URL: \(url)")
                if viewModel.importPreset(from: url) {
                    showImportAlert = true
                }
            }
            // Обработка открытия файлов через систему
            .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { userActivity in
                if let url = userActivity.webpageURL {
                    print("🌐 Received web URL: \(url)")
                    if viewModel.importPreset(from: url) {
                        showImportAlert = true
                    }
                }
            }
            // Алерт для пользователя
            .alert("Template Imported! 🎉", isPresented: $showImportAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("A new workout template has been added to your collection.")
            }
            // Анимация смены рутового экрана
            .animation(.default, value: hasCompletedOnboarding)
        }
    }
}
