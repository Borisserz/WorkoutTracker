//
//  SetRowView.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 24.12.25.
//
//  Строка одного сета в таблице упражнения.
//  Содержит:
//  1. Номер сета.
//  2. Поля ввода (Вес/Повторы/Время) с подсказками из прошлой тренировки.
//  3. Кнопку типа сета (Разминка/Обычный).
//  4. Чекбокс завершения.
//

internal import SwiftUI
import SwiftData

struct SetRowView: View {
    
    // MARK: - Bindings & Properties
    
    @Bindable var set: WorkoutSet 
    @AppStorage("autoStartTimer") private var autoStartTimer: Bool = true
    // ИСПРАВЛЕНИЕ: Используем @ObservedObject для синглтона. Использование @StateObject на синглтонах внутри повторяющихся списков приводит к зависанию!
    @ObservedObject private var unitsManager = UnitsManager.shared
    let exerciseType: ExerciseType
    let isLastSet: Bool
    let isExerciseCompleted: Bool 
    let isWorkoutCompleted: Bool 
    
    var onCheck: (_ shouldStartTimer: Bool) -> Void
    
    var prevWeight: Double? = nil
    var prevReps: Int? = nil
    var prevDist: Double? = nil
    var prevTime: Int? = nil
    
    var autoFocus: Bool = false
    
    @State private var showSliderSheet: Bool = false
    @State private var activeBindingType: InputFieldType = .weight
    @State private var hasAutoFocused: Bool = false 
    
    // MARK: - Computed Bindings (Type Adapters)
    
    private var repsBinding: Binding<Double?> {
        Binding<Double?>(
            get: { set.reps.map { Double($0) } },
            set: { newValue in
                if let doubleValue = newValue {
                    let intValue = Int(doubleValue)
                    let validation = InputValidator.validateReps(intValue)
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
                    let intValue = Int(doubleValue)
                    let validation = InputValidator.validateTime(intValue)
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
                    let kg = unitsManager.convertToKilograms(value)
                    let validation = InputValidator.validateWeight(kg)
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
                    let m = unitsManager.convertToMeters(value)
                    let validation = InputValidator.validateDistance(m)
                    set.distance = validation.clampedValue
                } else {
                    set.distance = nil
                }
            }
        )
    }

    // MARK: - Body
    
    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            
            indexLabel
            
            inputsSection
            
            Spacer(minLength: 0)
            
            setTypeButton
            
            Spacer(minLength: 0)
            
            checkButton
        }
        .padding(.vertical, 4)
        .background(set.isCompleted ? Color.green.opacity(0.05) : Color.clear)
        .cornerRadius(6)
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
                case .strength:
                    activeBindingType = .weight
                case .cardio:
                    activeBindingType = .distance
                case .duration:
                    activeBindingType = .timeSec
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    showSliderSheet = true
                }
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
            HStack(spacing: 4) {
                inputColumn(
                    type: .weight,
                    binding: weightBinding,
                    ghostText: prevWeight.map { 
                        let converted = unitsManager.convertFromKilograms($0)
                        return LocalizationHelper.shared.formatFlexible(converted)
                    }
                )
                
                inputColumn(
                    type: .reps,
                    binding: repsBinding,
                    ghostText: prevReps.map { "\($0)" }
                )
            }
            
        case .cardio:
            inputColumn(
                type: .distance,
                binding: distanceBinding,
                ghostText: prevDist.map { 
                    let converted = unitsManager.convertFromMeters($0)
                    return LocalizationHelper.shared.formatDecimal(converted) 
                }
            )
            
            Spacer()
            
            inputColumn(
                type: .timeMin,
                binding: timeBinding,
                ghostText: prevTime.map { formatTime($0) }
            )
            
        case .duration:
            inputColumn(
                type: .timeSec,
                binding: timeBinding,
                ghostText: prevTime.map { "\($0)s" }
            )
        }
    }
    
    private func getActiveBinding() -> Binding<Double?> {
        switch activeBindingType {
        case .weight:
            return weightBinding
        case .reps:
            return repsBinding
        case .distance:
            return distanceBinding
        case .timeMin, .timeSec:
            return timeBinding
        }
    }
    
    private func formatValue(_ value: Double?, type: InputFieldType) -> String {
        guard let value = value, value >= 0 else {
            return type.title(unitsManager: unitsManager)
        }
        
        switch type {
        case .weight:
            return LocalizationHelper.shared.formatFlexible(value)
        case .reps:
            return LocalizationHelper.shared.formatInteger(value)
        case .distance:
            return LocalizationHelper.shared.formatDecimal(value)
        case .timeMin, .timeSec:
            return LocalizationHelper.shared.formatInteger(value)
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
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }
            .buttonStyle(BorderlessButtonStyle())
            
            if let ghost = ghostText {
                Text(ghost)
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
            }
        }
        .frame(width: 100)
    }
    
    private var setTypeButton: some View {
        Button {
            guard !isExerciseCompleted && !isWorkoutCompleted else { return }
            set.type = (set.type == .normal) ? .warmup : .normal
        } label: {
            Text(set.type.rawValue)
                .font(.system(size: 12, weight: .bold))
                .frame(width: 32, height: 32)
                .background(set.type.color.opacity(0.8))
                .foregroundColor(set.type == .warmup ? .black : .white)
                .clipShape(Circle())
        }
        .buttonStyle(BorderlessButtonStyle())
        .disabled(isExerciseCompleted || isWorkoutCompleted) 
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
    
    // MARK: - Logic
    
    func toggleComplete() {
        guard !isExerciseCompleted && !isWorkoutCompleted else { return }
        
        withAnimation { set.isCompleted.toggle() }
        
        if set.isCompleted {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            if autoStartTimer && !isLastSet {
                onCheck(true) 
            } else {
                onCheck(false) 
            }
        }
    }
    
    private func formatTime(_ seconds: Int) -> String {
        return "\(seconds / 60):\(String(format: "%02d", seconds % 60))"
    }
}
