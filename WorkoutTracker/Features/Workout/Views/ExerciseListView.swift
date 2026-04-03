// ============================================================
// FILE: WorkoutTracker/Views/Exercise/ExerciseListView.swift
// ============================================================

internal import SwiftUI
internal import UniformTypeIdentifiers

struct ExerciseListView: View {
    @Bindable var workout: Workout
    @Binding var expandedExercises: [UUID: Bool]
    @Binding var draggedExercise: Exercise?
    
    // ✅ ИСПРАВЛЕНИЕ: Оставляем только локальный ViewModel
    @Environment(WorkoutDetailViewModel.self) var viewModel
    
    var scrollToExerciseId: (UUID?) -> Void
    
    var body: some View {
        if workout.exercises.isEmpty {
            Button { } label: {
                EmptyStateView(
                    icon: "plus.circle.fill",
                    title: LocalizedStringKey("No exercises added yet"),
                    message: LocalizedStringKey("Tap the + button above to add your first exercise to this workout.")
                )
                .padding(.vertical, 30)
            }.buttonStyle(.plain)
        } else {
            VStack(spacing: 16) {
                ForEach(Array(workout.exercises.enumerated()), id: \.element.id) { index, exercise in
                    
                    let isExpandedBinding = Binding(
                        get: { expandedExercises[exercise.id] ?? false },
                        set: { expandedExercises[exercise.id] = $0 }
                    )
                    
                    let isCurrentExercise = workout.isActive && !exercise.isCompleted && (expandedExercises[exercise.id] ?? false) && workout.exercises.prefix(index).allSatisfy { $0.isCompleted }

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
        
        guard let currentIndex = workout.exercises.firstIndex(where: { $0.id == currentExerciseId }) else { return }
        
        if let nextIndex = workout.exercises.indices.first(where: { $0 > currentIndex && !workout.exercises[$0].isCompleted }) {
            let nextId = workout.exercises[nextIndex].id
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
