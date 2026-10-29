internal import SwiftUI
import SwiftData

struct SupersetCardView: View {
    @Environment(WorkoutDetailViewModel.self) var viewModel
    @Environment(TutorialManager.self) var tutorialManager
    @Environment(UnitsManager.self) var unitsManager

    @Bindable var superset: Exercise
    var workout: Workout
    @Binding var isExpanded: Bool
    var isCurrentExercise: Bool = false
    var onExpandNext: ((UUID) -> Void)? = nil

    @State private var showEffortSheet = false

    private var isActiveExercise: Bool { isCurrentExercise && !superset.isCompleted }
    private var isWorkoutCompleted: Bool { !workout.isActive }

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                headerView
                if isExpanded {
                    exerciseListView
                    finishButton
                } else {
                    collapsedInfoSection
                }
            }
            .padding()
            .background(isActiveExercise ? PastelTheme.cardSurfaceSubtle : PastelTheme.cardSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isActiveExercise ? PastelTheme.cardBorderFocused : PastelTheme.cardBorder, lineWidth: 1)
            )
        }
        .sheet(isPresented: $showEffortSheet, onDismiss: { if superset.isCompleted { finishSupersetAction() } }) {
            EffortInputView(effort: $superset.effort, exerciseName: superset.name)
        }
    }

    var headerView: some View {
        HStack {
            Image(systemName: "line.3.horizontal")
                .foregroundColor(PastelTheme.textTertiary)
                .font(.caption)
                .frame(width: 20, height: 20)
            HStack {
                Image(systemName: "link")
                    .foregroundColor(PastelTheme.pastelLavender)
                Text(String(localized: "Superset"))
                    .font(.headline)
                    .foregroundColor(PastelTheme.pastelLavender)
            }
            Spacer()
            Menu {
                Button(role: .destructive) {
                    viewModel.removeExercise(superset, from: workout)
                } label: {
                    Label(String(localized: "Remove Superset"), systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundColor(PastelTheme.textTertiary)
                    .padding(10)
            }
            .highPriorityGesture(TapGesture().onEnded { })
        }
        .padding(.bottom, 10)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { isExpanded.toggle() }
        }
    }

    private var collapsedInfoSection: some View {
        HStack {
            Spacer()
            Text(String(localized: "Tap to expand"))
                .font(.caption)
                .foregroundColor(PastelTheme.textTertiary)
                .italic()
            Spacer()
        }
        .padding(.vertical, 8)
    }

    var exerciseListView: some View {
        ForEach(superset.subExercises.indices, id: \.self) { index in
            let isLast = index == superset.subExercises.count - 1

            VStack(spacing: 0) {
                ExerciseCardView(
                    exercise: superset.subExercises[index],
                    workout: workout,
                    isEmbeddedInSuperset: true,
                    isExpanded: .constant(true),
                    isCurrentExercise: false
                )
                .background(Color.clear)
                .shadow(color: .clear, radius: 0)
                .padding(.horizontal, -16)
                .padding(.vertical, -8)

                if !isLast {
                    Divider()
                        .background(PastelTheme.separator)
                        .padding(.leading, 16)
                        .padding(.vertical, 8)
                }
            }
        }
    }

    var finishButton: some View {
        Button(action: {
            if superset.isCompleted {
                withAnimation { superset.isCompleted = false }
            } else {
                showEffortSheet = true
            }
        }) {
            Text(superset.isCompleted ? String(localized: "Continue") : String(localized: "Finish Superset"))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity)
                .frame(height: PastelTheme.ButtonMetrics.splitHeight)
                .background(superset.isCompleted ? PastelTheme.cardSurfaceSubtle : PastelTheme.pastelEmerald)
                .foregroundColor(superset.isCompleted ? PastelTheme.pastelEmerald : PastelTheme.textOnOat)
                .clipShape(RoundedRectangle(cornerRadius: PastelTheme.ButtonMetrics.splitRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: PastelTheme.ButtonMetrics.splitRadius, style: .continuous)
                        .stroke(superset.isCompleted ? PastelTheme.cardBorderFocused : Color.clear, lineWidth: 1)
                )
        }
        .padding(.top, 12)
        .buttonStyle(BorderlessButtonStyle())
        .disabled(isWorkoutCompleted)
    }

    private func finishSupersetAction() {
        viewModel.handleExerciseFinished(
            exerciseId: superset.id,
            workout: workout,
            weightUnit: unitsManager.weightUnitString(),
            onExpandNext: { nextId in
                onExpandNext?(nextId)
            }
        )
    }
}
