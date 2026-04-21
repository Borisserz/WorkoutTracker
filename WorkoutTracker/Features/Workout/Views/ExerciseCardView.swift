

internal import SwiftUI
import SwiftData

struct ExerciseCardView: View {
    @Environment(TutorialManager.self) var tutorialManager
    @Environment(UnitsManager.self) var unitsManager
    @Environment(WorkoutDetailViewModel.self) var detailViewModel
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var colorScheme 
    @Environment(ThemeManager.self) private var themeManager

    @State private var showHistory = false
    let exercise: Exercise
    let workout: Workout
    var isEmbeddedInSuperset: Bool = false
    @Binding var isExpanded: Bool
    var isCurrentExercise: Bool = false
    var onExpandNext: ((UUID) -> Void)? = nil

    @State private var showEffortSheet = false
    @State private var showTechniqueSheet = false

    private var isActiveExercise: Bool { isCurrentExercise && !exercise.isCompleted && workout.isActive }
    private var isWorkoutCompleted: Bool { !workout.isActive }

    private var isAISupported: Bool {
        let category = ExerciseCategory.determine(from: exercise.name)
        return [.squat, .curl, .press, .deadlift, .pull].contains(category)
    }

    private var cardBackgroundColor: Color {
        if exercise.isCompleted {
            return colorScheme == .dark ? Color.green.opacity(0.1) : Color.green.opacity(0.05)
        } else if isActiveExercise {
            return colorScheme == .dark ? themeManager.current.primaryAccent.opacity(0.1) : themeManager.current.primaryAccent.opacity(0.05)
        } else {
            return colorScheme == .dark ? Color(red: 0.12, green: 0.12, blue: 0.14) : Color.white
        }
    }

