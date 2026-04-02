
//
//  ExerciseListView..swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 1.04.26.
//

internal import SwiftUI
internal import UniformTypeIdentifiers
import SwiftData

struct ExerciseListView: View {
    @Bindable var workout: Workout
    @Binding var expandedExercises: [UUID: Bool]
    @Binding var draggedExercise: Exercise?
    
    @Environment(CatalogViewModel.self) var catalogViewModel
    @Environment(TutorialManager.self) var tutorialManager
    @Environment(UnitsManager.self) var unitsManager
    @Environment(\.modelContext) private var context
    @Environment(DashboardViewModel.self) var dashboardViewModel
    var globalViewModel: WorkoutViewModel
    var viewModel: WorkoutDetailViewModel 
    
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
                                currentWorkoutId: workout.id,
                                onDelete: { withAnimation { globalViewModel.removeExercise(exercise, from: workout) } },
                                isWorkoutCompleted: !workout.isActive,
                                isExpanded: isExpandedBinding,
                                onExerciseFinished: {
                                    // ✅ ПОРЯДОК АРГУМЕНТОВ ИСПРАВЛЕН
                                    viewModel.handleExerciseFinished(
                                        exerciseId: exercise.id,
                                        workout: workout,
                                        modelContainer: context.container,
                                        tutorialManager: tutorialManager,
                                        dashboardViewModel: dashboardViewModel, // Переместили сюда
                                        catalog: catalogViewModel.combinedCatalog,
                                        weightUnit: unitsManager.weightUnitString(),
                                        onExpandNext: { id in
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { expandedExercises[id] = true }
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { scrollToExerciseId(id) }
                                        }
                                    )
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { expandedExercises[exercise.id] = false }
                                    viewModel.updateWorkoutAnalytics(for: workout, modelContainer: context.container)
                                },
                                isCurrentExercise: isCurrentExercise,
                                onPRSet: { level in
                                    viewModel.handlePRSet(level: level, exerciseName: exercise.name, workout: workout, catalog: catalogViewModel.combinedCatalog, weightUnit: unitsManager.weightUnitString())
                                },
                                onSetCompleted: { set, isLast, name in
                                    viewModel.handleSetCompleted(set: set, isLast: isLast, exerciseName: name, workout: workout, catalog: catalogViewModel.combinedCatalog, weightUnit: unitsManager.weightUnitString())
                                }
                            )
                        } else {
                            ExerciseCardView(
                                exercise: exercise,
                                currentWorkoutId: workout.id,
                                onDelete: { withAnimation { globalViewModel.removeExercise(exercise, from: workout) } },
                                onSwap: { viewModel.exerciseToSwap = exercise; viewModel.showSwapSheet = true },
                                isWorkoutCompleted: !workout.isActive,
                                isExpanded: isExpandedBinding,
                                onExerciseFinished: {
                                    // ✅ ПОРЯДОК АРГУМЕНТОВ ИСПРАВЛЕН
                                    viewModel.handleExerciseFinished(
                                        exerciseId: exercise.id,
                                        workout: workout,
                                        modelContainer: context.container,
                                        tutorialManager: tutorialManager,
                                        dashboardViewModel: dashboardViewModel, // Переместили сюда
                                        catalog: catalogViewModel.combinedCatalog,
                                        weightUnit: unitsManager.weightUnitString(),
                                        onExpandNext: { id in
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { expandedExercises[id] = true }
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { scrollToExerciseId(id) }
                                        }
                                    )
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { expandedExercises[exercise.id] = false }
                                    viewModel.updateWorkoutAnalytics(for: workout, modelContainer: context.container)
                                },
                                isCurrentExercise: isCurrentExercise,
                                onPRSet: { level in
                                    viewModel.handlePRSet(level: level, exerciseName: exercise.name, workout: workout, catalog: catalogViewModel.combinedCatalog, weightUnit: unitsManager.weightUnitString())
                                },
                                onSetCompleted: { set, isLast, name in
                                    viewModel.handleSetCompleted(set: set, isLast: isLast, exerciseName: name, workout: workout, catalog: catalogViewModel.combinedCatalog, weightUnit: unitsManager.weightUnitString())
                                }
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
}
