//
//  ContentView.swift
//  WorkoutTracker
//

internal import SwiftUI
import SwiftData

struct ContentView: View {
    // ДОБАВЛЕНО: Получаем доступ к контексту для передачи контейнера в фон
    @Environment(\.modelContext) private var modelContext 
    
    @EnvironmentObject var viewModel: WorkoutViewModel
    @EnvironmentObject var timerManager: RestTimerManager
    @EnvironmentObject var tutorialManager: TutorialManager
    
    // УДАЛЕН: @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]
    // Нам больше не нужно загружать все тренировки в UI-поток!
    
    // ИЗМЕНЕНО: Начинаем с вкладки Overview (0) вместо тренировок (1)
    @State private var selectedTab = 0 

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                OverviewView()
                    .tabItem { Image(systemName: "chart.pie"); Text(LocalizedStringKey("Overview")) }
                    .tag(0)
                
                WorkoutView()
                    .tabItem { Image(systemName: "figure.run"); Text(LocalizedStringKey("Workout")) }
                    .tag(1)
                
                StatsView()
                    .tabItem { Image(systemName: "trophy"); Text(LocalizedStringKey("Progress")) }
                    .tag(2)
                    .spotlight(step: .progressTab, manager: tutorialManager, text: "Check your Progress", alignment: .bottom, xOffset: -20)
            }
            
            if timerManager.isRestTimerActive {
                RestTimerView()
                    .padding(.bottom, 60)
                    .transition(.move(edge: .bottom))
                    .zIndex(100)
            }
        }
        // ДОБАВЛЕНО: Инициализируем кеши при запуске в фоне
        .onAppear {
            viewModel.refreshAllCaches(container: modelContext.container)
        }
        .alert(item: $viewModel.currentError) { error in
            Alert(
                title: Text(error.title),
                message: Text(error.message),
                dismissButton: .default(Text(LocalizedStringKey("OK")))
            )
        }
    }
}
