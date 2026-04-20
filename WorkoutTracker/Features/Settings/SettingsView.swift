//
//  SettingsView.swift
//  WorkoutTracker
//

internal import SwiftUI
internal import UniformTypeIdentifiers
import SwiftData
import UIKit

// MARK: - Main Settings View

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(DIContainer.self) private var di
    @AppStorage(Constants.UserDefaultsKeys.includeWarmupsInStats.rawValue) private var includeWarmupsInStats: Bool = false
    @State private var isProcessing = false
    @State private var showTestDataAlert = false
    @State private var testDataAlertMessage = ""
    @State private var showClearAllAlert = false
    @State private var fileToShare: SharedFileWrapper?
    @State private var showExportFormatPicker = false
    @Environment(ThemeManager.self) private var themeManager
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text(LocalizedStringKey("Preferences"))) {
                    NavigationLink(destination: AppearanceSettingsView()) {
                        Label(LocalizedStringKey("Appearance & Profile"), systemImage: "person.crop.circle")
                    }
                    NavigationLink(destination: UnitsSettingsView()) {
                        Label(LocalizedStringKey("Units of Measure"), systemImage: "ruler")
                    }
                }
                
                Section(header: Text(LocalizedStringKey("Workout Options"))) {
                    NavigationLink(destination: TimerSettingsView()) {
                        Label(LocalizedStringKey("Rest Timer"), systemImage: "timer")
                    }
                    NavigationLink(destination: AudioSettingsView()) {
                        Label(LocalizedStringKey("Voice Coach"), systemImage: "speaker.wave.3.fill")
                    }
                    Toggle(isOn: $includeWarmupsInStats) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(LocalizedStringKey("Include Warmups in Stats"))
                                .foregroundColor(themeManager.current.primaryText)
                            Text(LocalizedStringKey("If enabled, warm-up sets will be counted in total volume and personal records."))
                                .font(.caption)
                                .foregroundColor(themeManager.current.secondaryText)
                        }
                    }
                    .tint(.accentColor)
                }
                
                Section(header: Text(LocalizedStringKey("Gamification"))) {
                    NavigationLink(destination: StreakSettingsView()) {
                        Label(LocalizedStringKey("Streak Settings"), systemImage: "flame.fill")
                    }
                }
                
                Section(header: Text(LocalizedStringKey("Support & Data"))) {
                    NavigationLink(destination: FeedbackView()) {
                        Label(LocalizedStringKey("Send Feedback"), systemImage: "envelope.fill")
                    }
                    
                    Button {
                        showExportFormatPicker = true
                    } label: {
                        Label(LocalizedStringKey("Export All Data"), systemImage: "square.and.arrow.up")
                            .foregroundColor(themeManager.current.primaryText)
                    }
                }
                
#if DEBUG
                debugSection
#endif
                
                Section {
                    HStack {
                        Spacer()
                        Text(LocalizedStringKey("Version 1.0.0"))
                            .font(.caption)
                            .foregroundColor(themeManager.current.secondaryText)
                        Spacer()
                    }
                }
                .listRowBackground(Color.clear)
            }
            .navigationTitle(LocalizedStringKey("Settings"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("Done")) { dismiss() }
                }
            }
            .confirmationDialog(LocalizedStringKey("Export Format"), isPresented: $showExportFormatPicker) {
                Button(LocalizedStringKey("Export as JSON")) { Task { await exportAllData(format: .json) } }
                Button(LocalizedStringKey("Export as CSV")) { Task { await exportAllData(format: .csv) } }
                Button(LocalizedStringKey("Cancel"), role: .cancel) { }
            }
            .sheet(item: $fileToShare) { wrapper in
                ActivityViewController(activityItems: [wrapper.url])
                    .presentationDetents([.medium, .large])
            }
            // Alerts for debug
            .alert(LocalizedStringKey("Test Data"), isPresented: $showTestDataAlert) {
                Button(LocalizedStringKey("OK"), role: .cancel) { }
            } message: {
                Text(testDataAlertMessage)
            }
            .alert(LocalizedStringKey("Clear All Data?"), isPresented: $showClearAllAlert) {
                Button(LocalizedStringKey("Clear All"), role: .destructive) {
                    Task { await clearAllWorkouts() }
                }
                Button(LocalizedStringKey("Cancel"), role: .cancel) { }
            } message: {
                Text(LocalizedStringKey("Are you sure you want to delete all data? This action cannot be undone."))
            }
        }
    }
    
    // MARK: - Debug Section & Export Logic
    
