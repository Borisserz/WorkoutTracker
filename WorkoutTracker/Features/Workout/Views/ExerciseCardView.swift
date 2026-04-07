// ============================================================
// FILE: WorkoutTracker/Features/Workout/Views/ExerciseCardView.swift
// ============================================================

internal import SwiftUI
import SwiftData

struct ExerciseCardView: View {
    @Environment(TutorialManager.self) var tutorialManager
    @Environment(UnitsManager.self) var unitsManager
    @Environment(WorkoutDetailViewModel.self) var detailViewModel
    @Environment(\.modelContext) private var context
    
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
    
    // Поддерживает ли упражнение трекинг по камере
    private var isAISupported: Bool {
        let category = ExerciseCategory.determine(from: exercise.name)
        return [.squat, .curl, .press, .deadlift, .pull].contains(category)
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
                    .fill(exercise.isCompleted ? Color.green.opacity(0.05) : (isActiveExercise ? Color.cyan.opacity(0.05) : Color(UIColor.secondarySystemBackground)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(exercise.isCompleted ? Color.green.opacity(0.3) : (isActiveExercise ? Color.cyan.opacity(0.5) : Color.clear), lineWidth: (isActiveExercise || exercise.isCompleted) ? 2 : 0)
            )
            .shadow(color: isActiveExercise ? Color.cyan.opacity(0.2) : .clear, radius: 15, x: 0, y: 5)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: exercise.isCompleted)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isActiveExercise)
        }
        .sheet(isPresented: $showEffortSheet, onDismiss: { completeExerciseAfterRPE() }) {
            @Bindable var bindableExercise = exercise
            EffortInputView(effort: $bindableExercise.effort)
        }
        .sheet(isPresented: $showTechniqueSheet) {
            TechniqueSheetView(category: exercise.category)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
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
                    onDataChange: { // ✅ FIX: Поставлено в правильное место (после onCheck)
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
                Image(systemName: "line.3.horizontal").foregroundColor(.gray).font(.caption).frame(width: 20, height: 20)
                
                NavigationLink(destination: ExerciseHistoryView(exerciseName: exercise.name)) {
                    HStack {
                        Image(systemName: getIcon()).foregroundColor(getColor()).font(.caption)
                        Text(LocalizedStringKey(exercise.name)).font(.headline).foregroundColor(.primary)
                    }
                }.highPriorityGesture(TapGesture().onEnded { })
                
                Button { showTechniqueSheet = true } label: { Image(systemName: "info.circle").font(.subheadline).foregroundColor(.secondary).padding(.horizontal, 4) }.buttonStyle(BorderlessButtonStyle())
                
                Spacer()
                
                let completedCount = exercise.setsList.filter { $0.isCompleted }.count
                let totalCount = exercise.setsList.count
                
                HStack(spacing: 4) {
                    Image(systemName: completedCount == totalCount && totalCount > 0 ? "checkmark.circle.fill" : "checkmark.circle")
                        .foregroundColor(completedCount == totalCount && totalCount > 0 ? .green : (completedCount > 0 ? .cyan : .gray)).font(.caption)
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
            
            // Динамический блок колонок (растягивается на все свободное место)
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
            
            // Зарезервированное место под кнопки
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
                .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14).background(Color.cyan.opacity(0.15)).foregroundColor(.cyan).cornerRadius(14)
            }
            .buttonStyle(BorderlessButtonStyle()).disabled(exercise.isCompleted || isWorkoutCompleted)
            
            if !isEmbeddedInSuperset {
                Button(action: { finishExerciseAction() }) {
                    Text(exercise.isCompleted ? LocalizedStringKey("Resume Exercise") : LocalizedStringKey("Finish Exercise"))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(exercise.isCompleted ? Color.blue.opacity(0.15) : Color.green.opacity(0.15))
                        .foregroundColor(exercise.isCompleted ? .blue : .green)
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
    private func getColor() -> Color { exercise.type == .strength ? .cyan : (exercise.type == .cardio ? .orange : .purple) }
}
