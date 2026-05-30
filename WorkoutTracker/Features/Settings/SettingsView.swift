internal import SwiftUI
internal import UniformTypeIdentifiers
import SwiftData
import UIKit
import FirebaseAuth
import FirebaseFunctions

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
    @State private var showDeleteProfileAlert = false
    @State private var showDeleteSuccessAlert = false
    @State private var showDeleteAccountAlert = false
    @State private var deleteAccountError: String?
    @State private var showDeleteAccountError = false
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme

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
                                .foregroundColor(colorScheme == .dark ? themeManager.current.primaryText : .primary)
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

                    Link(destination: Constants.Legal.privacyPolicyURL) {
                        HStack {
                            Label(LocalizedStringKey("Privacy Policy"), systemImage: "hand.raised.fill")
                                .foregroundColor(colorScheme == .dark ? themeManager.current.primaryText : .primary)
                            Spacer()
                            Image(systemName: "arrow.up.forward.app")
                                .font(.caption)
                                .foregroundColor(themeManager.current.secondaryText)
                        }
                    }

                    Link(destination: Constants.Legal.eulaURL) {
                        HStack {
                            Label(LocalizedStringKey("Terms of Use (EULA)"), systemImage: "doc.text.fill")
                                .foregroundColor(colorScheme == .dark ? themeManager.current.primaryText : .primary)
                            Spacer()
                            Image(systemName: "arrow.up.forward.app")
                                .font(.caption)
                                .foregroundColor(themeManager.current.secondaryText)
                        }
                    }

                    Menu {
                        Button(action: { Task { await exportAllData(format: .json) } }) {
                            Label("Export as JSON", systemImage: "curlybraces")
                        }
                        Button(action: { Task { await exportAllData(format: .csv) } }) {
                            Label("Export as CSV", systemImage: "tablecells")
                        }
                    } label: {
                        Label(LocalizedStringKey("Export All Data"), systemImage: "square.and.arrow.up")
                            .foregroundColor(colorScheme == .dark ? themeManager.current.primaryText : .primary)
                    }

                    Button(role: .destructive) {
                        showDeleteProfileAlert = true
                    } label: {
                        Label(LocalizedStringKey("Delete Profile & Data"), systemImage: "trash")
                            .foregroundColor(.red)
                    }
                }

                Section(
                    header: Text(LocalizedStringKey("Account")),
                    footer: Text(LocalizedStringKey("Permanently deletes your account and all associated data from our servers, including shared workouts, your blocked list, and submitted reports. This cannot be undone."))
                ) {
                    Button(role: .destructive) {
                        showDeleteAccountAlert = true
                    } label: {
                        HStack {
                            Label(LocalizedStringKey("Delete Account"), systemImage: "person.crop.circle.badge.xmark")
                                .foregroundColor(.red)
                            Spacer()
                            if isProcessing { ProgressView() }
                        }
                    }
                    .disabled(isProcessing)
                }

                #if DEBUG
                debugSection
                #endif

                Section {
                    HStack {
                        Spacer()
                        Text(appVersionString)
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
            .sheet(item: $fileToShare) { wrapper in
                ActivityViewController(activityItems: [wrapper.url])
                    .presentationDetents([.medium, .large])
            }
            .alert(LocalizedStringKey("Test Data"), isPresented: $showTestDataAlert) {
                Button(LocalizedStringKey("OK"), role: .cancel) { }
            } message: {
                Text(testDataAlertMessage)
            }
            .alert("Delete Profile & Data", isPresented: $showDeleteProfileAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete Everything", role: .destructive) {
                    deleteProfileAndData()
                }
            } message: {
                Text("This will permanently delete your profile, body measurements, all workouts, and settings. This action cannot be undone.")
            }
            .alert("Delete Account", isPresented: $showDeleteAccountAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete Account", role: .destructive) {
                    Task { await deleteAccount() }
                }
            } message: {
                Text("This permanently deletes your account and all server-side data (shared workouts, blocked list, reports) as well as everything on this device. This action cannot be undone.")
            }
            .alert("Couldn't Delete Account", isPresented: $showDeleteAccountError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(deleteAccountError ?? "Unknown error")
            }
            .alert("Data Deleted", isPresented: $showDeleteSuccessAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("All your profile data and history have been successfully deleted. Please restart the app to set up a new profile.")
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
            }
            .disabled(isProcessing)

            Button(role: .destructive) { showClearAllAlert = true } label: {
                HStack {
                    Label(LocalizedStringKey("Clear All Data"), systemImage: "trash.fill")
                    Spacer()
                    if isProcessing { ProgressView() }
                }
            }
            .disabled(isProcessing)
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
    private var appVersionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "Version \(version) (\(build))"
    }
    private enum ExportFormat { case json, csv }

    private func exportAllData(format: ExportFormat) async {
        isProcessing = true
        let bgContext = ModelContext(di.modelContainer)
        let descriptor = FetchDescriptor<Workout>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        let workouts = (try? bgContext.fetch(descriptor)) ?? []

        let fileURL: URL?
        switch format {
        case .json: fileURL = DataManager.shared.exportAllDataAsJSON(workouts: workouts)
        case .csv:  fileURL = DataManager.shared.exportAllDataToCSV(workouts: workouts)
        }

        self.isProcessing = false
        if let fileURL = fileURL {
            self.fileToShare = SharedFileWrapper(url: fileURL)
        } else {
            self.testDataAlertMessage = "Failed to export data. Please try again."
            self.showTestDataAlert = true
        }
    }

    // MARK: - Account / Data deletion

    /// Guideline 5.1.1(v): full in-app account deletion.
    /// 1) Deletes ALL server-side data via the Admin-SDK Cloud Function.
    /// 2) Deletes the Firebase Auth account itself.
    /// 3) Wipes all local data on this device.
    private func deleteAccount() async {
        isProcessing = true
        defer { isProcessing = false }
        do {
            // 1) Delete all server-side Firestore data (shared_workouts, reports,
            //    users/{uid} + blocked subcollection) using the Admin SDK.
            let functions = Functions.functions(region: "us-central1")
            _ = try await functions.httpsCallable("deleteAccount").call()

            // 2) Delete the Firebase Auth account.
            //    Anonymous users don't require recent re-auth, so this succeeds.
            try await Auth.auth().currentUser?.delete()

            // 3) Stop the blocked-list listener and wipe local storage.
            await BlockedUsersStore.shared.stopListening()
            deleteLocalData()
            showDeleteSuccessAlert = true
        } catch {
            deleteAccountError = error.localizedDescription
            showDeleteAccountError = true
        }
    }

    /// Local-only deletion: clears SwiftData models and UserDefaults keys.
    private func deleteProfileAndData() {
        isProcessing = true
        deleteLocalData()
        isProcessing = false
        showDeleteSuccessAlert = true
    }

    /// Shared helper that removes all on-device data.
    private func deleteLocalData() {
        do {
            try modelContext.delete(model: Workout.self)
            try modelContext.delete(model: Exercise.self)
            try modelContext.delete(model: WorkoutSet.self)
            try modelContext.delete(model: WeightEntry.self)
            try modelContext.delete(model: UserStats.self)
            try modelContext.delete(model: ExerciseStat.self)
            try modelContext.delete(model: MuscleStat.self)
            try modelContext.delete(model: ExerciseNote.self)
            try modelContext.delete(model: BodyMeasurement.self)
            try modelContext.delete(model: UserGoal.self)
            try modelContext.delete(model: AIChatSession.self)

            let customPresetsDesc = FetchDescriptor<WorkoutPreset>(predicate: #Predicate { $0.isSystem == false })
            if let customPresets = try? modelContext.fetch(customPresetsDesc) {
                for preset in customPresets { modelContext.delete(preset) }
            }
            try modelContext.save()
        } catch {
            print("Failed to clear SwiftData: \(error)")
        }

        let keysToReset = [
            Constants.UserDefaultsKeys.userName.rawValue,
            Constants.UserDefaultsKeys.userBodyWeight.rawValue,
            Constants.UserDefaultsKeys.userGender.rawValue,
            "userHeight",
            "userAge",
            "hasConsentedToAI",
            Constants.UserDefaultsKeys.hasSeenTutorial_Final_v8.rawValue
        ]
        for key in keysToReset {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}

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
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme

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
                        Text(LocalizedStringKey("Language")).foregroundColor(colorScheme == .dark ? themeManager.current.primaryText : .primary)
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
                            Text("\(seconds / 60) min").tag(seconds)
                        } else {
                            Text("\(seconds) sec").tag(seconds)
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
                        Text("\(streakRestDays) " + (streakRestDays > 1 ? "days" : "day"))
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

struct SettingsCheckmarkRow: View {
    let title: LocalizedStringKey
    let isSelected: Bool
    let action: () -> Void
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            action()
        }) {
            HStack {
                Text(title)
                    .foregroundColor(colorScheme == .dark ? themeManager.current.primaryText : .primary)
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
