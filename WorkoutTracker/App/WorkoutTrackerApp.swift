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
    
    // 🚩 ИСПРАВЛЕНИЕ: Менеджер единиц измерения. Создаем его 1 раз на уровне приложения
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
            // ИСПРАВЛЕНИЕ: Добавлены WeightEntry и MuscleColorPreference в единый контейнер данных
            sharedModelContainer = try ModelContainer(for: Workout.self, WorkoutPreset.self, ExerciseNote.self, UserStats.self, ExerciseStat.self, MuscleStat.self, WeightEntry.self, MuscleColorPreference.self, AIChatSession.self)
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
                    // 1. ЗАПУСКАЕМ МИГРАЦИЮ СТАРЫХ ДАННЫХ
                    LegacyDataMigrator.migrateAllIfNeeded(context: container.mainContext)
                    
                    // ИСПРАВЛЕНИЕ: Передаем container напрямую
                    viewModel.checkAndGenerateDefaultPresets(container: container)
                    
                    // 2. ЗАГРУЖАЕМ ЦВЕТА ИЗ SWIFTDATA В ПАМЯТЬ
                    MuscleColorManager.shared.load(context: container.mainContext)
                    
                    // 3. ПРОГРЕВ КЭША SVG В ФОНЕ (Оптимизация CPU на старте)
                    // Тяжелые регулярные выражения отработают в фоновом потоке,
                    // спасая Main Thread от фризов при первой отрисовке BodyHeatmapView
                    Task.detached(priority: .high) {
                        let allMuscles = BodyData.frontMuscles + BodyData.backMuscles + BodyData.frontMusclesFemale + BodyData.backMusclesFemale
                        for muscle in allMuscles {
                            for pathStr in muscle.paths {
                                _ = SVGParser.path(from: pathStr) // Кэшируем
                            }
                        }
                    }
                }
                .onOpenURL { url in
                    // ИСПРАВЛЕНИЕ: Передаем container напрямую
                    if viewModel.importPreset(from: url, container: container) {
                        showImportAlert = true
                    }
                }
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { userActivity in
                    if let url = userActivity.webpageURL {
                        // ИСПРАВЛЕНИЕ: Передаем container напрямую
                        if viewModel.importPreset(from: url, container: container) {
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
                .onChange(of: scenePhase) { newPhase in
                    if newPhase == .active {
                        UIApplication.shared.applicationIconBadgeNumber = 0
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
