
internal import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(DashboardViewModel.self) var dashboardViewModel
    @Environment(WorkoutService.self) var workoutService
    @Environment(RestTimerManager.self) var timerManager
    @Environment(TutorialManager.self) var tutorialManager
    
    @State private var selectedTab = 0
  
    var body: some View {
        // Создаем Bindable-обертку для глобального сервиса
        @Bindable var bindableWorkoutService = workoutService
        
        ZStack(alignment: .bottom) {
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
            
            if timerManager.isRestTimerActive && !timerManager.isHidden {
                RestTimerView()
                    .padding(.bottom, 60)
                    .transition(.move(edge: .bottom))
                    .zIndex(100)
            }
        }
        .onAppear {
            dashboardViewModel.refreshAllCaches()
        }
        // Выводим ошибки из сервиса
        .alert(item: $bindableWorkoutService.currentError) { error in
            Alert(
                title: Text(error.title),
                message: Text(error.message),
                dismissButton: .default(Text(LocalizedStringKey("OK")))
            )
        }
    }
}
