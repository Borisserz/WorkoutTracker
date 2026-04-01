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
    @StateObject private var viewModel = WorkoutViewModel()
    @StateObject private var tutorialManager = TutorialManager()
    
    // НОВЫЙ МЕНЕДЖЕР ТАЙМЕРА
    @StateObject private var timerManager = RestTimerManager()
    
    // ИСПРАВЛЕНИЕ: Менеджер единиц измерения. Создаем его 1 раз на уровне приложения
    @StateObject private var unitsManager = UnitsManager.shared
    
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @AppStorage("appearanceMode") private var appearanceMode: String = "system"
    
    @State private var showImportAlert = false
    
    let sharedModelContainer: ModelContainer?
    let databaseLoadError: Error?
    
    private var colorScheme: ColorScheme? {
        switch appearanceMode {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }
    
    init() {
        do {
            // ИСПРАВЛЕНИЕ: Добавлен BodyMeasurement в контейнер данных
            sharedModelContainer = try ModelContainer(for: Workout.self, WorkoutPreset.self, ExerciseNote.self, UserStats.self, ExerciseStat.self, MuscleStat.self, WeightEntry.self, MuscleColorPreference.self, AIChatSession.self, BodyMeasurement.self)
            databaseLoadError = nil
        } catch {
            print("Could not create ModelContainer: \(error)")
            // Оставляем контейнер пустым и сохраняем ошибку, чтобы показать её в UI.
            // Ни в коем случае не удаляем и не подменяем файлы базы данных.
            sharedModelContainer = nil
            databaseLoadError = error
        }
    }

    var body: some Scene {
        WindowGroup {
            if let container = sharedModelContainer {
                Group {
                    if hasCompletedOnboarding {
                        ContentView()
                            .transition(.opacity)
                    } else {
                        OnboardingFlowView(isOnboardingCompleted: $hasCompletedOnboarding)
                    }
                }
                .environmentObject(viewModel)
                .environmentObject(tutorialManager)
                .environmentObject(timerManager)
                .environmentObject(unitsManager)
                .onAppear {
                    // ОПТИМИЗАЦИЯ SWIFT 6: Оборачиваем в Task для безопасной инициализации
                    Task {
                        // 1. ЗАПУСКАЕМ МИГРАЦИЮ СТАРЫХ ДАННЫХ (MainActor, так как метод требует этого)
                        await MainActor.run {
                            LegacyDataMigrator.migrateAllIfNeeded(context: container.mainContext)
                        }
                        
                        // ИЗМЕНЕНО: Инъекция ModelContainer в ViewModel
                        await MainActor.run {
                            viewModel.modelContainer = container
                            
                            // ИЗМЕНЕНО: viewModel теперь знает о контейнере, параметр не нужен
                            viewModel.checkAndGenerateDefaultPresets()
                            
                            // 2. ЗАГРУЖАЕМ ЦВЕТА ИЗ SWIFTDATA В ПАМЯТЬ
                            MuscleColorManager.shared.load(context: container.mainContext)
                        }
                        
                        // 3. ПРОГРЕВ КЭША SVG (Выполняем на MainActor, но асинхронно, с паузами, чтобы не фризить UI)
                        // Так как Path должен создаваться на MainActor.
                        let allMuscles = BodyData.frontMuscles + BodyData.backMuscles + BodyData.frontMusclesFemale + BodyData.backMusclesFemale
                        for muscle in allMuscles {
                            for pathStr in muscle.paths {
                                await MainActor.run {
                                    _ = SVGParser.path(from: pathStr) // Кэшируем
                                }
                                // Небольшая пауза, чтобы дать UI возможность перерисоваться (избегаем фризов)
                                try? await Task.sleep(nanoseconds: 1_000_000)
                            }
                        }
                    }
                }
                .onOpenURL { url in
                    // ИЗМЕНЕНО: viewModel теперь знает о контейнере, параметр не нужен
                    if viewModel.importPreset(from: url) {
                        showImportAlert = true
                    }
                }
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { userActivity in
                    if let url = userActivity.webpageURL {
                        // ИЗМЕНЕНО: viewModel теперь знает о контейнере, параметр не нужен
                        if viewModel.importPreset(from: url) {
                            showImportAlert = true
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
                        // ОПТИМИЗАЦИЯ SWIFT 6: Использование нового API для бейджей
                        UNUserNotificationCenter.current().setBadgeCount(0)
                        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
                    }
                }
                .modelContainer(container)
            } else {
                // Если база данных не загрузилась, показываем заглушку с ошибкой
                DatabaseErrorView(error: databaseLoadError)
                    .preferredColorScheme(colorScheme)
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
