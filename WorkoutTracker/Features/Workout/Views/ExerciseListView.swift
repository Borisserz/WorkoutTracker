internal import SwiftUI
internal import UniformTypeIdentifiers

struct ExerciseListView: View {
    @Bindable var workout: Workout
    @Binding var expandedExercises: [UUID: Bool]
    @Binding var draggedExercise: Exercise?
    
    @Environment(WorkoutDetailViewModel.self) var viewModel
    
    var scrollToExerciseId: (UUID?) -> Void
    var onAddExerciseTap: () -> Void // ✅ FIX: Added callback for the empty state button
    
    // ✅ FIX: Computed property to keep uncompleted exercises at the top,
    // preserving their natural order without jumping randomly.
    private var sortedExercises: [Exercise] {
        let uncompleted = workout.exercises.filter { !$0.isCompleted }
        let completed = workout.exercises.filter { $0.isCompleted }
        return uncompleted + completed
    }
    
    var body: some View {
        if workout.exercises.isEmpty {
                   // ✅ FIX: Executing the callback and making the whole area tappable
                   Button {
                       onAddExerciseTap()
                   } label: {
                       EmptyStateView(
                           icon: "plus.circle.fill",
                           title: LocalizedStringKey("No exercises added yet"),
                           message: LocalizedStringKey("Tap the + button above to add your first exercise to this workout.")
                       )
                       .padding(.vertical, 30)
                       .frame(maxWidth: .infinity, maxHeight: .infinity)
                       .contentShape(Rectangle()) // ✅ FIX: Makes transparent areas clickable
                   }
                   .buttonStyle(.plain)
               } else {
                   VStack(spacing: 16) {
                // ✅ FIX: Iterate over the stably sorted array
                ForEach(sortedExercises) { exercise in
                    
                    let isExpandedBinding = Binding(
                        get: { expandedExercises[exercise.id] ?? false },
                        set: { expandedExercises[exercise.id] = $0 }
                    )
                    
                    // Check if it's the current exercise logically
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
        
        // ✅ FIX: Find the NEXT uncompleted exercise dynamically instead of relying on indices
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
