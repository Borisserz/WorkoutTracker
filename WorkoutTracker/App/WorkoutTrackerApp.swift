//
//  WorkoutTrackerApp.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 24.12.25.
//

internal import SwiftUI


@main
struct WorkoutTrackerApp: App {
    // 1. Создаем объект-хранилище. Он живет пока жива программа.
    @StateObject private var viewModel = WorkoutViewModel()
    // Добавляем инициализатор для запроса прав
       init() {
           NotificationManager.shared.requestPermission()
       }
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .onAppear { // <--- ДОБАВЬТЕ ЭТОТ МОДИФИКАТОР
                    print("--- APP HAS APPEARED, CONSOLE IS WORKING ---")
                }
        }
    }
}
