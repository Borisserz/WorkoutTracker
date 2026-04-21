

internal import SwiftUI

struct WatchActiveWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(WatchWorkoutManager.self) private var workoutManager
    @Bindable var viewModel: WatchActiveWorkoutViewModel

    @State private var showExerciseList = false
    @State private var showCancelAlert = false

    var body: some View {
        ZStack {
            WatchTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 12) {
                    headerSection

                    if viewModel.exercises.isEmpty {
                        Text("No exercises.\nTap Add below.")
                            .font(.footnote)
                            .foregroundColor(.gray)
                            .padding(.vertical, 20)
                            .multilineTextAlignment(.center)
                    } else {
                        ForEach(viewModel.exercises.indices, id: \.self) { index in
                            Button {
                                viewModel.activeExercise = ActiveExerciseWrapper(index: index)
                            } label: {
                                exerciseCard(for: viewModel.exercises[index])
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    actionsMenuSection
                }
                .padding(.bottom, 24)
            }
        }
        .navigationBarHidden(true)
        .task {

                    if !viewModel.isInitialized {

                        try? await workoutManager.requestAuthorization()

                        await workoutManager.startWorkout()
                        await viewModel.initializeWorkout()
                    }
                }
        .onDisappear { viewModel.cleanup() }
        .sheet(isPresented: $showExerciseList) {
            WatchExerciseSelectionView { exerciseName in
                Task { await viewModel.addExercise(name: exerciseName) }
                showExerciseList = false
            }
        }

        .sheet(isPresented: $viewModel.showRestTimer) {
            WatchRestTimerView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showRPE) {
            WatchRPEView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showSummary) {
            WatchSummaryView(viewModel: viewModel) {
                viewModel.showSummary = false
                dismiss()
            }
        }
        .alert("Cancel Workout?", isPresented: $showCancelAlert) {
            Button("Discard", role: .destructive) {
                Task {
                    await viewModel.cancelWorkout()
                    await workoutManager.endWorkout()
                    dismiss()
                }
            }
            Button("Keep Training", role: .cancel) { }
        } message: {
            Text("Are you sure you want to discard this workout?")
        }
        .navigationDestination(item: $viewModel.activeExercise) { wrapper in
            WatchExerciseSetView(viewModel: viewModel, exerciseIndex: wrapper.id)
        }
        .onChange(of: viewModel.goBackToWorkoutView) { _, shouldGoBack in
            if shouldGoBack {
                viewModel.activeExercise = nil
                viewModel.goBackToWorkoutView = false

                if let nextIndex = viewModel.pendingNextExerciseIndex {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        viewModel.activeExercise = ActiveExerciseWrapper(index: nextIndex)
                        viewModel.pendingNextExerciseIndex = nil
                    }
                }
            }
        }
    }

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.workoutTitle)
                    .font(.headline)
                    .foregroundColor(.white)

                TimelineView(.periodic(from: viewModel.startDate, by: 1.0)) { context in
                    let elapsed = context.date.timeIntervalSince(viewModel.startDate)
                    Text(Duration.seconds(elapsed), format: .time(pattern: .minuteSecond))
                        .font(.system(size: 16, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundColor(.white)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 4)
    }

    private func exerciseCard(for exercise: ExerciseDTO) -> some View {
        let completedSets = (exercise.setsList ?? []).filter { $0.isCompleted }.count

        let totalSets = (exercise.setsList ?? []).count
        let isDone = completedSets >= totalSets && totalSets > 0

        return HStack(spacing: 12) {

            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(isDone ? .gray : .white)
                    .lineLimit(2)

                Text("\(completedSets)/\(totalSets) Sets")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(isDone ? WatchTheme.green : WatchTheme.cyan)
            }
            Spacer()
        }
        .padding(12)
        .background(WatchTheme.cardBackground)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(isDone ? WatchTheme.green.opacity(0.3) : Color.clear, lineWidth: 1))
    }
    private var actionsMenuSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Actions")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .padding(.top, 16)
                .padding(.horizontal, 4)

            Button {
                showExerciseList = true
            } label: {
                Text("Add Exercise")
                    .font(.system(size: 15, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(WatchTheme.buttonGray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }.buttonStyle(.plain)

            HStack(spacing: 10) {
                Button(role: .destructive) {
                    showCancelAlert = true
                } label: {
                    Image(systemName: "xmark")
                        .font(.title2.bold())
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(WatchTheme.buttonGray)
                        .foregroundColor(WatchTheme.red)
                        .cornerRadius(16)
                }.buttonStyle(.plain)

                Button {
                    Task {
                        await workoutManager.endWorkout()

                        await viewModel.finishWorkout(activeEnergy: workoutManager.activeEnergy)
                    }
                } label: {
                    Text("Finish")
                        .font(.headline.bold())
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(WatchTheme.blue)
                        .foregroundColor(.white)
                        .cornerRadius(16)
                }.buttonStyle(.plain)
            }
        }
    }
}
