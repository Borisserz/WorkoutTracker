internal import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: WorkoutViewModel
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
                    .spotlight(step: .progressTab, manager: tutorialManager, text: "Check your Progress", alignment: .bottom, xOffset: -20) // Сдвинул чуть левее
            }
            
            if viewModel.isRestTimerActive {
                RestTimerView()
                    .padding(.bottom, 60)
                    .transition(.move(edge: .bottom))
                    .zIndex(100)
            }
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
