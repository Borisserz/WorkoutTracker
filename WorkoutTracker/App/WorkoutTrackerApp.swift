//
//  WorkoutTrackerApp.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 24.12.25.
//

internal import SwiftUI


@main
struct WorkoutTrackerApp: App {
    // 1. Создаем ViewModel для тренировок
     @StateObject private var viewModel = WorkoutViewModel()
     
     // 2. !!! СОЗДАЕМ МЕНЕДЖЕР ЗАМЕТОК !!!
     @StateObject private var notesManager = ExerciseNotesManager.shared
       init() {
           NotificationManager.shared.requestPermission()
       }
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .environmentObject(notesManager) 
                .onAppear { // <--- ДОБАВЬТЕ ЭТОТ МОДИФИКАТОР
                    print("--- APP HAS APPEARED, CONSOLE IS WORKING ---")
                }
        }
    }
}
