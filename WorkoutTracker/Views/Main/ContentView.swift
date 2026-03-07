//
//  ContentView.swift
//  WorkoutTracker
//

internal import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext // ДОБАВЛЕНО: Достаем контекст БД
    @EnvironmentObject var viewModel: WorkoutViewModel
    @EnvironmentObject var timerManager: RestTimerManager
    @EnvironmentObject var tutorialManager: TutorialManager
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
        .onAppear {
            // Передаем контекст БД в ViewModel при загрузке приложения
            viewModel.setContext(modelContext)
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