    private var cardBorderColor: Color {
        if exercise.isCompleted {
            return Color.green.opacity(0.4)
        } else if isActiveExercise {
            return themeManager.current.primaryAccent.opacity(0.5)
        } else {
            return colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05)
        }
    }

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                headerSection

                if isExpanded {
                    columnHeadersSection
                    setsSection
                    actionButtonsSection
                } else {
                    collapsedInfoSection
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(cardBackgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(cardBorderColor, lineWidth: (isActiveExercise || exercise.isCompleted) ? 2 : 1)
            )
            .shadow(color: isActiveExercise ? themeManager.current.primaryAccent.opacity(0.2) : .black.opacity(colorScheme == .dark ? 0.2 : 0.05), radius: 15, x: 0, y: 5)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: exercise.isCompleted)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isActiveExercise)
        }
        .sheet(isPresented: $showEffortSheet, onDismiss: { completeExerciseAfterRPE() }) {
            @Bindable var bindableExercise = exercise
            EffortInputView(effort: $bindableExercise.effort)
        }
        .sheet(isPresented: $showTechniqueSheet) {
            TechniqueSheetView(exerciseName: exercise.name, category: exercise.category)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .navigationDestination(isPresented: $showHistory) {
            ExerciseHistoryView(exerciseName: exercise.name)
        }
    }

    @ViewBuilder
    private var setsSection: some View {
        let lastExerciseData = detailViewModel.lastPerformancesCache[exercise.name]
        let sortedSets = exercise.sortedSets
        let sortedPrevSets: [WorkoutSet] = lastExerciseData?.sortedSets ?? []

        ForEach(Array(sortedSets.enumerated()), id: \.element.id) { currentIndex, set in
            let isLast = currentIndex == sortedSets.count - 1
            let prevSet: WorkoutSet? = currentIndex < sortedPrevSets.count ? sortedPrevSets[currentIndex] : nil

            SetRowView(
                set: set,
                exerciseName: exercise.name,
                cached1RM: detailViewModel.personalRecordsCache[exercise.name] ?? 0.0,
                effort: exercise.effort,
                exerciseType: exercise.type,
                isLastSet: isLast,
                isExerciseCompleted: exercise.isCompleted,
                isWorkoutCompleted: isWorkoutCompleted,
                onCheck: { checkedSet, shouldStartTimer, suggestedDuration in
                    detailViewModel.startTimerIfNeeded(shouldStartTimer: shouldStartTimer, suggestedDuration: suggestedDuration)
                    detailViewModel.handleSetCompleted(set: checkedSet, isLast: isLast, exerciseName: exercise.name, workout: workout, weightUnit: unitsManager.weightUnitString())
                },
                onDataChange: {
                    detailViewModel.updateWorkoutAnalytics(for: workout)
                },
                prevWeight: prevSet?.weight,
                prevReps: prevSet?.reps,
                prevDist: prevSet?.distance,
                prevTime: prevSet?.time,
                autoFocus: set.id == detailViewModel.newlyAddedSetId
            )
            .swipeActions(edge: .trailing) {
                if !exercise.isCompleted && !isWorkoutCompleted {
                    Button(role: .destructive) {
                        withAnimation { detailViewModel.removeSet(set, from: exercise, context: context) }
                    } label: { Label(LocalizedStringKey("Delete"), systemImage: "trash") }
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "line.3.horizontal").foregroundColor(colorScheme == .dark ? .gray : .gray.opacity(0.5)).font(.caption).frame(width: 20, height: 20)

                Button {
                    showHistory = true
                } label: {
                    HStack {
                        Image(systemName: getIcon()).foregroundColor(getColor()).font(.caption)
                        Text(LocalizationHelper.shared.translateName(exercise.name))
                            .font(.headline)
                            .foregroundColor(colorScheme == .dark ? .white : .black) 
                    }
                }
                .buttonStyle(.plain)

                Button { showTechniqueSheet = true } label: { Image(systemName: "info.circle").font(.subheadline).foregroundColor(.secondary).padding(.horizontal, 4) }.buttonStyle(BorderlessButtonStyle())

                Spacer()

                let completedCount = exercise.setsList.filter { $0.isCompleted }.count
                let totalCount = exercise.setsList.count

                HStack(spacing: 4) {
                    Image(systemName: completedCount == totalCount && totalCount > 0 ? "checkmark.circle.fill" : "checkmark.circle")
                        .foregroundColor(completedCount == totalCount && totalCount > 0 ? .green : (completedCount > 0 ? themeManager.current.primaryAccent : .gray)).font(.caption)
                    Text("\(completedCount)/\(totalCount)").font(.subheadline).foregroundColor(.secondary)
                }

                Menu {
                    if !isEmbeddedInSuperset { Button { detailViewModel.activeEvent = .showSwapExercise(exercise) } label: { Label(LocalizedStringKey("Swap Exercise"), systemImage: "arrow.triangle.2.circlepath") } }
                    Button(role: .destructive) { detailViewModel.removeExercise(exercise, from: workout) } label: { Label(LocalizedStringKey("Remove Exercise"), systemImage: "trash") }
                } label: { Image(systemName: "ellipsis").foregroundColor(.gray).padding(10) }
                .highPriorityGesture(TapGesture().onEnded { })
            }

            let targetMuscles = MuscleDisplayHelper.getTargetMuscleNames(for: exercise.name, muscleGroup: exercise.muscleGroup)
            if !targetMuscles.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "figure.strengthtraining.traditional").font(.caption2).foregroundColor(.secondary)
                    Text(targetMuscles.joined(separator: ", ")).font(.caption).foregroundColor(.secondary).lineLimit(1)
                }.padding(.leading, 28)
            }
        }
        .padding(.bottom, 10).contentShape(Rectangle())
        .onTapGesture { withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { isExpanded.toggle() } }
    }

    private var columnHeadersSection: some View {
        HStack(spacing: 8) {
            Text(LocalizedStringKey("Set")).font(.caption2.bold()).frame(width: 32).foregroundColor(.secondary)

            HStack(spacing: 8) {
                switch exercise.type {
                case .strength:
                    Text(unitsManager.weightUnitString()).font(.caption2.bold()).frame(maxWidth: .infinity).foregroundColor(.secondary)
                    Text(LocalizedStringKey("Reps")).font(.caption2.bold()).frame(maxWidth: .infinity).foregroundColor(.secondary)
                case .cardio:
                    Text(unitsManager.distanceUnitString()).font(.caption2.bold()).frame(maxWidth: .infinity).foregroundColor(.secondary)
                    Text(LocalizedStringKey("Time")).font(.caption2.bold()).frame(maxWidth: .infinity).foregroundColor(.secondary)
                case .duration:
                    Text(LocalizedStringKey("Time")).font(.caption2.bold()).frame(maxWidth: .infinity).foregroundColor(.secondary)
                }
            }

            if isAISupported {
                Image(systemName: "brain").font(.caption2.bold()).frame(width: 44).foregroundColor(.secondary)
            }
            Image(systemName: "checkmark").font(.caption2.bold()).frame(width: 44).foregroundColor(.secondary)
        }.padding(.horizontal, 10).padding(.bottom, 4)
    }

    private var collapsedInfoSection: some View {
        HStack { Spacer(); Text(LocalizedStringKey("Tap to expand")).font(.caption).foregroundColor(.secondary).italic(); Spacer() }.padding(.vertical, 8)
    }

    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            Button(action: { withAnimation { detailViewModel.addSet(to: exercise, context: context) } }) {
                Text(LocalizedStringKey("+ Add Set"))
                .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(themeManager.current.primaryAccent.opacity(0.15))
                .foregroundColor(themeManager.current.primaryAccent)
                .cornerRadius(14)
            }
            .buttonStyle(BorderlessButtonStyle()).disabled(exercise.isCompleted || isWorkoutCompleted)

            if !isEmbeddedInSuperset {
                Button(action: { finishExerciseAction() }) {
                    Text(exercise.isCompleted ? LocalizedStringKey("Resume Exercise") : LocalizedStringKey("Finish Exercise"))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(exercise.isCompleted ? themeManager.current.primaryAccent.opacity(0.15) : Color.green.opacity(0.15))
                        .foregroundColor(exercise.isCompleted ? themeManager.current.primaryAccent : .green)
                        .cornerRadius(14)
                }
                .buttonStyle(BorderlessButtonStyle()).disabled(isWorkoutCompleted)
            }
        }.padding(.top, 12)
    }

    private func finishExerciseAction() {
        if exercise.isCompleted { withAnimation { exercise.isCompleted = false } } else { showEffortSheet = true }
    }

    private func completeExerciseAfterRPE() {
        detailViewModel.handleExerciseFinished(exerciseId: exercise.id, workout: workout, weightUnit: unitsManager.weightUnitString(), onExpandNext: { nextId in onExpandNext?(nextId) })
    }

    private func getIcon() -> String { exercise.type == .strength ? "dumbbell.fill" : (exercise.type == .cardio ? "figure.run" : "stopwatch.fill") }
    private func getColor() -> Color { exercise.type == .strength ? themeManager.current.primaryAccent : (exercise.type == .cardio ? .orange : .purple) }
}
