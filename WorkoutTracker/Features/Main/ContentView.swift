internal import SwiftUI
import SwiftData
import UIKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(DashboardViewModel.self) var dashboardViewModel
    @Environment(TutorialManager.self) var tutorialManager
    @Environment(DIContainer.self) private var di
    @Environment(\.scenePhase) private var scenePhase

    init() {
        configureTabBarAppearance()
    }

    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        // Deep cashmere dark blur
        appearance.backgroundColor = UIColor(red: 0.055, green: 0.059, blue: 0.071, alpha: 0.92)
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        appearance.shadowColor = UIColor(white: 1.0, alpha: 0.08)

        let itemAppearance = UITabBarItemAppearance()
        // Selected Tab (Warm Oat / Champagne)
        let selectedColor = UIColor(red: 0.937, green: 0.890, blue: 0.827, alpha: 1.0)
        itemAppearance.selected.iconColor = selectedColor
        itemAppearance.selected.titleTextAttributes = [
            .foregroundColor: selectedColor,
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold)
        ]

        // Normal (Unselected) Tab (Refined Slate / Neutral)
        let unselectedColor = UIColor(red: 0.50, green: 0.51, blue: 0.55, alpha: 0.85)
        itemAppearance.normal.iconColor = unselectedColor
        itemAppearance.normal.titleTextAttributes = [
            .foregroundColor: unselectedColor,
            .font: UIFont.systemFont(ofSize: 10, weight: .medium)
        ]

        appearance.stackedLayoutAppearance = itemAppearance
        appearance.inlineLayoutAppearance = itemAppearance
        appearance.compactInlineLayoutAppearance = itemAppearance

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        @Bindable var appState = di.appState

        ZStack {
            TabView(selection: $appState.selectedTab) {
                OverviewView()
                    .tabItem {
                        Image(systemName: "chart.pie.fill")
                        Text(LocalizedStringKey("Overview"))
                    }
                    .tag(0)

                HistoryView()
                    .tabItem {
                        Image(systemName: "clock.arrow.circlepath")
                        Text(LocalizedStringKey("History"))
                    }
                    .tag(1)

                WorkoutHubView()
                    .tabItem {
                        Image(systemName: "plus.circle.fill")
                        Text(LocalizedStringKey("Workout"))
                    }
                    .tag(2)

                AICoachView()
                    .tabItem {
                        Image(systemName: "sparkles")
                        Text(LocalizedStringKey("AI Hub"))
                    }
                    .tag(3)

                StatsView()
                    .tabItem {
                        Image(systemName: "trophy.fill")
                        Text(LocalizedStringKey("Progress"))
                    }
                    .tag(4)
            }
            .tint(PastelTheme.pastelOat)
            .preferredColorScheme(.dark)
            .zIndex(1)

            if appState.selectedTab != 2 {
                VStack {
                    Spacer() 

                    ActiveWorkoutBannerContainer()
                }
                .padding(.bottom, 56) 
                .ignoresSafeArea(.keyboard, edges: .bottom) 
                .zIndex(100)
            }

            TimerOverlayContainer()
                .zIndex(200) 
        }
        .onAppear {
            dashboardViewModel.refreshAllCaches()
            NotificationManager.shared.requestPermission()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                dashboardViewModel.refreshAllCaches()
            }
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
        .sheet(isPresented: $appState.showGuestSignUpPrompt) {
            GuestSignUpPromptView()
        }
    }

    struct TimerOverlayContainer: View {
        @Environment(RestTimerManager.self) var timerManager
        var body: some View {
            if timerManager.isRestTimerActive && !timerManager.isHidden {
                RestTimerView()
            }
        }
    }
}
