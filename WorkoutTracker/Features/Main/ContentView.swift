internal import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(DashboardViewModel.self) var dashboardViewModel
    @Environment(TutorialManager.self) var tutorialManager
    @Environment(DIContainer.self) private var di
    
    var body: some View {
        @Bindable var appState = di.appState
        
        ZStack {
            // 1. Основной UI со стандартным системным TabView
            TabView(selection: $appState.selectedTab) {
                OverviewView()
                    .tabItem {
                        Image(systemName: "chart.pie")
                        Text(LocalizedStringKey("Overview"))
                    }
                    .tag(0)
                
                HistoryView()
                    .tabItem {
                        Image(systemName: "clock.arrow.circlepath")
                        Text(LocalizedStringKey("History"))
                    }
                    .tag(1)
                
                WorkoutHubView()
                    .tabItem {
                        Image(systemName: "plus.circle.fill")
                        Text(LocalizedStringKey("Workout"))
                    }
                    .tag(2)
                
                AICoachView()
                    .tabItem {
                        Image(systemName: "brain.head.profile")
                        Text(LocalizedStringKey("AI Coach"))
                    }
                    .tag(3)
                
                StatsView()
                    .tabItem {
                        Image(systemName: "trophy")
                        Text(LocalizedStringKey("Progress"))
                    }
                    .tag(4)
            }
            // Форсируем темную тему для таб-бара, чтобы он подходил к дизайну
            .preferredColorScheme(.dark)
            .zIndex(1)
            
            // 2. Глобальные оверлеи (Таймер отдыха и плашка активной тренировки)
            VStack {
                Spacer() // Прижимает контент к низу
                
                ActiveWorkoutBannerContainer()
                
                TimerOverlayContainer()
            }
            .padding(.bottom, 50) // Идеальный отступ над системным TabBar
            .ignoresSafeArea(.keyboard, edges: .bottom) // Позволяет таймеру подняться над клавиатурой
            .zIndex(100) // Оверлеи всегда сверху
        }
        .onAppear {
            dashboardViewModel.refreshAllCaches()
            NotificationManager.shared.requestPermission()
        }
        .alert(item: $appState.currentError) { error in
            Alert(
                title: Text(error.title),
                message: Text(error.message),
                dismissButton: .default(Text(LocalizedStringKey("OK"))) {
                    appState.clearError()
                }
            )
        }
    }
    
    struct TimerOverlayContainer: View {
        @Environment(RestTimerManager.self) var timerManager
        var body: some View {
            if timerManager.isRestTimerActive && !timerManager.isHidden {
                RestTimerView()
            }
        }
    }
}
