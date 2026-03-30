//
//  ExerciseCardView.swift
//  WorkoutTracker
//

internal import SwiftUI
import SwiftData

struct ExerciseCardView: View {
    
    // MARK: - Environment & Bindings
    @Environment(\.modelContext) private var context
    @EnvironmentObject var tutorialManager: TutorialManager
    @EnvironmentObject var viewModel: WorkoutViewModel
    @EnvironmentObject var timerManager: RestTimerManager
    @ObservedObject private var unitsManager = UnitsManager.shared
    
    @Bindable var exercise: Exercise
    
    // MARK: - Properties
    
    let currentWorkoutId: UUID
    var onDelete: () -> Void
    var onSwap: (() -> Void)? = nil
    var isEmbeddedInSuperset: Bool = false
    var isWorkoutCompleted: Bool = false
    var isCurrentExercise: Bool = false
    
    // MARK: - Local State
    
    @State private var showEffortSheet = false
    @State private var showTechniqueSheet = false
    @Binding var isExpanded: Bool
    @State private var newlyAddedSetId: UUID? = nil
    
    var onExerciseFinished: (() -> Void)? = nil
    var onPRSet: ((PRLevel) -> Void)? = nil
    
    // ADDED: Замыкание для передачи завершенного подхода наверх
    var onSetCompleted: ((WorkoutSet, String) -> Void)? = nil
    
    // MARK: - Initializer
    
    init(
        exercise: Exercise,
        currentWorkoutId: UUID,
        onDelete: @escaping () -> Void,
        onSwap: (() -> Void)? = nil,
        isEmbeddedInSuperset: Bool = false,
        isWorkoutCompleted: Bool = false,
        isExpanded: Binding<Bool>,
        onExerciseFinished: (() -> Void)? = nil,
        isCurrentExercise: Bool = false,
        onPRSet: ((PRLevel) -> Void)? = nil,
        onSetCompleted: ((WorkoutSet, String) -> Void)? = nil // ADDED
    ) {
        self.exercise = exercise
        self.currentWorkoutId = currentWorkoutId
        self.onDelete = onDelete
        self.onSwap = onSwap
        self.isEmbeddedInSuperset = isEmbeddedInSuperset
        self.isWorkoutCompleted = isWorkoutCompleted
        self._isExpanded = isExpanded
        self.onExerciseFinished = onExerciseFinished
        self.isCurrentExercise = isCurrentExercise
        self.onPRSet = onPRSet
        self.onSetCompleted = onSetCompleted // ADDED
    }
    
    // MARK: - Computed
    
    private var isActiveExercise: Bool {
        isCurrentExercise && !exercise.isCompleted
    }
    