#if DEBUG
    @ViewBuilder
    private var debugSection: some View {
        Section(footer: Text(LocalizedStringKey("These buttons are for testing only. Remove TestDataGenerator.swift and this section after testing."))) {
            Button(role: .destructive) { Task { await generateTestData() } } label: {
                HStack {
                    Label(LocalizedStringKey("Generate All Test Data"), systemImage: "flask.fill")
                    Spacer()
                    if isProcessing { ProgressView() }
                }
            }.disabled(isProcessing)
            
            Button(role: .destructive) { showClearAllAlert = true } label: {
                HStack {
                    Label(LocalizedStringKey("Clear All Data"), systemImage: "trash.fill")
                    Spacer()
                    if isProcessing { ProgressView() }
                }
            }.disabled(isProcessing)
        }
    }
    
    private func generateTestData() async {
        isProcessing = true
        let generator = TestDataGenerator(modelContainer: di.modelContainer)
        await generator.generateAllData()
        await di.analyticsService.rebuildAllStats()
        await di.workoutService.updateWidgetData()
        self.isProcessing = false
        self.testDataAlertMessage = "Test data generated successfully!"
        self.showTestDataAlert = true
    }

    private func clearAllWorkouts() async {
        isProcessing = true
        let generator = TestDataGenerator(modelContainer: di.modelContainer)
        await generator.clearAllDataAsync()
        await di.analyticsService.rebuildAllStats()
        await di.workoutService.updateWidgetData()
        self.isProcessing = false
        self.testDataAlertMessage = "All workouts and weight history cleared."
        self.showTestDataAlert = true
    }
#endif
    
    private enum ExportFormat { case json, csv }
    
    private func exportAllData(format: ExportFormat) async {
        isProcessing = true
        let bgContext = ModelContext(di.modelContainer)
        let descriptor = FetchDescriptor<Workout>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        let workouts = (try? bgContext.fetch(descriptor)) ?? []
        let fileURL: URL?
        
        do {
            switch format {
            case .json: fileURL = DataManager.shared.exportAllDataAsJSON(workouts: workouts)
            case .csv: fileURL = DataManager.shared.exportAllDataToCSV(workouts: workouts)
            }
            
            self.isProcessing = false
            if let fileURL = fileURL { self.fileToShare = SharedFileWrapper(url: fileURL) } else {
                self.testDataAlertMessage = "Failed to export data. Please try again."
                self.showTestDataAlert = true
            }
        } catch {
            self.isProcessing = false
            self.testDataAlertMessage = "Failed to export data: \(error.localizedDescription)"
            self.showTestDataAlert = true
        }
    }
}

// MARK: - Sub-Settings Views

struct UnitsSettingsView: View {
    @Environment(UnitsManager.self) var unitsManager
    
