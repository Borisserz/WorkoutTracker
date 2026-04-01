internal import SwiftUI
internal import UniformTypeIdentifiers
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(WorkoutViewModel.self) var viewModel
    
    @AppStorage(Constants.UserDefaultsKeys.userName.rawValue) private var userName = ""
    @AppStorage(Constants.UserDefaultsKeys.userBodyWeight.rawValue) private var userBodyWeight = 0.0
    @AppStorage(Constants.UserDefaultsKeys.userGender.rawValue) private var userGender = "male"
    
    @AppStorage(Constants.UserDefaultsKeys.streakRestDays.rawValue) private var streakRestDays: Int = 2
    @AppStorage(Constants.UserDefaultsKeys.defaultRestTime.rawValue) private var defaultRestTime: Int = 60
    @AppStorage(Constants.UserDefaultsKeys.autoStartTimer.rawValue) private var autoStartTimer: Bool = true
    @AppStorage(Constants.UserDefaultsKeys.appearanceMode.rawValue) private var appearanceMode: String = "system"
    
    @Environment(UnitsManager.self) var unitsManager
    
    @FocusState private var isProfileFocused: Bool
    
    @State private var isProcessing = false
    @State private var showTestDataAlert = false
    @State private var testDataAlertMessage = ""
    @State private var showClearAllAlert = false
    @State private var fileToShare: URL?
    @State private var showExportFormatPicker = false
    
    let restOptions = [30, 45, 60, 90, 120, 180, 300]
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    DisclosureGroup(LocalizedStringKey("Workout Management")) {
                        NavigationLink(destination: PresetListView()) {
                            Label(LocalizedStringKey("Workout Templates"), systemImage: "list.bullet.clipboard")
                        }
                    }
                }
                
                Section(footer: Text(LocalizedStringKey("If enabled, the rest timer will start automatically when you check off a set."))) {
                    DisclosureGroup(LocalizedStringKey("Rest Timer")) {
                        HStack {
                            Label(LocalizedStringKey("Default"), systemImage: "timer")
                            Spacer()
                            Picker(LocalizedStringKey("Time"), selection: $defaultRestTime) {
                                ForEach(restOptions, id: \.self) { seconds in
                                    if seconds % 60 == 0 {
                                        Text(LocalizedStringKey("\(seconds / 60) min")).tag(seconds)
                                    } else {
                                        Text(LocalizedStringKey("\(seconds) sec")).tag(seconds)
                                    }
                                }
                            }
                            .pickerStyle(.menu)
                        }
                        Toggle(isOn: $autoStartTimer) {
                            Label(LocalizedStringKey("Auto-start Timer"), systemImage: "play.circle")
                        }
                    }
                }
                
                Section(footer: Text(LocalizedStringKey("Your streak will reset if you don't train within this number of rest days."))) {
                    DisclosureGroup(LocalizedStringKey("Streak Settings")) {
                        Stepper(value: $streakRestDays, in: 1...7) {
                            HStack {
                                Label(LocalizedStringKey("Max Rest Days"), systemImage: "flame.fill")
                                Spacer()
                                Text(LocalizedStringKey("\(streakRestDays) day\(streakRestDays > 1 ? "s" : "")"))
                                    .foregroundColor(.secondary)
                                    .bold()
                            }
                        }
                    }
                }
                
                Section {
                    DisclosureGroup(LocalizedStringKey("Additional Settings")) {
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
                        
                        HStack {
                            Label(LocalizedStringKey("Gender"), systemImage: "person.fill")
                            Spacer()
                            Picker("", selection: $userGender) {
                                Text(LocalizedStringKey("Male")).tag("male")
                                Text(LocalizedStringKey("Female")).tag("female")
                            }
                            .pickerStyle(.menu)
                        }
                        
                        HStack {
                            Label(LocalizedStringKey("Weight Units"), systemImage: "scalemass")
                            Spacer()
                            Picker("", selection: Binding(get: { unitsManager.weightUnit }, set: { unitsManager.setWeightUnit($0) })) {
                                ForEach(WeightUnit.allCases, id: \.self) { unit in Text(unit.displayName).tag(unit) }
                            }
                            .pickerStyle(.menu)
                        }
                        
                        HStack {
                            Label(LocalizedStringKey("Distance Units"), systemImage: "ruler")
                            Spacer()
                            Picker("", selection: Binding(get: { unitsManager.distanceUnit }, set: { unitsManager.setDistanceUnit($0) })) {
                                ForEach(DistanceUnit.allCases, id: \.self) { unit in Text(unit.displayName).tag(unit) }
                            }
                            .pickerStyle(.menu)
                        }
                        
                        HStack {
                            Label(LocalizedStringKey("Size Units"), systemImage: "ruler.fill")
                            Spacer()
                            Picker("", selection: Binding(get: { unitsManager.sizeUnit }, set: { unitsManager.setSizeUnit($0) })) {
                                ForEach(SizeUnit.allCases, id: \.self) { unit in Text(unit.displayName).tag(unit) }
                            }
                            .pickerStyle(.menu)
                        }
                        
                        Button {
                            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                        } label: {
                            HStack {
                                Label(LocalizedStringKey("Language"), systemImage: "globe").foregroundColor(.primary)
                                Spacer()
                                Text(Locale.current.language.languageCode?.identifier == "ru" ? "Русский" : "English").foregroundColor(.secondary)
                                Image(systemName: "arrow.up.forward.app").font(.caption).foregroundColor(.secondary)
                            }
                        }
                    }
                }
