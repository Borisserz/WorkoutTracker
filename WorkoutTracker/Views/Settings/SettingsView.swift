//
//  SettingsView.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 27.12.25.
//

internal import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var viewModel: WorkoutViewModel
    
    @AppStorage("streakRestDays") private var streakRestDays: Int = 2
    @AppStorage("defaultRestTime") private var defaultRestTime: Int = 60
    @AppStorage("autoStartTimer") private var autoStartTimer: Bool = true
    @State private var showTestDataAlert = false
    @State private var testDataAlertMessage = ""
    
    let restOptions = [30, 45, 60, 90, 120, 180, 300]
    
    var body: some View {
        NavigationStack {
            List {
                // Секция управления тренировками
                Section(header: Text("Workout Management")) {
                    NavigationLink(destination: PresetListView()) {
                        Label("Workout Templates", systemImage: "list.bullet.clipboard")
                            .tint(.blue) // <-- ИКОНКА СТАНЕТ СИНЕЙ
                    }
                }
                
                // Секция настроек таймера
                Section(header: Text("Rest Timer"), footer: Text("If enabled, the rest timer will start automatically when you check off a set.")) {
                                 
                                 // 1. Выбор времени
                                 HStack {
                                     Label("Default Timer", systemImage: "timer")
                                         .tint(.blue)
                                     Spacer()
                                     Picker("Time", selection: $defaultRestTime) {
                                         ForEach(restOptions, id: \.self) { seconds in
                                             if seconds < 60 {
                                                 Text("\(seconds) sec").tag(seconds)
                                             } else {
                                                 Text("\(seconds / 60) min").tag(seconds)
                                             }
                                         }
                                     }
                                     .pickerStyle(.menu)
                                     .tint(.blue)
                                 }
                                 
                                 // 2. Переключатель авто-старта
                                 Toggle(isOn: $autoStartTimer) {
                                     Label("Auto-start Timer", systemImage: "play.circle")
                                         .tint(.blue)
                                 }
                             }
                // Секция настроек стрика
                Section {
                    Stepper(value: $streakRestDays, in: 1...7) {
                        HStack {
                            Label("Max Rest Days", systemImage: "flame.fill")
                                .tint(.blue) // <-- ИКОНКА СТАНЕТ СИНЕЙ
                            Spacer()
                            Text("\(streakRestDays) day\(streakRestDays > 1 ? "s" : "")")
                                .foregroundColor(.blue) // <-- ТЕКСТ СТАНЕТ СИНИМ
                                .bold()
                        }
                    }
                    .tint(.blue) // <-- КНОПКИ "+" И "-" СТАНУТ СИНИМИ
                } header: {
                    Text("Streak Settings")
                } footer: {
                    Text("Your streak will reset if you don't train within this number of rest days.")
                }
                
                // Секция предпочтений (язык)
                Section(header: Text("Preferences")) {
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack {
                            Label("Language", systemImage: "globe")
                                .tint(.blue) // <-- ИКОНКА СТАНЕТ СИНЕЙ
                                .foregroundColor(.primary) // Оставляем текст черным
                            Spacer()
                            Text(Locale.current.language.languageCode?.identifier == "ru" ? "Русский" : "English")
                                .foregroundColor(.secondary)
                            Image(systemName: "arrow.up.forward.app")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                // ВРЕМЕННАЯ СЕКЦИЯ ДЛЯ ТЕСТИРОВАНИЯ - УДАЛИТЬ ПОСЛЕ ТЕСТОВ
                Section {
                    Button(role: .destructive) {
                        generateTestData()
                    } label: {
                        HStack {
                            Label("Generate 2 Years Test Data", systemImage: "flask.fill")
                                .tint(.orange)
                            Spacer()
                            Text("⚠️ TEST")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                    
                    Button(role: .destructive) {
                        clearAllWorkouts()
                    } label: {
                        HStack {
                            Label("Clear All Workouts", systemImage: "trash.fill")
                                .tint(.red)
                            Spacer()
                            Text("⚠️ DANGER")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                } header: {
                    Text("🧪 TESTING (REMOVE AFTER TEST)")
                } footer: {
                    Text("These buttons are for testing only. Remove TestDataGenerator.swift and this section after testing.")
                }
                
                // Секция "О программе"
                Section(header: Text("About")) {
                    Text("Version 1.0.0")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Test Data", isPresented: $showTestDataAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(testDataAlertMessage)
            }
        }
    }
    
    // MARK: - Test Data Functions
    
    private func generateTestData() {
        DispatchQueue.global(qos: .userInitiated).async {
            TestDataGenerator.generateAndSaveTestData()
            
            DispatchQueue.main.async {
                // Обновляем ViewModel
                viewModel.workouts = DataManager.shared.loadWorkouts()
                testDataAlertMessage = "✅ Test data generated successfully!\n\nCreated 2 years of workout history (3 workouts per week)."
                showTestDataAlert = true
            }
        }
    }
    
    private func clearAllWorkouts() {
        DataManager.shared.saveWorkouts([])
        viewModel.workouts = []
        testDataAlertMessage = "✅ All workouts cleared."
        showTestDataAlert = true
    }
}
