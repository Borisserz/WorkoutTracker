

internal import SwiftUI
import SwiftData

struct SetRowView: View {
    @Bindable var set: WorkoutSet
    @AppStorage("autoStartTimer") private var autoStartTimer: Bool = true
    @Environment(UnitsManager.self) var unitsManager
    @Environment(\.colorScheme) private var colorScheme 
    @Environment(ThemeManager.self) private var themeManager
    @State private var showSetTypeSheet: Bool = false
    @State private var showAITracker: Bool = false
    @State private var isAISupported: Bool = false
    @State private var swipeOffset: CGFloat = 0

    let exerciseName: String
    let cached1RM: Double
    let effort: Int

    let exerciseType: ExerciseType
    let isLastSet: Bool
    let isExerciseCompleted: Bool
    let isWorkoutCompleted: Bool

    var onCheck: (_ set: WorkoutSet, _ shouldStartTimer: Bool, _ suggestedDuration: Int?) -> Void
    var onDataChange: (() -> Void)? = nil

    var prevWeight: Double? = nil
    var prevReps: Int? = nil
    var prevDist: Double? = nil
    var prevTime: Int? = nil

    var autoFocus: Bool = false
    
    @FocusState private var focusedField: InputFieldType?
    @State private var hasAutoFocused: Bool = false

    private var previousPerformanceText: String {
        switch exerciseType {
        case .strength:
            if let w = prevWeight, let r = prevReps {
                let convertedW = unitsManager.convertFromKilograms(w)
                return "\(LocalizationHelper.shared.formatFlexible(convertedW)) × \(r)"
            } else if let r = prevReps {
                return "— × \(r)"
            } else {
                return "—"
            }
        case .cardio:
            if let d = prevDist, let t = prevTime {
                let convertedD = unitsManager.convertFromMeters(d)
                return "\(LocalizationHelper.shared.formatDecimal(convertedD)) × \(formatTime(t))"
            } else if let d = prevDist {
                let convertedD = unitsManager.convertFromMeters(d)
                return "\(LocalizationHelper.shared.formatDecimal(convertedD))"
            } else if let t = prevTime {
                return formatTime(t)
            } else {
                return "—"
            }
        case .duration:
            if let t = prevTime {
                return "\(t)s"
            } else {
                return "—"
            }
        }
    }

    private var previousColumn: some View {
        Text(previousPerformanceText)
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundColor(.secondary)
            .frame(width: 70, alignment: .leading)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }

    private var repsBinding: Binding<Double?> {
        Binding<Double?>(get: { set.reps.map { Double($0) } }, set: { set.reps = $0.map { InputValidator.validateReps(Int($0)).clampedValue }; onDataChange?() })
    }
    private var timeBinding: Binding<Double?> {
        Binding<Double?>(get: { set.time.map { Double($0) } }, set: { set.time = $0.map { InputValidator.validateTime(Int($0)).clampedValue }; onDataChange?() })
    }
    private var weightBinding: Binding<Double?> {
        Binding<Double?>(get: { set.weight.map { unitsManager.convertFromKilograms($0) } }, set: { set.weight = $0.map { InputValidator.validateWeight(unitsManager.convertToKilograms($0)).clampedValue }; onDataChange?() })
    }
    private var distanceBinding: Binding<Double?> {
        Binding<Double?>(get: { set.distance.map { unitsManager.convertFromMeters($0) } }, set: { set.distance = $0.map { InputValidator.validateDistance(unitsManager.convertToMeters($0)).clampedValue }; onDataChange?() })
    }