    // MARK: - Body
    
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
                isActiveExercise
                    ? Color.blue.opacity(0.08)
                    : Color(UIColor.secondarySystemBackground)
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isActiveExercise ? Color.blue.opacity(0.5) : Color.clear,
                        lineWidth: isActiveExercise ? 2 : 0
                    )
            )
            .shadow(
                color: isActiveExercise ? Color.blue.opacity(0.2) : Color.clear,
                radius: isActiveExercise ? 8 : 0,
                x: 0,
                y: 2
            )
        }
        .sheet(isPresented: $showEffortSheet, onDismiss: {
            if exercise.isCompleted {
                onExerciseFinished?()
            }
        }) {
            EffortInputView(effort: $exercise.effort)
        }
        .sheet(isPresented: $showTechniqueSheet) {
            TechniqueSheetView(category: exercise.category)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private var setsSection: some View {
        let lastExerciseData = viewModel.lastPerformancesCache[exercise.name]
        let sortedSets = exercise.sortedSets
        let sortedPrevSets: [WorkoutSet] = lastExerciseData?.sortedSets ?? []
        
        ForEach(Array(sortedSets.enumerated()), id: \.element.id) { currentIndex, set in
            let isLast = currentIndex == sortedSets.count - 1
            
            let prevSet: WorkoutSet? = {
                if currentIndex < sortedPrevSets.count {
                    return sortedPrevSets[currentIndex]
                }
                return nil
            }()
            
            SetRowView(
                set: set,
                exerciseName: exercise.name,
                cached1RM: viewModel.personalRecordsCache[exercise.name] ?? 0.0,
                effort: exercise.effort,
                exerciseType: exercise.type,
                isLastSet: isLast,
                isExerciseCompleted: exercise.isCompleted,
                isWorkoutCompleted: isWorkoutCompleted,
                onCheck: { checkedSet, shouldStartTimer, suggestedDuration in // MODIFIED: Обновлена сигнатура onCheck
                    if shouldStartTimer {
                        if let duration = suggestedDuration {
                            timerManager.startRestTimer(duration: duration)
                        } else {
                            timerManager.startRestTimer()
                        }
                    }
                    onSetCompleted?(checkedSet, exercise.name) // ADDED: Пробрасываем данные о подходе наверх
                },
                prevWeight: prevSet?.weight,
                prevReps: prevSet?.reps,
                prevDist: prevSet?.distance,
                prevTime: prevSet?.time,
                autoFocus: set.id == newlyAddedSetId
            )
            .swipeActions(edge: .trailing) {
                if !exercise.isCompleted && !isWorkoutCompleted {
                    Button(role: .destructive) {
                        removeSet(withId: set.id)
                    } label: {
                        Label(LocalizedStringKey("Delete"), systemImage: "trash")
                    }
                }
            }
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "line.3.horizontal")
                    .foregroundColor(.gray)
                    .font(.caption)
                    .frame(width: 20, height: 20)
                
                NavigationLink(destination: ExerciseHistoryView(exerciseName: exercise.name)) {
                    HStack {
                        Image(systemName: getIcon())
                            .foregroundColor(getColor())
                            .font(.caption)
                        
                        Text(LocalizedStringKey(exercise.name))
                            .font(.headline)
                            .foregroundColor(.blue)
                    }
                }
                .highPriorityGesture(TapGesture().onEnded { })
                
                Button {
                    showTechniqueSheet = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                }
                .buttonStyle(BorderlessButtonStyle())
                
                Spacer()
                
                let completedCount = exercise.setsList.filter { $0.isCompleted }.count
                let totalCount = exercise.setsList.count
                
                HStack(spacing: 4) {
                    Image(systemName: completedCount == totalCount && totalCount > 0 ? "checkmark.circle.fill" : "checkmark.circle")
                        .foregroundColor(completedCount == totalCount && totalCount > 0 ? .green : (completedCount > 0 ? .blue : .gray))
                        .font(.caption)
                    
                    (Text("\(completedCount)/\(totalCount) ") + Text(LocalizedStringKey("sets")))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Menu {
                    if let onSwap = onSwap {
                        Button(action: onSwap) {
                            Label(LocalizedStringKey("Swap Exercise"), systemImage: "arrow.triangle.2.circlepath")
                        }
                    }
                    
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label(LocalizedStringKey("Remove Exercise"), systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.gray)
                        .padding(10)
                }
                .highPriorityGesture(TapGesture().onEnded { })
            }
            
            let targetMuscles = MuscleDisplayHelper.getTargetMuscleNames(for: exercise.name, muscleGroup: exercise.muscleGroup)
            if !targetMuscles.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(targetMuscles.joined(separator: ", "))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .padding(.leading, 28)
            }
        }
        .padding(.bottom, 10)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isExpanded.toggle()
            }
        }
    }
    
    private var columnHeadersSection: some View {
        HStack(spacing: 8) {
            Text(LocalizedStringKey("Set"))
                .font(.caption2)
                .frame(width: 25)
                .foregroundColor(.secondary)
            
            switch exercise.type {
            case .strength:
                Text(unitsManager.weightUnitString()).font(.caption2).frame(width: 100).foregroundColor(.secondary)
                Text(LocalizedStringKey("Reps")).font(.caption2).frame(width: 100).foregroundColor(.secondary)
            case .cardio:
                Text(unitsManager.distanceUnitString()).font(.caption2).frame(width: 100).foregroundColor(.secondary)
                Spacer()
                Text(LocalizedStringKey("Time")).font(.caption2).frame(width: 100).foregroundColor(.secondary)
            case .duration:
                Text(LocalizedStringKey("Time")).font(.caption2).frame(width: 100).foregroundColor(.secondary)
            }
            
            Image(systemName: "brain.head.profile").font(.title3).frame(width: 32).foregroundColor(.secondary)
            Image(systemName: "checkmark").font(.caption2).frame(width: 32).foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 4)
    }
    
    private var collapsedInfoSection: some View {
        HStack {
            Spacer()
            Text(LocalizedStringKey("Tap to expand"))
                .font(.caption)
                .foregroundColor(.secondary)
                .italic()
            Spacer()
        }
        .padding(.vertical, 8)
    }
    
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            Button(action: addSet) {
                Text(exercise.isCompleted ? LocalizedStringKey("Exercise Completed") : LocalizedStringKey("+ Add Set"))
                    .font(.subheadline).bold()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
            }
            .buttonStyle(BorderlessButtonStyle())
            .disabled(exercise.isCompleted || isWorkoutCompleted)
            
            if !isEmbeddedInSuperset {
                Button(action: {
                    if exercise.isCompleted {
                        withAnimation {
                            exercise.isCompleted = false
                        }
                    } else {
                        finishExercise()
                    }
                }) {
                    Text(exercise.isCompleted ? LocalizedStringKey("Continue") : LocalizedStringKey("Finish Exercise"))
                        .font(.subheadline).bold()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.green.opacity(0.1))
                        .foregroundColor(.green)
                        .cornerRadius(8)
                }
                .buttonStyle(BorderlessButtonStyle())
                .disabled(isWorkoutCompleted)
                .spotlight(
                    step: .finishExercise,
                    manager: tutorialManager,
                    text: "Tap here when you are done with this exercise.",
                    alignment: .top,
                    yOffset: -20
                )
            }
        }
        .padding(.top, 12)
    }
    
    private func finishExercise() {
        guard !exercise.isCompleted && !isWorkoutCompleted else { return }
        
        let uncompletedSets = exercise.setsList.filter { !$0.isCompleted }
        for set in uncompletedSets {
            viewModel.deleteSet(set, from: exercise, container: context.container)
        }
        
        exercise.isCompleted = true
        
        let lastData = viewModel.lastPerformancesCache[exercise.name]
        var newRecordWasSet = false
        var maxIncreasePercent: Double = 0.0
        
        if exercise.type == .strength {
            let maxWeightInWorkout = exercise.setsList
                .filter { $0.isCompleted }
                .compactMap { $0.weight }
                .max() ?? 0
            
            if let _ = lastData {
                let oldRecord = viewModel.personalRecordsCache[exercise.name] ?? 0.0
                if maxWeightInWorkout > oldRecord {
                    newRecordWasSet = true
                    
                    let increase = oldRecord > 0 ? (maxWeightInWorkout - oldRecord) / oldRecord : 0.0
                    if increase > maxIncreasePercent {
                        maxIncreasePercent = increase
                    }
                }
            }
        }
        
        if tutorialManager.currentStep == .finishExercise {
            tutorialManager.setStep(.explainEffort)
        }
        
        if newRecordWasSet {
            let calculatedPRLevel: PRLevel
            
            if maxIncreasePercent >= 0.20 {
                calculatedPRLevel = .diamond
            } else if maxIncreasePercent >= 0.10 {
                calculatedPRLevel = .gold
            } else if maxIncreasePercent >= 0.05 {
                calculatedPRLevel = .silver
            } else {
                calculatedPRLevel = .bronze
            }
            
            onPRSet?(calculatedPRLevel)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                showEffortSheet = true
            }
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        } else {
            showEffortSheet = true
        }
    }
    
    private func addSet() {
        guard !exercise.isCompleted && !isWorkoutCompleted else { return }
        
        let sortedSets = exercise.sortedSets
        let lastSet = sortedSets.last
        let newIndex = (lastSet?.index ?? 0) + 1
        
        withAnimation {
            viewModel.addSet(
                to: exercise,
                index: newIndex,
                weight: lastSet?.weight,
                reps: lastSet?.reps,
                distance: lastSet?.distance,
                time: lastSet?.time,
                type: .normal,
                isCompleted: false,
                container: context.container
            )
            newlyAddedSetId = exercise.setsList.last?.id
        }
    }
    
    private func removeSet(withId id: UUID) {
        guard !exercise.isCompleted && !isWorkoutCompleted else { return }
        
        withAnimation {
            if let setToDelete = exercise.setsList.first(where: { $0.id == id }) {
                viewModel.deleteSet(setToDelete, from: exercise, container: context.container)
            }
        }
    }
    
    private func getIcon() -> String {
        switch exercise.type {
        case .strength: return "dumbbell.fill"
        case .cardio: return "figure.run"
        case .duration: return "stopwatch.fill"
        }
    }
    
    private func getColor() -> Color {
        switch exercise.type {
        case .strength: return .blue
        case .cardio: return .orange
        case .duration: return .purple
        }
    }
}
