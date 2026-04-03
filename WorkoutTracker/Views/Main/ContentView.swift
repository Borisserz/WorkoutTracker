// ============================================================
// FILE: WorkoutTracker/Views/Main/ContentView.swift
// ============================================================

internal import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(DashboardViewModel.self) var dashboardViewModel
    @Environment(TutorialManager.self) var tutorialManager
    
    // ✅ ВНЕДРЯЕМ DI-КОНТЕЙНЕР
    @Environment(DIContainer.self) private var di
    
    @State private var selectedTab = 0
  
    var body: some View {
        @Bindable var appState = di.appState
        
        ZStack(alignment: .bottom) {
            // ✅ ИСПРАВЛЕНИЕ: TabView больше не зависит от timerManager.
            // Он перерисовывается ТОЛЬКО при смене вкладки или глобальных данных.
            TabView(selection: $selectedTab) {
                OverviewView()
                    .tabItem { Image(systemName: "chart.pie"); Text(LocalizedStringKey("Overview")) }
                    .tag(0)
                
                WorkoutView()
                    .tabItem { Image(systemName: "figure.run"); Text(LocalizedStringKey("Workout")) }
                    .tag(1)
                
                AICoachView()
                    .tabItem { Image(systemName: "brain.head.profile"); Text(LocalizedStringKey("AI Coach")) }
                    .tag(2)
                
                StatsView()
                    .tabItem { Image(systemName: "trophy"); Text(LocalizedStringKey("Progress")) }
                    .tag(3)
                    .spotlight(step: .progressTab, manager: tutorialManager, text: "Check your Progress", alignment: .bottom, xOffset: -20)
            }
            
            // ✅ ИСПРАВЛЕНИЕ: Изолированная обертка таймера.
            // Она сама подписывается на timerManager, не заражая ContentView.
            TimerOverlayContainer()
        }
        .onAppear {
            dashboardViewModel.refreshAllCaches()
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
}

// ✅ НОВЫЙ КОМПОНЕНТ: Берет на себя зависимость от таймера.
// ContentView больше не обновляется 10 раз в секунду.
struct TimerOverlayContainer: View {
    @Environment(RestTimerManager.self) var timerManager
    
    var body: some View {
        if timerManager.isRestTimerActive && !timerManager.isHidden {
            RestTimerView()
                .padding(.bottom, 60)
                .transition(.move(edge: .bottom))
                .zIndex(100)
        }
    }
}
