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
            ScrollView {
                VStack(spacing: 12) {
                    
                    // Sync Button
                    Button {
                        WKInterfaceDevice.current().play(.click)
                        WatchSyncManager.shared.modelContext = context
                        WatchSyncManager.shared.requestPresetsFromPhone()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Sync with iPhone")
                        }
                        .font(.headline)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(WatchTheme.primaryGradient)
                        .cornerRadius(20)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                    
                    // Empty Workout
                    Button(action: startEmptyWorkout) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(WatchTheme.cyan)
                                .font(.title3)
                            Text("Empty Workout")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        .padding()
                        .background(WatchTheme.surface)
                        .cornerRadius(16)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                    
                    // My Routines
                    if myPresets.isEmpty {
                        Text("No routines found.\nTap Sync to load from iPhone.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.top, 20)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("MY ROUTINES")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.gray)
                                .padding(.horizontal)
                                .padding(.top, 8)
                            
                            ForEach(myPresets) { preset in
                                Button(action: { startPresetWorkout(preset) }) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(preset.name)
                                            .font(.headline)
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                        Text("\(preset.exercises.count) Exercises")
                                            .font(.footnote)
                                            .foregroundColor(WatchTheme.cyan)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding()
                                    .background(WatchTheme.surface)
                                    .cornerRadius(16)
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal)
                            }
                        }
                    }
                }
            }
            .background(WatchTheme.background.ignoresSafeArea())
            .navigationTitle("Workouts")
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
                WatchSyncManager.shared.modelContext = context
            }
        }
    }
    
    private func startEmptyWorkout() { workoutToStart = (id: UUID(), title: "Watch Workout", presetDTO: nil) }
    private func startPresetWorkout(_ preset: WorkoutPreset) { workoutToStart = (id: UUID(), title: preset.name, presetDTO: preset.toDTO()) }
}
