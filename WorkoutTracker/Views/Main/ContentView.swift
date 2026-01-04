internal import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: WorkoutViewModel
    @EnvironmentObject var tutorialManager: TutorialManager

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView {
                OverviewView()
                    .tabItem { Image(systemName: "chart.pie"); Text("Overview") }
                    // УБРАЛИ ПОДСВЕТКУ .spotlight(...) отсюда
                
                WorkoutView()
                    .tabItem { Image(systemName: "figure.run"); Text("Workout") }
                
                StatsView()
                    .tabItem { Image(systemName: "trophy"); Text("Progress") }
                    .spotlight(step: .progressTab, manager: tutorialManager, text: "Check your Progress", alignment: .bottom, xOffset: -20) // Сдвинул чуть левее
            }
            
            if viewModel.isRestTimerActive {
                RestTimerView()
                    .padding(.bottom, 60)
                    .transition(.move(edge: .bottom))
                    .zIndex(100)
            }
        }
    }
}
