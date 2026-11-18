
internal import SwiftUI
import SwiftData

struct WatchWorkoutHubView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<WorkoutPreset> { $0.isSystem == false }, sort: \WorkoutPreset.name)
    private var myPresets: [WorkoutPreset]

    @State private var activeWorkoutVM: WatchActiveWorkoutViewModel? = nil

    private var groupedPresets: [String: [WorkoutPreset]] {
        Dictionary(grouping: myPresets) { preset in
            let name = preset.folderName ?? ""
            return name.isEmpty ? "My Routines" : name
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                WatchTheme.background.ignoresSafeArea()

                if myPresets.isEmpty {
                    emptyState
                } else {
                    List {
                        Button {
                            WKInterfaceDevice.current().play(.click)
                            startEmptyWorkout()
                        } label: {
                            Label("Start Empty Workout", systemImage: "plus.circle.fill")
                                .font(.system(size: 15, weight: .bold))
                        }
                        .listRowBackground(WatchTheme.green.opacity(0.24))
                        .listItemTint(WatchTheme.green)

                        Button {
                            WKInterfaceDevice.current().play(.click)
                            WatchSyncManager.shared.requestPresetsFromPhone()
                        } label: {
                            Label("Sync with iPhone", systemImage: "arrow.triangle.2.circlepath")
                                .font(.system(size: 15, weight: .bold))
                        }
                        .listRowBackground(WatchTheme.blue.opacity(0.3))
                        .listItemTint(WatchTheme.cyan)

                        ForEach(groupedPresets.keys.sorted(), id: \.self) { folder in
                            Section(header: Text(folder).fontWeight(.bold).foregroundColor(WatchTheme.cyan)) {
                                ForEach(groupedPresets[folder] ?? []) { preset in
                                    Button(action: { startPresetWorkout(preset) }) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(preset.name)
                                                .font(.system(size: 15, weight: .bold))
                                                .foregroundColor(.white)
                                                .lineLimit(1)
                                            Text("\(preset.exercises.count) Exercises")
                                                .font(.footnote)
                                                .foregroundColor(.gray)
                                        }
                                        .padding(.vertical, 4)
                                    }
                                    .listRowBackground(WatchTheme.cardBackground)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Workouts")
            .navigationDestination(item: $activeWorkoutVM) { vm in
                WatchActiveWorkoutView(viewModel: vm)
            }
            .onAppear {
                WatchSyncManager.shared.modelContext = context

                WatchSyncManager.shared.requestActiveStateFromPhone()
            }

            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("WatchStateRecoveryEvent"))) { notif in
                if let payload = notif.userInfo?["payload"] as? LiveSyncPayload, payload.action == .syncFullState {
                    restoreWorkout(from: payload)
                }
            }
        }
    }

    private var emptyState: some View {
        ScrollView {
            VStack(spacing: 10) {
                Button {
                    WKInterfaceDevice.current().play(.click)
                    startEmptyWorkout()
                } label: {
                    Label("Start Empty Workout", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(WatchTheme.green)

                Text("Or create routines on your iPhone and tap Sync.")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.gray)

                Button("Sync Now") {
                    WatchSyncManager.shared.requestPresetsFromPhone()
                }
                .buttonStyle(.bordered)
                .tint(WatchTheme.blue)
            }
            .padding()
        }
    }

    private func startEmptyWorkout() {
        let vm = WatchActiveWorkoutViewModel(
            workoutID: UUID(),
            workoutTitle: String(localized: "Quick Workout"),
            presetDTO: nil,
            store: WatchWorkoutStore(modelContainer: context.container)
        )
        vm.listenForRemoteUpdates()
        activeWorkoutVM = vm
    }

    private func startPresetWorkout(_ preset: WorkoutPreset) {
        let vm = WatchActiveWorkoutViewModel(workoutID: UUID(), workoutTitle: preset.name, presetDTO: preset.toDTO(), store: WatchWorkoutStore(modelContainer: context.container))
        vm.listenForRemoteUpdates()
        activeWorkoutVM = vm
    }

    private func restoreWorkout(from payload: LiveSyncPayload) {
            guard let uuid = UUID(uuidString: payload.workoutID) else { return }

            // Avoid tearing down the active Watch workout VM / HKWorkoutSession when already tracking this session.
            if let current = activeWorkoutVM, current.workoutID == uuid {
                current.applyRemoteDelta(payload)
                return
            }

            let vm = WatchActiveWorkoutViewModel(workoutID: uuid, workoutTitle: payload.workoutTitle ?? "Active Workout", presetDTO: nil, store: WatchWorkoutStore(modelContainer: context.container))
            vm.exercises = payload.exercises ?? []
            vm.isInitialized = true
            vm.listenForRemoteUpdates()
            activeWorkoutVM = vm
        }
}
