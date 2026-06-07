internal import SwiftUI
internal import UniformTypeIdentifiers
import SwiftData
import UIKit
import FirebaseAuth
import AuthenticationServices
import GoogleSignIn
import FirebaseFunctions

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(DIContainer.self) private var di
    @Environment(AuthManager.self) private var authManager
    @AppStorage(Constants.UserDefaultsKeys.includeWarmupsInStats.rawValue) private var includeWarmupsInStats: Bool = false
    @State private var isProcessing = false
    @State private var showTestDataAlert = false
    @State private var testDataAlertMessage = ""
    @State private var showClearAllAlert = false
    @State private var fileToShare: SharedFileWrapper?
    @State private var showDeleteProfileAlert = false
    @State private var showDeleteSuccessAlert = false
    @State private var showSignOutAlert = false
    @State private var showSignOutSuccessAlert = false
    @State private var showDeleteAccountAlert = false
    @State private var deleteAccountError: String?
    @State private var showDeleteAccountError = false
    @State private var authErrorMessage: String?
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            List {
                preferencesSection
                workoutOptionsSection
                gamificationSection
                supportAndDataSection
                accountSection

                #if DEBUG
                debugSection
                #endif

                appVersionSection
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
            .alert("Sign Out", isPresented: $showSignOutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    Task { await signOut() }
                }
            } message: {
                Text("Are you sure you want to sign out? This will clear all data on this device. You can access it again by signing back in.")
            }
            .alert("Signed Out", isPresented: $showSignOutSuccessAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("You have been successfully signed out. You are now using a guest account.")
            }
            .alert("Authentication Error", isPresented: Binding(get: { authErrorMessage != nil }, set: { if !$0 { authErrorMessage = nil } })) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(authErrorMessage ?? "")
            }
            .alert("Data Deleted", isPresented: $showDeleteSuccessAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("All your profile data and history have been successfully deleted. Please restart the app to set up a new profile.")
            }
            .alert(LocalizedStringKey("Clear All Data?"), isPresented: $showClearAllAlert) {
                Button(LocalizedStringKey("Clear All"), role: .destructive) {
                }
                Button(LocalizedStringKey("Cancel"), role: .cancel) { }
            } message: {
                Text(LocalizedStringKey("Are you sure you want to delete all data? This action cannot be undone."))
            }
        }
    }

    @ViewBuilder
    private var preferencesSection: some View {
        Section(header: Text(LocalizedStringKey("Preferences"))) {
            NavigationLink(destination: AppearanceSettingsView()) {
                Label {
                    Text(LocalizedStringKey("Appearance & Profile"))
                } icon: {
                    Image(systemName: "person.crop.circle").foregroundStyle(Color.accentColor)
                }
            }
            NavigationLink(destination: UnitsSettingsView()) {
                Label {
                    Text(LocalizedStringKey("Units of Measure"))
                } icon: {
                    Image(systemName: "ruler").foregroundStyle(Color.accentColor)
                }
            }
        }
    }

    @ViewBuilder
    private var workoutOptionsSection: some View {
        Section(header: Text(LocalizedStringKey("Workout Options"))) {
            NavigationLink(destination: TimerSettingsView()) {
                Label {
                    Text(LocalizedStringKey("Rest Timer"))
                } icon: {
                    Image(systemName: "timer").foregroundStyle(Color.accentColor)
                }
            }
            NavigationLink(destination: AudioSettingsView()) {
                Label {
                    Text(LocalizedStringKey("Voice Coach"))
                } icon: {
                    Image(systemName: "speaker.wave.3.fill").foregroundStyle(Color.accentColor)
                }
            }
            Toggle(isOn: $includeWarmupsInStats) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStringKey("Include Warmups in Stats"))
                        
                    Text(LocalizedStringKey("If enabled, warm-up sets will be counted in total volume and personal records."))
                        .font(.caption)
                        .foregroundColor(themeManager.current.secondaryText)
                }
            }
            .tint(.accentColor)
        }
    }

    @ViewBuilder
    private var gamificationSection: some View {
        Section(header: Text(LocalizedStringKey("Gamification"))) {
            NavigationLink(destination: StreakSettingsView()) {
                Label {
                    Text(LocalizedStringKey("Streak Settings"))
                } icon: {
                    Image(systemName: "flame.fill").foregroundStyle(Color.accentColor)
                }
            }
        }
    }

        @ViewBuilder
    private var supportAndDataSection: some View {
        Section(header: Text(LocalizedStringKey("Support & Data"))) {
            Button(action: {
                AppReviewManager.openAppStoreReview()
            }) {
                Label {
                    Text(LocalizedStringKey("Rate the App"))
                        .foregroundColor(colorScheme == .dark ? themeManager.current.primaryText : .primary)
                } icon: {
                    Image(systemName: "star.fill").foregroundStyle(Color.accentColor)
                }
            }

            NavigationLink(destination: FeedbackView()) {
                Label {
                    Text(LocalizedStringKey("Send Feedback"))
                } icon: {
                    Image(systemName: "envelope.fill").foregroundStyle(Color.accentColor)
                }
            }

            Link(destination: Constants.Legal.privacyPolicyURL) {
                HStack {
                    Label {
                        Text(LocalizedStringKey("Privacy Policy"))
                            .foregroundColor(colorScheme == .dark ? themeManager.current.primaryText : .primary)
                    } icon: {
                        Image(systemName: "hand.raised.fill").foregroundStyle(Color.accentColor)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.forward.app")
                        .font(.caption)
                        .foregroundColor(themeManager.current.secondaryText)
                }
            }

            Link(destination: Constants.Legal.eulaURL) {
                HStack {
                    Label {
                        Text(LocalizedStringKey("Terms of Use (EULA)"))
                            .foregroundColor(colorScheme == .dark ? themeManager.current.primaryText : .primary)
                    } icon: {
                        Image(systemName: "doc.text.fill").foregroundStyle(Color.accentColor)
                    }
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
                Label {
                    Text(LocalizedStringKey("Export All Data"))
                        .foregroundColor(colorScheme == .dark ? themeManager.current.primaryText : .primary)
                } icon: {
                    Image(systemName: "square.and.arrow.up").foregroundStyle(Color.accentColor)
                }
            }

            Button(role: .destructive) {
                showDeleteProfileAlert = true
            } label: {
                Label {
                    Text(LocalizedStringKey("Delete Profile & Data"))
                        .foregroundColor(.red)
                } icon: {
                    Image(systemName: "trash").foregroundStyle(.red)
                }
            }
            
            if !authManager.isAnonymous {
                Button(role: .destructive) {
                    showDeleteAccountAlert = true
                } label: {
                    HStack {
                        Label {
                            Text(LocalizedStringKey("Delete Account"))
                                .foregroundColor(.red)
                        } icon: {
                            Image(systemName: "person.crop.circle.badge.xmark").foregroundStyle(.red)
                        }
                        Spacer()
                        if isProcessing { ProgressView() }
                    }
                }
                .disabled(isProcessing)
            }
        }
    }

    @ViewBuilder
    private var appVersionSection: some View {
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

        @ViewBuilder
    private var accountSection: some View {
        if authManager.isAnonymous {
            Section(
                header: Text(LocalizedStringKey("Account")),
                footer: Text(LocalizedStringKey("Register an account to securely save your progress, sync across devices, and share workouts."))
            ) {
                Button(action: {
                    Task {
                        isProcessing = true
                        do {
                            try await SocialAuthService.shared.signInWithApple()
                        } catch {
                            authErrorMessage = error.localizedDescription
                        }
                        isProcessing = false
                    }
                }) {
                    HStack {
                        Image(systemName: "apple.logo")
                        Text("Continue with Apple")
                        Spacer()
                        if isProcessing { ProgressView() }
                    }
                }
                .buttonStyle(SettingsGlassAuthButtonStyle())
                .disabled(isProcessing)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                Button(action: {
                    Task {
                        isProcessing = true
                        do {
                            try await SocialAuthService.shared.signInWithGoogle()
                        } catch let error as NSError where error.code == GIDSignInError.canceled.rawValue {
                            // Ignored
                        } catch {
                            authErrorMessage = error.localizedDescription
                        }
                        isProcessing = false
                    }
                }) {
                    HStack {
                        Image(systemName: "globe")
                        Text("Continue with Google")
                        Spacer()
                        if isProcessing { ProgressView() }
                    }
                }
                .buttonStyle(SettingsGlassAuthButtonStyle())
                .disabled(isProcessing)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
        } else {
            Section(
                header: Text(LocalizedStringKey("Account"))
            ) {
                if let user = authManager.currentUser {
                    HStack {
                        Label {
                            Text("Signed in as")
                                .foregroundColor(themeManager.current.secondaryText)
                        } icon: {
                            Image(systemName: "person.circle.fill").foregroundStyle(Color.accentColor)
                        }
                        Spacer()
                        Text(user.email ?? user.displayName ?? "User")
                            .foregroundColor(themeManager.current.primaryText)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                Button(role: .cancel) {
                    showSignOutAlert = true
                } label: {
                    HStack {
                        Label {
                            Text(LocalizedStringKey("Sign Out"))
                                .foregroundColor(.orange)
                        } icon: {
                            Image(systemName: "rectangle.portrait.and.arrow.right").foregroundStyle(.orange)
                        }
                        Spacer()
                        if isProcessing { ProgressView() }
                    }
                }
                .disabled(isProcessing)
            }
        }
    }

    #if DEBUG
    private var debugSection: some View {
        Section(footer: Text(LocalizedStringKey("These buttons are for testing only. Remove TestDataGenerator.swift and this section after testing."))) {
            Button(role: .destructive) { Task { await generateTestData() } } label: {
                HStack {
                    Label {
                    Text(LocalizedStringKey("Generate All Test Data"))
                } icon: {
                    Image(systemName: "flask.fill").foregroundStyle(Color.accentColor)
                }
                    Spacer()
                    if isProcessing { ProgressView() }
                }
            }
            .disabled(isProcessing)

            Button(role: .destructive) { showClearAllAlert = true } label: {
                HStack {
                    Label {
                    Text(LocalizedStringKey("Clear All Data"))
                } icon: {
                    Image(systemName: "trash.fill").foregroundStyle(.red)
                }
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

    // MARK: - Sign Out
    private func signOut() async {
        isProcessing = true
        defer { isProcessing = false }
        do {
            try await SocialAuthService.shared.signOut()
            deleteLocalData()
            showSignOutSuccessAlert = true
        } catch {
            authErrorMessage = "Failed to sign out: \(error.localizedDescription)"
        }
    }

    // MARK: - Account / Data deletion
    /// Guideline 5.1.1(v): full in-app account deletion.
    /// Order matters: re-auth + Apple token revocation MUST happen BEFORE any
    /// destructive server-side deletion, otherwise we risk an orphaned Auth
    /// account and an un-revoked Apple refresh token.
    private func deleteAccount() async {
        isProcessing = true
        defer { isProcessing = false }
        do {
            // 0) Re-authenticate the user and, for Sign in with Apple, revoke the
            //    Apple refresh token. Nothing destructive runs until this succeeds.
            //    If the user cancels the auth sheet, this throws and we abort with
            //    all data still intact.
            try await SocialAuthService.shared.reauthenticateForDeletion()

            // 1) Delete all server-side Firestore data (shared_workouts, reports,
            //    users/{uid} + blocked subcollection) using the Admin SDK.
            let functions = Functions.functions(region: "us-central1")
            _ = try await functions.httpsCallable("deleteAccount").call()

            // 2) Delete the Firebase Auth account. The recent re-auth in step 0
            //    satisfies requiresRecentLogin for Apple/Google users.
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
            Constants.UserDefaultsKeys.hasConsentedToAI.rawValue,
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
    @AppStorage(Constants.UserDefaultsKeys.appearanceMode.rawValue) private var appearanceMode: String = "dark"
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
                        Text(LocalizedStringKey("Language"))
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

struct SettingsGlassAuthButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundStyle(colorScheme == .dark ? .white : .black)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .padding(.horizontal, 16)
            .background(colorScheme == .dark ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.white), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.accentColor.opacity(colorScheme == .dark ? 0.6 : 0.4), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
