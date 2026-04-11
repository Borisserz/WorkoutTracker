// ============================================================
// FILE: WatchApp/Views/WatchActiveWorkoutView.swift
// ============================================================
internal import SwiftUI

struct WatchActiveWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(WatchWorkoutManager.self) private var workoutManager
    @Bindable var viewModel: WatchActiveWorkoutViewModel
    
    @State private var startDate = Date()
    
    var body: some View {
        ZStack {
            WatchTheme.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 12) {
                    hudSection
                    
                    if viewModel.exercises.isEmpty {
                        Text("No exercises.\nTap + to add one.")
                            .font(.footnote)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.vertical, 20)
                    } else {
                        ForEach(viewModel.exercises.indices, id: \.self) { index in
                            NavigationLink {
                                WatchExerciseSetView(viewModel: viewModel, exerciseIndex: index)
                            } label: {
                                exerciseRow(for: viewModel.exercises[index])
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    actionButtonsSection
                }
                .padding(.bottom, 24)
            }
        }
        .navigationBarHidden(true)
        .task {
            await workoutManager.startWorkout()
            await viewModel.initializeWorkout()
        }
        .onAppear { startDate = Date() }
        .onDisappear {
            viewModel.cleanup() // Replaces the deinit task cancellation
        }
        // MARK: - Full Screen Overlays (The Workout Flow)
        .fullScreenCover(isPresented: $viewModel.showRestTimer) {
            WatchRestTimerView(viewModel: viewModel)
        }
        .fullScreenCover(isPresented: $viewModel.showRPE) {
            WatchRPEView(viewModel: viewModel)
        }
        .fullScreenCover(isPresented: $viewModel.showSummary) {
            WatchSummaryView(viewModel: viewModel) { dismiss() }
        }
    }
    
    private var hudSection: some View {
        HStack {
            TimelineView(.periodic(from: startDate, by: 1.0)) { context in
                let elapsed = context.date.timeIntervalSince(startDate)
                Text(Duration.seconds(elapsed), format: .time(pattern: .minuteSecond))
                    .font(.system(size: 24, weight: .black, design: .rounded).monospacedDigit())
                    .foregroundColor(WatchTheme.cyan)
            }
            
            Spacer()
            
            HStack(spacing: 2) {
                Text("\(Int(workoutManager.heartRate))")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                Image(systemName: "heart.fill")
                    .foregroundColor(WatchTheme.red)
                    .font(.system(size: 14))
                    .symbolEffect(.pulse, options: .repeating, isActive: workoutManager.isRunning)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    private func exerciseRow(for exercise: ExerciseDTO) -> some View {
        let completedSets = (exercise.setsList ?? []).count
        let totalSets = exercise.sets ?? 3
        let isDone = completedSets >= totalSets
        
        return HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(isDone ? .gray : .white)
                    .lineLimit(2)
                
                Text("\(completedSets)/\(totalSets) Sets")
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundColor(isDone ? WatchTheme.green : WatchTheme.cyan)
            }
            Spacer()
            if isDone {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(WatchTheme.green)
                    .font(.title3)
            } else {
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(WatchTheme.surface)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isDone ? WatchTheme.green.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
    
    private var actionButtonsSection: some View {
        VStack(spacing: 10) {
            Button {
                Task { await viewModel.addExercise(name: "Custom Exercise") }
            } label: {
                HStack {
                    Image(systemName: "plus")
                    Text("Add Exercise")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(WatchTheme.surfaceVariant)
                .cornerRadius(16)
            }
            .buttonStyle(.plain)
            
            HStack(spacing: 10) {
                Button(role: .destructive) {
                    Task {
                        await viewModel.cancelWorkout()
                        await workoutManager.endWorkout()
                        dismiss()
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.title2.bold())
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(WatchTheme.surfaceVariant)
                        .foregroundColor(WatchTheme.red)
                        .cornerRadius(16)
                }
                .buttonStyle(.plain)
                
                Button {
                    Task {
                        await workoutManager.endWorkout()
                        await viewModel.finishWorkout()
                    }
                } label: {
                    Text("Finish")
                        .font(.headline.bold())
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(WatchTheme.primaryGradient)
                        .foregroundColor(.black)
                        .cornerRadius(16)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 8)
    }
}
