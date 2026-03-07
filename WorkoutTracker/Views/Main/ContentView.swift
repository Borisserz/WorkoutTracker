//
//  ContentView.swift
//  WorkoutTracker
//

internal import SwiftUI
import SwiftData

struct ContentView: View {
    @EnvironmentObject var viewModel: WorkoutViewModel
    @EnvironmentObject var timerManager: RestTimerManager
    @EnvironmentObject var tutorialManager: TutorialManager
    
    // Загружаем тренировки, чтобы кэшировать перфоманс и рекавери
    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]
    
    @State private var selectedTab = 1 // Начинаем с вкладки тренировок (Workout)

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
        .onChange(of: workouts) { oldValue, newValue in
            // Глобально обновляем кеши при изменении БД
            viewModel.updatePerformanceCaches(workouts: newValue, oldWorkouts: oldValue)
            viewModel.calculateRecovery(workouts: newValue)
        }
        .onAppear {
            // При первом запуске загружаем кеши
            viewModel.updatePerformanceCaches(workouts: workouts)
            viewModel.calculateRecovery(workouts: workouts)
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
