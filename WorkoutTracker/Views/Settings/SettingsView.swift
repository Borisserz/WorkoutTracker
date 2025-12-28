//
//  SettingsView.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 27.12.25.
//

internal import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    
    @AppStorage("streakRestDays") private var streakRestDays: Int = 2
    @AppStorage("defaultRestTime") private var defaultRestTime: Int = 60
    
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
                Section(header: Text("Rest Timer")) {
                    HStack {
                        Label("Default Timer", systemImage: "timer")
                            .tint(.blue) // <-- ИКОНКА СТАНЕТ СИНЕЙ
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
                        .tint(.blue) // <-- СТРЕЛОЧКА PICKER'А СТАНЕТ СИНЕЙ
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
        }
    }
}
