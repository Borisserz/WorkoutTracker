// ============================================================
// FILE: WorkoutTracker/Features/Workout/Views/SetRowView.swift
// ============================================================

internal import SwiftUI
import SwiftData

struct SetRowView: View {
    @Bindable var set: WorkoutSet
    @AppStorage("autoStartTimer") private var autoStartTimer: Bool = true
    @Environment(UnitsManager.self) var unitsManager
    @State private var showSetTypeSheet: Bool = false
    @State private var showAITracker: Bool = false
    
    let exerciseName: String
    let cached1RM: Double
    let effort: Int
    
    let exerciseType: ExerciseType
    let isLastSet: Bool
    let isExerciseCompleted: Bool
    let isWorkoutCompleted: Bool
    
    var onCheck: (_ set: WorkoutSet, _ shouldStartTimer: Bool, _ suggestedDuration: Int?) -> Void
    var onDataChange: (() -> Void)? = nil // ✅ FIX: Добавлен триггер обновления
    
    var prevWeight: Double? = nil
    var prevReps: Int? = nil
    var prevDist: Double? = nil
    var prevTime: Int? = nil
    
    var autoFocus: Bool = false
    
    @State private var showSliderSheet: Bool = false
    @State private var activeBindingType: InputFieldType = .weight
    @State private var hasAutoFocused: Bool = false
    
    private var repsBinding: Binding<Double?> {
        Binding<Double?>(
            get: { set.reps.map { Double($0) } },
            set: {
                set.reps = $0.map { InputValidator.validateReps(Int($0)).clampedValue }
                onDataChange?() // ✅ FIX: Мгновенный пересчет при вводе
            }
        )
    }
    private var timeBinding: Binding<Double?> {
        Binding<Double?>(
            get: { set.time.map { Double($0) } },
            set: {
                set.time = $0.map { InputValidator.validateTime(Int($0)).clampedValue }
                onDataChange?() // ✅ FIX: Мгновенный пересчет при вводе
            }
        )
    }
    private var weightBinding: Binding<Double?> {
        Binding<Double?>(
            get: { set.weight.map { unitsManager.convertFromKilograms($0) } },
            set: {
                set.weight = $0.map { InputValidator.validateWeight(unitsManager.convertToKilograms($0)).clampedValue }
                onDataChange?() // ✅ FIX: Мгновенный пересчет при вводе
            }
        )
    }
    private var distanceBinding: Binding<Double?> {
        Binding<Double?>(
            get: { set.distance.map { unitsManager.convertFromMeters($0) } },
            set: {
                set.distance = $0.map { InputValidator.validateDistance(unitsManager.convertToMeters($0)).clampedValue }
                onDataChange?() // ✅ FIX: Мгновенный пересчет при вводе
            }
        )
    }

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            indexLabel
            inputsSection
            // Spacer() удален, теперь инпуты растягиваются на всё доступное пространство
            aiTrackerButton
            checkButton
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(set.isCompleted ? Color.green.opacity(0.1) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(set.isCompleted ? Color.green.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: set.isCompleted)
        .compositingGroup()
        .disabled(set.isCompleted || isExerciseCompleted || isWorkoutCompleted)
        .sheet(isPresented: $showSliderSheet) {
            SliderSheetView(fieldType: activeBindingType, value: getActiveBinding(), isPresented: $showSliderSheet)
        }
        .onAppear {
            if autoFocus && !hasAutoFocused {
                hasAutoFocused = true
                activeBindingType = exerciseType == .strength ? .weight : (exerciseType == .cardio ? .distance : .timeSec)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { showSliderSheet = true }
            }
        }
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
                selectedType: Binding(get: { set.type }, set: { set.type = $0; try? set.modelContext?.save() }),
                onRemove: { if let ctx = set.modelContext, let ex = set.exercise { ex.removeSafeSet(set); ctx.delete(set); try? ctx.save() } }
            )
        }
    }
    
    @ViewBuilder
    private var inputsSection: some View {
        HStack(spacing: 8) {
            switch exerciseType {
            case .strength:
                inputColumn(type: .weight, binding: weightBinding, ghostText: prevWeight.map { LocalizationHelper.shared.formatFlexible(unitsManager.convertFromKilograms($0)) })
                inputColumn(type: .reps, binding: repsBinding, ghostText: prevReps.map { "\($0)" })
            case .cardio:
                inputColumn(type: .distance, binding: distanceBinding, ghostText: prevDist.map { LocalizationHelper.shared.formatDecimal(unitsManager.convertFromMeters($0)) })
                inputColumn(type: .timeMin, binding: timeBinding, ghostText: prevTime.map { formatTime($0) })
            case .duration:
                inputColumn(type: .timeSec, binding: timeBinding, ghostText: prevTime.map { "\($0)s" })
            }
        }
    }
    
    private func getActiveBinding() -> Binding<Double?> {
        switch activeBindingType { case .weight: return weightBinding; case .reps: return repsBinding; case .distance: return distanceBinding; case .timeMin, .timeSec: return timeBinding }
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
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(binding.wrappedValue != nil ? .primary : .secondary)
                    .frame(maxWidth: .infinity) // Динамическая ширина вместо жесткой привязки
                    .frame(height: 44)
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            
            if let ghost = ghostText {
                Text(ghost).font(.system(size: 10, weight: .medium, design: .rounded)).foregroundColor(.gray)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private var checkButton: some View {
        Button(action: toggleComplete) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(set.isCompleted ? Color.green : Color.gray.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: "checkmark")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(set.isCompleted ? .white : Color.gray.opacity(0.4))
                    .symbolEffect(.bounce, value: set.isCompleted)
            }
        }
        .buttonStyle(.plain)
        .disabled(isExerciseCompleted || isWorkoutCompleted)
    }
    
    @ViewBuilder
    private var aiTrackerButton: some View {
        let category = ExerciseCategory.determine(from: exerciseName)
        let isAISupported = [.squat, .curl, .press, .deadlift, .pull].contains(category)
        
        if isAISupported {
            Button {
                showAITracker = true
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(LinearGradient(colors: [.purple.opacity(0.15), .indigo.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(LinearGradient(colors: [.purple, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
                }
            }
            .buttonStyle(.plain)
            .disabled(isExerciseCompleted || isWorkoutCompleted)
            .fullScreenCover(isPresented: $showAITracker) {
                AITrackerView(exerciseName: exerciseName) { countedReps in
                    if countedReps > 0 {
                        set.reps = countedReps
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { if !set.isCompleted { toggleComplete() } }
                    }
                }
            }
        }
    }
    
    private func toggleComplete() {
           guard !isExerciseCompleted && !isWorkoutCompleted else { return }
           withAnimation { set.isCompleted.toggle() }
           try? set.modelContext?.save()
           
           if set.isCompleted {
               let generator = UIImpactFeedbackGenerator(style: .medium)
               generator.impactOccurred()
               
               var suggestedDuration: Int? = nil
               if exerciseType == .strength {
                   if effort >= 8 { suggestedDuration = 180 } else if effort >= 6 { suggestedDuration = 120 } else { suggestedDuration = 90 }
               }
               onCheck(set, autoStartTimer && !isLastSet, autoStartTimer && !isLastSet ? suggestedDuration : nil)
           } else {
               // ✅ FIX: Ensure the ViewModel recalculates analytics even if the set is unchecked!
               onCheck(set, false, nil)
           }
       }

    
    private func formatTime(_ seconds: Int) -> String { "\(seconds / 60):\(String(format: "%02d", seconds % 60))" }
}
