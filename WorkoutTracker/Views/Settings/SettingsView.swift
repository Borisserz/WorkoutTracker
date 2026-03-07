//
//  SettingsView.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 27.12.25.
//

internal import SwiftUI
internal import UniformTypeIdentifiers
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var viewModel: WorkoutViewModel
    
    // Постепенный отказ от ViewModel: используем @Query для прямой работы с данными
    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]
    
    @AppStorage("streakRestDays") private var streakRestDays: Int = 2
    @AppStorage("defaultRestTime") private var defaultRestTime: Int = 60
    @AppStorage("autoStartTimer") private var autoStartTimer: Bool = true
    @AppStorage("appearanceMode") private var appearanceMode: String = "system" // "light", "dark", "system"
    @StateObject private var unitsManager = UnitsManager.shared
    
    @State private var isProcessing = false
    @State private var showTestDataAlert = false
    @State private var testDataAlertMessage = ""
    @State private var showClearAllAlert = false
    @State private var fileToShare: URL?
    @State private var showExportFormatPicker = false
    @State private var showBackupsList = false
    @State private var showRestoreConfirmation = false
    @State private var showImportBackupPicker = false
    @State private var isBackupSectionExpanded = false
    
    let restOptions = [30, 45, 60, 90, 120, 180, 300]
    
    var body: some View {
        NavigationStack {
            List {
                // Секция управления тренировками
                Section(header: Text(LocalizedStringKey("Workout Management"))) {
                    NavigationLink(destination: PresetListView()) {
                        Label(LocalizedStringKey("Workout Templates"), systemImage: "list.bullet.clipboard")
                    }
                }
                
                // Секция настроек таймера
                Section(header: Text(LocalizedStringKey("Rest Timer")), footer: Text(LocalizedStringKey("If enabled, the rest timer will start automatically when you check off a set."))) {
                                 
                                 // 1. Выбор времени
                                 HStack {
                                     Label(LocalizedStringKey("Default"), systemImage: "timer")
                                     Spacer()
                                     Picker(LocalizedStringKey("Time"), selection: $defaultRestTime) {
                                         ForEach(restOptions, id: \.self) { seconds in
                                             if seconds < 60 {
                                                 Text(LocalizedStringKey("\(seconds) sec")).tag(seconds)
                                             } else {
                                                 Text(LocalizedStringKey("\(seconds / 60) min")).tag(seconds)
                                             }
                                         }
                                     }
                                     .pickerStyle(.menu)
                                 }
                                 
                                 // 2. Переключатель авто-старта
                                 Toggle(isOn: $autoStartTimer) {
                                     Label(LocalizedStringKey("Auto-start Timer"), systemImage: "play.circle")
                                 }
                             }
                // Секция настроек стрика
                Section {
                    Stepper(value: $streakRestDays, in: 1...7) {
                        HStack {
                            Label(LocalizedStringKey("Max Rest Days"), systemImage: "flame.fill")
                            Spacer()
                            Text(LocalizedStringKey("\(streakRestDays) day\(streakRestDays > 1 ? "s" : "")"))
                                .foregroundColor(.secondary)
                                .bold()
                        }
                    }
                } header: {
                    Text(LocalizedStringKey("Streak Settings"))
                } footer: {
                    Text(LocalizedStringKey("Your streak will reset if you don't train within this number of rest days."))
                }
                
                // Секция дополнительных настроек
                Section(header: Text(LocalizedStringKey("Additional Settings"))) {
                    // Темная тема
                    HStack {
                        Label(LocalizedStringKey("Appearance"), systemImage: appearanceMode == "dark" ? "moon.fill" : appearanceMode == "light" ? "sun.max.fill" : "circle.lefthalf.filled")
                        Spacer()
                        Picker("", selection: $appearanceMode) {
                            Text(LocalizedStringKey("System")).tag("system")
                            Text(LocalizedStringKey("Light")).tag("light")
                            Text(LocalizedStringKey("Dark")).tag("dark")
                        }
                        .pickerStyle(.menu)
                    }
                    
                    // Единицы измерения
                    HStack {
                        Label(LocalizedStringKey("Weight Units"), systemImage: "scalemass")
                        Spacer()
                        Picker("", selection: Binding(
                            get: { unitsManager.weightUnit },
                            set: { unitsManager.setWeightUnit($0) }
                        )) {
                            ForEach(WeightUnit.allCases, id: \.self) { unit in
                                Text(unit.displayName).tag(unit)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    
                    // Язык
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack {
                            Label(LocalizedStringKey("Language"), systemImage: "globe")
                                .foregroundColor(.primary)
                            Spacer()
                            Text(Locale.current.language.languageCode?.identifier == "ru" ? "Русский" : "English")
                                .foregroundColor(.secondary)
                            Image(systemName: "arrow.up.forward.app")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // ВРЕМЕННАЯ СЕКЦИЯ ДЛЯ ТЕСТИРОВАНИЯ - УДАЛИТЬ ПОСЛЕ ТЕСТОВ
                Section {
                    Button(role: .destructive) {
                        generateTestData()
                    } label: {
                        HStack {
                            Label(LocalizedStringKey("Generate All Test Data"), systemImage: "flask.fill")
                            Spacer()
                            if isProcessing {
                                ProgressView()
                            } else {
                                Text(LocalizedStringKey("TEST"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .disabled(isProcessing)
                    
                    Button(role: .destructive) {
                        showClearAllAlert = true
                    } label: {
                        HStack {
                            Label(LocalizedStringKey("Clear All Data"), systemImage: "trash.fill")
                            Spacer()
                            if isProcessing {
                                ProgressView()
                            } else {
                                Text(LocalizedStringKey("DANGER"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .disabled(isProcessing)
                } header: {
                    Text(LocalizedStringKey("TESTING (REMOVE AFTER TEST)"))
                } footer: {
                    Text(LocalizedStringKey("These buttons are for testing only. Remove TestDataGenerator.swift and this section after testing."))
                }
                
               
                
                // Секция поддержки и обратной связи
                Section(header: Text(LocalizedStringKey("Support & Feedback"))) {
                    NavigationLink(destination: FeedbackView()) {
                        Label(LocalizedStringKey("Send Feedback"), systemImage: "envelope.fill")
                    }
                    
                    Button {
                        showExportFormatPicker = true
                    } label: {
                        Label(LocalizedStringKey("Export All Data"), systemImage: "square.and.arrow.up")
                    }
                    .confirmationDialog(LocalizedStringKey("Export Format"), isPresented: $showExportFormatPicker) {
                        Button(LocalizedStringKey("Export as JSON")) {
                            exportAllData(format: .json)
                        }
                        Button(LocalizedStringKey("Export as CSV")) {
                            exportAllData(format: .csv)
                        }
                        Button(LocalizedStringKey("Cancel"), role: .cancel) { }
                    }
                }
                
                // Секция "О программе"
                Section(header: Text(LocalizedStringKey("About"))) {
                    Text(LocalizedStringKey("Version 1.0.0"))
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle(LocalizedStringKey("Settings"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("Done")) { dismiss() }
                }
            }
            .alert(LocalizedStringKey("Test Data"), isPresented: $showTestDataAlert) {
                Button(LocalizedStringKey("OK"), role: .cancel) { }
            } message: {
                Text(testDataAlertMessage)
            }
            .alert(LocalizedStringKey("Clear All Data?"), isPresented: $showClearAllAlert) {
                Button(LocalizedStringKey("Clear All"), role: .destructive) {
                    clearAllWorkouts()
                }
                Button(LocalizedStringKey("Cancel"), role: .cancel) { }
            } message: {
                Text(LocalizedStringKey("Are you sure you want to delete all data? This action cannot be undone."))
            }
            .sheet(item: $fileToShare) { url in
                ActivityViewController(activityItems: [url])
                    .presentationDetents([.medium, .large])
            }
        }
    }
    
    // MARK: - Test Data Functions
    
    private func generateTestData() {
        isProcessing = true
        let container = modelContext.container
        
        Task.detached {
            await TestDataGenerator.generateAllData(container: container)
            
            await MainActor.run {
                // viewModel.fetchData() — Убрано. SwiftData и @Query обновят UI сами.
                isProcessing = false
                testDataAlertMessage = "Test data generated successfully!\n\nCreated workouts and weight tracking history from 2021 to 2026."
                showTestDataAlert = true
            }
        }
    }
    
    private func clearAllWorkouts() {
        isProcessing = true
        let container = modelContext.container
        
        Task.detached {
            await TestDataGenerator.clearAllDataAsync(container: container)
            
            await MainActor.run {
                // viewModel.fetchData() — Убрано.
                isProcessing = false
                testDataAlertMessage = "All workouts and weight history cleared."
                showTestDataAlert = true
            }
        }
    }
    
    // MARK: - Export Functions
    
    private enum ExportFormat {
        case json
        case csv
    }
    
    private func exportAllData(format: ExportFormat) {
        let fileURL: URL?
        
        switch format {
        case .json:
            fileURL = DataManager.shared.exportAllDataAsJSON(workouts: workouts)
        case .csv:
            fileURL = DataManager.shared.exportAllDataToCSV(workouts: workouts)
        }
        
        if let fileURL = fileURL {
            fileToShare = fileURL
        } else {
            testDataAlertMessage = "Failed to export data. Please try again."
            showTestDataAlert = true
        }
    }
}
