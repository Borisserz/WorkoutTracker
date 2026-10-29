internal import SwiftUI
internal import UniformTypeIdentifiers

struct ExerciseListView: View {
    @Bindable var workout: Workout
    @Binding var expandedExercises: [UUID: Bool]
    @Binding var draggedExercise: Exercise?

    @Environment(WorkoutDetailViewModel.self) var viewModel
    @Environment(ThemeManager.self) private var themeManager

    var scrollToExerciseId: (UUID?) -> Void
    var onAddExerciseTap: () -> Void 
    var onAddSupersetTap: () -> Void

    private var sortedExercises: [Exercise] {
        let uncompleted = workout.exercises.filter { !$0.isCompleted }
        let completed = workout.exercises.filter { $0.isCompleted }
        return uncompleted + completed
    }

    var body: some View {
        if workout.exercises.isEmpty {
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(PastelTheme.cardSurfaceSubtle)
                        .frame(width: 80, height: 80)
                        .overlay(Circle().stroke(PastelTheme.cardBorder, lineWidth: 1))
                    
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundColor(PastelTheme.pastelOat)
                }
                .padding(.bottom, 2)
                
                VStack(spacing: 8) {
                    Text(LocalizedStringKey("Ready to Sweat?"))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(PastelTheme.textPrimary)
                    
                    Text(LocalizedStringKey("Start by adding an exercise or build a superset to target multiple muscles."))
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(PastelTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                
                HStack(spacing: 14) {
                    // Add Exercise Square Button
                    Button(action: {
                        HapticManager.shared.impact(.medium)
                        onAddExerciseTap()
                    }) {
                        VStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(PastelTheme.cardSurface)
                                    .frame(width: 48, height: 48)
                                    .overlay(Circle().stroke(PastelTheme.cardBorder, lineWidth: 1))

                                Image(systemName: "dumbbell.fill")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(PastelTheme.pastelOat)
                            }
                            
                            VStack(spacing: 4) {
                                Text(LocalizedStringKey("Add Exercise"))
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(PastelTheme.textPrimary)
                                    .multilineTextAlignment(.center)
                                
                                Text(LocalizedStringKey("Log single exercises with sets and weight"))
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundColor(PastelTheme.textTertiary)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.8)
                            }
                        }
                        .padding(.vertical, 18)
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity, minHeight: 160)
                        .background(PastelTheme.cardSurfaceSubtle)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(PastelTheme.cardBorder, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)

                    // Build Superset Square Button
                    Button(action: {
                        HapticManager.shared.impact(.medium)
                        onAddSupersetTap()
                    }) {
                        VStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(PastelTheme.cardSurface)
                                    .frame(width: 48, height: 48)
                                    .overlay(Circle().stroke(PastelTheme.cardBorder, lineWidth: 1))

                                Image(systemName: "rectangle.stack.badge.plus")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(PastelTheme.pastelAmber)
                            }
                            
                            VStack(spacing: 4) {
                                Text(LocalizedStringKey("Build Superset"))
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(PastelTheme.textPrimary)
                                    .multilineTextAlignment(.center)
                                
                                Text(LocalizedStringKey("Group exercises to perform back-to-back"))
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundColor(PastelTheme.textTertiary)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.8)
                            }
                        }
                        .padding(.vertical, 18)
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity, minHeight: 160)
                        .background(PastelTheme.cardSurfaceSubtle)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(PastelTheme.cardBorder, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 8)
                .padding(.top, 6)
            }
            .padding(.vertical, 28)
            .padding(.horizontal, 16)
            .background(PastelTheme.cardSurface)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(PastelTheme.cardBorder, lineWidth: 1)
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
                   VStack(spacing: 16) {

                ForEach(sortedExercises) { exercise in

                    let isExpandedBinding = Binding(
                        get: { expandedExercises[exercise.id] ?? false },
                        set: { expandedExercises[exercise.id] = $0 }
                    )

                    let isCurrentExercise = workout.isActive && !exercise.isCompleted && (expandedExercises[exercise.id] ?? false)

                    let card = Group {
                        if exercise.isSuperset {
                            SupersetCardView(
                                superset: exercise,
                                workout: workout,
                                isExpanded: isExpandedBinding,
                                isCurrentExercise: isCurrentExercise,
                                onExpandNext: handleExpandNext
                            )
                        } else {
                            ExerciseCardView(
                                exercise: exercise,
                                workout: workout,
                                isEmbeddedInSuperset: false,
                                isExpanded: isExpandedBinding,
                                isCurrentExercise: isCurrentExercise,
                                onExpandNext: handleExpandNext
                            )
                        }
                    }

                    card
                        .id(exercise.id)
                        .background(Color.white.opacity(0.01))
                        .onDrag {
                            self.draggedExercise = exercise
                            return NSItemProvider(object: exercise.id.uuidString as NSString)
                        }
                        .onDrop(of: [UTType.text], delegate: ExerciseDropDelegate(item: exercise, items: $workout.exercises, draggedItem: $draggedExercise))
                }
            }
        }
    }

    private func handleExpandNext(currentExerciseId: UUID) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            expandedExercises[currentExerciseId] = false
        }

        let remainingUncompleted = workout.exercises.filter { !$0.isCompleted && $0.id != currentExerciseId }

        if let nextExercise = remainingUncompleted.first {
            let nextId = nextExercise.id
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                expandedExercises[nextId] = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                scrollToExerciseId(nextId)
            }
        }

        viewModel.updateWorkoutAnalytics(for: workout)
    }
}
