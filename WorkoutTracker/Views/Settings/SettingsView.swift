//
//  SettingsView.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 27.12.25.
//

internal import SwiftUI
internal import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var viewModel: WorkoutViewModel
    
    @AppStorage("streakRestDays") private var streakRestDays: Int = 2
    @AppStorage("defaultRestTime") private var defaultRestTime: Int = 60
    @AppStorage("autoStartTimer") private var autoStartTimer: Bool = true
    @AppStorage("appearanceMode") private var appearanceMode: String = "system" // "light", "dark", "system"
    @StateObject private var unitsManager = UnitsManager.shared
    @StateObject private var backupManager = BackupManager.shared
    @State private var showTestDataAlert = false
    @State private var testDataAlertMessage = ""
    @State private var showClearAllAlert = false
    @State private var fileToShare: URL?
    @State private var showExportFormatPicker = false
    @State private var showBackupsList = false
    @State private var showRestoreConfirmation = false
    @State private var selectedBackup: BackupManager.BackupInfo?
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
                            Label(LocalizedStringKey("Generate 2 Years Test Data"), systemImage: "flask.fill")
                            Spacer()
                            Text(LocalizedStringKey("⚠️ TEST"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button(role: .destructive) {
                        generate2026TestData()
                    } label: {
                        HStack {
                            Label(LocalizedStringKey("Generate 2026 Year Test Data"), systemImage: "calendar")
                            Spacer()
                            Text(LocalizedStringKey("⚠️ TEST"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button(role: .destructive) {
                        generateWeightTestData()
                    } label: {
                        HStack {
                            Label(LocalizedStringKey("Generate Weight Test Data"), systemImage: "chart.line.uptrend.xyaxis")
                            Spacer()
                            Text(LocalizedStringKey("⚠️ TEST"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button(role: .destructive) {
                        showClearAllAlert = true
                    } label: {
                        HStack {
                            Label(LocalizedStringKey("Clear All Workouts"), systemImage: "trash.fill")
                            Spacer()
                            Text(LocalizedStringKey("⚠️ DANGER"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text(LocalizedStringKey("🧪 TESTING (REMOVE AFTER TEST)"))
                } footer: {
                    Text(LocalizedStringKey("These buttons are for testing only. Remove TestDataGenerator.swift and this section after testing."))
                }
                
                // Секция резервного копирования (сворачиваемая)
                Section {
                    DisclosureGroup(
                        isExpanded: $isBackupSectionExpanded,
                        content: {
                            // Частота бэкапа
                            HStack {
                                Label(LocalizedStringKey("Frequency"), systemImage: "clock")
                                Spacer()
                                Picker("", selection: Binding(
                                    get: { backupManager.backupFrequencyHours },
                                    set: { backupManager.backupFrequencyHours = $0 }
                                )) {
                                    ForEach(BackupManager.BackupFrequency.allCases) { frequency in
                                        Text(frequency.displayName).tag(frequency.rawValue)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                            
                            // Максимальное количество копий (только если бэкап включен)
                            if backupManager.isAutoBackupEnabled {
                                Stepper(value: Binding(
                                    get: { backupManager.maxBackupsCount },
                                    set: { backupManager.maxBackupsCount = $0 }
                                ), in: 3...30) {
                                    HStack {
                                        Label(LocalizedStringKey("Keep Backups"), systemImage: "doc.on.doc")
                                        Spacer()
                                        Text("\(backupManager.maxBackupsCount)")
                                            .foregroundColor(.secondary)
                                            .bold()
                                    }
                                }
                            }
                            
                            // Кнопка создания бэкапа вручную
                            Button {
                                createManualBackup()
                            } label: {
                                Label(LocalizedStringKey("Backup Now"), systemImage: "arrow.clockwise")
                            }
                            
                            // Управление резервными копиями
                            NavigationLink(destination: BackupListView(viewModel: viewModel)) {
                                HStack {
                                    Label(LocalizedStringKey("Manage Backups"), systemImage: "folder")
                                    Spacer()
                                    Text("\(backupManager.backups.count)")
                                        .foregroundColor(.secondary)
                                }
                            }
                        },
                        label: {
                            HStack {
                                Label(LocalizedStringKey("Backup"), systemImage: "arrow.clockwise.icloud")
                                Spacer()
                                if backupManager.isAutoBackupEnabled {
                                    Text(LocalizedStringKey("On"))
                                        .foregroundColor(.secondary)
                                } else {
                                    Text(LocalizedStringKey("Off"))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    )
                } footer: {
                    if isBackupSectionExpanded {
                        Text(LocalizedStringKey("Automatic backups protect your workout data. Backups are stored locally on your device."))
                    }
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
            .alert(LocalizedStringKey("Clear All Workouts?"), isPresented: $showClearAllAlert) {
                Button(LocalizedStringKey("Clear All"), role: .destructive) {
                    clearAllWorkouts()
                }
                Button(LocalizedStringKey("Cancel"), role: .cancel) { }
            } message: {
                Text(LocalizedStringKey("Are you sure you want to delete all workouts? This action cannot be undone."))
            }
            .sheet(item: $fileToShare) { url in
                ActivityViewController(activityItems: [url])
                    .presentationDetents([.medium, .large])
            }
        }
    }
    
    // MARK: - Test Data Functions
    
    private func generateTestData() {
        DispatchQueue.global(qos: .userInitiated).async {
            TestDataGenerator.generateAndSaveTestData()
            
            DispatchQueue.main.async {
                // Обновляем ViewModel
                DataManager.shared.loadWorkouts { result in
                    switch result {
                    case .success(let workouts):
                        viewModel.workouts = workouts
                    case .failure(let error):
                        viewModel.workouts = []
                    }
                }
                testDataAlertMessage = "✅ Test data generated successfully!\n\nCreated 2 years of workout history (3 workouts per week)."
                showTestDataAlert = true
            }
        }
    }
    
    private func generate2026TestData() {
        DispatchQueue.global(qos: .userInitiated).async {
            TestDataGenerator.generate2026TestData()
            
            DispatchQueue.main.async {
                // Обновляем ViewModel
                DataManager.shared.loadWorkouts { result in
                    switch result {
                    case .success(let workouts):
                        viewModel.workouts = workouts
                    case .failure(let error):
                        viewModel.workouts = []
                    }
                }
                testDataAlertMessage = "✅ 2026 test data generated successfully!\n\nCreated 1 year of future workout history for 2026 (3 workouts per week)."
                showTestDataAlert = true
            }
        }
    }
    
    private func generateWeightTestData() {
        DispatchQueue.global(qos: .userInitiated).async {
            TestDataGenerator.generateWeightTestData()
            
            DispatchQueue.main.async {
                testDataAlertMessage = "✅ Weight test data generated successfully!\n\nCreated 2 years of weight tracking data with realistic fluctuations."
                showTestDataAlert = true
            }
        }
    }
    
    private func clearAllWorkouts() {
        DataManager.shared.saveWorkouts([]) { [weak viewModel] error in
            viewModel?.showError(
                title: NSLocalizedString("Failed to Clear Workouts", comment: "Error title when clearing workouts fails"),
                message: String(format: NSLocalizedString("Failed to clear all workouts. Please try again.\n\nError: %@", comment: "Error message when clearing workouts fails"), error.localizedDescription)
            )
        }
        viewModel.workouts = []
        testDataAlertMessage = "✅ All workouts cleared."
        showTestDataAlert = true
    }
    
    // MARK: - Backup Functions
    
    private func createManualBackup() {
        let success = backupManager.createBackup(workouts: viewModel.workouts, viewModel: viewModel)
        if success {
            testDataAlertMessage = NSLocalizedString("✅ Backup created successfully!", comment: "Backup success message")
        } else {
            testDataAlertMessage = NSLocalizedString("❌ Failed to create backup. Please try again.", comment: "Backup failure message")
        }
        showTestDataAlert = true
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
            fileURL = DataManager.shared.exportAllData(workouts: viewModel.workouts, viewModel: viewModel)
        case .csv:
            fileURL = DataManager.shared.exportAllDataToCSV(workouts: viewModel.workouts, viewModel: viewModel)
        }
        
        if let fileURL = fileURL {
            fileToShare = fileURL
        } else {
            testDataAlertMessage = "❌ Failed to export data. Please try again."
            showTestDataAlert = true
        }
    }
}

// MARK: - Backup List View

struct BackupListView: View {
    @ObservedObject var backupManager = BackupManager.shared
    @ObservedObject var viewModel: WorkoutViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedBackup: BackupManager.BackupInfo?
    @State private var showRestoreConfirmation = false
    @State private var showDeleteConfirmation = false
    @State private var backupToDelete: BackupManager.BackupInfo?
    @State private var showRestoreSuccess = false
    @State private var showRestoreError = false
    @State private var fileToShare: URL?
    @State private var showImportPicker = false
    @State private var showImportSuccess = false
    @State private var showImportError = false
    
    var body: some View {
        List {
            // Информация
            Section {
                HStack {
                    Label(LocalizedStringKey("Total Backups"), systemImage: "doc.on.doc.fill")
                    Spacer()
                    Text("\(backupManager.backups.count)")
                        .foregroundColor(.secondary)
                        .bold()
                }
                
                if let lastBackup = backupManager.lastBackupDate {
                    HStack {
                        Label(LocalizedStringKey("Last Backup"), systemImage: "clock.fill")
                        Spacer()
                        Text(lastBackup, style: .relative)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Импорт бэкапа
            Section {
                Button {
                    showImportPicker = true
                } label: {
                    Label(LocalizedStringKey("Import Backup"), systemImage: "square.and.arrow.down")
                }
            }
            
            // Список бэкапов
            Section(header: Text(LocalizedStringKey("Available Backups"))) {
                if backupManager.backups.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "tray")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                            Text(LocalizedStringKey("No backups yet"))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical)
                        Spacer()
                    }
                } else {
                    ForEach(backupManager.backups) { backup in
                        BackupRowView(
                            backup: backup,
                            onRestore: {
                                selectedBackup = backup
                                showRestoreConfirmation = true
                            },
                            onExport: {
                                if let url = backupManager.exportBackup(backup) {
                                    fileToShare = url
                                }
                            },
                            onDelete: {
                                backupToDelete = backup
                                showDeleteConfirmation = true
                            }
                        )
                    }
                }
            }
        }
        .navigationTitle(LocalizedStringKey("Backups"))
        .navigationBarTitleDisplayMode(.inline)
        .alert(LocalizedStringKey("Restore Backup?"), isPresented: $showRestoreConfirmation) {
            Button(LocalizedStringKey("Restore"), role: .destructive) {
                restoreSelectedBackup()
            }
            Button(LocalizedStringKey("Cancel"), role: .cancel) { }
        } message: {
            if let backup = selectedBackup {
                Text(String(format: NSLocalizedString("This will restore %d workouts from %@. Your current data will be merged with the backup.", comment: "Restore confirmation message"), backup.workoutCount, backup.formattedDate))
            }
        }
        .alert(LocalizedStringKey("Delete Backup?"), isPresented: $showDeleteConfirmation) {
            Button(LocalizedStringKey("Delete"), role: .destructive) {
                if let backup = backupToDelete {
                    backupManager.deleteBackup(backup)
                }
            }
            Button(LocalizedStringKey("Cancel"), role: .cancel) { }
        } message: {
            Text(LocalizedStringKey("This backup will be permanently deleted."))
        }
        .alert(LocalizedStringKey("Restore Complete! 🎉"), isPresented: $showRestoreSuccess) {
            Button(LocalizedStringKey("OK"), role: .cancel) { }
        } message: {
            Text(LocalizedStringKey("Your data has been successfully restored from the backup."))
        }
        .alert(LocalizedStringKey("Restore Failed"), isPresented: $showRestoreError) {
            Button(LocalizedStringKey("OK"), role: .cancel) { }
        } message: {
            Text(LocalizedStringKey("Could not restore data from this backup. The file may be corrupted."))
        }
        .alert(LocalizedStringKey("Import Complete! 🎉"), isPresented: $showImportSuccess) {
            Button(LocalizedStringKey("OK"), role: .cancel) { }
        } message: {
            Text(LocalizedStringKey("Your data has been successfully imported from the backup file."))
        }
        .alert(LocalizedStringKey("Import Failed"), isPresented: $showImportError) {
            Button(LocalizedStringKey("OK"), role: .cancel) { }
        } message: {
            Text(LocalizedStringKey("Could not import data from this file. Please make sure it's a valid backup file."))
        }
        .sheet(item: $fileToShare) { url in
            ActivityViewController(activityItems: [url])
                .presentationDetents([.medium, .large])
        }
        .fileImporter(
            isPresented: $showImportPicker,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleImportResult(result)
        }
    }
    
    private func restoreSelectedBackup() {
        guard let backup = selectedBackup else { return }
        
        if let backupData = backupManager.restoreBackup(backup) {
            backupManager.applyRestoredData(backupData, to: viewModel)
            showRestoreSuccess = true
        } else {
            showRestoreError = true
        }
    }
    
    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            if let backupData = backupManager.importBackup(from: url) {
                backupManager.applyRestoredData(backupData, to: viewModel)
                showImportSuccess = true
            } else {
                showImportError = true
            }
            
        case .failure:
            showImportError = true
        }
    }
}

// MARK: - Backup Row View

struct BackupRowView: View {
    let backup: BackupManager.BackupInfo
    let onRestore: () -> Void
    let onExport: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(backup.formattedDate)
                        .font(.headline)
                    
                    HStack(spacing: 12) {
                        Label("\(backup.workoutCount)", systemImage: "figure.run")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Label(backup.formattedSize, systemImage: "doc")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Menu {
                    Button {
                        onRestore()
                    } label: {
                        Label(LocalizedStringKey("Restore"), systemImage: "arrow.counterclockwise")
                    }
                    
                    Button {
                        onExport()
                    } label: {
                        Label(LocalizedStringKey("Export"), systemImage: "square.and.arrow.up")
                    }
                    
                    Divider()
                    
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label(LocalizedStringKey("Delete"), systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