    var body: some View {
        let isSetCompleted = set.isCompleted
        let bgColor = isSetCompleted ? PastelTheme.pastelEmerald.opacity(0.12) : PastelTheme.cardSurfaceSubtle
        let strokeColor = isSetCompleted ? PastelTheme.pastelEmerald.opacity(0.3) : PastelTheme.cardBorder

        return HStack(alignment: .center, spacing: 8) {
            indexLabel
            previousColumn
            inputsSection
            aiTrackerButton
            checkButton
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(bgColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(strokeColor, lineWidth: 1)
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: set.isCompleted)
        .offset(x: swipeOffset)
        .gesture(
            DragGesture(minimumDistance: 30)
                .onChanged { value in
                    guard !set.isCompleted && !isExerciseCompleted && !isWorkoutCompleted else { return }
                    if abs(value.translation.width) > abs(value.translation.height) {
                        swipeOffset = value.translation.width / 3
                    }
                }
                .onEnded { value in
                    guard !set.isCompleted && !isExerciseCompleted && !isWorkoutCompleted else { return }
                    if abs(value.translation.width) > 60 {
                        let swipeDirection: CGFloat = value.translation.width > 0 ? 1 : -1
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            swipeOffset = swipeDirection * 200
                        }
                        
                        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            swipeToLog()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                swipeOffset = 0
                            }
                        }
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            swipeOffset = 0
                        }
                    }
                }
        )
        .compositingGroup()
        .disabled(isExerciseCompleted || isWorkoutCompleted)
        .onAppear {
            if autoFocus && !hasAutoFocused {
                hasAutoFocused = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { 
                    focusedField = exerciseType == .strength ? .weight : (exerciseType == .cardio ? .distance : .timeSec) 
                }
            }
        }
        .task {
            let pattern = await ExerciseDatabaseService.shared.getPattern(for: exerciseName)
            isAISupported = pattern != .unsupported
        }
    }

    private func swipeToLog() {
        if set.weight == nil && prevWeight != nil { set.weight = prevWeight }
        if set.reps == nil && prevReps != nil { set.reps = prevReps }
        if set.distance == nil && prevDist != nil { set.distance = prevDist }
        if set.time == nil && prevTime != nil { set.time = prevTime }
        onDataChange?()
        toggleComplete()
    }

    private var indexLabel: some View {
        Button {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            showSetTypeSheet = true
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(set.type.displayColor.opacity(0.15))
                Text(set.type.shortIndicator(index: set.index))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(set.type.displayColor)
            }
            .frame(width: 32, height: 44)
        }
        .buttonStyle(.plain)
        .disabled(set.isCompleted || isExerciseCompleted || isWorkoutCompleted)
        .sheet(isPresented: $showSetTypeSheet) {
            SetTypeSelectionSheet(
                selectedType: Binding(get: { set.type }, set: { set.type = $0; onDataChange?() }),
                onRemove: { if let ctx = set.modelContext, let ex = set.exercise { ex.removeSafeSet(set); ctx.delete(set); onDataChange?() } }
            )
        }
    }

    @ViewBuilder
    private var inputsSection: some View {
        HStack(spacing: 8) {
            switch exerciseType {
            case .strength:
                inputColumn(type: .weight, binding: weightBinding)
                inputColumn(type: .reps, binding: repsBinding)
            case .cardio:
                inputColumn(type: .distance, binding: distanceBinding)
                inputColumn(type: .timeMin, binding: timeBinding)
            case .duration:
                inputColumn(type: .timeSec, binding: timeBinding)
            }
        }
    }

    private func textBinding(for binding: Binding<Double?>) -> Binding<String> {
        Binding<String>(
            get: {
                if let val = binding.wrappedValue {
                    return val.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", val) : String(val)
                } else {
                    return ""
                }
            },
            set: {
                if let val = Double($0.replacingOccurrences(of: ",", with: ".")) {
                    binding.wrappedValue = val
                } else if $0.isEmpty {
                    binding.wrappedValue = nil
                }
            }
        )
    }

    private func inputColumn(type: InputFieldType, binding: Binding<Double?>) -> some View {
        HStack(spacing: 0) {
            TextField(type.title(unitsManager: unitsManager), text: textBinding(for: binding))
                .keyboardType(type == .reps ? .numberPad : .decimalPad)
                .multilineTextAlignment(.center)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(binding.wrappedValue != nil ? (colorScheme == .dark ? .white : .black) : .secondary)
                .focused($focusedField, equals: type)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(PastelTheme.cardSurfaceSubtle)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(focusedField == type ? PastelTheme.cardBorderFocused : PastelTheme.cardBorder, lineWidth: 1)
                )
        }
    }

    private var checkButton: some View {
        Button(action: toggleComplete) {
            ZStack {
                if set.isCompleted {
                    RoundedRectangle(cornerRadius: PastelTheme.ButtonMetrics.squareRadius, style: .continuous)
                        .fill(PastelTheme.pastelEmerald)
                        .frame(width: PastelTheme.ButtonMetrics.squareSize, height: PastelTheme.ButtonMetrics.squareSize)

                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .symbolEffect(.bounce, value: set.isCompleted)
                } else {
                    RoundedRectangle(cornerRadius: PastelTheme.ButtonMetrics.squareRadius, style: .continuous)
                        .fill(PastelTheme.cardSurfaceSubtle)
                        .frame(width: PastelTheme.ButtonMetrics.squareSize, height: PastelTheme.ButtonMetrics.squareSize)
                        .overlay(
                            RoundedRectangle(cornerRadius: PastelTheme.ButtonMetrics.squareRadius, style: .continuous)
                                .stroke(PastelTheme.cardBorder, lineWidth: 1)
                        )

                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(PastelTheme.textTertiary.opacity(0.4))
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isExerciseCompleted || isWorkoutCompleted)
    }

    @ViewBuilder
    private var aiTrackerButton: some View {
        if isAISupported {
            Button {
                showAITracker = true
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: PastelTheme.ButtonMetrics.squareRadius, style: .continuous)
                        .fill(PastelTheme.cardSurfaceSubtle)
                        .frame(width: PastelTheme.ButtonMetrics.squareSize, height: PastelTheme.ButtonMetrics.squareSize)
                        .overlay(
                            RoundedRectangle(cornerRadius: PastelTheme.ButtonMetrics.squareRadius, style: .continuous)
                                .stroke(PastelTheme.cardBorder, lineWidth: 1)
                        )

                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(PastelTheme.pastelLavender)
                }
            }
            .buttonStyle(.plain)
            .disabled(isExerciseCompleted || isWorkoutCompleted)
            .fullScreenCover(isPresented: $showAITracker) {
                AITrackerView(exerciseName: exerciseName) { countedReps in
                    if countedReps > 0 {
                        set.reps = countedReps
                        onDataChange?()
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { if !set.isCompleted { toggleComplete() } }
                }
            }
        }
    }

    private func toggleComplete() {
           guard !isExerciseCompleted && !isWorkoutCompleted else { return }
           withAnimation { set.isCompleted.toggle() }
           // Do NOT call modelContext.save() here — route through onDataChange/onCheck
           // so that WorkoutDetailViewModel orchestrates the save on its background context.

           if set.isCompleted {
               let generator = UIImpactFeedbackGenerator(style: .medium)
               generator.impactOccurred()

               var suggestedDuration: Int? = nil
               if exerciseType == .strength {
                   if effort >= 8 { suggestedDuration = 180 } else if effort >= 6 { suggestedDuration = 120 } else { suggestedDuration = 90 }
               }
               onCheck(set, autoStartTimer && !isLastSet, autoStartTimer && !isLastSet ? suggestedDuration : nil)
           } else {
               onCheck(set, false, nil)
           }
       }

    private func formatTime(_ seconds: Int) -> String { "\(seconds / 60):\(String(format: "%02d", seconds % 60))" }
}
