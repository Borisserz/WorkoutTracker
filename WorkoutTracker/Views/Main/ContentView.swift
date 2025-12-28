internal import SwiftUI


struct ContentView: View {
    // Нам нужен доступ к ViewModel, чтобы знать, показывать таймер или нет
    @EnvironmentObject var viewModel: WorkoutViewModel

    var body: some View {
        // Оборачиваем TabView в ZStack
        ZStack(alignment: .bottom) {
            
            TabView {
                // 1. Главная
                OverviewView()
                    .tabItem {
                        Image(systemName: "chart.pie")
                        Text("Overview")
                    }
                
                // 2. Тренировка
                WorkoutView()
                    .tabItem {
                        Image(systemName: "figure.run")
                        Text("Workout")
                    }
                    
                // 3. Каталог
                ExerciseView()
                    .tabItem {
                        Image(systemName: "list.bullet")
                        Text("Exercises")
                    }
                
                // 4. Прогресс
                StatsView()
                    .tabItem {
                        Image(systemName: "trophy")
                        Text("Progress")
                    }
            }
            
            // --- ГЛОБАЛЬНЫЙ ТАЙМЕР ---
            // Он теперь живет здесь, поверх всех табов
            if viewModel.isRestTimerActive {
                RestTimerView()
                    .padding(.bottom, 60) // Поднимаем чуть выше TabBar'а
                    .transition(.move(edge: .bottom))
                    .zIndex(100) // Гарантируем, что он сверху всего
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(WorkoutViewModel())
}
