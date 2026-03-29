//
//  ContentView.swift
//  WorkoutTracker
//

internal import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    
    @EnvironmentObject var viewModel: WorkoutViewModel
    @EnvironmentObject var timerManager: RestTimerManager
    @EnvironmentObject var tutorialManager: TutorialManager
    
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
                
                AICoachView()
                    .tabItem { Image(systemName: "brain.head.profile"); Text(LocalizedStringKey("AI Coach")) }
                    .tag(2)
                
                StatsView()
                    .tabItem { Image(systemName: "trophy"); Text(LocalizedStringKey("Progress")) }
                    .tag(3)
                    .spotlight(step: .progressTab, manager: tutorialManager, text: "Check your Progress", alignment: .bottom, xOffset: -20)
            }
            
            // ИСПРАВЛЕНИЕ: Скрываем таймер, если установлен флаг isHidden
            if timerManager.isRestTimerActive && !timerManager.isHidden {
                RestTimerView()
                    .padding(.bottom, 60)
                    .transition(.move(edge: .bottom))
                    .zIndex(100)
            }
        }
        .onAppear {
            viewModel.refreshAllCaches(container: modelContext.container)
            fetchAvailableGeminiModels()
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

func fetchAvailableGeminiModels() {
    let apiKey = Secrets.geminiApiKey
    let urlString = "https://generativelanguage.googleapis.com/v1beta/models?key=\(apiKey)"
    guard let url = URL(string: urlString) else { return }
    Task {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let jsonString = String(data: data, encoding: .utf8) {
                print("=== 🚀 ДОСТУПНЫЕ МОДЕЛИ GOOGLE ===")
                print(jsonString)
                print("==================================")
            }
        } catch {
            print("❌ Ошибка сети: \(error)")
        }
    }
}
