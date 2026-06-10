

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
                        // Save is handled by handleSetCompleted → WorkoutStore (@ModelActor)
                        
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
                            .lineLimit(nil)
                            .minimumScaleFactor(0.8)
                            .allowsTightening(true)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .buttonStyle(.plain)

                Button { 
                    showTechniqueSheet = true 
                } label: { 
                    HStack(spacing: 4) {
                        Image(systemName: "info.circle.fill")
                        Text(LocalizedStringKey("Technique"))
                    }
                    .font(.caption2.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(themeManager.current.primaryAccent.opacity(0.15))
                    .foregroundColor(themeManager.current.primaryAccent)
                    .clipShape(Capsule())
                }
                .buttonStyle(BorderlessButtonStyle())

                Spacer()

                let completedCount = exercise.setsList.filter { $0.isCompleted }.count
                let totalCount = exercise.setsList.count

                HStack(spacing: 4) {
                    Image(systemName: completedCount == totalCount && totalCount > 0 ? "checkmark.circle.fill" : "checkmark.circle")
                        .foregroundColor(completedCount == totalCount && totalCount > 0 ? .green : (completedCount > 0 ? themeManager.current.primaryAccent : .gray)).font(.caption)
                    Text("\(completedCount)/\(totalCount)").font(.subheadline).foregroundColor(.secondary)
                }

                Menu {
                    Button { showHistory = true } label: { Label(LocalizedStringKey("Exercise Info & History"), systemImage: "info.circle") }
                    if !isEmbeddedInSuperset { Button { detailViewModel.activeEvent = .showSwapExercise(exercise) } label: { Label(LocalizedStringKey("Swap Exercise"), systemImage: "arrow.triangle.2.circlepath") } }
                    Button(role: .destructive) { detailViewModel.removeExercise(exercise, from: workout) } label: { Label(LocalizedStringKey("Remove Exercise"), systemImage: "trash") }
                } label: { Image(systemName: "ellipsis").foregroundColor(.gray).padding(10) }
                .highPriorityGesture(TapGesture().onEnded { })
            }

            let targetMuscles = MuscleDisplayHelper.getTargetMuscleNames(for: exercise.name, muscleGroup: exercise.muscleGroup)
            if !targetMuscles.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "figure.strengthtraining.traditional").font(.caption2).foregroundColor(.secondary)
                    Text(targetMuscles.joined(separator: ", "))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .allowsTightening(true)
                        .fixedSize(horizontal: false, vertical: true)
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

            Button(action: { showHistory = true }) {
                HStack {
                    Image(systemName: "book.pages")
                    Text(LocalizedStringKey("Exercise Info & History"))
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
                .foregroundColor(colorScheme == .dark ? .white : .black)
                .cornerRadius(14)
            }
            .buttonStyle(BorderlessButtonStyle())

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
                                    .background(exercise.effort == val ? Color.purple : Color.gray.opacity(0.15))
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
