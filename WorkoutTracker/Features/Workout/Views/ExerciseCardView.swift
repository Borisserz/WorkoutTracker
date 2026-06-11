

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
            .background(colorScheme == .dark ? Color(white: 0.1) : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(isActiveExercise ? themeManager.current.primaryAccent : (colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05)), lineWidth: isActiveExercise ? 2 : 1)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isActiveExercise)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: showEffortSheet)
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

            let nextSet: WorkoutSet? = (currentIndex + 1 < sortedSets.count) ? sortedSets[currentIndex + 1] : nil
            let upcomingWeightStr: String? = {
                if let w = nextSet?.weight { return "\(w) \(unitsManager.weightUnitString())" }
                if let pw = prevSet?.weight { return "\(pw) \(unitsManager.weightUnitString())" }
                return nil
            }()

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
                    detailViewModel.startTimerIfNeeded(shouldStartTimer: shouldStartTimer, suggestedDuration: suggestedDuration, exerciseName: exercise.name, upcomingWeight: upcomingWeightStr)
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
            .swipeActions(edge: .leading) {
                if !set.isCompleted && !exercise.isCompleted && !isWorkoutCompleted {
                    Button {
                        if set.weight == nil && prevSet?.weight != nil { set.weight = prevSet?.weight }
                        if set.reps == nil && prevSet?.reps != nil { set.reps = prevSet?.reps }
                        if set.distance == nil && prevSet?.distance != nil { set.distance = prevSet?.distance }
                        if set.time == nil && prevSet?.time != nil { set.time = prevSet?.time }
                        
                        detailViewModel.updateWorkoutAnalytics(for: workout)
                        withAnimation { set.isCompleted = true }
                        
                        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                        
                        var suggestedDuration: Int? = nil
                        if exercise.type == .strength {
                            if exercise.effort >= 8 { suggestedDuration = 180 } else if exercise.effort >= 6 { suggestedDuration = 120 } else { suggestedDuration = 90 }
                        }
                        
                        let autoStartTimer = UserDefaults.standard.bool(forKey: "autoStartTimer")
                        detailViewModel.startTimerIfNeeded(shouldStartTimer: autoStartTimer && !isLast, suggestedDuration: autoStartTimer && !isLast ? suggestedDuration : nil, exerciseName: exercise.name, upcomingWeight: upcomingWeightStr)
                        detailViewModel.handleSetCompleted(set: set, isLast: isLast, exerciseName: exercise.name, workout: workout, weightUnit: unitsManager.weightUnitString())
                    } label: { Label(LocalizedStringKey("Log Set"), systemImage: "checkmark.circle.fill") }
                    .tint(.green)
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                // Reorder handle or icon
                Image(systemName: "line.3.horizontal")
                    .foregroundColor(.gray)
                    .font(.caption)
                    .frame(width: 16)
                
                // Exercise Icon and Title (tap to see history)
                Button {
                    showHistory = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: getIcon())
                            .foregroundColor(getColor())
                            .font(.system(size: 14, weight: .bold))
                        
                        Text(LocalizationHelper.shared.translateName(exercise.name))
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                .buttonStyle(.plain)
                
                // Technique pill
                Button {
                    showTechniqueSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text(LocalizedStringKey("Technique"))
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .lineLimit(1)
                    }
                    .foregroundColor(colorScheme == .dark ? .white : .primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(themeManager.current.primaryAccent.opacity(colorScheme == .dark ? 0.2 : 0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(BorderlessButtonStyle())
                .fixedSize(horizontal: true, vertical: false)
                
                Spacer()
                
                // Completed Sets pill/text
                let completedCount = exercise.setsList.filter { $0.isCompleted }.count
                let totalCount = exercise.setsList.count
                Text("\(completedCount)/\(totalCount) Completed")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
                
                // Menu dots
                Menu {
                    if !isEmbeddedInSuperset {
                        Button { detailViewModel.activeEvent = .showSwapExercise(exercise) } label: { Label(LocalizedStringKey("Swap Exercise"), systemImage: "arrow.triangle.2.circlepath") }
                    }
                    Button(role: .destructive) { detailViewModel.removeExercise(exercise, from: workout) } label: { Label(LocalizedStringKey("Remove Exercise"), systemImage: "trash") }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.gray)
                        .padding(6)
                }
                .highPriorityGesture(TapGesture().onEnded { })
            }
            
            // Muscle category badge
            let targetMuscles = MuscleDisplayHelper.getTargetMuscleNames(for: exercise.name, muscleGroup: exercise.muscleGroup)
            if !targetMuscles.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 10))
                    Text(targetMuscles.joined(separator: ", "))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                }
                .foregroundColor(themeManager.current.secondaryText)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.06))
                .cornerRadius(6)
                .padding(.leading, 28)
            }
        }
        .padding(.bottom, 12)
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
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .frame(width: 32)
                .foregroundColor(.secondary)

            Text(LocalizedStringKey("Previous"))
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .frame(width: 70, alignment: .leading)
                .foregroundColor(.secondary)

            HStack(spacing: 8) {
                switch exercise.type {
                case .strength:
                    Text(LocalizedStringKey("Weight")).font(.system(size: 11, weight: .bold, design: .rounded)).frame(maxWidth: .infinity).foregroundColor(.secondary)
                    Text(LocalizedStringKey("Reps")).font(.system(size: 11, weight: .bold, design: .rounded)).frame(maxWidth: .infinity).foregroundColor(.secondary)
                case .cardio:
                    Text(LocalizedStringKey("Distance")).font(.system(size: 11, weight: .bold, design: .rounded)).frame(maxWidth: .infinity).foregroundColor(.secondary)
                    Text(LocalizedStringKey("Time")).font(.system(size: 11, weight: .bold, design: .rounded)).frame(maxWidth: .infinity).foregroundColor(.secondary)
                case .duration:
                    Text(LocalizedStringKey("Time")).font(.system(size: 11, weight: .bold, design: .rounded)).frame(maxWidth: .infinity).foregroundColor(.secondary)
                }
            }

            if isAISupported {
                Image(systemName: "brain").font(.system(size: 11, weight: .bold)).frame(width: 44).foregroundColor(.secondary)
            }
            Text(LocalizedStringKey("Check"))
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .frame(width: 44)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 6)
    }

    private var collapsedInfoSection: some View {
        HStack { Spacer(); Text(LocalizedStringKey("Tap to expand")).font(.caption).foregroundColor(.secondary).italic(); Spacer() }.padding(.vertical, 8)
    }

    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                if !isEmbeddedInSuperset {
                    Button(action: { finishExerciseAction() }) {
                        HStack(spacing: 6) {
                            Image(systemName: exercise.isCompleted ? "arrow.uturn.backward" : "checkmark.circle.fill")
                                .font(.system(size: 14, weight: .bold))
                            Text(exercise.isCompleted ? LocalizedStringKey("Resume") : LocalizedStringKey("Finish Exercise"))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(exercise.isCompleted ? themeManager.current.surfaceVariant : themeManager.current.successColor.opacity(0.15))
                        .foregroundColor(exercise.isCompleted ? .secondary : themeManager.current.successColor)
                        .cornerRadius(12)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .disabled(isWorkoutCompleted)
                }

                Button(action: { withAnimation { detailViewModel.addSet(to: exercise, context: context) } }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .bold))
                        Text(LocalizedStringKey("Add Set"))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(themeManager.current.primaryAccent)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .buttonStyle(BorderlessButtonStyle())
                .disabled(exercise.isCompleted || isWorkoutCompleted)
            }
            
            if showEffortSheet && !exercise.isCompleted {
                VStack(spacing: 12) {
                    Text(LocalizedStringKey("Rate Your Effort (RPE)"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                        
                    HStack(spacing: 8) {
                        ForEach(1...10, id: \.self) { val in
                            Button {
                                UISelectionFeedbackGenerator().selectionChanged()
                                exercise.effort = val
                                TrackingManager.shared.track(.rpeGiven(rpeValue: val, exerciseName: exercise.name))
                                withAnimation { showEffortSheet = false }
                                completeExerciseAfterRPE()
                            } label: {
                                Text("\(val)")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 36)
                                    .background(exercise.effort == val ? themeManager.current.secondaryAccent : Color.white.opacity(0.08))
                                    .foregroundColor(exercise.effort == val ? .white : .primary)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(BorderlessButtonStyle())
                        }
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(16)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }.padding(.top, 12)
    }

    private func finishExerciseAction() {
        if exercise.isCompleted { 
            withAnimation { exercise.isCompleted = false } 
        } else { 
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                showEffortSheet.toggle() 
            }
        }
    }

    private func completeExerciseAfterRPE() {
        detailViewModel.handleExerciseFinished(exerciseId: exercise.id, workout: workout, weightUnit: unitsManager.weightUnitString(), onExpandNext: { nextId in onExpandNext?(nextId) })
    }

    private func getIcon() -> String { exercise.type == .strength ? "dumbbell.fill" : (exercise.type == .cardio ? "figure.run" : "stopwatch.fill") }
    private func getColor() -> Color { exercise.type == .strength ? themeManager.current.primaryAccent : (exercise.type == .cardio ? .orange : .purple) }
}
