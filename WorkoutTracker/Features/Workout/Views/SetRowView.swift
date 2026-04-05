// ============================================================
// FILE: WorkoutTracker/Views/Workout/SetRowView.swift
// ============================================================

internal import SwiftUI
import SwiftData

struct SetRowView: View {
    
    // MARK: - Bindings & Properties
    @Bindable var set: WorkoutSet
    @AppStorage("autoStartTimer") private var autoStartTimer: Bool = true
    @Environment(UnitsManager.self) var unitsManager
    
    @State private var showAITracker: Bool = false
    
    let exerciseName: String
    let cached1RM: Double
    let effort: Int
    
    let exerciseType: ExerciseType
    let isLastSet: Bool
    let isExerciseCompleted: Bool
    let isWorkoutCompleted: Bool
    
    var onCheck: (_ set: WorkoutSet, _ shouldStartTimer: Bool, _ suggestedDuration: Int?) -> Void
    
    var prevWeight: Double? = nil
    var prevReps: Int? = nil
    var prevDist: Double? = nil
    var prevTime: Int? = nil
    
    var autoFocus: Bool = false
    
    @State private var showSliderSheet: Bool = false
    @State private var activeBindingType: InputFieldType = .weight
    @State private var hasAutoFocused: Bool = false
    
    // MARK: - Computed Bindings (Type Adapters)
    
    // ✅ ИСПРАВЛЕНИЕ: Вычисления конвертации происходят ТОЛЬКО при чтении/записи (get/set),
    // а не при рендере (body).
    private var repsBinding: Binding<Double?> {
        Binding<Double?>(
            get: { set.reps.map { Double($0) } },
            set: { newValue in
                if let doubleValue = newValue {
                    let validation = InputValidator.validateReps(Int(doubleValue))
                    set.reps = validation.clampedValue
                } else {
                    set.reps = nil
                }
            }
        )
    }
    
    private var timeBinding: Binding<Double?> {
        Binding<Double?>(
            get: { set.time.map { Double($0) } },
            set: { newValue in
                if let doubleValue = newValue {
                    let validation = InputValidator.validateTime(Int(doubleValue))
                    set.time = validation.clampedValue
                } else {
                    set.time = nil
                }
            }
        )
    }
    
    private var weightBinding: Binding<Double?> {
        Binding<Double?>(
            get: {
                guard let kg = set.weight else { return nil }
                return unitsManager.convertFromKilograms(kg)
            },
            set: { newValue in
                if let value = newValue {
                    let validation = InputValidator.validateWeight(unitsManager.convertToKilograms(value))
                    set.weight = validation.clampedValue
                } else {
                    set.weight = nil
                }
            }
        )
    }
    
    private var distanceBinding: Binding<Double?> {
        Binding<Double?>(
            get: {
                guard let m = set.distance else { return nil }
                return unitsManager.convertFromMeters(m)
            },
            set: { newValue in
                if let value = newValue {
                    let validation = InputValidator.validateDistance(unitsManager.convertToMeters(value))
                    set.distance = validation.clampedValue
                } else {
                    set.distance = nil
                }
            }
        )
    }

    private var estimated1RM: Double {
        guard let w = set.weight, let r = set.reps, w > 0, r > 0 else { return 0 }
        return w * (1.0 + Double(r) / 30.0) // Epley formula
    }

