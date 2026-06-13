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
                        .fill(themeManager.current.primaryAccent.opacity(0.12))
                        .frame(width: 100, height: 100)
                        .blur(radius: 6)
                    
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [themeManager.current.primaryAccent, themeManager.current.primaryAccent.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .padding(.bottom, 4)
                
                VStack(spacing: 10) {
                    Text(LocalizedStringKey("Ready to Sweat?"))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text(LocalizedStringKey("Start by adding an exercise or build a superset to target multiple muscles."))
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(themeManager.current.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                
                HStack(spacing: 20) {
                    // Add Exercise Square Button
                    Button(action: {
                        HapticManager.shared.impact(.medium)
                        onAddExerciseTap()
                    }) {
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(themeManager.current.primaryAccent.opacity(0.12))
                                    .frame(width: 56, height: 56)
                                Image(systemName: "dumbbell.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(themeManager.current.primaryAccent)
                            }
                            
                            VStack(spacing: 6) {
                                Text(LocalizedStringKey("Add Exercise"))
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundColor(themeManager.current.primaryAccent)
                                    .multilineTextAlignment(.center)
                                
                                Text(LocalizedStringKey("Log single exercises with sets and weight"))
                                    .font(.system(size: 12, weight: .regular, design: .rounded))
                                    .foregroundColor(themeManager.current.secondaryText)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(3)
                                    .minimumScaleFactor(0.8)
                            }
                        }
                        .padding(.vertical, 20)
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, minHeight: 185)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(themeManager.current.surfaceVariant.opacity(0.4))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(
                                    LinearGradient(colors: [themeManager.current.primaryAccent, themeManager.current.primaryAccent.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                    lineWidth: 1.5
                                )
                                .shadow(color: themeManager.current.primaryAccent.opacity(0.35), radius: 10, x: 0, y: 4)
                        )
                    }
                    .buttonStyle(.plain)

                    // Build Superset Square Button
                    Button(action: {
                        HapticManager.shared.impact(.medium)
                        onAddSupersetTap()
                    }) {
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(themeManager.current.secondaryMidTone.opacity(0.12))
                                    .frame(width: 56, height: 56)
                                Image(systemName: "rectangle.stack.badge.plus")
                                    .font(.system(size: 24))
                                    .foregroundColor(themeManager.current.secondaryMidTone)
                            }
                            
                            VStack(spacing: 6) {
                                Text(LocalizedStringKey("Build Superset"))
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundColor(themeManager.current.secondaryMidTone)
                                    .multilineTextAlignment(.center)
                                
                                Text(LocalizedStringKey("Group exercises to perform back-to-back"))
                                    .font(.system(size: 12, weight: .regular, design: .rounded))
                                    .foregroundColor(themeManager.current.secondaryText)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(3)
                                    .minimumScaleFactor(0.8)
                            }
                        }
                        .padding(.vertical, 20)
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, minHeight: 185)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(themeManager.current.surfaceVariant.opacity(0.4))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(
                                    LinearGradient(colors: [themeManager.current.secondaryMidTone, themeManager.current.secondaryMidTone.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                    lineWidth: 1.5
                                )
                                .shadow(color: themeManager.current.secondaryMidTone.opacity(0.35), radius: 10, x: 0, y: 4)
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
            }
            .padding(.vertical, 32)
            .padding(.horizontal, 16)
            .background(themeManager.current.surface)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.15), radius: 15, y: 5)
            .padding(.horizontal, 20)
            .padding(.vertical, 30)
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