    var body: some View {
        Form {
            Section(header: Text(LocalizedStringKey("Weight Units"))) {
                SettingsCheckmarkRow(title: "Kilograms", isSelected: unitsManager.weightUnit == .kilograms) {
                    unitsManager.setWeightUnit(.kilograms)
                }
                SettingsCheckmarkRow(title: "Pounds", isSelected: unitsManager.weightUnit == .pounds) {
                    unitsManager.setWeightUnit(.pounds)
                }
            }
            
            Section(header: Text(LocalizedStringKey("Distance Units"))) {
                SettingsCheckmarkRow(title: "Meters / Kilometers", isSelected: unitsManager.distanceUnit == .meters) {
                    unitsManager.setDistanceUnit(.meters)
                }
                SettingsCheckmarkRow(title: "Miles", isSelected: unitsManager.distanceUnit == .miles) {
                    unitsManager.setDistanceUnit(.miles)
                }
            }
            
            Section(header: Text(LocalizedStringKey("Body Measurement Units"))) {
                SettingsCheckmarkRow(title: "Centimeters", isSelected: unitsManager.sizeUnit == .centimeters) {
                    unitsManager.setSizeUnit(.centimeters)
                }
                SettingsCheckmarkRow(title: "Inches", isSelected: unitsManager.sizeUnit == .inches) {
                    unitsManager.setSizeUnit(.inches)
                }
            }
        }
        .navigationTitle(LocalizedStringKey("Units of Measure"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AppearanceSettingsView: View {
    @AppStorage(Constants.UserDefaultsKeys.appearanceMode.rawValue) private var appearanceMode: String = "system"
    @AppStorage(Constants.UserDefaultsKeys.userGender.rawValue) private var userGender = "male"
    
    @Environment(ThemeManager.self) private var themeManager // <--- ДОБАВЛЕНО
    
    var body: some View {
        Form {

            Section(header: Text(LocalizedStringKey("System Theme"))) {
                SettingsCheckmarkRow(title: "System", isSelected: appearanceMode == "system") { appearanceMode = "system" }
                SettingsCheckmarkRow(title: "Light", isSelected: appearanceMode == "light") { appearanceMode = "light" }
                SettingsCheckmarkRow(title: "Dark", isSelected: appearanceMode == "dark") { appearanceMode = "dark" }
            }
            
            Section(header: Text(LocalizedStringKey("Anatomy Model")), footer: Text("This model is used for your personal muscle recovery heatmap.")) {
                SettingsCheckmarkRow(title: "Male", isSelected: userGender == "male") { userGender = "male" }
                SettingsCheckmarkRow(title: "Female", isSelected: userGender == "female") { userGender = "female" }
            }
            
            Section(header: Text(LocalizedStringKey("Localization"))) {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                } label: {
                    HStack {
                        Text(LocalizedStringKey("Language")).foregroundColor(themeManager.current.primaryText)
                        Spacer()
                        Text(Locale.current.language.languageCode?.identifier == "ru" ? "Русский" : "English").foregroundColor(themeManager.current.secondaryText)
                        Image(systemName: "arrow.up.forward.app").font(.caption).foregroundColor(themeManager.current.secondaryText)
                    }
                }
            }
        }
        .navigationTitle(LocalizedStringKey("Appearance & Profile"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct TimerSettingsView: View {
    @AppStorage(Constants.UserDefaultsKeys.defaultRestTime.rawValue) private var defaultRestTime: Int = 60
    @AppStorage(Constants.UserDefaultsKeys.autoStartTimer.rawValue) private var autoStartTimer: Bool = true
    let restOptions = [30, 45, 60, 90, 120, 180, 300]
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        Form {
            Section(header: Text("Timer Behavior"), footer: Text(LocalizedStringKey("If enabled, the rest timer will start automatically when you check off a set."))) {
                Toggle(isOn: $autoStartTimer) {
                    Text(LocalizedStringKey("Auto-start Timer"))
                }
                .tint(.accentColor)
                
                Picker(LocalizedStringKey("Default Duration"), selection: $defaultRestTime) {
                    ForEach(restOptions, id: \.self) { seconds in
                        if seconds % 60 == 0 {
                            Text(LocalizedStringKey("\(seconds / 60) min")).tag(seconds)
                        } else {
                            Text(LocalizedStringKey("\(seconds) sec")).tag(seconds)
                        }
                    }
                }
            }
        }
        .navigationTitle(LocalizedStringKey("Rest Timer"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct StreakSettingsView: View {
    @AppStorage(Constants.UserDefaultsKeys.streakRestDays.rawValue) private var streakRestDays: Int = 2
    @Environment(ThemeManager.self) private var themeManager
    var body: some View {
        Form {
            Section(footer: Text(LocalizedStringKey("Your streak will reset if you don't train within this number of rest days."))) {
                Stepper(value: $streakRestDays, in: 1...7) {
                    HStack {
                        Text(LocalizedStringKey("Max Rest Days"))
                        Spacer()
                        Text(LocalizedStringKey("\(streakRestDays) day\(streakRestDays > 1 ? "s" : "")"))
                            .foregroundColor(themeManager.current.secondaryText)
                            .bold()
                    }
                }
            }
        }
        .navigationTitle(LocalizedStringKey("Streak Settings"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AudioSettingsView: View {
    @AppStorage(Constants.UserDefaultsKeys.voiceCoachDucking.rawValue) private var voiceCoachDucking: Bool = false
    
    var body: some View {
        Form {
            Section(footer: Text(LocalizedStringKey("If enabled, background music will lower its volume when the AI coach speaks."))) {
                Toggle(isOn: $voiceCoachDucking) {
                    Text(LocalizedStringKey("Audio Ducking"))
                }
                .tint(.accentColor)
            }
        }
        .navigationTitle(LocalizedStringKey("Voice Coach"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Reusable Components

struct SettingsCheckmarkRow: View {
    let title: LocalizedStringKey
    let isSelected: Bool
    let action: () -> Void
    @Environment(ThemeManager.self) private var themeManager
    var body: some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            action()
        }) {
            HStack {
                Text(title)
                    .foregroundColor(themeManager.current.primaryText)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.accentColor)
                        .fontWeight(.semibold)
                }
            }
        }
    }
}