    // MARK: - Body
    
    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            indexLabel
            inputsSection
            Spacer(minLength: 0)
            aiTrackerButton
            Spacer(minLength: 0)
            checkButton
        }
        .padding(.vertical, 4)
        .background(set.isCompleted ? Color.green.opacity(0.05) : Color.clear)
        .cornerRadius(6)
        // ✅ ИСПРАВЛЕНИЕ: compositingGroup объединяет слои и предотвращает лишние перерисовки теней
        .compositingGroup()
        .disabled(set.isCompleted || isExerciseCompleted || isWorkoutCompleted)
        .sheet(isPresented: $showSliderSheet) {
            SliderSheetView(
                fieldType: activeBindingType,
                value: getActiveBinding(),
                isPresented: $showSliderSheet
            )
        }
        .onAppear {
            if autoFocus && !hasAutoFocused {
                hasAutoFocused = true
                switch exerciseType {
                case .strength: activeBindingType = .weight
                case .cardio: activeBindingType = .distance
                case .duration: activeBindingType = .timeSec
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { showSliderSheet = true }
            }
        }
    }
    
    // MARK: - Subviews (Components)
    
    private var indexLabel: some View {
        Text("\(set.index)")
            .font(.subheadline).bold()
            .foregroundColor(.secondary)
            .frame(width: 25)
    }
    
    @ViewBuilder
    private var inputsSection: some View {
        switch exerciseType {
        case .strength:
            HStack(spacing: 8) {
                inputColumn(
                    type: .weight,
                    binding: weightBinding,
                    ghostText: prevWeight.map { LocalizationHelper.shared.formatFlexible(unitsManager.convertFromKilograms($0)) }
                )
                inputColumn(type: .reps, binding: repsBinding, ghostText: prevReps.map { "\($0)" })
            }
            
        case .cardio:
            inputColumn(
                type: .distance,
                binding: distanceBinding,
                ghostText: prevDist.map { LocalizationHelper.shared.formatDecimal(unitsManager.convertFromMeters($0)) }
            )
            Spacer()
            inputColumn(type: .timeMin, binding: timeBinding, ghostText: prevTime.map { formatTime($0) })
            
        case .duration:
            inputColumn(type: .timeSec, binding: timeBinding, ghostText: prevTime.map { "\($0)s" })
        }
    }
    
    private func getActiveBinding() -> Binding<Double?> {
        switch activeBindingType {
        case .weight: return weightBinding
        case .reps: return repsBinding
        case .distance: return distanceBinding
        case .timeMin, .timeSec: return timeBinding
        }
    }
    
    private func formatValue(_ value: Double?, type: InputFieldType) -> String {
        guard let value = value, value >= 0 else { return type.title(unitsManager: unitsManager) }
        switch type {
        case .weight: return LocalizationHelper.shared.formatFlexible(value)
        case .reps: return LocalizationHelper.shared.formatInteger(value)
        case .distance: return LocalizationHelper.shared.formatDecimal(value)
        case .timeMin, .timeSec: return LocalizationHelper.shared.formatInteger(value)
        }
    }
    
    private func inputColumn(type: InputFieldType, binding: Binding<Double?>, ghostText: String?) -> some View {
        VStack(spacing: 2) {
            Button {
                activeBindingType = type
                showSliderSheet = true
            } label: {
                Text(formatValue(binding.wrappedValue, type: type))
                    .font(.headline)
                    .foregroundColor(binding.wrappedValue != nil ? .primary : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    // ✅ ИСПРАВЛЕНИЕ: Меньше вычислений цветов (drawingGroup)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }
            .buttonStyle(BorderlessButtonStyle())
            
            if let ghost = ghostText {
                Text(ghost).font(.system(size: 10)).foregroundColor(.gray)
            }
        }
        .frame(width: 100)
    }
    
    private var checkButton: some View {
        Button(action: toggleComplete) {
            Image(systemName: set.isCompleted ? "checkmark.square.fill" : "square")
                .resizable()
                .frame(width: 32, height: 32)
                .foregroundColor(set.isCompleted ? .green : .gray.opacity(0.5))
        }
        .buttonStyle(BorderlessButtonStyle())
        .disabled(isExerciseCompleted || isWorkoutCompleted)
    }
    
    @ViewBuilder
    private var aiTrackerButton: some View {
        let category = ExerciseCategory.determine(from: exerciseName)
        let supportedCategories: [ExerciseCategory] = [.squat, .curl, .press, .deadlift, .pull]
        let isAISupported = supportedCategories.contains(category)
        
        Button {
            showAITracker = true
        } label: {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 20))
                .symbolRenderingMode(.multicolor)
                .foregroundStyle(
                    isAISupported
                        ? AnyShapeStyle(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                        : AnyShapeStyle(Color.gray.opacity(0.4))
                )
                .frame(width: 32, height: 32)
        }
        .buttonStyle(BorderlessButtonStyle())
        .disabled(!isAISupported || isExerciseCompleted || isWorkoutCompleted)
        .fullScreenCover(isPresented: $showAITracker) {
            AITrackerView(exerciseName: exerciseName) { countedReps in
                if countedReps > 0 {
                    set.reps = countedReps
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        if !set.isCompleted { toggleComplete() }
                    }
                }
            }
        }
    }
    
    // MARK: - Logic
    
    func toggleComplete() {
           guard !isExerciseCompleted && !isWorkoutCompleted else { return }
           
           withAnimation { set.isCompleted.toggle() }
           
           // ✅ ФОРСИРУЕМ СОХРАНЕНИЕ: База данных мгновенно узнает о галочке
           try? set.modelContext?.save()
           
           if set.isCompleted {
               let generator = UIImpactFeedbackGenerator(style: .medium)
               generator.impactOccurred()
               
               var suggestedDuration: Int? = nil
               if exerciseType == .strength {
                   if effort >= 8 { suggestedDuration = 180 }
                   else if effort >= 6 { suggestedDuration = 120 }
                   else { suggestedDuration = 90 }
               }
               
               if autoStartTimer && !isLastSet {
                   onCheck(set, true, suggestedDuration)
               } else {
                   onCheck(set, false, nil)
               }
           }
       }
    
    private func formatTime(_ seconds: Int) -> String {
        return "\(seconds / 60):\(String(format: "%02d", seconds % 60))"
    }
}
