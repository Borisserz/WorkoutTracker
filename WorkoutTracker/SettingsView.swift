//
//  SettingsView.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 27.12.25.
//

internal import SwiftUI

// В SettingsView.swift

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink(destination: PresetListView()) {
                        Label("Workout Templates", systemImage: "list.bullet.clipboard")
                    }
                } header: {
                    Text("Workout Management")
                }
                
                // --- НОВАЯ СЕКЦИЯ ЯЗЫКА ---
                Section {
                    Button {
                        // Эта команда открывает настройки именно ТВОЕГО приложения в iOS
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack {
                            Label("Language", systemImage: "globe")
                                .foregroundColor(.primary)
                            Spacer()
                            // Показываем текущий язык
                            Text(Locale.current.language.languageCode?.identifier == "ru" ? "Русский" : "English")
                                .foregroundColor(.secondary)
                            Image(systemName: "arrow.up.forward.app")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                } header: {
                    Text("Preferences")
                }
                // ---------------------------
                
                Section {
                    Text("Version 1.0.0")
                        .foregroundColor(.secondary)
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
