internal import SwiftUI
import SwiftData
import UserNotifications

@main
struct WorkoutTrackerApp: App {
    @Environment(\.scenePhase) private var scenePhase
    
    // 1. DI-контейнер теперь опциональный и инициализируется асинхронно
    @State private var diContainer: DIContainer?
    @State private var databaseLoadError: Error?
    
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @AppStorage("appearanceMode") private var appearanceMode: String = "system"
    @State private var showImportAlert = false
    
    // 2. Глобальные менеджеры (оставляем только легковесные State)
    @State private var restTimerManager = RestTimerManager()
    @State private var tutorialManager = TutorialManager()
    
    private var colorScheme: ColorScheme? {
        switch appearanceMode {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if let error = databaseLoadError {
                    DatabaseErrorView(error: error)
                        .preferredColorScheme(colorScheme)
                } else if let di = diContainer {
                    // 3. Запускаем основной контент ТОЛЬКО когда БД готова
                    mainContent(di: di)
                } else {
                    // Экран загрузки (Splash Screen) во время инициализации БД
                    ProgressView("Инициализация...")
                        .controlSize(.large)
                        .preferredColorScheme(colorScheme)
                }
            }
            .task {
                await setupDependencies()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    UNUserNotificationCenter.current().setBadgeCount(0)
                    UNUserNotificationCenter.current().removeAllDeliveredNotifications()
                }
            }
        }
    }
    
    @ViewBuilder
    private func mainContent(di: DIContainer) -> some View {
        Group {
            if hasCompletedOnboarding {
                ContentView()
                    .transition(.opacity)
            } else {
                OnboardingFlowView(isOnboardingCompleted: $hasCompletedOnboarding)
            }
        }
        .animation(.default, value: hasCompletedOnboarding)
        .modelContainer(di.modelContainer)
        .environment(di)
        .environment(di.workoutService)
        .environment(di.presetService)
        // ВАЖНО: Вьюмодели передаются только туда, где они реально нужны, или создаются локально
        .environment(restTimerManager)
        .environment(tutorialManager)
        .environment(UnitsManager.shared)
        .preferredColorScheme(colorScheme)
        // Обработчики URL оставляем здесь
        .onOpenURL { url in
            Task {
                if await di.presetService.importPreset(from: url) {
                    await MainActor.run { showImportAlert = true }
                }
            }
        }
        .alert("Template Imported!", isPresented: $showImportAlert) {
            Button("OK", role: .cancel) { }
        }
    }
    
    @MainActor
    private func setupDependencies() async {
        do {
            let container = try ModelContainer(for: Workout.self, WorkoutPreset.self, ExerciseNote.self, UserStats.self, ExerciseStat.self, MuscleStat.self, WeightEntry.self, MuscleColorPreference.self, AIChatSession.self, BodyMeasurement.self, ExerciseDictionaryItem.self)
            
            let di = DIContainer(modelContainer: container)
            
            // Фоновые миграции
            let migrator = LegacyDataMigrator(modelContainer: container)
            await migrator.migrateAllIfNeeded()
            try? await di.exerciseCatalogService.checkAndGenerateDefaultPresets()
            MuscleColorManager.shared.initialize(modelContainer: container)
            
            self.diContainer = di
        } catch {
            self.databaseLoadError = error
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
