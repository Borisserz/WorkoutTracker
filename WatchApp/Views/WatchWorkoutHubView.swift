// ============================================================
// FILE: WatchApp/Views/WatchWorkoutHubView.swift
// ============================================================
internal import SwiftUI
import SwiftData

struct WatchWorkoutHubView: View {
    @Environment(\.modelContext) private var context
    
    @Query(filter: #Predicate<WorkoutPreset> { $0.isSystem == false }, sort: \WorkoutPreset.name)
    private var myPresets: [WorkoutPreset]
    
    @State private var workoutToStart: (id: UUID, title: String, presetDTO: WorkoutPresetDTO?)? = nil
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button(action: {
                        // Привязываем контекст к менеджеру и запрашиваем пресеты
                        WatchSyncManager.shared.modelContext = context
                        WatchSyncManager.shared.requestPresetsFromPhone()
                    }) {
                        Label("Sync with iPhone", systemImage: "arrow.triangle.2.circlepath")
                            .foregroundColor(.blue)
                    }
                }
                
                Section {
                    Button(action: startEmptyWorkout) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.green)
                                .font(.title2)
                            Text("Empty Workout")
                                .bold()
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                Section(header: Text("My Routines")) {
                    if myPresets.isEmpty {
                        Text("No routines found.\nTap Sync to load from iPhone.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(myPresets) { preset in
                            Button(action: { startPresetWorkout(preset) }) {
                                VStack(alignment: .leading) {
                                    Text(preset.name).font(.headline)
                                    Text("\(preset.exercises.count) exercises")
                                        .font(.caption2).foregroundColor(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Workout")
            .navigationDestination(isPresented: Binding(
                get: { workoutToStart != nil },
                set: { if !$0 { workoutToStart = nil } }
            )) {
                if let config = workoutToStart {
                    let vm = WatchActiveWorkoutViewModel(
                        workoutID: config.id,
                        workoutTitle: config.title,
                        presetDTO: config.presetDTO,
                        store: WatchWorkoutStore(modelContainer: context.container)
                    )
                    WatchActiveWorkoutView(viewModel: vm)
                }
            }
            .onAppear {
                // Устанавливаем контекст при появлении экрана
                WatchSyncManager.shared.modelContext = context
            }
        }
    }
    
    private func startEmptyWorkout() {
        workoutToStart = (id: UUID(), title: "Watch Workout", presetDTO: nil)
    }
    
    private func startPresetWorkout(_ preset: WorkoutPreset) {
        workoutToStart = (id: UUID(), title: preset.name, presetDTO: preset.toDTO())
    }
}
