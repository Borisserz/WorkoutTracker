import SwiftUI

// MARK: - 1. Главная навигация
struct WorkoutTrackerUI: View {
   @State private var selectedTab = 0
   
   init() {
       let appearance = UITabBarAppearance()
       appearance.configureWithTransparentBackground()
       appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
       appearance.backgroundColor = UIColor(Color.premiumBackground.opacity(0.8))
       UITabBar.appearance().standardAppearance = appearance
       UITabBar.appearance().scrollEdgeAppearance = appearance
   }
 
   var body: some View {
       TabView(selection: $selectedTab) {
           OverviewTab()
               .tabItem { Label("Обзор", systemImage: "magnifyingglass") }.tag(0)
           
           Text("История").foregroundStyle(.white)
               .tabItem { Label("История", systemImage: "clock.arrow.circlepath") }.tag(1)
           
           WorkoutView()
               .tabItem { Label("Тренировка", systemImage: "figure.run") }.tag(2)
           
           Text("Прогресс").foregroundStyle(.white)
               .tabItem { Label("Прогресс", systemImage: "chart.xyaxis.line") }.tag(4)
       }
       .tint(Color.neonBlue)
   }
}
