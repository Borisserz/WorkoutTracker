//
//  ConfigureExerciseView.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 24.12.25.
//

internal import SwiftUI

struct ConfigureExerciseView: View {
    
    // MARK: - Environment
    @Environment(\.dismiss) var dismiss
    @Environment(WorkoutViewModel.self) var viewModel
    @Environment(UnitsManager.self) var unitsManager
    
    // MARK: - Input Parameters
    let exerciseName: String
    let muscleGroup: String
    var exerciseType: ExerciseType = .strength
    var onAdd: (Exercise) -> Void
    
    // MARK: - State
    @State private var form = ExerciseFormState()
    @State private var showValidationAlert = false
    
    @State private var hasAutoFilled = false
    @State private var showOverloadBanner = false
    @State private var recommendedWeight: Double = 0.0
    
    // MARK: - Binding Adapters
    // Адаптеры остаются, так как они связывают FormState с UI и UnitsManager
    private var weightBinding: Binding<Double?> {
        Binding(
            get: { form.weight.map { unitsManager.convertFromKilograms($0) } },
            set: { form.weight = $0.map { unitsManager.convertToKilograms($0) } }
        )
    }
    
    private var distanceBinding: Binding<Double?> {
        Binding(
            get: { form.distance.map { unitsManager.convertFromMeters($0) } },
            set: { form.distance = $0.map { unitsManager.convertToMeters($0) } }
        )
    }
    
    private var minutesBinding: Binding<Double?> {
        Binding(
            get: { form.minutes.map { Double($0) } },
            set: { form.minutes = $0.map { Int($0) } }
        )
    }
    
    private var secondsBinding: Binding<Double?> {
        Binding(
            get: { form.seconds.map { Double($0) } },
            set: { form.seconds = $0.map { Int($0) } }
        )
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Form {
                if showOverloadBanner { overloadBannerSection }
                
                Section(header: Text("Configuration")) {
                    HStack {
                        Text("Exercise"); Spacer()
                        Text(exerciseName).bold()
                    }
                    
                    switch exerciseType {
                    case .strength: strengthConfig
                    case .cardio: cardioConfig
                    case .duration: durationConfig
                    }
                }
                
                Button("Add Exercise") { handleSave() }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.borderedProminent)
            }
            .navigationTitle("Configure")
            .alert("Invalid Input", isPresented: $showValidationAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(form.validationErrorMessage ?? "Unknown error")
            }
            .onAppear {
                if !hasAutoFilled {
                    loadLastPerformance()
                    hasAutoFilled = true
                }
            }
        }
    }
    
    // MARK: - View Components
    
    private var overloadBannerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis").foregroundColor(.green)
                    Text("Progressive Overload").font(.headline).foregroundColor(.green)
                }
                
                let convertedWeight = unitsManager.convertFromKilograms(recommendedWeight)
                let weightStr = convertedWeight.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", convertedWeight) : String(format: "%.1f", convertedWeight)
                
                Text("Your forecast allows it! Try **\(weightStr) \(unitsManager.weightUnitString())** today for better results.")
                    .font(.subheadline).foregroundColor(.primary)
                
                HStack(spacing: 12) {
                    Button("Discard") { withAnimation { showOverloadBanner = false } }
                        .buttonStyle(.bordered).tint(.gray).frame(maxWidth: .infinity)
                    
                    Button("Apply") {
                        withAnimation {
                            form.weight = recommendedWeight
                            showOverloadBanner = false
                        }
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                    }
                    .buttonStyle(.borderedProminent).tint(.green).frame(maxWidth: .infinity)
                }
                .padding(.top, 4)
            }
            .padding(.vertical, 4)
        }
    }
    
    @ViewBuilder private var strengthConfig: some View {
        Stepper("Sets: \(form.sets)", value: $form.sets, in: 1...20)
        Stepper("Reps: \(form.reps)", value: $form.reps, in: 1...100)
        HStack {
            Text("Weight (\(unitsManager.weightUnitString())):")
            Spacer()
            ClearableTextField(placeholder: unitsManager.weightUnitString(), value: weightBinding)
                .frame(width: 80)
        }
    }
    
    @ViewBuilder private var cardioConfig: some View {
        HStack {
            Text("Distance (\(unitsManager.distanceUnitString())):")
            Spacer()
            ClearableTextField(placeholder: unitsManager.distanceUnitString(), value: distanceBinding)
                .frame(width: 80)
        }
        timePickerRow(label: "Duration")
    }
    
    @ViewBuilder private var durationConfig: some View {
        Stepper("Sets: \(form.sets)", value: $form.sets, in: 1...10)
        timePickerRow(label: "Time per set")
    }
    
    private func timePickerRow(label: String) -> some View {
        HStack {
            Text(LocalizedStringKey(label))
            Spacer()
            HStack(spacing: 5) {
                ClearableTextField(placeholder: "0", value: minutesBinding)
                    .frame(width: 50)
                Text("min")
                ClearableTextField(placeholder: "0", value: secondsBinding)
                    .frame(width: 50)
                    .onChange(of: form.seconds) { _, newValue in
                        if let s = newValue, s > 59 { form.seconds = 59 }
                    }
                Text("sec")
            }
        }
    }
    
    // MARK: - Logic
    
    private func loadLastPerformance() {
        guard let lastPerf = viewModel.lastPerformancesCache[exerciseName] else { return }
        let lastSets = lastPerf.sortedSets.filter { $0.type != .warmup && $0.isCompleted }
        guard !lastSets.isEmpty else { return }
        
        if exerciseType == .strength {
            form.sets = lastSets.count
            form.reps = lastSets.first?.reps ?? 10
            let lastMax = lastSets.compactMap { $0.weight }.max() ?? 0.0
            form.weight = lastMax > 0 ? lastMax : nil
            
            if lastMax > 0 {
                self.recommendedWeight = lastMax + 2.5
                withAnimation { self.showOverloadBanner = true }
            }
        } else if exerciseType == .cardio, let firstSet = lastSets.first {
            form.distance = firstSet.distance
            let t = firstSet.time ?? 0
            form.minutes = t / 60
            form.seconds = t % 60
        } else if exerciseType == .duration, let firstSet = lastSets.first {
            form.sets = lastSets.count
            let t = firstSet.time ?? 0
            form.minutes = t / 60
            form.seconds = t % 60
        }
    }
    
    private func handleSave() {
        guard form.validate(for: exerciseType, unitsManager: unitsManager) else {
            showValidationAlert = true
            return
        }
        
        let setsCount = (exerciseType == .cardio) ? 1 : form.sets
        let totalSeconds = ((form.minutes ?? 0) * 60) + (form.seconds ?? 0)
        
        var generatedSets: [WorkoutSet] = []
        for i in 1...setsCount {
            generatedSets.append(WorkoutSet(
                index: i,
                weight: (exerciseType == .strength) ? form.weight : nil,
                reps: (exerciseType == .strength) ? form.reps : nil,
                distance: (exerciseType == .cardio) ? form.distance : nil,
                time: (totalSeconds > 0) ? totalSeconds : nil,
                isCompleted: false,
                type: .normal
            ))
        }
        
        let newExercise = Exercise(
            name: exerciseName,
            muscleGroup: muscleGroup,
            type: exerciseType,
            sets: setsCount,
            reps: form.reps,
            weight: form.weight ?? 0.0,
            distance: form.distance,
            timeSeconds: totalSeconds > 0 ? totalSeconds : nil,
            effort: 5,
            setsList: generatedSets
        )
        
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        onAdd(newExercise)
        dismiss()
    }
}
