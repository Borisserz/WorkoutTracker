//
//  SupersetCardView.swift
//  WorkoutTracker
//

internal import SwiftUI
import SwiftData

// (PRCelebrationView и структуры оставляем как есть, меняем только сам SupersetCardView)

// ... Весь код до SupersetCardView включительно остается без изменений ...

struct SupersetCardView: View {
    @Environment(\.modelContext) private var context
    @Environment(WorkoutService.self) var workoutService // ✅ Заменили WorkoutViewModel
    @Environment(WorkoutDetailViewModel.self) var viewModel
    @Environment(DashboardViewModel.self) var dashboardViewModel
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
            .background(isActiveExercise ? Color.blue.opacity(0.08) : Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(isActiveExercise ? Color.blue.opacity(0.5) : Color.clear, lineWidth: isActiveExercise ? 2 : 0))
            .shadow(color: isActiveExercise ? Color.blue.opacity(0.2) : Color.clear, radius: isActiveExercise ? 8 : 0, x: 0, y: 2)
        }
        .sheet(isPresented: $showEffortSheet, onDismiss: { if superset.isCompleted { finishSupersetAction() } }) {
            EffortInputView(effort: $superset.effort)
        }
    }
    
    var headerView: some View {
        HStack {
            Image(systemName: "line.3.horizontal").foregroundColor(.gray).font(.caption).frame(width: 20, height: 20)
            HStack {
                Image(systemName: "link").foregroundColor(.purple)
                Text(String(localized: "Superset")).font(.headline).foregroundColor(.purple)
            }
            Spacer()
            Menu {
                Button(role: .destructive) {
                    // The Task is correct, but wrapping it in `withAnimation` is ambiguous for the compiler.
                    // The UI will still animate because the parent list observes the data change.
                    Task { await workoutService.removeExercise(superset, from: workout) }
                } label: {
                    Label(String(localized: "Remove Superset"), systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis").foregroundColor(.gray).padding(10)
            }
            .highPriorityGesture(TapGesture().onEnded { })
        }
        .padding(.bottom, 10).contentShape(Rectangle())
        .onTapGesture { withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { isExpanded.toggle() } }
    }
    
    private var collapsedInfoSection: some View {
        HStack {
            Spacer()
            Text(String(localized: "Tap to expand")).font(.caption).foregroundColor(.secondary).italic()
            Spacer()
        }.padding(.vertical, 8)
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
                
                if !isLast { Divider().padding(.leading, 16).padding(.vertical, 8) }
            }
        }
    }
    
    var finishButton: some View {
        Button(action: {
            if superset.isCompleted {
                withAnimation { superset.isCompleted = false }
            } else {
                finishSupersetAction()
            }
        }) {
            Text(superset.isCompleted ? String(localized: "Continue") : String(localized: "Finish Superset"))
                .font(.subheadline)
                .bold()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.green.opacity(0.1))
                .foregroundColor(.green)
                .cornerRadius(8)
        }
        .padding(.top, 12)
        .buttonStyle(BorderlessButtonStyle())
        .disabled(isWorkoutCompleted)
    }
    
    private func finishSupersetAction() {
        viewModel.handleExerciseFinished(
            exerciseId: superset.id,
            workout: workout,
            modelContainer: context.container,
            tutorialManager: tutorialManager,
            dashboardViewModel: dashboardViewModel,
            catalog: Exercise.catalog,
            weightUnit: unitsManager.weightUnitString(),
            onExpandNext: { nextId in
                onExpandNext?(nextId)
            }
        )
    }
}