#if DEBUG
                Section(footer: Text(LocalizedStringKey("These buttons are for testing only. Remove TestDataGenerator.swift and this section after testing."))) {
                    DisclosureGroup(LocalizedStringKey("TESTING (REMOVE AFTER TEST)")) {
                        Button(role: .destructive) { generateTestData() } label: {
                            HStack {
                                Label(LocalizedStringKey("Generate All Test Data"), systemImage: "flask.fill")
                                Spacer()
                                if isProcessing { ProgressView() } else { Text(LocalizedStringKey("TEST")).font(.caption).foregroundColor(.secondary) }
                            }
                        }.disabled(isProcessing)
                        
                        Button(role: .destructive) { showClearAllAlert = true } label: {
                            HStack {
                                Label(LocalizedStringKey("Clear All Data"), systemImage: "trash.fill")
                                Spacer()
                                if isProcessing { ProgressView() } else { Text(LocalizedStringKey("DANGER")).font(.caption).foregroundColor(.secondary) }
                            }
                        }.disabled(isProcessing)
                    }
                }
#endif
                Section {
                    DisclosureGroup(LocalizedStringKey("Support & Feedback")) {
                        NavigationLink(destination: FeedbackView()) { Label(LocalizedStringKey("Send Feedback"), systemImage: "envelope.fill") }
                        Button { showExportFormatPicker = true } label: { Label(LocalizedStringKey("Export All Data"), systemImage: "square.and.arrow.up") }
                        .confirmationDialog(LocalizedStringKey("Export Format"), isPresented: $showExportFormatPicker) {
                            Button(LocalizedStringKey("Export as JSON")) { exportAllData(format: .json) }
                            Button(LocalizedStringKey("Export as CSV")) { exportAllData(format: .csv) }
                            Button(LocalizedStringKey("Cancel"), role: .cancel) { }
                        }
                    }
                }
                
                Section {
                    DisclosureGroup(LocalizedStringKey("About")) {
                        Text(LocalizedStringKey("Version 1.0.0")).foregroundColor(.secondary)
                    }
                }
            }
            .onChange(of: isProfileFocused) { _, isFocused in if !isFocused { triggerLightHaptic() } }
            .navigationTitle(LocalizedStringKey("Settings"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(LocalizedStringKey("Done")) { dismiss() } }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button(LocalizedStringKey("Done")) { isProfileFocused = false }.bold() }
            }
            .alert(LocalizedStringKey("Test Data"), isPresented: $showTestDataAlert) { Button(LocalizedStringKey("OK"), role: .cancel) { } } message: { Text(testDataAlertMessage) }
            .alert(LocalizedStringKey("Clear All Data?"), isPresented: $showClearAllAlert) {
                Button(LocalizedStringKey("Clear All"), role: .destructive) { clearAllWorkouts() }
                Button(LocalizedStringKey("Cancel"), role: .cancel) { }
            } message: { Text(LocalizedStringKey("Are you sure you want to delete all data? This action cannot be undone.")) }
            .sheet(item: $fileToShare) { url in ActivityViewController(activityItems: [url]).presentationDetents([.medium, .large]) }
        }
    }
    
    private func triggerLightHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    private func generateTestData() {
        isProcessing = true
        let container = modelContext.container
        Task.detached {
            let generator = TestDataGenerator(modelContainer: container)
            await generator.generateAllData()
            
            let repo = WorkoutRepository(modelContainer: container)
            await repo.rebuildAllStats()
            
            await MainActor.run {
                self.viewModel.refreshAllCaches()
                self.isProcessing = false
                self.testDataAlertMessage = "Test data generated successfully!\n\nCreated workouts and weight tracking history from 2021 to 2026."
                self.showTestDataAlert = true
            }
        }
    }

    private func clearAllWorkouts() {
        isProcessing = true
        let container = modelContext.container
        Task.detached {
            let generator = TestDataGenerator(modelContainer: container)
            await generator.clearAllDataAsync()
            
            let repo = WorkoutRepository(modelContainer: container)
            await repo.rebuildAllStats()
            
            await MainActor.run {
                self.viewModel.refreshAllCaches()
                self.isProcessing = false
                self.testDataAlertMessage = "All workouts and weight history cleared."
                self.showTestDataAlert = true
            }
        }
    }
    
    private enum ExportFormat { case json, csv }
    
    private func exportAllData(format: ExportFormat) {
        isProcessing = true
        let container = modelContext.container
        Task.detached(priority: .userInitiated) {
            let bgContext = ModelContext(container)
            let descriptor = FetchDescriptor<Workout>(sortBy: [SortDescriptor(\.date, order: .reverse)])
            let workouts = (try? bgContext.fetch(descriptor)) ?? []
            let fileURL: URL?
            switch format {
            case .json: fileURL = DataManager.shared.exportAllDataAsJSON(workouts: workouts)
            case .csv: fileURL = DataManager.shared.exportAllDataToCSV(workouts: workouts)
            }
            await MainActor.run {
                self.isProcessing = false
                if let fileURL = fileURL { self.fileToShare = fileURL } else {
                    self.testDataAlertMessage = "Failed to export data. Please try again."
                    self.showTestDataAlert = true
                }
            }
        }
    }
}
